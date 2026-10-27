# App Store product page – version 2.6 translations

Same layout as `../2.5`, and every field except "What's New" is copied from 2.5 unchanged. The description's rounded numbers still hold: "more than 1,800" landmarks (1,879), 101 campuses, "over 250" traditions (263).

## What's New

2.6 leads with Michigan State (14 more buildings, 7 more traditions), then the "Know a tradition we're missing?" link, website links that open the app, full-screen Look Around and Apple Weather, plus two report-email fixes. See `CHANGELOG.md` for the full list.

- **Apple Weather** uses Apple's own name for the Weather app in each language (Apple Wetter, Météo Apple, El Tiempo de Apple, Clima de Apple, Meteo di Apple, Tempo da Apple, Apple の天気, Apple 날씨, Apple 天气).
- **Vision Pro** is left out: it ships separately, after its own review.

## ⚠️ Please review

- The website links only work once the site's `.well-known/apple-app-site-association` is live (it is) and the build is signed with the Associated Domains capability. Test a link on a real iPhone before submitting; if it doesn't work, drop that bullet.

## Character counts (What's New, limit 4000)

| en-US | de-DE | es-ES | es-MX | fr-FR | it | ja | ko | pt-BR | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|
| 554 | 636 | 633 | 625 | 666 | 617 | 327 | 323 | 581 | 275 |
