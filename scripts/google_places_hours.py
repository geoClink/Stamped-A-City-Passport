#!/usr/bin/env python3
"""
Use Google Places API to find opening hours for candidate POIs and infer meal availability.
Reads `scripts/restaurant_candidates.json` and writes `scripts/restaurant_hours_google.json`.

Requirements:
  - Set environment variable GOOGLE_API_KEY with your API key.
  - python3 requests installed: pip install --user requests

This script does a nearby search using the candidate name as keyword, then requests Place Details
for opening_hours and website. It outputs structured hours and meal inference.
"""
from pathlib import Path
import os, json, time, math
import requests
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
CAND = ROOT / 'scripts' / 'restaurant_candidates.json'
OUT = ROOT / 'scripts' / 'restaurant_hours_google.json'
API_KEY = os.environ.get('GOOGLE_API_KEY')
if not API_KEY:
    raise SystemExit('Set GOOGLE_API_KEY in environment before running this script')

NEARBY_URL = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
DETAILS_URL = 'https://maps.googleapis.com/maps/api/place/details/json'

MEAL_WINDOWS = {
    'breakfast': ("05:00","10:30"),
    'lunch': ("10:30","14:30"),
    'dinner': ("17:00","22:30")
}
WEEK = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday']


def periods_to_hours(periods):
    # periods is list of {open:{day:0-6,time:HHMM}, close:{...}} ; day 0=Sunday in Google
    hours = {d: [] for d in WEEK}
    if not periods:
        return hours
    for p in periods:
        o = p.get('open')
        c = p.get('close')
        if not o:
            continue
        oday = o.get('day')
        otime = o.get('time')
        if otime and len(otime)==4:
            ost = otime[:2]+':'+otime[2:]
        else:
            ost = None
        if c and c.get('time') and len(c.get('time'))==4:
            ctime = c.get('time'); cst = ctime[:2]+':'+ctime[2:]
        else:
            cst = None
        # map Google day (0=Sunday) to WEEK index where monday=0
        # Let's convert: google 0->sunday->WEEK index 6
        if ost and cst is not None:
            gd = int(oday)
            # map to weekday name
            wd_idx = (gd - 1) % 7  # google 1->mon => 0
            wd = WEEK[wd_idx]
            hours[wd].append([ost,cst])
    return hours


def infer_meals_from_hours(hours, types):
    meals = {}
    for meal,(start,end) in MEAL_WINDOWS.items():
        count = 0
        for d in WEEK:
            for r in hours.get(d,[]):
                if r[0] <= end and r[1] >= start:
                    count += 1; break
        available = (count >= 3)
        # cuisine hint from types
        hint=False
        if types:
            txt = ' '.join(types).lower()
            if meal=='breakfast' and any(x in txt for x in ('bakery','cafe','breakfast','brunch','coffee')):
                hint=True
            if meal=='dinner' and any(x in txt for x in ('restaurant','bar','steak','grill','seafood')):
                hint=True
            if meal=='lunch' and any(x in txt for x in ('restaurant','lunch','deli','sandwich','pizza','burger')):
                hint=True
        if available and hint:
            conf='high'
        elif available:
            conf='medium'
        elif hint:
            conf='medium'
        else:
            conf='low'
        meals[meal] = {'available': available, 'confidence': conf, 'days_open_count': count}
    return meals


def best_result_by_distance(results, lat, lon):
    best=None; bd=1e9
    for r in results:
        loc = r.get('geometry',{}).get('location')
        if not loc: continue
        d = haversine(lat, lon, loc['lat'], loc['lng'])
        if d < bd:
            bd=d; best=r
    return best, bd


def haversine(lat1,lon1,lat2,lon2):
    R=6371000.0
    import math
    phi1=math.radians(lat1); phi2=math.radians(lat2)
    dphi=math.radians(lat2-lat1); dl=math.radians(lon2-lon1)
    a=math.sin(dphi/2)**2+math.cos(phi1)*math.cos(phi2)*math.sin(dl/2)**2
    return R*2*math.atan2(math.sqrt(a), math.sqrt(1-a))


def run():
    cand = json.loads(CAND.read_text(encoding='utf-8'))
    out=[]
    for i,c in enumerate(cand, start=1):
        print(f'[{i}/{len(cand)}] Searching Google Places for {c.get("id")} - {c.get("name")}')
        lat=c['latitude']; lon=c['longitude']
        params={'location':f'{lat},{lon}','radius':500,'keyword':c.get('name') or '', 'key':API_KEY}
        r = requests.get(NEARBY_URL, params=params, timeout=10)
        if r.status_code!=200:
            print('  Nearby search failed', r.status_code, r.text[:200])
            out.append({'id':c['id'],'error':'nearby failed'})
            time.sleep(0.2); continue
        data=r.json()
        results=data.get('results',[])
        best,dist = best_result_by_distance(results, lat, lon)
        record={'id':c['id'],'name':c.get('name'),'city':c.get('city'),'latitude':lat,'longitude':lon,'sources':[],'hours':None,'types':None,'meals':None,'confidence':'none','last_checked':datetime.utcnow().isoformat()+'Z'}
        if best:
            place_id = best.get('place_id')
            # fetch details
            dp = requests.get(DETAILS_URL, params={'place_id':place_id,'fields':'name,opening_hours,types,website','key':API_KEY}, timeout=10)
            if dp.status_code==200:
                d = dp.json().get('result',{})
                oh = d.get('opening_hours')
                types = d.get('types')
                website = d.get('website')
                if oh and oh.get('periods'):
                    hours = periods_to_hours(oh.get('periods'))
                    meals = infer_meals_from_hours(hours, types)
                    record.update({'sources':['google_places'],'hours':hours,'types':types,'meals':meals,'confidence':'high'})
                elif oh and oh.get('weekday_text'):
                    # fallback: parse weekday_text format like 'Monday: 9:00 AM – 5:00 PM'
                    # The script won't fully parse AM/PM; mark medium confidence
                    record.update({'sources':['google_places'],'hours':{'note':oh.get('weekday_text')},'types':types,'meals':infer_meals_from_hours({},types),'confidence':'medium'})
                else:
                    record.update({'sources':['google_places'],'types':types,'confidence':'medium'})
            else:
                record.update({'error':'details_failed','status':dp.status_code})
        else:
            record.update({'confidence':'none'})
        out.append(record)
        time.sleep(0.2)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Wrote', OUT)

if __name__=='__main__':
    run()
