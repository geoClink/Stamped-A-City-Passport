# Stamped! 2.8 – iPad, Mac and Apple Vision Pro App Store screenshots

Same look as the iPhone set (`PLAN.md`): orange #F2743F, SF Pro Display Black, a big verb over one or
two descriptor lines, the app underneath. Counts used: 156 cities, 117 campuses.

Captured 2026-11-02 from `main` (9bd07b9) in light mode, English, 9:41 status bar, with stamps,
traditions, a college list and one Chicago trip seeded by temporary launch hooks (env-var driven,
all removed again; their saves were blocked, so nothing was written to iCloud or left on the devices).

How to rebuild every set in every language (from `screenshots/`):

    python3 2.8/render_locales.py            # or: python3 2.8/render_locales.py ja ko

It reads `2.8/headlines.json` ({locale: {set: [{verb, lines}]}}) and writes
`2.8/<set>/<locale>/01.png, 02.png, ...` (set = iphone, ipad, mac, vision) plus one contact sheet per
language in `2.8/contact-sheets/<locale>.jpg`. Only the headline changes per language; the app screens
are the English captures. Japanese uses Hiragino Kaku Gothic W9, Korean Apple SD Gothic Neo Heavy,
Chinese Hiragino Sans GB W6, everything else SF Pro Display Black. A headline that is too wide is
shrunk until it fits (never clipped); English is drawn at the design size, unchanged.

Raw captures are in `raw/` (iPhone), `raw-ipad/`, `raw-mac/` and `raw-vision/`. The iPad alternate is
made by hand: `python3 compose.py ipad-full 2.8/raw-ipad/07-save-offline.png SAVE "CITIES FOR|OFFLINE TRIPS" 2.8/ipad/alt-07-save-offline.png`.

## Uploading (tools/appstore-metadata/upload_metadata.py, branch feature/uploader-platform)

One folder per language, e.g. `--screenshots screenshots/2.8/ipad/de-DE --screenshot-locales de-DE`:

| Set | --platform | --display-type | Size |
|---|---|---|---|
| iphone | ios | APP_IPHONE_67 (the 6.9" slot; takes 1320 x 2868 and 1290 x 2796) | 1320 x 2868 |
| ipad | ios | APP_IPAD_PRO_3GEN_129 (the 13" slot; takes 2064 x 2752 and 2048 x 2732) | 2064 x 2752 |
| mac | macos | APP_DESKTOP (default) | 2880 x 1800 |
| vision | visionos | APP_APPLE_VISION_PRO (default) | 3840 x 2160 |

## iPad 13" (`ipad/`, 2064 x 2752)

Captured on an iPad Pro 13" simulator clone (iPadOS 27).

| # | File | Headline (verb / descriptor) | What's on screen |
|---|---|---|---|
| 1 | `01.png` | VISIT / 156 CITIES AND / 117 CAMPUSES | New sidebar layout: home sidebar with the Campuses filter (Big Ten), Michigan State's campus page open beside it, campus stamp in school colours |
| 2 | `02.png` | SEE / EVERY STAMP ON / ONE WORLD MAP | Full-screen World Map: the Americas and Europe with visited pins and clusters; 133/156 cities, 14/117 campuses |
| 3 | `03.png` | COLLECT / A PASSPORT PAGE / FOR EVERY COUNTRY | My Passport opened on its stamped countries list, United States page of city stamps |
| 4 | `04.png` | LISTEN / TO THE STORY BEHIND / EVERY BUILDING | The Rookery (Chicago) landmark page with the Listen button above its story |
| 5 | `05.png` | STAY / STEPS FROM / THE LANDMARKS | The Rookery's Local Flavors and Stays Near Here: hotel cards with walking times, "Compare on Booking.com" and "Vacation Rentals on Vrbo" |
| 6 | `06.png` | PLAN / YOUR WHOLE TRIP, / DAY BY DAY | Trip planner: "Chicago Architecture Weekend", 3 days, route map, Tour This Trip in 3D, Find Hotels / Booking.com / Vrbo |
| alt | `alt-07-save-offline.png` | SAVE / CITIES FOR / OFFLINE TRIPS | Kyoto Plan tab: itinerary, "Saved for Offline" (4 MB) card, Travel Dossier |

## Mac (`mac/`, 2880 x 1800)

Built from `main` and run on this Mac; windows opened by the app's own window scenes and captured
with `screencapture -l <window id>`. Each panel is a real window, not a sheet.

| # | File | Headline (verb / descriptor) | What's on screen |
|---|---|---|---|
| 1 | `01.png` | FLY / THROUGH 156 CITIES IN 3D | Main 3-column window: city sidebar, Chicago photoreal 3D map with stamped pins, city details inspector |
| 2 | `02.png` | SEE / YOUR STAMPS ON A WORLD MAP | Main window plus the World Map window (Europe, Africa, Asia; 133/156 cities) |
| 3 | `03.png` | PLAN / YOUR WHOLE TRIP, DAY BY DAY | Main window plus the My Trips window: Chicago Architecture Weekend with route map and Day 1 |
| 4 | `04.png` | COLLECT / STAMPS AND ACHIEVEMENTS | Main window plus My Journey and, on top, Achievements (31/40) windows |
| 5 | `05.png` | TEST / YOUR ARCHITECTURE SMARTS | Main window plus the Architecture Quiz window (Chicago, The Rookery question) |

Also captured but not used: `raw-mac/win-college-list.png` (My College List window).

## Apple Vision Pro (`vision/`, 3840 x 2160)

Captured on the Apple Vision Pro simulator (visionOS 27).

| # | File | Headline (verb / descriptor) | What's on screen |
|---|---|---|---|
| 1 | `01.png` | EXPLORE / EVERY LANDMARK IN 3D | Rome 3D map, the Colosseum card with Listen, 360° View, Want to Go and the Look Around preview |
| 2 | `02.png` | STEP / INSIDE LANDMARKS IN 360° | Full immersive 360° panorama of the Taj Mahal Palace Hotel's grand staircase (Mumbai), with the credit card and Exit |
| 3 | `03.png` | TOUR / A CITY WITH A NARRATED FLYOVER | Play Tour running: the camera flies to each landmark and its card shows while the story is read |
| 4 | `04.png` | VISIT / 156 CITIES AND 117 CAMPUSES | Main window: city list with stamp progress, a city's photoreal 3D map |

## iPhone fix

`iphone/01-college-list.png` was re-rendered with "117 CAMPUSES" (was 112). Its headline in the
localization JSON needs the same number change.

## Translations

All in `headlines.json`. Shrunk to fit (iPhone unless noted): es-ES/es-MX 03 and 06 (es-ES 05 too), fr-FR 03 (COLLECTIONNEZ, 56%), 04, 05 and iPad 03, it 03 and 05, pt-BR 03 and iPad 04, ja several by 2-4%.
