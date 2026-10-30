# Changelog

What changed in each version of Stamped! A City Passport.
Each released version has a matching git tag (`v2.3` and so on), so `git checkout v2.3` shows exactly that code.

How to use this file:
- Add new work under **Unreleased** as you go.
- When you upload to App Store Connect, rename **Unreleased** to the new version and date, and tag that commit.
- The bullets double as the App Store "What's New" text.

## [Unreleased]

### Added
- Vision Pro app: every city on a photoreal 3D map, landmark cards, and stamps synced from iPhone. Shares the iPhone app's App Store listing.
- Vision Pro: layered app icon, a 10-question architecture quiz per city, and the Want to Visit list (landmarks and saved places synced with iPhone). Download size cut from 355 MB to about 24 MB by leaving out the Detroit 3D model.
- Vision Pro: a 3D globe of every city with live stamp pins; drag to spin and tilt, tap to turn a city toward you.
- Vision Pro: available in all 9 of the app's languages.

## [2.7] (build 12) – not yet uploaded

### Added
- Map pins group into numbered bubbles when zoomed out and split apart as you zoom in; tapping a bubble zooms in. On city maps (landmarks and saved places) and trip route maps.
- Adrian Smith buildings: Burj Khalifa (Dubai) and Trump International Hotel & Tower (Chicago). Jin Mao Tower (Shanghai) is now credited to Adrian Smith (SOM).
- Tours & Tickets on every city landmark page: a GetYourGuide search for that landmark (partner ID PBXFUP9), with a commission note. Campus buildings don't get it.
- Events also come from SeatGeek, merged with Ticketmaster, so cities Ticketmaster covers thinly get a fuller list. Needs `SEATGEEK_CLIENT_ID` in the API-key plist; without it the app uses Ticketmaster only.

### Changed
- Cleaner home screen: pick a continent (or Campuses) from a row of chips and its cities show right away, grouped by country, instead of opening continent, then country. My College List now leads the Campuses chip.
- City pages are split into Landmarks, Plan (itinerary, events, hotels) and Local (weather, dining) tabs, so the page is no longer one long scroll.
- Landmark pages keep every action together under the name: stamp, Want to Visit, Look Around, Tours & Tickets and the address.
- Passport has a search bar: find a city, country or campus, including ones not stamped yet.
- Find Hotels and Check Prices open Expedia, through Expedia's affiliate program (Partnerize), with a "may earn a commission" note. Booking.com stays supported for when its affiliate application is approved.

### Fixed
- City map pins show as soon as the map opens, instead of only after the map is moved.

## [2.6] (build 11) – 2026-10-27

