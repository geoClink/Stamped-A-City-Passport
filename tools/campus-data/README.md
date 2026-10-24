# Campus Architecture data

The "Campus Architecture" collection in the city list is built from the JSON files in
`campuses/`. Each campus is a case of `CityLocation.City`, so stamps, the map, the quiz,
the trip planner and the passport work for it like any city. Campuses get their own list
section and their own achievements, and the city counts leave them out (see
`Models/Campus.swift`).

## Setup (once)

```bash
cd tools/campus-data
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

The script itself only uses the Python standard library; `requirements.txt` is for the tests.

## Add or change a campus

1. Edit (or add) a file in `campuses/`. Copy the shape of an existing campus.
   - `wiki` is the building's exact English Wikipedia title. The script takes the coordinates
     from that article, so you never type coordinates by hand. Only if the article has none,
     add `"coordinates": [lat, lon]` and `"coordinatesSource"` (the OpenStreetMap link you checked).
   - When several buildings are only described together in one article (e.g. Florida Southern's
     "Child of the Sun"), set `"sharedArticle": true` on each one and give each its own hand-checked
     `coordinates`. The article's single point is then ignored, and no shared photo is used.
   - Building ids look like `campus_yale_sterling_library` and must never change once shipped
     (iCloud stamps are saved by id).
2. Check it:
   ```bash
   python build_campuses.py --check
   ```
3. Write the app files:
   ```bash
   python build_campuses.py
   ```
   This appends campus entries to the end of `BuildingRegistry.json` and `CityDetails.json`
   (existing cities are never reformatted), replaces the `BEGIN CAMPUSES` / `END CAMPUSES` blocks
   in `Model.swift` and `CityCoordinates.swift`, and rewrites `Models/CampusList.swift`.

## What the check catches

| Check | Why |
|---|---|
| Fewer than 4 buildings | The quiz needs 4 landmarks per city or campus |
| Building more than 2 km from its campus | Wrong article, or a building on another campus |
| No coordinates on the Wikipedia article | Pick the right article or add hand-checked OSM coordinates |
| Duplicate id, enum case or name | Ids must be unique across the whole app |
| Country not in `CityLocation.Country` | Add the country to the app first |
| Empty text, odd year | Missing or placeholder data |

## Translations

Each app language has its own `CityDetails.json` (e.g. `de.lproj/CityDetails.json`). The script also
appends campus details to each of those, using `translations/<language>.json` (campus name → the 8
translated fields: nickname, airportInfo, funFact, language, languageInfo, currencyInfo, transportation,
transportationFact). A campus or field that isn't translated yet uses the English text, and
`--check` warns about it. When you add a campus, add its translations too.

`wiki_coordinates.json` caches the Wikipedia lookups so later runs are fast and repeatable.

## Tests

```bash
python -m pytest
```
