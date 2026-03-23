#!/usr/bin/env python3
"""
Deduplicate BuildingRegistry.json by building 'id' within each city.
- Creates a backup file BuildingRegistry.json.bak timestamped.
- Keeps the first occurrence of any duplicate id in a city.
- Prints a summary of removed duplicates.
"""
import json
import pathlib
import time
from collections import OrderedDict

ROOT = pathlib.Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'
if not JSON_PATH.exists():
    print('ERROR: registry JSON not found at', JSON_PATH)
    raise SystemExit(2)

# create timestamped backup
ts = time.strftime('%Y%m%d-%H%M%S')
backup_path = JSON_PATH.with_name(f'BuildingRegistry.json.{ts}.bak')
# copy to backup
backup_path.write_bytes(JSON_PATH.read_bytes())
print('Created backup:', backup_path)

# read backup
j = json.load(backup_path.open('r', encoding='utf-8'))
removed_total = 0
per_city_removed = {}
new_j = {}
for city, buildings in j.items():
    seen = set()
    deduped = []
    removed = 0
    for b in buildings:
        if not isinstance(b, dict):
            continue
        bid = b.get('id')
        if not bid:
            # if no id, keep it
            deduped.append(b)
            continue
        if bid in seen:
            removed += 1
            continue
        seen.add(bid)
        deduped.append(b)
    if removed:
        per_city_removed[city] = removed
        removed_total += removed
    new_j[city] = deduped

# write the cleaned JSON back to the original path
with JSON_PATH.open('w', encoding='utf-8') as f:
    json.dump(new_j, f, ensure_ascii=False, indent=2)

print('Deduplication complete.')
print('Total removed duplicates:', removed_total)
if per_city_removed:
    for city, count in per_city_removed.items():
        print(f'  {city}: removed {count}')
else:
    print('No duplicates were found.')

print('\nWrote cleaned registry to', JSON_PATH)
print('Backup kept at', backup_path)
