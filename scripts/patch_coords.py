#!/usr/bin/env python3
"""
Patch latitude/longitude into BuildingRegistry.json for specific building ids.

Usage:
  # Single patch
  python3 scripts/patch_coords.py --input "Stamped! A City Passport/Resources/BuildingRegistry.json" --id uk_thermae_bath_spa --lat 51.3815 --lon -2.3596

  # Multiple from CSV (id,lat,lon per line)
  python3 scripts/patch_coords.py --input ".../BuildingRegistry.json" --csv fixes.csv

The script makes a timestamped backup of the input file before writing.
"""
import argparse
import csv
import json
import time
from pathlib import Path
from typing import Dict, Tuple, List, Any


def load_json(p: Path) -> Any:
    return json.loads(p.read_text(encoding='utf-8'))


def save_json(obj: Any, p: Path) -> None:
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')


def find_and_patch(data: Any, patches: Dict[str, Tuple[float, float]]) -> int:
    """Patches in-place. Returns number of patches applied."""
    applied = 0
    if isinstance(data, dict) and 'cities' in data and isinstance(data['cities'], dict):
        for cname, blist in data['cities'].items():
            for b in blist:
                bid = b.get('id')
                if bid and bid in patches:
                    lat, lon = patches[bid]
                    b['latitude'] = lat
                    b['longitude'] = lon
                    applied += 1
    elif isinstance(data, dict):
        for cname, blist in data.items():
            if not isinstance(blist, list):
                continue
            for b in blist:
                bid = b.get('id')
                if bid and bid in patches:
                    lat, lon = patches[bid]
                    b['latitude'] = lat
                    b['longitude'] = lon
                    applied += 1
    else:
        raise SystemExit('Unrecognized JSON shape')
    return applied


def parse_csv(p: Path) -> Dict[str, Tuple[float, float]]:
    res: Dict[str, Tuple[float, float]] = {}
    with p.open('r', encoding='utf-8') as f:
        rdr = csv.reader(f)
        for row in rdr:
            if len(row) < 3:
                continue
            bid = row[0].strip()
            try:
                lat = float(row[1])
                lon = float(row[2])
            except Exception:
                continue
            res[bid] = (lat, lon)
    return res


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', '-i', required=True)
    parser.add_argument('--id', help='Building id to patch')
    parser.add_argument('--lat', type=float, help='Latitude for single patch')
    parser.add_argument('--lon', type=float, help='Longitude for single patch')
    parser.add_argument('--csv', help='CSV path with id,lat,lon rows')
    args = parser.parse_args()

    inp = Path(args.input)
    if not inp.exists():
        print('Input not found:', inp)
        return

    patches: Dict[str, Tuple[float, float]] = {}
    if args.csv:
        patches.update(parse_csv(Path(args.csv)))
    if args.id and args.lat is not None and args.lon is not None:
        patches[args.id] = (args.lat, args.lon)

    if not patches:
        print('No patches provided; use --id/--lat/--lon or --csv')
        return

    # backup
    ts = time.strftime('%Y%m%d-%H%M%S')
    backup = inp.with_suffix(inp.suffix + f'.{ts}.bak')
    backup.write_bytes(inp.read_bytes())
    print('Backup created:', backup)

    data = load_json(inp)
    applied = find_and_patch(data, patches)
    save_json(data, inp)
    print(f'Applied {applied} patches to {inp}')

if __name__ == '__main__':
    main()
