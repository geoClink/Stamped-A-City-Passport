#!/usr/bin/env python3
"""
Reverse-check selected coordinates in BuildingRegistry.json using Nominatim.
Writes results to scripts/coord_check_results.json.
Selection: validator outliers (from scripts/validate_report.json), the 7 recently changed IDs,
and a random sample of 20 other buildings for spot-check.
"""
import json, time, random
from pathlib import Path
from urllib.parse import urlencode
import requests

ROOT = Path(__file__).resolve().parents[1]
REG = ROOT / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'
VALID = ROOT / 'scripts' / 'validate_report.json'
OUT = ROOT / 'scripts' / 'coord_check_results.json'

NOMINATIM = 'https://nominatim.openstreetmap.org/reverse'
USER_AGENT = 'StampedCityPassportCoordCheck/1.0 (your-email@example.com)'
DELAY = 1.2

# IDs that were updated earlier
CHANGED_IDS = {'auh_al_bahr_towers','bom_apple_bkc','sha_apple_campus','bali-potato-head','jakarta-istiqlal','ist_suleymaniye','br_ibirapuera_auditorium'}

print('Loading registry...')
reg = json.loads(REG.read_text(encoding='utf-8'))
# flatten buildings to id->record
build_map = {}
for city, bl in reg.items():
    if not isinstance(bl, list):
        continue
    for b in bl:
        bid = b.get('id')
        if not bid:
            continue
        build_map[bid] = {'id': bid, 'name': b.get('name'), 'city': city, 'lat': b.get('latitude'), 'lon': b.get('longitude')}

# load outliers
outliers = set()
if VALID.exists():
    vr = json.loads(VALID.read_text(encoding='utf-8'))
    for o in vr.get('outliers', []):
        outliers.add(o.get('id'))

# prepare sample of random ids excluding the changed and outliers
all_ids = list(build_map.keys())
candidates = [i for i in all_ids if i not in CHANGED_IDS and i not in outliers]
random.seed(42)
sample_ids = random.sample(candidates, min(20, len(candidates)))

# final list to check
to_check = list(outliers.union(CHANGED_IDS).union(sample_ids))
print('Will check', len(to_check), 'points (', len(outliers), 'outliers,', len(CHANGED_IDS), 'changed,', len(sample_ids), 'random )')

results = []
session = requests.Session()
headers = {'User-Agent': USER_AGENT}

for bid in to_check:
    rec = build_map.get(bid)
    if not rec:
        continue
    lat = rec['lat']; lon = rec['lon']
    entry = {'id': bid, 'name': rec.get('name'), 'city': rec.get('city'), 'latitude': lat, 'longitude': lon, 'nominatim': None, 'match': None}
    if lat is None or lon is None:
        entry['match'] = 'missing_coords'
        results.append(entry)
        continue
    params = {'format': 'jsonv2', 'lat': lat, 'lon': lon, 'zoom': 16, 'addressdetails': 1}
    try:
        r = session.get(NOMINATIM, params=params, headers=headers, timeout=15)
        if r.status_code == 200:
            data = r.json()
            display = data.get('display_name')
            address = data.get('address', {})
            entry['nominatim'] = {'display_name': display, 'address': address}
            # simple city/county/country match test
            # normalize strings to lowercase
            target_city = (rec.get('city') or '').lower()
            # check several address fields for presence of city string
            addr_text = ' '.join(str(v).lower() for v in address.values() if v)
            if target_city and target_city in addr_text:
                entry['match'] = 'city_match'
            else:
                entry['match'] = 'no_city_match'
        else:
            entry['nominatim'] = {'error': f'status_{r.status_code}'}
            entry['match'] = 'nominatim_error'
    except Exception as e:
        entry['nominatim'] = {'error': str(e)}
        entry['match'] = 'nominatim_exception'
    results.append(entry)
    time.sleep(DELAY)

OUT.write_text(json.dumps({'checked_at': time.strftime('%Y-%m-%dT%H:%M:%SZ'), 'count': len(results), 'results': results}, ensure_ascii=False, indent=2), encoding='utf-8')
print('Wrote', OUT)

# Summarize
matches = [r for r in results if r.get('match')=='city_match']
nomatch = [r for r in results if r.get('match')=='no_city_match']
errors = [r for r in results if r.get('match') and r.get('match').startswith('nominatim')]
print('Summary: total', len(results), 'city_match', len(matches), 'no_city_match', len(nomatch), 'errors', len(errors))

PY