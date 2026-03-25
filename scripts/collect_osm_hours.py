#!/usr/bin/env python3
"""
Query Overpass (OSM) for opening_hours and cuisine for candidate restaurant POIs.
Reads `scripts/restaurant_candidates.json` and writes `scripts/restaurant_hours_osm.json`.

This script is polite: it batches one query per POI and sleeps between requests.
It implements a simple opening_hours parser for common cases (e.g., "Mo-Su 08:00-22:00; Sa 09:00-14:00").
"""
from pathlib import Path
import json
import requests
import time
import re
from difflib import SequenceMatcher
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
CAND_PATH = ROOT / 'scripts' / 'restaurant_candidates.json'
OUT_PATH = ROOT / 'scripts' / 'restaurant_hours_osm.json'
OVERPASS_URL = 'https://overpass-api.de/api/interpreter'
RADIUS = 50  # meters
DELAY = 1.2  # seconds between queries (polite)

WEEKDAY_ORDER = ['Mo','Tu','We','Th','Fr','Sa','Su']
WEEKDAY_MAP = {'Mo':'monday','Tu':'tuesday','We':'wednesday','Th':'thursday','Fr':'friday','Sa':'saturday','Su':'sunday'}

# simple regex to find time ranges like 08:00-18:30
TIME_RANGE_RE = re.compile(r"(\d{1,2}:\d{2})-(\d{1,2}:\d{2})")
DAY_RANGE_RE = re.compile(r"(Mo|Tu|We|Th|Fr|Sa|Su)(?:-(Mo|Tu|We|Th|Fr|Sa|Su))?")

# meal windows (24-hour) ephemeral thresholds
MEAL_WINDOWS = {
    'breakfast': ("05:00","10:30"),
    'lunch': ("10:30","14:30"),
    'dinner': ("17:00","22:30")
}


def similar(a,b):
    return SequenceMatcher(None, (a or '').lower(), (b or '').lower()).ratio()


def parse_opening_hours_tag(tag: str):
    """
    Very simple parser: handle patterns like "Mo-Su 08:00-22:00; Sa 09:00-14:00" and single-day specs.
    Returns a dict: weekday -> list of [start, end] strings (HH:MM).
    If parsing fails, returns {}.
    """
    if not tag or not isinstance(tag, str):
        return {}
    out = {d: [] for d in WEEKDAY_MAP.values()}
    try:
        # split on ; to get rules
        parts = [p.strip() for p in tag.split(';') if p.strip()]
        for part in parts:
            # find days prefix
            # example: Mo-Fr 08:00-18:00
            m = re.match(r'^([A-Za-z0-9,\- ]+)\s+(.*)$', part)
            if m:
                dayspec = m.group(1).strip()
                timespec = m.group(2).strip()
            else:
                # maybe only times like 08:00-20:00 apply to all days
                dayspec = 'Mo-Su'
                timespec = part
            # extract all time ranges from timespec
            ranges = TIME_RANGE_RE.findall(timespec)
            if not ranges:
                continue
            # expand dayspec which may be like Mo-Fr or Sa or Mo,We,Fr
            days = []
            for token in re.split(r',\s*', dayspec):
                token = token.strip()
                if '-' in token:
                    dm = token.split('-')
                    if dm[0] in WEEKDAY_ORDER and dm[1] in WEEKDAY_ORDER:
                        start_idx = WEEKDAY_ORDER.index(dm[0])
                        end_idx = WEEKDAY_ORDER.index(dm[1])
                        if start_idx <= end_idx:
                            rng = WEEKDAY_ORDER[start_idx:end_idx+1]
                        else:
                            rng = WEEKDAY_ORDER[start_idx:] + WEEKDAY_ORDER[:end_idx+1]
                        days.extend(rng)
                elif token in WEEKDAY_ORDER:
                    days.append(token)
                elif token.lower() in ('mo','mon','monday'):
                    days.append('Mo')
                else:
                    # ignore unknown token
                    pass
            if not days:
                days = WEEKDAY_ORDER[:]  # assume all days
            # map ranges to weekdays
            for dr in days:
                wd = WEEKDAY_MAP.get(dr)
                if not wd:
                    continue
                for tr in ranges:
                    start = tr[0]
                    end = tr[1]
                    out[wd].append([start, end])
        return out
    except Exception:
        return {}


def time_in_window(time_str, window):
    # compare 'HH:MM' strings lexicographically works for 24h padded
    return time_str >= window[0] and time_str <= window[1]


