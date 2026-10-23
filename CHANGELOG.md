# Changelog

What changed in each version of Stamped! A City Passport.
Each released version has a matching git tag (`v2.3` and so on), so `git checkout v2.3` shows exactly that code.

How to use this file:
- Add new work under **Unreleased** as you go.
- When you upload to App Store Connect, rename **Unreleased** to the new version and date, and tag that commit.
- The bullets double as the App Store "What's New" text.

## [Unreleased]

### Added
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

### Fixed
- Years showing as "1,913" in the itinerary and other screens.
- Missing or wrong landmark photos (Rockefeller Center, The Vessel, One World Trade Center).
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
