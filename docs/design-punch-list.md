# Design punch list (2.5)

From a screenshot audit on iPhone 18 Pro in light mode, dark mode and large text (Accessibility Large),
2026-10-24. Ranked by how much each issue makes the app look unfinished × how often people see it.

## Fixed in this pass

- [x] **Map: title cut off** ("Michigan State..."). Now the short name ("Michigan State"); campuses drop "University" and "Map".
- [x] **Map: no way to close it on iPhone.** Swiping down only panned the map. There's now a Done button on every device.
- [x] **Map: four toolbar buttons.** Filters, satellite/map and Add a Place now share one menu; the right side has two buttons.
- [x] **Map: legend always covering the map** (and a quarter of the screen with large text). It shows once as a popover, then lives behind a small "?" button. Text is now readable (primary color, footnote size).
- [x] **Map: blue 2D/3D and compass controls.** Now orange, like the rest of the app.
- [x] **Map: chips cut off at the screen edge.** Edges fade, the chosen chip scrolls into view, and chips stop growing at XXL text so they don't cover the map.
- [x] **Hotel card: two filled buttons in two colors.** One filled button per card: Check Prices on hotels, Want to Visit elsewhere.
- [x] **Hotel card with large text: name cut in half and buttons wrapping inside themselves.** The card opens full height and the buttons stack.

- [x] **Search lag.** Search now uses an index built once and runs when typing pauses (150 ms); "Ole Miss" keeps up at full typing speed.
- [x] **"My Passport" over search results.** Hidden whenever the search field is active.
- [x] **Home: unlabeled icons.** My Journey, Achievements, World Map and My Trips are labeled tiles under the search bar; only Settings stays in the top bar.
- [x] **Campus page: three stacked cards.** One row of three tiles (Quiz · Plan a Trip · Campus Visit); full-width rows with large text.
- [x] **Large-text "Archi-tecture Quiz".** Fixed by the same tiles.
- [x] **World Map "0 / 241 cities".** Now "0 / 140 cities visited" and "0 / 101 campuses visited"; My Journey's city counts no longer include campuses either.
- [x] **Too many accent colors.** Continent and campus section icons share one orange gradient (no more purple cap or multicolored globes); My Journey stat icons are orange; unvisited landmark pins are gray, matching the map, and no longer pulse. Pink stays for Want to Visit, school colors for campus stamps and traditions.
- [x] **Home empty state too big.** Now a slim banner: "Pick a city or campus below, then stamp every landmark." The home tiles become a 2×2 grid at the largest text sizes.
- [x] **Traditions read like a document.** One-line descriptions that expand on tap, plus a progress ring in the school color.
- [x] **Map strings not translated.** All map text is translated, and the map key rows and filter names now actually use the translations (they were plain strings before).
- [x] **Campus stamps didn't count.** "My Passport" and the home card now count completed campuses ("+ 1 campus"); the welcome banner goes away after any stamp.
- [x] **Passport mixed campuses into countries** (KU Leuven under Belgium). Campuses have their own section near the top with a count (an entry in the iPad sidebar); the header shows cities and campuses separately.
- [x] **Passport text breaking mid-word** ("ARGENTI-NA", "COPEN-HAGEN") with large text.
- [x] **"City Explored!" on a campus stamp.** Now "Campus Explored!".
- [x] **Trip day header cramped**: campus name cut off, "Opti-mize route" over three lines with large text. Now stacked.
- [x] **My College List hard to find.** Now a card on home under the shortcut tiles, showing your schools ("Michigan State, Georgia, and Duke") or a prompt to start; it opens the list and road trip.

### Design system rollout (`Models/Design.swift`)

- [x] **City/campus page sections all look the same now.** Weather, Events, Nearby Dining, Chronology and Travel Dossier sit in cards like Traditions and Landmarks, with the same header, spacing and margins. The itinerary lost its stray divider and uses the same header.
- [x] **Building page.** Big rounded photo first, serif name, fact chips (built, style, height, stories), one full-width Stamp button, then Want to Visit and Look Around.
- [x] **Passport.** Locked cities are a quiet dashed outline instead of gray boxes; stamped cities and campuses stay in color. Country and campus headers match the rest of the app.
- [x] **Trips and College List.** Trip rows are cards with an icon; one filled orange button per screen (Tour, Plan a College Road Trip) and bordered secondary buttons.
- [x] **Found while checking:** hero ring and conference chip in dark green on black (now the dark-mode school color); "Collec-tor" and "land-marks" breaking with large text (facts stack); Campus Visit icon overlapping its title with large text; cloud weather icons invisible in light mode; section headers cut off with large text (now wrap); trip day header campus name too faint.

- [x] **Achievements, My Journey, Settings and onboarding** use the design system: cards, spacing, Dynamic Type, high contrast, gold only for earned/mastered. Settings icons are all orange (they were system blue, because the app has no AccentColor asset).
- [x] **Onboarding "Skip" didn't respond.** It sat alone in an empty navigation bar over the pager with only the text tappable; it's now a 44-pt button in the page. Works in the simulator.
- [x] **Pink only for Want to Visit.** "Arts" events are teal; saved places (which are Want to Visit items) and the Birthday icon now use the shared colors.

- [x] **My Journey and Achievements in every language.** Labels, all achievement titles and goals, category filters and the conference badges ("Roadtrip: Big Ten") are translated in all 8 languages; checked in German.

- [x] **Home and the first-launch card in every language.** Search placeholder, continent names, "My Passport", the welcome banner and the "Unlock Your Collection" card (including its Golden Gate fact) are translated in all 8 languages, and so are the location, camera and photo permission prompts. Checked in German.

- [x] **Country names in every language.** Home, the passport, the World Map and the college list show country names in the app's language and sort them in that language's order (German: Ägypten, Argentinien, Äthiopien). Names come from iOS; England, Scotland and the Australian states are translated in the app. Search finds cities by the translated country name too. The passport title and the World Map legend are translated as well.

## Still to do



- [ ] Three achievement badges use pink as their own badge color.

## Apple's own, can't change

- The hotel/restaurant card's top half is Apple's place card. Its icon is blank for a moment while it loads, and its phone link is low contrast in dark mode.
- Hotel and other Apple Maps pins use Apple's category colors (hotels are purple), the same as in Apple Maps.

## Audited

Home, search, campus page, map, hotel card, World Map, passport, stamp celebration, quiz, My College List,
road trip sheet and trip planner, in light, dark and large text. Not yet: settings, achievements detail,
trip tour in 3D, iPad layouts.