"""Build the "Student Life" section of campus pages from student_life.json.

student_life.json lists, per campus, the places a prospective student would want to see:
residence-hall neighborhoods, the student union, study spots, dining halls and hangouts.
This script:

1. Checks every spot (required fields, unique "life_" ids, a known category, and that
   its coordinates are within 2 km of the campus's map centre in CityCoordinates.swift).
2. Writes CampusStudentLife.json (unless --check is passed): English in Resources/, and one
   per language in each *.lproj/, using translations/student_life/<language>.json.
   A spot that isn't translated yet uses the English text.

It is separate from build_campuses.py so the two can change without merge conflicts.

Run from this folder:
    python build_student_life.py --check      # check only, writes nothing
    python build_student_life.py              # check, then write the app files
"""

import argparse
import json
import re
import sys
from pathlib import Path

from build_campuses import APP_DIR, COORDINATES_PATH, MAX_KM_FROM_CAMPUS, MODEL_PATH, distance_km

TOOL_DIR = Path(__file__).resolve().parent
SOURCE_PATH = TOOL_DIR / "student_life.json"
# Spot descriptions per language: {campus name: {spot id: {description, optional name}}}
TRANSLATION_FOLDER = TOOL_DIR / "translations" / "student_life"
OUTPUT_FILE = "CampusStudentLife.json"  # in Resources/ (English) and each *.lproj/

# Must match StudentLifeSpot.Category in Models/CampusStudentLife.swift
CATEGORIES = ["housing", "union", "study", "dining", "hangout"]
REQUIRED_FIELDS = ["id", "name", "category", "description", "coordinatesSource", "source"]


def campus_centres() -> dict[str, tuple[float, float]]:
    """Campus name -> (lat, lon) map centre, read from Model.swift and CityCoordinates.swift."""
    # `case michiganState = "Michigan State University"` gives the enum case for each name
    names = dict(re.findall(r'case (\w+) = "([^"]+)"', MODEL_PATH.read_text()))
    # `case .michiganState:       return (42.7306, -84.4823)`
    centres = {
        case: (float(lat), float(lon))
        for case, lat, lon in re.findall(r"case \.(\w+):\s*return \((-?[\d.]+), (-?[\d.]+)\)", COORDINATES_PATH.read_text())
    }
    return {name: centres[case] for case, name in names.items() if case in centres}


def check(spots_by_campus: dict) -> list[str]:
    errors: list[str] = []
    centres = campus_centres()
    seen_ids: set[str] = set()
    for campus, spots in spots_by_campus.items():
        if campus not in centres:
            errors.append(f"{campus}: not a campus in Model.swift / CityCoordinates.swift")
            continue
        for spot in spots:
            label = f"{campus} / {spot.get('name', '?')}"
            for field in REQUIRED_FIELDS:
                if not str(spot.get(field, "")).strip():
                    errors.append(f"{label}: '{field}' is empty")
            spot_id = spot.get("id", "")
            if not re.fullmatch(r"life_[a-z0-9_]+", spot_id):
                errors.append(f"{label}: id '{spot_id}' should look like life_school_place")
            if spot_id in seen_ids:
                errors.append(f"{label}: duplicate id '{spot_id}'")
            seen_ids.add(spot_id)
            if spot.get("category") not in CATEGORIES:
                errors.append(f"{label}: category '{spot.get('category')}' is not one of {', '.join(CATEGORIES)}")
            point = spot.get("coordinates")
            if not (isinstance(point, list) and len(point) == 2 and all(isinstance(v, (int, float)) for v in point)):
                errors.append(f"{label}: needs 'coordinates' [lat, lon]")
                continue
            km = distance_km(*centres[campus], *point)
            if km > MAX_KM_FROM_CAMPUS:
                errors.append(f"{label}: {km:.2f} km from the campus centre")
    return errors


def load_translations(language: str) -> dict:
    path = TRANSLATION_FOLDER / f"{language}.json"
    return json.loads(path.read_text()) if path.exists() else {}


def entries(spots_by_campus: dict, translations: dict) -> dict:
    """The app's format: campus name -> [{id, name, category, description, latitude, longitude}]."""
    result = {}
    for campus, spots in spots_by_campus.items():
        translated = translations.get(campus, {})
        result[campus] = [
            {
                "id": spot["id"],
                # Proper names (hall names, "MSU Union") normally stay in English
                "name": translated.get(spot["id"], {}).get("name", spot["name"]),
                "category": spot["category"],
                "description": translated.get(spot["id"], {}).get("description", spot["description"]),
                "latitude": spot["coordinates"][0],
                "longitude": spot["coordinates"][1],
            }
            for spot in spots
        ]
    return result


def write(spots_by_campus: dict) -> None:
    def dump(data: dict) -> str:
        return json.dumps(data, indent=2, ensure_ascii=False) + "\n"

    (APP_DIR / "Resources" / OUTPUT_FILE).write_text(dump(entries(spots_by_campus, {})))
    # Same languages as the campus details (de.lproj, ja.lproj...)
    for language_path in sorted(APP_DIR.glob("*.lproj/CityDetails.json")):
        language = language_path.parent.stem
        translations = load_translations(language)
        missing = [
            spot["id"] for campus, spots in spots_by_campus.items() for spot in spots
            if "description" not in translations.get(campus, {}).get(spot["id"], {})
        ]
        if missing:
            print(f"warning: {language}: {len(missing)} spots not translated (English is used)")
        (language_path.parent / OUTPUT_FILE).write_text(dump(entries(spots_by_campus, translations)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="check only, write nothing")
    args = parser.parse_args()

    spots_by_campus = json.loads(SOURCE_PATH.read_text())
    errors = check(spots_by_campus)
    for error in errors:
        print(f"error: {error}")
    if errors:
        sys.exit(1)
    count = sum(len(spots) for spots in spots_by_campus.values())
    print(f"{count} student-life spots on {len(spots_by_campus)} campuses look good")
    if not args.check:
        write(spots_by_campus)
        print(f"wrote {OUTPUT_FILE} in Resources/ and every *.lproj/")


if __name__ == "__main__":
    main()
