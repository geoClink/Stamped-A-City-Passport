#!/usr/bin/env python3
"""
Try alternate queries for entries in scripts/geocode_failures.json and update the main BuildingRegistry.json
Uses OPENCAGE_API_KEY from env. Creates a timestamped backup before writing.
"""
from pathlib import Path
import json
import os
import time
import random
import sys

import requests

ROOT = Path(__file__).resolve().parents[1]
REG_PATH = ROOT / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'
FAIL_PATH = Path(__file__).parent / 'geocode_failures.json'
CACHE_PATH = Path(__file__).parent / '.geocode_cache.json'

# Use Nominatim (OpenStreetMap) for a second-pass geocode (no API key required).
# Nominatim policy requests a contact email; you can set GEOCODE_EMAIL or NOMINATIM_EMAIL env var.
EMAIL = os.environ.get('GEOCODE_EMAIL') or os.environ.get('NOMINATIM_EMAIL')


# Nominatim geocode helper
def nominatim_geocode(query, email):
    url = 'https://nominatim.openstreetmap.org/search'
    params = {'q': query, 'format': 'jsonv2', 'limit': 1}
    if email:
        params['email'] = email
    try:
        r = requests.get(url, params=params, headers={'User-Agent': f'StampedCityPassportGeocoder/1.0 (+{email or "no-email-provided"})'}, timeout=15)
        if r.status_code == 200:
            data = r.json()
            if isinstance(data, list) and len(data) > 0:
                first = data[0]
                lat = float(first.get('lat'))
                lon = float(first.get('lon'))
                display = first.get('display_name')
                return lat, lon, display
            return None
        else:
            if r.status_code == 429:
                print(f'WARN: Nominatim rate-limited for query: {query}', file=sys.stderr)
            return None
    except Exception as e:
        print('WARN: Nominatim request failed:', e, file=sys.stderr)
        return None


def load_registry():
    return json.loads(REG_PATH.read_text(encoding='utf-8'))


def save_registry(data):
    bak = REG_PATH.with_name(f'{REG_PATH.name}.{time.strftime("%Y%m%d-%H%M%S")}.bak')
    REG_PATH.replace(bak)
    REG_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Backup created:', bak)


# Load failures
fails = json.loads(FAIL_PATH.read_text(encoding='utf-8'))
print('Found', len(fails), 'failures to attempt')

registry = load_registry()

succeeded = []
still_failed = []

for item in fails:
    bid = item.get('id')
    orig_addr = item.get('address')
    city = item.get('city')
    print('\nTrying', bid, '->', orig_addr)
    candidates = ALTERNATES.get(bid, [])
    # always try original first
    tried = []
    if orig_addr:
        candidates = [orig_addr] + candidates
    found = False
    for q in candidates:
        if q in tried:
            continue
        tried.append(q)
        print('  Trying query:', q)
        try:
            res = nominatim_geocode(q, EMAIL)
        except Exception as e:
            print('  Error querying Nominatim:', e)
            res = None
        if res:
            lat, lon, formatted = res
            print(f'  Success: {lat},{lon} (match: {formatted})')
            # find building in registry and update
            updated = False
            for cityk, blist in registry.items():
                if isinstance(blist, list):
                    for b in blist:
                        if b.get('id') == bid:
                            b['latitude'] = lat
                            b['longitude'] = lon
                            b['_geocoded_by'] = 'nominatim-second-pass'
                            b['_geocode_query'] = q
                            b['_geocode_ts'] = time.strftime('%Y%m%d-%H%M%S')
                            updated = True
                            break
                    if updated:
                        break
            if updated:
                succeeded.append({'id': bid, 'query': q, 'lat': lat, 'lon': lon})
            else:
                print('  Warning: could not find building id in registry to update')
            found = True
            # small delay to be polite
            time.sleep(1.1 + random.random()*0.2)
            break
        else:
            print('  No result for query')
            time.sleep(1.1 + random.random()*0.2)
    if not found:
        still_failed.append(item)

# Save results if we updated any
if succeeded:
    print('\nUpdating registry with', len(succeeded), 'new coordinates')
    save_registry(registry)
else:
    print('\nNo new coordinates found')

# write updated failures file
Path(FAIL_PATH).write_text(json.dumps(still_failed, ensure_ascii=False, indent=2), encoding='utf-8')
print('Wrote updated failures file to', FAIL_PATH)

print('\nSummary:')
print('Succeeded:', len(succeeded))
for s in succeeded:
    print(' ', s)
print('Remaining failures:', len(still_failed))
for f in still_failed:
    print(' ', f.get('id'), '->', f.get('address'))
