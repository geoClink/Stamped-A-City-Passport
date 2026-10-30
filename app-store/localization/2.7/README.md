# App Store product page – version 2.7 translations

Same layout as `../2.6`. "What's New" is new, and the subtitle, keywords and promotional text are city-first: Stamped leads with city landmarks, with college campuses as the extra. The promotional text already went live on 2.6 on 29 Oct 2026. The subtitle was not final yet; "3D Landmarks & Campus Tours" is the other English option. The rest is copied from 2.6, except that the promotional text and description now say 1,900 landmarks (1,974 in the app) and 112 campuses, and the description has two new lines: restaurants, hotels, tours and local events under PLAN ANY TRIP, and architect pages, photo galleries and Library of Congress photos under DISCOVER THE STORIES.

## What's New

2.7 leads with the 11 new campuses and the new campus cards (History, Game Day, campus event calendars, College Facts), then architect pages, photo galleries and Library of Congress photos, restaurants and hotels near each landmark, the bigger events list with library and museum calendars, map clusters, the quiz and the cleaner pages. Fixes: map pins showing on open, and events listed once. See `CHANGELOG.md` for the full list.

- **Building names** keep their usual local names: 哈利法塔 / 金茂大厦 in Chinese, ブルジュ・ハリファ / 金茂大厦 in Japanese, 부르즈 할리파 / 진마오 타워 in Korean. Trump International Hotel & Tower stays in English except in Japanese, Korean and Chinese.
- **Vision Pro** uses the same version numbers, so its next upload is 2.7 (12) too. Its own What's New is in `../2.6-visionos`.

## ⚠️ Please review

- **College Facts** (the third bullet in every language) only shows if `COLLEGE_SCORECARD_API_KEY` is in the API-key plist on the Mac that archives the build. Without it the card is hidden, so drop that bullet in every language.
- The events bullet no longer names SeatGeek, so it holds either way.
- **Screenshots** still say "101 CAMPUSES" in the first headline (`screenshot_headlines`, unchanged). The images on App Store Connect are what users see; regenerate them if you want 112.
- Student Life (Michigan State only) and the hidden 3D scans aren't in What's New on purpose.

## Character counts (What's New, limit 4000)

| en-US | de-DE | es-ES | es-MX | fr-FR | it | ja | ko | pt-BR | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|
| 1231 | 1471 | 1484 | 1515 | 1499 | 1432 | 663 | 679 | 1445 | 481 |
