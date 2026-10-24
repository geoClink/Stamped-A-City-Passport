# Landmark data audit

Checks `Stamped! A City Passport/Resources/BuildingRegistry.json` for data mistakes.

## Setup (once)

```bash
cd tools/data-audit
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run the audit

```bash
python audit_registry.py --output reports/audit-after.md
```

The audit only **reads** the JSON. It flags:

| Check | What it means |
|---|---|
| `missing_coordinates` | lat/lon missing, 0, or out of range |
| `wrong_country_or_sign` | more than 500 km from the real city centre |
| `far_from_city` | more than 25 km from the real city centre (often a real day trip: decide case by case) |
| `swapped_coordinates` | swapping lat and lon would put it back in the city |
| `placeholder_coordinates` | a rounded number, whole arc-minutes, or the exact city centre instead of the building |
| `stacked_pins` | several different landmarks on exactly the same point |
| `city_centre_mismatch` | the city's landmarks as a group are in the wrong place |
| `duplicate_id` / `duplicate_name` | ids must be unique everywhere (stamps are saved by id) |
| `implausible_year` | `yearBuilt` is 0, in the future, or impossibly old |
| `empty_text` / `stray_whitespace` | empty or placeholder text such as "N/A" |
| `suspicious_size` / `height_unknown` | stories and height that don't fit together |
| `too_few_landmarks` | the quiz needs at least 4 mappable landmarks per city |
| `unknown_city_key` | a JSON city name the app's `City` enum doesn't know (the app silently skips it) |

The real city centre comes from the offline GeoNames list in the `geonamescache` package.

## Fix coordinates

1. Find the landmark's real location in a reliable source (Wikipedia, Wikidata, or OpenStreetMap).
2. Add a row to `coordinate_fixes.csv`: `id,latitude,longitude,source`.
3. Run `python apply_coordinate_fixes.py`. It changes only `latitude`/`longitude`
   and keeps the JSON's formatting, so the git diff stays small.
4. Re-run the audit.

Never rename an `id`: users' iCloud stamps are stored by id.

## Tests

```bash
pytest
```
