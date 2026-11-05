# Learn History with Stamped — plan

Goal: turn each landmark into a history lesson, on iPhone and especially Vision Pro.
Today a landmark has a story, audio, architect page, quiz, Library of Congress photos
and Wikipedia. Missing: history *over time* and the *sources* behind it.

Build in this order. Each phase is shippable on its own.

## Phase 1 — Landmark timeline (no keys needed)
- **Wikidata** (`query.wikidata.org/sparql`, already called once): built (P571),
  demolished (P576), significant events (P793), heritage designation (P1435),
  "replaces" / "replaced by" (P1365/P1366) → a timeline and "what stood here before".
- **Chronicling America** (`chroniclingamerica.loc.gov/search/pages/results/?format=json`):
  newspaper pages near the build year that mention the landmark. Pre-1927 pages
  are public domain. Show "What the paper said" with a page image and a link.
- Shared code (iPhone + Vision): `HistoryTimelineService`, `HistoryTimelineView`.

## Phase 2 — Then vs. now map (no keys needed)
- **OpenHistoricalMap** vector tiles, plus **David Rumsey** georeferenced maps
  (check each map's licence; many are CC BY-NC-SA, which the app may not use
  commercially: confirm before shipping).
- Vision Pro: a slider on the 3D map that fades an old map over today's.

## Phase 3 — More archives (free API keys needed: the user signs up)
- **DPLA** (`api.dp.la`, key by email), **Smithsonian Open Access** (`api.si.edu`, key via
  api.data.gov, already used for College Scorecard), **Europeana** (`api.europeana.eu`, free key).
- Only show items whose rights are public domain / CC0 / CC BY; show the credit.
- Extends the existing historic photos section.

## Phase 4 — Official significance
- **National Register of Historic Places** (NPS NPGallery / NRHP dataset): the
  "why it matters" statement and nomination PDF for US landmarks. Probably best
  baked into BuildingRegistry.json by a tools/ script instead of fetched live.
- **UNESCO World Heritage** list (`whc.unesco.org/en/list/xml` or the open dataset):
  a badge plus the outstanding universal value text. Also bake into the registry.

## Phase 5 — Daily hook
- **Wikimedia "On this day"** (`api.wikimedia.org/feed/v1/wikipedia/en/onthisday/all/MM/DD`):
  events matched to the app's cities/landmarks → a home card and an optional notification.

## Phase 6 — Ask the building
- **Apple Foundation Models** (on device, already used once): spoken Q&A grounded only in
  the landmark's own text + timeline (no made-up facts; answer "I don't know" otherwise).

## Phase 7 — Lost buildings in 3D (token needed)
- **Sketchfab Download API** (OAuth token): only CC BY / CC0 models of demolished or
  historic buildings, shown in the city volume or immersive space with credit.

## Notes
- Every source needs an on-screen credit and a rights check; keep a list in AudioCredits-style JSON.
- Cache everything (OfflineStore already does this for Wikipedia).
- New UI strings need translations in both string catalogs.
