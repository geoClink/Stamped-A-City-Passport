"""Apply the verified coordinate fixes in coordinate_fixes.csv to BuildingRegistry.json.

Usage (from tools/data-audit, with the venv active):
    python apply_coordinate_fixes.py

Each CSV row names a landmark id, its corrected latitude/longitude, and the
source the numbers came from. Only latitude and longitude are touched, and the
JSON is written back with the same indentation and key order, so the git diff
shows just the changed numbers. Running it twice is safe.
"""

import csv
import json
import sys
from pathlib import Path

from audit_registry import REGISTRY_PATH

FIXES_PATH = Path(__file__).resolve().parent / "coordinate_fixes.csv"


def load_fixes(fixes_path: Path) -> dict[str, tuple[float, float]]:
    """Map landmark id -> (latitude, longitude) from the CSV."""
    fixes: dict[str, tuple[float, float]] = {}
    with fixes_path.open(encoding="utf-8", newline="") as fixes_file:
        for row in csv.DictReader(fixes_file):
            fixes[row["id"]] = (float(row["latitude"]), float(row["longitude"]))
    return fixes


def apply_fixes(registry: dict[str, list[dict]], fixes: dict[str, tuple[float, float]]) -> list[str]:
    """Update coordinates in place and return a human-readable change log."""
    change_log: list[str] = []
    unused_ids = set(fixes)
    for city_name, landmarks in registry.items():
        for landmark in landmarks:
            landmark_id = landmark["id"]
            if landmark_id not in fixes:
                continue
            unused_ids.discard(landmark_id)
            new_latitude, new_longitude = fixes[landmark_id]
            old_point = (landmark["latitude"], landmark["longitude"])
            if old_point == (new_latitude, new_longitude):
                continue
            # Assigning to existing keys keeps their position in the dict,
            # so the key order in the JSON file doesn't change.
            landmark["latitude"] = new_latitude
            landmark["longitude"] = new_longitude
            change_log.append(f"{city_name}: {landmark_id} {old_point} -> ({new_latitude}, {new_longitude})")
    for landmark_id in sorted(unused_ids):
        change_log.append(f"WARNING: {landmark_id} is in the CSV but not in the registry")
    return change_log


def main() -> int:
    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    change_log = apply_fixes(registry, load_fixes(FIXES_PATH))
    # indent=2 and ensure_ascii=False match how the file is already formatted
    # (e.g. "São Paulo" stays readable instead of becoming "São Paulo").
    REGISTRY_PATH.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")
    print("\n".join(change_log) or "No changes needed.")
    print(f"{sum(1 for line in change_log if not line.startswith('WARNING'))} landmarks updated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
