# Landmark photo audit

Checks the Wikipedia photo the app shows for every landmark in
`BuildingRegistry.json`, using the same lookup as
`Stamped! A City Passport/Managers/WikimediaService.swift`. It reads the
`titleOverrides` table and the logo patterns straight out of that Swift file,
so the audit always matches what the app does.

## Setup (once)

```bash
cd tools/photo-audit
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## Run

```bash
.venv/bin/python audit.py --label after     # reports/audit-after.md (+ .json)
.venv/bin/python find_titles.py --report reports/audit-after.json   # reports/suggestions.json
.venv/bin/python manual_review.py           # reports/manual-review.md (needs audit-before/after.json)
```

Every HTTP response is cached in `cache/http_cache.json`, so a rerun takes
seconds. Delete that file to re-check against live Wikipedia.

## Categories

| Category | Meaning |
| --- | --- |
| `ok` | A real photo, from an article near the landmark |
| `no_article` | None of the titles the app tries exists |
| `disambiguation` | The title lands on a "may refer to" page |
| `no_photo` | Article found, but no usable photo in it |
| `logo_like` | File name looks like a logo/map/seal/flag/diagram |
| `far_away` | Article is more than 2 km from the registry coordinates |
| `skipped` | In `skipWikipedia`: Wikipedia only has a different place, so the app shows its placeholder |

`far_away` usually means the registry coordinates are wrong, not the article.

## Adding an override

`find_titles.py` only suggests a title when the article is within 2 km of the
landmark, shares its distinctive words, and gives a real photo. Still read the
suggestions before using them: a nearby article can pass all three checks and
be a different building. Add good ones to `titleOverrides` (keyed by building
`id`, grouped by city), then rerun `audit.py`.
