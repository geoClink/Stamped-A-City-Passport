# App Store product page – version 2.8

Three folders, one JSON per App Store locale in each (de-DE, en-US, es-ES, es-MX, fr-FR, it, ja, ko, pt-BR, zh-Hans):

| Folder | Platform | Fields |
|---|---|---|
| `2.8/` (this one) | iPhone/iPad (iOS) | subtitle, promotional_text, keywords, whats_new, description, screenshot_headlines, banner |
| `../2.8-macos/` | Mac | promotional_text, keywords, whats_new, description |
| `../2.8-visionos/` | Vision Pro | promotional_text, keywords, whats_new, description |

Check every field in every language against Apple's limits (no internet, no key):

```
python3 docs/app-store/localization/2.8/check_limits.py
```

## ⚠️ How to upload the Mac and Vision Pro text

`tools/appstore-metadata/upload_metadata.py` is **iPhone-only**: `find_version_id` and `create_version` both use `platform: "IOS"`.

- `upload_metadata.py 2.8` works as usual for iPhone/iPad.
- `upload_metadata.py 2.8-macos --check-only` and `upload_metadata.py 2.8-visionos --check-only` work too: the folder name is the version argument, and the files use the same field names. All three pass.
- **Never run those two folders without `--check-only`.** The script would look for an iOS version called "2.8-macos". With `--create-version --apply` it would even try to create one.
- To upload them, either paste the text into App Store Connect by hand, or first add a `--platform MAC_OS|VISION_OS` flag to the uploader (its own branch and PR). The `platform` field in those JSON files is ready for that. The uploader ignores it today.
- The **subtitle** is on App Information, which all three platforms share. So only the iOS files have it.

## What changed versus 2.7, and why

Everything is aimed at downloads: lead with what a traveler gets, put the numbers in the first line people see, and keep the search words people actually type.

### iPhone/iPad

- **What's New** is new. It leads with the four biggest benefits: Save for Offline, Listen, the 16 new cities (all named, because city names are what people recognize) and more places to stay (Booking.com and Vrbo). Then the 5 campuses, Viator, event calendars in 11 cities, and the iPad redesign. Fixes come last.
- **Promotional text** opens with the new totals (2,200 buildings, 156 cities) and the two new features. The English version names Listen. The other languages name "plan your trip" instead, because Listen only reads in English (see below).
- **Description:** new totals (more than 2,200 landmarks, 156 cities, 117 campuses). Three new lines: Expedia + Booking.com + Vrbo, Save for Offline (both under PLAN ANY TRIP) and Listen (under DISCOVER THE STORIES). Everything else is the 2.7 text.
- **Subtitle: same as the 2.7 files** ("Landmark Travel & Campus Tours" and its translations). Careful: this is **not** what's live. The 2.7 upload skipped the subtitle, so the store most likely still shows 2.6's "Campus visits & architecture". The recommendation is to send the new one with 2.8:
  - It matches the city-first promo and description.
  - It adds "travel", the biggest search word in the category, plus "landmark" and "tours".
  - "architecture" moves to the keywords.
  - The other option ("3D Landmarks & Campus Tours") swaps "Travel" for "3D", which is already in the keywords, so it isn't better.
  - The keywords were chosen assuming this subtitle. If you keep the old one with `--skip-subtitle`, "architecture" is wasted in the keywords and "travel" is missing, so swap them.
- **Screenshot headlines and banner:** copied from 2.7 unchanged.

### Mac

