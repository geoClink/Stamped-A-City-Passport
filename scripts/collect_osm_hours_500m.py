#!/usr/bin/env python3
"""
Query Overpass for nearby food amenities with a larger radius (500m) for restaurant candidates.
Writes results to scripts/restaurant_hours_osm_500m.json with parsed opening_hours, cuisine, website where available.
"""
from pathlib import Path
import json, time, re
import requests
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
CAND = ROOT / 'scripts' / 'restaurant_candidates.json'
OUT = ROOT / 'scripts' / 'restaurant_hours_osm_500m.json'
OVERPASS = 'https://overpass-api.de/api/interpreter'
HEADERS = {'User-Agent':'StampedCityPassport/1.0 (+https://example.invalid)'}
RADIUS = 500
DELAY = 1.0

TIME_RANGE_RE = re.compile(r"(\d{1,2}:\d{2})-(\d{1,2}:\d{2})")
WEEKDAY_ORDER = ['Mo','Tu','We','Th','Fr','Sa','Su']
WEEKDAY_MAP = {'Mo':'monday','Tu':'tuesday','We':'wednesday','Th':'thursday','Fr':'friday','Sa':'saturday','Su':'sunday'}

def parse_opening_hours_tag(tag: str):
    if not tag: return {}
    out = {d: [] for d in WEEKDAY_MAP.values()}
    parts = [p.strip() for p in tag.split(';') if p.strip()]
    for part in parts:
        m = re.match(r'^([A-Za-z0-9,\- ]+)\s+(.*)$', part)
        if m:
            dayspec = m.group(1).strip(); timespec = m.group(2).strip()
        else:
            dayspec='Mo-Su'; timespec=part
        ranges = TIME_RANGE_RE.findall(timespec)
        if not ranges: continue
        days=[]
        for token in re.split(r',\s*', dayspec):
            token=token.strip()
            if '-' in token:
                dm=token.split('-')
                if dm[0] in WEEKDAY_ORDER and dm[1] in WEEKDAY_ORDER:
                    s=WEEKDAY_ORDER.index(dm[0]); e=WEEKDAY_ORDER.index(dm[1])
                    if s<=e: days.extend(WEEKDAY_ORDER[s:e+1])
                    else: days.extend(WEEKDAY_ORDER[s:]+WEEKDAY_ORDER[:e+1])
            elif token in WEEKDAY_ORDER:
                days.append(token)
        if not days: days=WEEKDAY_ORDER[:]
        for dr in days:
            wd=WEEKDAY_MAP.get(dr)
            if not wd: continue
            for tr in ranges:
                out[wd].append([tr[0],tr[1]])
    return out


def best_match(candidate, elements):
    # choose element with opening_hours or website or smallest distance if center provided
    best=None; score=0
    for el in elements:
        tags=el.get('tags',{})
        if tags.get('opening_hours'): s=3
        elif tags.get('website'): s=2
        elif tags.get('cuisine'): s=1
        else: s=0
        if el.get('type')!='node':
            ctr=el.get('center') or {}
            lat=ctr.get('lat'); lon=ctr.get('lon')
        else:
            lat=el.get('lat'); lon=el.get('lon')
        # distance roughly via Haversine
        if lat and lon:
            d=haversine(candidate['latitude'], candidate['longitude'], float(lat), float(lon))
        else:
            d=9999
        # closer is better; combine
        s_comb = s + max(0, (200 - d)/200)
        if s_comb>score:
            score=s_comb; best={'el':el,'dist_m':d,'score':s_comb}
    return best


def haversine(lat1,lon1,lat2,lon2):
    import math
    R=6371000.0
    phi1=math.radians(lat1); phi2=math.radians(lat2)
    dphi=math.radians(lat2-lat1); dl=math.radians(lon2-lon1)
    a=math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dl/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))


def query(lat,lon,radius=RADIUS):
    q = ("[out:json][timeout:25];(node(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|food'];"
         "way(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|food'];"
         "relation(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|food'];"
         ");out center tags;") % (radius, lat, lon, radius, lat, lon, radius, lat, lon)
    try:
        r = requests.post(OVERPASS, data=q.encode('utf-8'), headers=HEADERS, timeout=60)
        if r.status_code==200:
            return r.json().get('elements', [])
    except Exception as e:
        print('Overpass error', e)
    return []


def process():
    cand = json.loads(CAND.read_text(encoding='utf-8'))
    out=[]
    for i,c in enumerate(cand, start=1):
        print(f'[{i}/{len(cand)}] Querying 500m for', c['id'], c['name'])
        els = query(c['latitude'], c['longitude'], radius=RADIUS)
        best = best_match(c, els) if els else None
        rec = {'id':c['id'],'name':c.get('name'),'city':c.get('city'),'address':c.get('address'),'latitude':c.get('latitude'),'longitude':c.get('longitude'),'sources':[],'hours':None,'cuisine':None,'website':None,'confidence':'none','last_checked':datetime.utcnow().isoformat()+'Z'}
        if best:
            el = best['el']; tags = el.get('tags',{})
            oh = tags.get('opening_hours')
            website = tags.get('website') or tags.get('contact:website')
            cuisine = tags.get('cuisine')
            rec['cuisine'] = [x.strip() for x in cuisine.split(';')] if cuisine else None
            rec['website'] = website
            if oh:
                rec['hours'] = parse_opening_hours_tag(oh)
                rec['sources']=['osm']
                rec['confidence']='high'
            elif website:
                rec['sources']=['osm','website']
                rec['confidence']='medium'
            else:
                rec['sources']=['osm']
                rec['confidence']='low'
        out.append(rec)
        time.sleep(DELAY)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Wrote', OUT)

if __name__=='__main__':
    process()
