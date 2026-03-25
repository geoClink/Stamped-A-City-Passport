#!/usr/bin/env python3
"""
Extract `foodSpots` from BuildingRegistry.json and try to match each named food spot to a building entry.
Matching rules:
 - Exact case-insensitive name match across registry buildings.
 - Substring name match (case-insensitive).
 - Fuzzy name match (SequenceMatcher) with threshold 0.8, preferred when within distance threshold (200m) of the landmark.
Output: scripts/foodspot_associations.json with per-landmark foodSpot matches and summary printed to stdout.
"""
from pathlib import Path
import json
from difflib import SequenceMatcher
import math

ROOT = Path(__file__).resolve().parents[1]
REG_PATH = ROOT / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'
OUT_PATH = ROOT / 'scripts' / 'foodspot_associations.json'

DIST_THRESHOLD_M = 200.0
FUZZY_THRESHOLD = 0.78

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000.0
    phi1 = math.radians(lat1); phi2 = math.radians(lat2)
    dphi = math.radians(lat2-lat1); dl = math.radians(lon2-lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dl/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c


def similar(a,b):
    return SequenceMatcher(None, (a or '').lower(), (b or '').lower()).ratio()


def load_registry():
    return json.loads(REG_PATH.read_text(encoding='utf-8'))


def build_index(reg):
    # collect all buildings with names and coords
    buildings = []
    for city, bl in reg.items():
        if not isinstance(bl, list):
            continue
        for b in bl:
            name = b.get('name') or ''
            lat = b.get('latitude')
            lon = b.get('longitude')
            buildings.append({'city': city, 'id': b.get('id'), 'name': name, 'lat': float(lat) if lat is not None else None, 'lon': float(lon) if lon is not None else None})
    return buildings


def find_best_match(food_name, landmark, buildings):
    # Try exact (case-insensitive) then substring then fuzzy with distance
    lname = food_name.strip()
    if not lname:
        return None
    # exact match
    candidates = [b for b in buildings if b['name'] and b['name'].strip().lower() == lname.lower()]
    if candidates:
        # choose closest to landmark if coords available
        best = None; bd = 1e9
        for c in candidates:
            if c['lat'] is None or c['lon'] is None or landmark['lat'] is None:
                return {'found_by':'exact_name','building':c,'dist_m':None,'score':1.0}
            d = haversine(landmark['lat'], landmark['lon'], c['lat'], c['lon'])
            if d < bd:
                bd = d; best = c
        return {'found_by':'exact_name','building':best,'dist_m':round(bd,1),'score':1.0}
    # substring match
    candidates = [b for b in buildings if b['name'] and lname.lower() in b['name'].strip().lower()]
    if candidates:
        best = None; bd = 1e9; bestname = None
        for c in candidates:
            if c['lat'] is None or c['lon'] is None or landmark['lat'] is None:
                return {'found_by':'substring_name','building':c,'dist_m':None,'score':0.9}
            d = haversine(landmark['lat'], landmark['lon'], c['lat'], c['lon'])
            if d < bd:
                bd = d; best = c
        return {'found_by':'substring_name','building':best,'dist_m':round(bd,1),'score':0.9}
    # fuzzy match: check similarity and distance
    best = None; best_score = 0.0; best_d = None
    for c in buildings:
        if not c['name']:
            continue
        score = similar(lname, c['name'])
        if score < FUZZY_THRESHOLD:
            continue
        # compute distance if coords available
        if c['lat'] is None or c['lon'] is None or landmark['lat'] is None:
            # no coords, but name similar enough
            if score > best_score:
                best_score = score; best = c; best_d = None
            continue
        d = haversine(landmark['lat'], landmark['lon'], c['lat'], c['lon'])
        # prefer close matches
        if d <= DIST_THRESHOLD_M and score >= FUZZY_THRESHOLD:
            if score > best_score or (score == best_score and (best_d is None or d < best_d)):
                best_score = score; best = c; best_d = d
    if best:
        return {'found_by':'fuzzy_name_distance','building':best,'dist_m':round(best_d,1) if best_d is not None else None,'score':round(best_score,3)}
    # nothing found
    return None


def main():
    reg = load_registry()
    buildings = build_index(reg)
    # find landmarks that have foodSpots key
    landmarks = []
    for city, bl in reg.items():
        if not isinstance(bl, list):
            continue
        for b in bl:
            if 'foodSpots' in b and b.get('foodSpots'):
                landmarks.append({'city': city, 'id': b.get('id'), 'name': b.get('name'), 'lat': float(b.get('latitude')) if b.get('latitude') is not None else None, 'lon': float(b.get('longitude')) if b.get('longitude') is not None else None, 'foodSpots': b.get('foodSpots')})

    results = []
    total_foodspots = 0; matched = 0; unmatched = 0
    for lm in landmarks:
        rec = {'landmark_id': lm['id'], 'landmark_name': lm['name'], 'city': lm['city'], 'lat': lm['lat'], 'lon': lm['lon'], 'foodSpots': []}
        for f in lm['foodSpots']:
            total_foodspots += 1
            match = find_best_match(f, lm, buildings)
            entry = {'name': f, 'match': None}
            if match:
                m = match['building']
                entry['match'] = {'found_by': match['found_by'], 'building_id': m['id'], 'building_name': m['name'], 'dist_m': match.get('dist_m'), 'score': match.get('score')}
                matched += 1
            else:
                entry['match'] = None
                unmatched += 1
            rec['foodSpots'].append(entry)
        results.append(rec)

    OUT = {'generated': True, 'total_landmarks': len(landmarks), 'total_foodSpots': total_foodspots, 'matched': matched, 'unmatched': unmatched, 'associations': results}
    OUT_PATH.write_text(json.dumps(OUT, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Wrote', OUT_PATH)
    print('Landmarks with foodSpots:', len(landmarks))
    print('Total foodSpots:', total_foodspots)
    print('Matched:', matched, 'Unmatched:', unmatched)

if __name__ == '__main__':
    main()