def infer_meals_from_hours(hours_dict, cuisine_list):
    # hours_dict: weekday -> list of [start,end]
    # cuisine_list: list or string
    meals = {}
    for meal, win in MEAL_WINDOWS.items():
        # count days where any opening interval overlaps the meal window
        count = 0
        for wd, ranges in hours_dict.items():
            for r in ranges:
                # check if r overlaps window
                # if start <= window_end and end >= window_start
                if r[0] <= win[1] and r[1] >= win[0]:
                    count += 1
                    break
        available = (count >= 4)  # available if on >=4 days
        # boost by cuisine hints
        cuisine_hint = False
        if cuisine_list:
            text = ','.join(cuisine_list).lower() if isinstance(cuisine_list,list) else str(cuisine_list).lower()
            if meal == 'breakfast' and any(x in text for x in ('bakery','breakfast','brunch','coffee','tea')):
                cuisine_hint = True
            if meal == 'dinner' and any(x in text for x in ('dinner','steak','grill','seafood')):
                cuisine_hint = True
            if meal == 'lunch' and any(x in text for x in ('lunch','sandwich','burger','salad','pizza')):
                cuisine_hint = True
        # confidence logic
        if available and cuisine_hint:
            conf = 'high'
        elif available:
            conf = 'medium'
        elif cuisine_hint:
            conf = 'medium'
        else:
            conf = 'low'
        meals[meal] = {'available': available, 'confidence': conf, 'days_open_count': count}
    return meals


def best_match_for_results(candidate, results):
    # candidate: dict with name, lat, lon
    # results: list of OSM elements (each with tags and center or lat/lon)
    best = None
    best_score = 0.0
    for el in results:
        tags = el.get('tags', {})
        # get geom
        if el.get('type')=='node':
            lat = float(el.get('lat'))
            lon = float(el.get('lon'))
        else:
            # way or relation: use center if present
            cen = el.get('center') or el.get('bounds') or {}
            lat = float(cen.get('lat') or cen.get('minlat') or candidate['latitude'])
            lon = float(cen.get('lon') or cen.get('minlon') or candidate['longitude'])
        # compute name similarity
        name_score = 0.0
        if candidate.get('name') and tags.get('name'):
            name_score = similar(candidate.get('name'), tags.get('name'))
        # compute distance score (closer better)
        # simple approx using haversine
        dist = haversine(candidate['latitude'], candidate['longitude'], lat, lon)
        # dist score: 1.0 at 0m, 0.0 at >=200m
        dist_score = max(0.0, 1.0 - (dist/200.0))
        score = 0.6*dist_score + 0.4*name_score
        if score > best_score:
            best_score = score
            best = {'element': el, 'score': score, 'name_score': name_score, 'dist_m': dist, 'lat': lat, 'lon': lon}
    return best


def haversine(lat1, lon1, lat2, lon2):
    import math
    R = 6371000.0
    phi1 = math.radians(lat1); phi2 = math.radians(lat2)
    dphi = math.radians(lat2-lat1); dl = math.radians(lon2-lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dl/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


def query_overpass(lat, lon, radius=RADIUS):
    # Query nodes/ways/relations with amenity tags for food within radius
    q = ("[out:json][timeout:25];("
         "node(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|biergarten|ice_cream|food_court|food'];"
         "way(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|biergarten|ice_cream|food_court|food'];"
         "relation(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|biergarten|ice_cream|food_court|food'];"
         ");\nout center tags;") % (radius, lat, lon, radius, lat, lon, radius, lat, lon)
    resp = requests.post(OVERPASS_URL, data=q.encode('utf-8'), timeout=60)
    if resp.status_code != 200:
        return None
    return resp.json()


def process_all():
    cand = json.loads(CAND_PATH.read_text(encoding='utf-8'))
    out = []
    print('Processing', len(cand), 'candidates')
    for i, c in enumerate(cand, start=1):
        print(f'[{i}/{len(cand)}] Querying OSM for', c.get('id'), c.get('name'))
        lat = c['latitude']; lon = c['longitude']
        try:
            data = query_overpass(lat, lon)
        except Exception as e:
            print('  Query failed:', e)
            data = None
        record = {'id': c.get('id'), 'name': c.get('name'), 'city': c.get('city'), 'address': c.get('address'), 'latitude': lat, 'longitude': lon, 'sources': [], 'hours': None, 'cuisine': None, 'meals': None, 'confidence': 'none', 'last_checked': datetime.utcnow().isoformat()+'Z'}
        if data and data.get('elements'):
            best = best_match_for_results({'name': c.get('name'), 'latitude': lat, 'longitude': lon}, data['elements'])
            if best and best['score'] > 0.25:
                el = best['element']
                tags = el.get('tags', {})
                oh = tags.get('opening_hours')
                cuisine = tags.get('cuisine')
                if cuisine:
                    cuisine_list = [x.strip() for x in cuisine.split(';')]
                else:
                    cuisine_list = None
                hours = parse_opening_hours_tag(oh) if oh else {}
                meals = infer_meals_from_hours(hours, cuisine_list)
                record.update({'sources': ['osm'], 'hours': hours if hours else None, 'cuisine': cuisine_list, 'meals': meals, 'confidence': 'high' if oh else 'medium'})
            else:
                # no good match
                record['confidence'] = 'low'
        else:
            record['confidence'] = 'none'
        out.append(record)
        # polite delay
        time.sleep(DELAY)
    OUT_PATH.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Wrote results to', OUT_PATH)

if __name__ == '__main__':
    process_all()
