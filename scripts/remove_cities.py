#!/usr/bin/env python3
"""
Remove one or more top-level city keys from the canonical BuildingRegistry.json.
Usage:
  python3 scripts/remove_cities.py Brasília "São Paulo"

This script creates a timestamped backup before modifying the file.
"""
import sys
from pathlib import Path
import shutil
import datetime
import json

if len(sys.argv) < 2:
    print("Usage: python3 scripts/remove_cities.py <CityName> [CityName ...]")
    sys.exit(1)

repo_root = Path(__file__).resolve().parents[1]
json_path = repo_root / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'
if not json_path.exists():
    print('ERROR: canonical JSON not found at', json_path)
    sys.exit(1)

cities_to_remove = sys.argv[1:]
print('Will remove cities:', cities_to_remove)

# Backup
ts = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
backup = json_path.with_suffix('.json.' + ts + '.bak')
shutil.copy2(json_path, backup)
print('Backup created at', backup)

with json_path.open('r', encoding='utf-8') as f:
    data = json.load(f)

removed_count = 0
for city in cities_to_remove:
    if city in data:
        popped = data.pop(city)
        print(f"Removed {city} ({len(popped)} buildings)")
        removed_count += 1
    else:
        print(f"{city} not present in canonical JSON")

with json_path.open('w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f'Done. Cities removed: {removed_count}.')
print('If you also have these cities in scripts/registry_editable.py, remove those blocks to avoid re-adding on import.')
