#!/usr/bin/env python3
"""
convert_registry.py

Utilities to convert between the canonical JSON `Resources/BuildingRegistry.json`
and an editable Python file `scripts/registry_editable.py` containing a
`REGISTRY` dict (useful for editing in VS Code with Python autocompletion).

Usage:
  - Export JSON -> editable Python:
      ./scripts/convert_registry.py export

  - Import editable Python -> JSON (overwrite):
      ./scripts/convert_registry.py import

  - Print help:
      ./scripts/convert_registry.py --help

The script validates basic schema expectations (top-level dict of city -> list of
building dicts) and preserves the JSON formatting (2-space indents).
"""
import argparse
import json
import os
import sys
from pprint import pformat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(ROOT, 'Stamped! A City Passport', 'Resources', 'BuildingRegistry.json')
EDITABLE_PY = os.path.join(ROOT, 'scripts', 'registry_editable.py')


def load_json(path=JSON_PATH):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def write_json(data, path=JSON_PATH):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def export_to_py(json_path=JSON_PATH, py_path=EDITABLE_PY):
    data = load_json(json_path)
    if not isinstance(data, dict):
        print('ERROR: JSON root is not an object/dict')
        sys.exit(2)

    # Create a Python file with a single REGISTRY variable assigned
    header = (
        '# Generated from Resources/BuildingRegistry.json - edit this file in VS Code\n'
        '# and run `./scripts/convert_registry.py import` to push changes back to the app JSON.\n\n'
        'REGISTRY = '
    )

    with open(py_path, 'w', encoding='utf-8') as f:
        f.write(header)
        # Use pformat for a readable, valid Python literal
        f.write(pformat(data, width=120))
        f.write('\n')

    print(f'Exported JSON -> Python editable: {py_path}')


def import_from_py(py_path=EDITABLE_PY, json_path=JSON_PATH):
    if not os.path.exists(py_path):
        print(f'ERROR: editable Python file not found: {py_path}')
        sys.exit(2)

    # Import the file as a module by executing it in a temporary namespace
    namespace = {}
    with open(py_path, 'r', encoding='utf-8') as f:
        code = f.read()
    exec(code, namespace)
    if 'REGISTRY' not in namespace:
        print('ERROR: REGISTRY variable not found in editable Python file')
        sys.exit(2)

    data = namespace['REGISTRY']
    # Basic validation
    if not isinstance(data, dict):
        print('ERROR: REGISTRY is not a dict in the editable file')
        sys.exit(2)

    # Optionally further validate building entries - ensure lists of dicts
    for city, arr in data.items():
        if not isinstance(arr, list):
            print(f'ERROR: city {city!r} has non-list value')
            sys.exit(2)
        for b in arr:
            if not isinstance(b, dict):
                print(f'ERROR: building entry in {city!r} is not a dict')
                sys.exit(2)

    # Write back to JSON (overwrite)
    write_json(data, json_path)
    print(f'Imported editable Python -> JSON: {json_path}')


def main():
    parser = argparse.ArgumentParser(description='Convert BuildingRegistry between JSON and editable Python')
    parser.add_argument('cmd', choices=['export', 'import'], help='export = JSON -> editable Python; import = editable Python -> JSON')
    args = parser.parse_args()

    if args.cmd == 'export':
        export_to_py()
    elif args.cmd == 'import':
        import_from_py()


if __name__ == '__main__':
    main()
