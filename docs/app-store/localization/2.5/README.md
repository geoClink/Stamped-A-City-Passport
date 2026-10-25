# App Store product page – version 2.5 translations

Same layout as `../2.4`: one JSON file per App Store Connect locale, with every text field of the product page plus the screenshot and banner headlines. See `../2.4/README.md` for the locale table and how to paste the text into App Store Connect.

## What changed from 2.4

2.5 leads with the college features: 101 campuses grouped by conference, My College List, College Road Trip, Plan a Campus Visit, campus traditions, school-colored stamps, nickname search, and the hotel buttons. City features are still listed below them.

- **Numbers** (from the app data): 1,865 landmarks ("more than 1,800"), 140 cities, 101 campuses with 470 buildings, 256 traditions ("over 250").
- **Disclaimer:** the last paragraph of every description is the same not-affiliated sentence the app shows in Settings and on campus pages.
- **Vision Pro:** left out on purpose. The Vision Pro app shares this listing but still needs its own review. If it ships with 2.5, add a bullet to "What's New" and the description.
- **Hotels:** described as "find hotels" / "opens a hotel search", with no mention of prices or deals, because no affiliate program is set up yet.
- **Keywords:** rebuilt around college searches (college visit, studying in the US, campus tour) in each market's own words: Studium USA, études aux USA, estudiar en EEUU / USA, studiare in USA, intercâmbio, アメリカ留学 and オープンキャンパス, 미국유학, 美国留学. None repeats a word from the app name.
- **Subtitles** in es, fr and it shortened to "Campus and architecture" to fit the 30-character limit.
- **Conference names** (Big Ten, SEC, ACC, Big 12) stay in English in every language, as they do in the app.

## ⚠️ Please review

- The **screenshot headlines** are new and need new screenshots: the college list or road trip, the traditions section, a school-colored stamp, and a campus in 3D. The old 2.4 shots for trips and the quiz still fit slots 5 and 6.
- "Over 250 traditions" and "101 campuses" depend on the data you approve in `docs/campus-review-2.5.md`. If you remove traditions, check that the count still holds.

## Character counts (all under the limits)

| Locale | Subtitle (30) | Promo (170) | Keywords (100) | What's New (4000) | Description (4000) |
|---|---|---|---|---|---|
| en-US | 28 | 163 | 93 | 960 | 1945 |
| de-DE | 27 | 169 | 91 | 1091 | 2239 |
| es-ES | 21 | 170 | 94 | 1177 | 2232 |
| es-MX | 21 | 167 | 95 | 1174 | 2223 |
| fr-FR | 22 | 154 | 93 | 1222 | 2355 |
| it | 21 | 163 | 90 | 1117 | 2183 |
| ja | 14 | 89 | 60 | 503 | 926 |
| ko | 16 | 98 | 47 | 556 | 972 |
| pt-BR | 30 | 164 | 94 | 1107 | 2121 |
| zh-Hans | 11 | 65 | 46 | 377 | 714 |
