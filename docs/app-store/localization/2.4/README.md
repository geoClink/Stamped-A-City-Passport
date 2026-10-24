# App Store product page – version 2.4 translations

One JSON file per App Store Connect locale. Each file has every text field of the product page for 2.4, plus the screenshot and banner headlines.

| File | App Store Connect language |
|---|---|
| `en-US.json` | English (U.S.) – the source |
| `de-DE.json` | German |
| `es-ES.json` | Spanish (Spain) |
| `es-MX.json` | Spanish (Mexico) |
| `fr-FR.json` | French |
| `it.json` | Italian |
| `ja.json` | Japanese |
| `ko.json` | Korean |
| `pt-BR.json` | Portuguese (Brazil) |
| `zh-Hans.json` | Chinese (Simplified) |

## ⚠️ DRAFT: the description is new, please approve it

The current English App Store description isn't in the repo (I searched `README.md`, both copies of `APP_STORE_CHECKLIST.md`, `docs/`, the `MSU_*` files and `CHANGELOG.md`). I couldn't read the live App Store page from the cloud machine either.

So `description` in `en-US.json` is a **new draft**, written only from features that exist in the code and the 2.4 changelog. Those features are the trip planner, the 3D map and guided tours, stamps with photos, the world map, achievements, sharing, the widget, the quiz, Campus Architecture, Want to Visit, Ticketmaster events, weather, places to eat, the travel dossier, the currency converter, ambient sounds, 9 languages, and high contrast and reduce motion. The Vision Pro app is left out because it's still "Unreleased". The 8 translations follow this draft. If you change the English, the translations need the same change.

Also new proposals (not existing text): `subtitle` and `keywords` for every language, including English.

## Fields and limits

| Field | App Store Connect box | Limit |
|---|---|---|
| `subtitle` | App Information → Subtitle | 30 |
| `promotional_text` | Version page → Promotional Text | 170 |
| `description` | Version page → Description | 4000 |
| `keywords` | Version page → Keywords | 100 |
| `whats_new` | Version page → What's New in This Version | 4000 |
| `screenshot_headlines`, `banner` | not pasted: read by the screenshot and banner scripts on the Mac | – |

## Character counts (all under the limits)

| Locale | Subtitle (30) | Promo (170) | Keywords (100) | What's New (4000) | Description (4000) |
|---|---|---|---|---|---|
| en-US | 27 | 138 | 98 | 1408 | 1666 |
| de-DE | 27 | 150 | 99 | 1680 | 1923 |
| es-ES | 29 | 151 | 96 | 1742 | 1942 |
| es-MX | 29 | 150 | 97 | 1762 | 1962 |
| fr-FR | 28 | 153 | 96 | 1772 | 2025 |
| it | 29 | 153 | 98 | 1647 | 1874 |
| ja | 11 | 75 | 61 | 781 | 806 |
| ko | 14 | 89 | 54 | 829 | 862 |
| pt-BR | 29 | 157 | 97 | 1641 | 1857 |
| zh-Hans | 11 | 57 | 47 | 571 | 621 |

Counts are Unicode characters, the same way App Store Connect counts them. Nothing had to be cut to fit a limit.

## How to paste them into App Store Connect

1. Open App Store Connect → your app → the **2.4** version page.
2. Click the language menu at the top right (it says "English (U.S.)"). If a language isn't listed yet, choose **Add Language** and add it. The table at the top of this file says which file goes with which language.
3. Open that language's JSON file in Xcode or any text editor. Copy each field into the box named in the "Fields and limits" table. Copy only the text **between the quotes**.
4. `\n` in the JSON means "new line". When you paste, start a new line wherever you see `\n`. The quick way is to print a field with real line breaks in Terminal, then copy it from there:
   ```bash
   cd docs/app-store/localization/2.4
   python3 -c "import json; print(json.load(open('de-DE.json'))['whats_new'])"
   ```
   Swap `de-DE.json` and `whats_new` for the file and field you need.
5. **Subtitle** is on the **App Information** page, not the version page. Change the language menu there too.
6. Click **Save** for each language before you switch to the next one.

## Notes on the wording

- Words already used in the app are reused, so the store page matches the app: "Want to Visit" (Wunschziele, Quiero visitar, À visiter, Da visitare, 行きたい場所, 가보고 싶은 곳, Quero visitar, 想去的地方), "Landmarks" (Wahrzeichen, monumentos, monuments, monumenti, ランドマーク, 랜드마크, marcos, 地标), "Campus Architecture" and "Stamped".
- "Look Around" uses Apple's own name in each language: Umsehen, Mirar alrededor, Look Around (French and Japanese keep the English), Guardati intorno, 둘러보기, Olhe ao Redor, 四处看看.
- German, Spanish, Italian and Portuguese speak to the reader informally (du/tú/tu/você), as most App Store pages do. French uses vous.
- es-MX and es-ES differ where people really talk differently: boletos/entradas, agrega/añade, pronóstico del clima/previsión del tiempo, "1,500"/"1.500".
- Keywords are what travellers in each market type into search, not word-for-word translations. Examples: Städtereise, escapada, carnet de voyage, スタンプラリー, 여행일정, roteiro, 打卡, 旅游攻略. None of them repeats a word from the app name. They use commas with no spaces.
- "Stamped!" is never translated.
- Headlines: the verb is one word, with at most two lines, each about as long as the English or shorter. In Japanese, Korean and Chinese the verb is a short word, because those scripts have no capitals.
