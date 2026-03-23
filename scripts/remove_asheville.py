#!/usr/bin/env python3
"""
Remove the top-level 'Asheville' key from the app's canonical BuildingRegistry.json.
Creates a backup at the same path with .bak timestamp.
"""
import json
from pathlib import Path
import shutil
import datetime

repo_root = Path(__file__).resolve().parents[1]
json_path = repo_root / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'
if not json_path.exists():
    print('ERROR: canonical JSON not found at', json_path)
    raise SystemExit(1)

# Backup
ts = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
backup_path = json_path.with_suffix('.json.' + ts + '.bak')
shutil.copy2(json_path, backup_path)
print('Backup created at', backup_path)

# Load, remove key, write back
with json_path.open('r', encoding='utf-8') as f:
    data = json.load(f)

if 'Asheville' in data:
    count_before = len(data.keys())
    removed = data.pop('Asheville')
    with json_path.open('w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Removed 'Asheville' ({len(removed)} buildings). Cities before: {count_before}, after: {len(data.keys())}")
else:
    print("'Asheville' key not found; no changes made.")

print('Done.')
