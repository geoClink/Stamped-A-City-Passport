# App Store product page – version 2.7 translations

Same layout as `../2.6`, and every field except "What's New" is copied from 2.6 unchanged. The description's rounded numbers still hold: "more than 1,800" landmarks (1,882), 101 campuses.

## What's New

2.7 leads with map pins that group into numbered bubbles, then Adrian Smith's towers and SeatGeek events, plus the fix for city map pins that only showed once the map was moved. See `CHANGELOG.md` for the full list.

- **Building names** keep their usual local names: 哈利法塔 / 金茂大厦 in Chinese, ブルジュ・ハリファ / 金茂大厦 in Japanese, 부르즈 할리파 / 진마오 타워 in Korean. Trump International Hotel & Tower stays in English except in Japanese, Korean and Chinese.
- **Vision Pro** uses the same version numbers, so its next upload is 2.7 (12) too. Its own What's New is in `../2.6-visionos`.

## ⚠️ Please review

- The SeatGeek bullet is only true if `SEATGEEK_CLIENT_ID` is in the API-key plist on the Mac that archives the build. Without it the app uses Ticketmaster only, so drop that bullet in every language.

## Character counts (What's New, limit 4000)

| en-US | de-DE | es-ES | es-MX | fr-FR | it | ja | ko | pt-BR | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|
| 416 | 506 | 473 | 483 | 482 | 462 | 255 | 240 | 473 | 169 |
