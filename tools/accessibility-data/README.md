# Landmark accessibility data

Builds `Stamped! A City Passport/Resources/LandmarkAccessibility.json`: whether each
landmark has step-free (wheelchair) access, from OpenStreetMap. The app shows it in the
"Accessibility" card on a landmark's page.

## Setup (once)

```bash
cd tools/accessibility-data
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run

```bash
python build_accessibility.py            # asks Overpass, then writes the JSON
python build_accessibility.py --offline  # re-match using the saved answers in .cache/
```

One Overpass query per city or campus (spread-out cities get a few), each asking only
about a small box around every landmark's pin. One request at a time with a pause,
backing off (30 s, doubling to 5 min) on 429/502/504; after two failures in a row it
moves to the next public Overpass server. A box that never gets an answer is listed at
the end; re-run to retry it. Answers are saved in `.cache/` (git-ignored) so you can
stop and resume.

## What counts as a match

- an OSM building, attraction or amenity (not a bus stop, entrance or car park)
- with the same or nearly the same name (or the name without the city, e.g. "Guildhall")
- within 150 m of the landmark's pin, or with the pin inside its outline
- tagged `wheelchair=yes`, `limited` or `no`

Anything else is left out: we never guess. If two equally good matches disagree, the
landmark is left out too. Only `wheelchair`, `toilets:wheelchair` and the OSM id are kept.

The data is © OpenStreetMap contributors under the ODbL; the app shows that credit.

## Tests

```bash
pytest
```
