# Changelog

What changed in each version of Stamped! A City Passport.
Each released version has a matching git tag (`v2.3` and so on), so `git checkout v2.3` shows exactly that code.

How to use this file:
- Add new work under **Unreleased** as you go.
- When you upload to App Store Connect, rename **Unreleased** to the new version and date, and tag that commit.
- The bullets double as the App Store "What's New" text.

## [Unreleased]

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
- Vision Pro app: every city on a photoreal 3D map, landmark cards, and stamps synced from iPhone. Shares the iPhone app's App Store listing.
- Vision Pro: layered app icon, a 10-question architecture quiz per city, and the Want to Visit list (landmarks and saved places synced with iPhone). Download size cut from 355 MB to about 24 MB by leaving out the Detroit 3D model.
- Vision Pro: a 3D globe of every city with live stamp pins; drag to spin and tilt, tap to turn a city toward you.
- Vision Pro: available in all 9 of the app's languages.

### Changed
- Riyadh: the King Abdulaziz Center for World Culture (Ithra), which is in Dhahran, is replaced by the King Fahad National Library.

### Fixed
- Map pins for 181 landmarks moved to their real locations; some were in the wrong city or even the wrong country.
- Natural places with no build date (lakes, mountains, villages) no longer show "Built 0", and the quiz no longer asks for their build year.
- Heights that were really a mountain's elevation (Monserrate, Mount Entoto, Amman Citadel, Elephant Mountain) are no longer shown.
- Years showing as "1,913" in the itinerary and other screens.
- Missing or wrong landmark photos for over 200 landmarks (including Rockefeller Center, The Vessel, One World Trade Center).
- iPhone mistranslations of Close, Done, Cancel and Exit, Spanish quiz prompts, and landmark wording.
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
