#!/usr/bin/env python3
"""
Simple registry CLI to list/add/remove cities in the canonical
`Stamped! A City Passport/Resources/BuildingRegistry.json`.

Usage:
  python3 scripts/registry_cli.py list
  python3 scripts/registry_cli.py add <CityName> --file path/to/city_buildings.json [--replace]
  python3 scripts/registry_cli.py remove <CityName>
  python3 scripts/registry_cli.py validate

The script makes a timestamped backup before any modifying operation.
"""
import argparse
import json
from pathlib import Path
import shutil
import datetime
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
CANONICAL = REPO_ROOT / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'


def load_registry():
    if not CANONICAL.exists():
        print(f"ERROR: canonical JSON not found at {CANONICAL}")
        sys.exit(1)
    with CANONICAL.open('r', encoding='utf-8') as f:
        return json.load(f)


def write_registry(data):
    ts = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    backup = CANONICAL.with_suffix('.json.' + ts + '.bak')
    shutil.copy2(CANONICAL, backup)
    with CANONICAL.open('w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f'Wrote registry and created backup: {backup}')


def cmd_list(args):
    j = load_registry()
    keys = sorted(j.keys())
    print(f"CITY_COUNT: {len(keys)}")
    for k in keys:
        print(k)


def cmd_add(args):
    city = args.city
    data = load_registry()
    if args.file:
        fp = Path(args.file)
        if not fp.exists():
            print('ERROR: file not found:', fp)
            sys.exit(1)
        with fp.open('r', encoding='utf-8') as f:
            payload = json.load(f)
        # payload can be a list (buildings) or a dict {city: [buildings]}
        if isinstance(payload, dict) and city in payload:
            buildings = payload[city]
        elif isinstance(payload, list):
            buildings = payload
        else:
            print('ERROR: provided file must be either a list of buildings or a dict with the city key')
            sys.exit(1)
    else:
        print('Interactive add mode: please paste a JSON array of building objects, then Ctrl-D:')
        try:
            raw = sys.stdin.read()
            buildings = json.loads(raw)
            if not isinstance(buildings, list):
                print('ERROR: expected a JSON array')
                sys.exit(1)
        except Exception as e:
            print('ERROR reading JSON from stdin:', e)
            sys.exit(1)

    if city in data and not args.replace:
        print(f"City '{city}' already exists. Use --replace to overwrite or remove first.")
        sys.exit(1)

    data[city] = buildings
    write_registry(data)
    print(f"Added/updated city '{city}' with {len(buildings)} buildings.")


def cmd_remove(args):
    city = args.city
    data = load_registry()
    if city not in data:
        print(f"City '{city}' not found in registry.")
        sys.exit(1)
    removed = data.pop(city)
    write_registry(data)
    print(f"Removed city '{city}' ({len(removed)} buildings).")


def cmd_validate(args):
    data = load_registry()
    print('CITY_COUNT:', len(data.keys()))
    # Basic validation: each building has id + name
    errors = 0
    for city, buildings in data.items():
        if not isinstance(buildings, list):
            print('ERROR: city has non-list buildings:', city)
            errors += 1
            continue
        for b in buildings:
            if not isinstance(b, dict):
                print('ERROR: building not object in', city)
                errors += 1
                continue
            if 'id' not in b or 'name' not in b:
                print('ERROR: building missing id/name in', city, b.get('id'))
                errors += 1
    if errors == 0:
        print('Validation passed: no obvious issues found.')
    else:
        print('Validation found', errors, 'issues.')
    sys.exit(0 if errors == 0 else 2)


def main():
    parser = argparse.ArgumentParser(description='Registry edit helper')
    sub = parser.add_subparsers(dest='cmd')

    p_list = sub.add_parser('list')
    p_list.set_defaults(func=cmd_list)

    p_add = sub.add_parser('add')
    p_add.add_argument('city')
    p_add.add_argument('--file', '-f', help='JSON file with either a list of buildings or a dict {city: [buildings]}')
    p_add.add_argument('--replace', action='store_true', help='Replace existing city if present')
    p_add.set_defaults(func=cmd_add)

    p_remove = sub.add_parser('remove')
    p_remove.add_argument('city')
    p_remove.set_defaults(func=cmd_remove)

    p_validate = sub.add_parser('validate')
    p_validate.set_defaults(func=cmd_validate)

    args = parser.parse_args()
    if not args.cmd:
        parser.print_help()
        sys.exit(1)
    args.func(args)

if __name__ == '__main__':
    main()