- Same description as iPhone, minus the Home Screen widget line, because the widget target is iOS-only (`SDKROOT = iphoneos`).
- **The Mac goes from 2.6 to 2.8.** Mac 2.7 was skipped on purpose, so the Mac What's New covers both 2.7 and 2.8, strongest first:
  - **Proper Mac windows** (PR #67), offline ("on your Mac") and Listen.
  - The 16 new cities, and 16 new campuses since 2.6 (11 from 2.7 + 5 from 2.8). The totals are 156 cities and 117 campuses.
  - Adrian Smith's towers.
  - Then the 2.7 bullets in their 2.7 translations (campus pages, architect pages, photo galleries, restaurants and hotels, events, map bubbles, quiz, cleaner pages), mixed in with the 2.8 hotel, Viator and calendar bullets.
  - Fixes from both versions.
  - Left out:
    - College Facts, which only shows if the archiving Mac's plist has `COLLEGE_SCORECARD_API_KEY`. If the 2.8 build has it, add the 2.7 bullet back.
    - The "9 cities" sentence of 2.7's events bullet, because the 2.8 calendar bullet says 11.
    - The iPad and iPhone bullets.
- Promotional text names the Mac windows, offline and Listen.
- Keywords are the same as iPhone.

### Vision Pro

Vision Pro goes from 2.6 to 2.8, so its What's New covers everything since 2.6:

- 360° View (PR #62)
- Play Tour and Listen (#59)
- Look Around (#61), now aimed at the building (#63)
- 32 new places: the cities went from 140 to 156 and the campuses from 101 to 117, counted from `BuildingRegistry.json` and `CampusList.swift` at `v2.6` and now. The Vision app lists every registry entry.
- Building styles in your language (#64). This bullet is in every language except English.
- Card buttons on one line (#65)

The 2.6 description gets the new totals and a new section, LISTEN, LOOK AROUND, STEP INSIDE, before SPIN THE GLOBE. The 2.6 note said Vision Pro had no Look Around. That's no longer true.

## Keyword reasoning

Apple searches the app name, the subtitle and the keywords together, so a word in the name or subtitle is wasted in keywords. Single words also combine with each other and with the name ("city" + "guide", "trip" + "planner", "audio" + "guide", "campus" + "tours").

- **en-US iPhone/Mac** (100 bytes): `architecture,sightseeing,trip,planner,vacation,guide,offline,audio,college,university,3d,map,history`
  - New: **offline** ("offline guide", "offline city guide") and **audio** ("audio guide", "audio tour"). These match the two headline features and are common travel searches. **vacation** is a high-volume travel word and goes with the Vrbo rentals. **history** fits the stories.
  - Dropped: **stamps** (the name has "Stamped"), **monuments** and **itinerary** (lower volume; "trip planner" covers itinerary searches).
- **en-US Vision Pro**: `architecture,immersive,virtual,360,panorama,3d,map,globe,audio,guide,sightseeing,college,university`. Vision Pro shoppers search for **immersive**, **virtual** (virtual travel), **360** and **panorama**, and the app now has all four. The globe is a Vision-only feature.
- **Other languages:** the same idea, in words natives type. Each one has its local word for offline (`offline`, `hors ligne`, `オフライン`, `오프라인`, `离线`) and for audio guide (`Audioguide`, `audioguía`, `audioguida`, `audioguia`, `音声ガイド`, `오디오가이드`, `语音导览`).
  - German uses **Stadtführer** (city guide). German compounds aren't split by search, so "Stadt" + "Führer" wouldn't match.
  - Japanese adds **世界遺産** (World Heritage), a top travel search there. Many of the landmarks are World Heritage sites.
  - Words already in each subtitle were taken out. For example 建築 is in 名建築 in Japanese, and 建筑 is in the Chinese subtitle.
- **Bytes, not characters:** keywords are counted in UTF-8 bytes. 2.7 de-DE was 103 bytes (ü and ä are 2 bytes each). That's fixed: 97 bytes now.
- I had no search-volume tool for this. The choices come from common App Store travel searches and Apple's matching rules, not from measured data. If you have App Store Connect search data (App Analytics → Sources → App Store Search), check it after a week and swap any word that brings no impressions.

## Claims checked against the code

- **156 cities, 117 campuses, 2,225 landmarks:** counted from `Resources/BuildingRegistry.json` (273 entries) and `Models/CampusList.swift` (117). Rounded down to "2,200".
- **16 new cities** (#49 + #51) and **5 new campuses** (#54): all in the registry.
- **11 cities with library/museum calendars:** `Models/CityEventFeeds.swift`.
- **26 panoramas in 19 cities:** `Resources/LandmarkPanoramas.json`. The Colosseum, Hallgrímskirkja, the Acropolis and the Brandenburg Gate are all in it.
- **Booking.com, Vrbo and Viator are live:** IDs are set in `Hotels/HotelLinks.swift` and `Tours/TourLinks.swift`, and none is nil, so the buttons show.
- **Offline and Listen on Mac:** both are in shared code with no platform guard.
- **Left out on purpose:**
  - the rating prompt (not a user feature)
  - accessibility data (not in 2.8)
  - College Facts (needs the Scorecard key, already in 2.7's text)
  - the word "free"

## Not sure / please review

- **Listen reads in English only.** `AudioStoryPlayer` uses an English voice, because the landmark descriptions are English. Every non-English text says so, e.g. "(auf Englisch)" or "（英語）". That's honest, but it makes the feature sound smaller. Leave it in to avoid 1-star reviews.
- **The "UN General Assembly hall" panorama:** its Commons file is a 2016 Wikipedia edit-a-thon photosphere at UN Headquarters. I couldn't confirm it's the General Assembly hall, so the text names the Colosseum, Hallgrímskirkja, the Acropolis and the Brandenburg Gate instead.
- **"Step into 26 landmarks"** (English) instead of "stand inside": several panoramas are outdoors (Brandenburg Gate, Acropolis).
- **Building styles on Vision Pro:** only the 39 most common styles are translated, so the text says "the most common building styles".
- **Look Around "turned to face the building":** true when Apple Maps finds the landmark by name within 300 m. Otherwise it falls back to the nearest street spot.
- **Look Around name:** kept as the brand everywhere. Where Apple's own name differs, it's added in brackets, e.g. "Look Around (Umsehen)", "Look Around（四处看看）".
- **City exonyms:**
  - Spanish has Múnich, Hamburgo, Róterdam.
  - Italian has Monaco di Baviera, Amburgo, Baltimora.
  - Portuguese has Munique, Roterdã, Valência.
  - The Japanese, Korean and Chinese names are standard transliterations.
  - Korean uses short campus names (콜로라도 주립대, 미시간공대…).
  - A native-speaker look would help, as with 2.7.
- **Mac status:** Mac is on 2.6 and skips 2.7. Its What's New covers 2.7 + 2.8. The Mac description and promo name nothing that's missing on Mac: the 2.7 features in the description ship to Mac with 2.8.
- **Screenshots** still say "101 CAMPUSES" (`screenshot_headlines` unchanged). The images on App Store Connect are what people see, so regenerate them if you want 117.
- **"Over 250 campus traditions"** is unchanged from 2.7. It's still true: there are more campuses now, not fewer.

## Character counts

From `check_limits.py`. Keywords are in bytes, the rest in characters. App name: "Stamped! A City Passport" = 24/30 in every language.

### iPhone/iPad (`2.8/`)

| locale | subtitle /30 | promo /170 | keywords /100 B | What's New /4000 | description /4000 |
|---|---|---|---|---|---|
| en-US | 30 | 168 | 100 | 1356 | 2298 |
| de-DE | 27 | 158 | 97 | 1580 | 2655 |
| es-ES | 29 | 159 | 98 | 1639 | 2664 |
| es-MX | 29 | 156 | 99 | 1631 | 2653 |
| fr-FR | 29 | 162 | 95 | 1722 | 2794 |
| it | 28 | 156 | 97 | 1623 | 2593 |
| ja | 16 | 82 | 92 | 811 | 1098 |
| ko | 15 | 92 | 95 | 837 | 1162 |
| pt-BR | 29 | 155 | 93 | 1537 | 2523 |
| zh-Hans | 13 | 70 | 92 | 588 | 854 |

### Mac (`2.8-macos/`)

| locale | promo /170 | keywords /100 B | What's New /4000 | description /4000 |
|---|---|---|---|---|
| en-US | 165 | 100 | 2268 | 2238 |
| de-DE | 163 | 97 | 2716 | 2582 |
| es-ES | 153 | 98 | 2741 | 2592 |
| es-MX | 150 | 99 | 2761 | 2581 |
| fr-FR | 169 | 95 | 2827 | 2716 |
| it | 150 | 97 | 2691 | 2520 |
| ja | 80 | 92 | 1306 | 1072 |
| ko | 96 | 95 | 1343 | 1136 |
| pt-BR | 160 | 93 | 2650 | 2459 |
| zh-Hans | 75 | 92 | 955 | 838 |

### Vision Pro (`2.8-visionos/`)

| locale | promo /170 | keywords /100 B | What's New /4000 | description /4000 |
|---|---|---|---|---|
| en-US | 155 | 99 | 655 | 1500 |
| de-DE | 148 | 93 | 842 | 1820 |
| es-ES | 137 | 88 | 833 | 1724 |
| es-MX | 137 | 88 | 835 | 1691 |
| fr-FR | 144 | 89 | 825 | 1797 |
| it | 120 | 90 | 827 | 1652 |
| ja | 69 | 95 | 401 | 779 |
| ko | 78 | 92 | 392 | 830 |
| pt-BR | 128 | 86 | 763 | 1689 |
| zh-Hans | 61 | 87 | 326 | 649 |