### Added
- Links to a city or campus page on the Stamped! website open that city or campus in the app.
- Michigan State: 14 more buildings (18 in all, from Linton Hall and Laboratory Row to Spartan Stadium and the Facility for Rare Isotope Beams) and 7 more traditions (10 in all, including the Dairy Store, Beal Botanical Garden and the band's march to the stadium), translated into all 9 languages.
- "Know a tradition we're missing?" under every campus's traditions opens a pre-filled email.

### Changed
- Weather now comes from Apple Weather (WeatherKit).
- Look Around opens full screen.
- Reports from a building page, a city's menu or Settings now include the building, app version and language, so a fix can be matched to what you saw.

### Fixed
- Report emails for names with "&" (like Texas A&M) were cut off.
- "Report an issue with this building" showed in English in every language.
- Opening the same city twice from Spotlight did nothing the second time.

## [2.5] (build 10) – 2026-10-24

### Added
- Campus Architecture: 60 more campuses (every Big Ten, SEC, ACC and Big 12 school), now 101 campuses and over 450 buildings, translated into all 9 languages.
- US campuses are grouped by conference (Big Ten, SEC, ACC, Big 12, Ivy League, Other) and sorted by short name; Australian campuses share one Australia group.
- Search finds campuses by short names and nicknames, such as "UGA", "Ole Miss" or "Tar Heels".
- Conference achievements: stamp a building on every campus in a conference.

### Changed
- Buildings with no known architect or style no longer show "Unknown"; the quiz skips those questions.

## [2.4] (build 9) – 2026-10-23

### Added
- Trip planner: plan a trip over several days with landmarks and saved places, reorder stops, see walking times, optimize the route, and view each day on a route map. Synced with iCloud.
- Add to Trip from the map's landmark card, saved-place card, or any Apple Maps place.
- Trip tour: fly through a trip on the 3D map, day by day.
- Campus Architecture collection: 41 university campuses and 202 buildings, with their own section in the city list and new achievements.
- Tap any Apple Maps place on the city map, with category chips and a Look Around preview in the card.
- Queenstown: three new landmarks (TSS Earnslaw, Kawarau Gorge Suspension Bridge, Queenstown Gardens), so its quiz now works.
- iPad: the city map opens full screen with a Done button.
- Custom "Want to Visit" places: search Apple Maps for any restaurant, shop or venue and save it. Saved places get their own map pins and a card with Look Around, Website, Call and Directions. Synced with iCloud.
- Wishlist: heart any landmark from the map card, the building page or a long-press, with a "Want to Visit" section on each city page.
- Map card quick actions: Stamp, Want to Go, Look Around, and arrows to step through landmarks in walking order.
- "View Details" on the map card opens the full building page.
- Guided city tour that flies between every landmark automatically.
- Map filters (Not Visited, Stamped, Want to Visit, architectural style) and a pulsing pin on the nearest unvisited landmark.
- Map and satellite toggle (remembered between launches).
- Websites and ticket pages open inside the app.
- Upcoming Ticketmaster events on map cards: events at a landmark venue, or nearby events for saved places, with ticket links.

### Changed
- Riyadh: the King Abdulaziz Center for World Culture (Ithra), which is in Dhahran, is replaced by the King Fahad National Library.

### Fixed
- Map pins for 181 landmarks moved to their real locations; some were in the wrong city or even the wrong country.
- Natural places with no build date (lakes, mountains, villages) no longer show "Built 0", and the quiz no longer asks for their build year.
- Heights that were really a mountain's elevation (Monserrate, Mount Entoto, Amman Citadel, Elephant Mountain) are no longer shown.
- Years showing as "1,913" in the itinerary and other screens.
- Missing or wrong landmark photos for over 200 landmarks (including Rockefeller Center, The Vessel, One World Trade Center).
- iPhone mistranslations of Close, Done, Cancel and Exit, Spanish quiz prompts, and landmark wording.
- Trip tour: the map card's arrows now step through the trip's stops and keep the tour going.
- iPad: the map card shows a plain Look Around preview without the full-screen buttons.
- City introductions no longer show a Wikipedia disambiguation page for cities with common names.
- Apple SoHo now has a photo.
- City maps opening too zoomed out when one landmark is far from the centre (New York and JFK).
- Map losing your place after returning from a building page.
- Unit tests compile and run again.

### Removed
- Debug data seeder used for screenshots.

## [2.3] (build 8) – 2026-10-22

### Added
- Photoreal 3D city map: satellite imagery on Apple's 3D city models, with a tilted camera, compass and 2D/3D toggle.
- Tapping a landmark pin flies the camera to it before opening its card.
- City Explore views, ambient city audio and the scan nudge sheet.

### Fixed
- AR mode now turns on the camera, explains when a city has no 3D model, and lets you tap buildings and scans.
- Build errors (a stale audio call and an ambiguous `blendMode`).

## [2.2] (build 7)

Tag `v2.2` points to the closest commit; the 2.2 version number itself was not committed before submission.

### Added
- Detailed information for Dhaka.
- Building scans: support for devices without LiDAR, and more reliable CloudKit syncing.

### Changed
- City list rebuilt around a new `NavigationManager`.

## [2.1] (build 6) – 2026-09-08

### Added
- Achievements and the world map.
- More achievements and an improved quiz.
- Sharing your passport.
- Updated building data and UI.

## Earlier versions

1.0 through 2.0 (February–September 2026) predate version tags. See `git log` for details.
