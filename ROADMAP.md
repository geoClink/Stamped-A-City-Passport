# Stamped! Roadmap

**Guiding rule:** every feature should help someone discover, plan, visit or collect great buildings.
Restaurants, hotels and events support that; they are never the main event. Stamped links out
for anything that costs money and never handles payments itself.

Shipped versions and their exact contents are in `CHANGELOG.md`, with matching git tags.

## Status

| Version | Theme | Status |
|---|---|---|
| 2.3 | Photoreal 3D city map, fly-to pins | Waiting for App Store review |
| 2.4 | "Plan a trip on a 3D map" | Ready to upload (branch `release/2.4`) |
| 2.5 | Around the landmark + Vision Pro launch | Planned |
| 2.6 | Tours and hotels (affiliate links) | Planned, waiting on partner approval |

## 2.4: Plan a trip on a 3D map

Built (see CHANGELOG 2.4):
- [x] Wishlist ("Want to Visit") and custom places from Apple Maps search, synced with iCloud
- [x] Map card quick actions, filters, guided tour, map/satellite toggle
- [x] Websites and ticket pages in-app; Ticketmaster events on cards
- [x] Tap any Apple Maps place, category chips, Look Around preview in the card
- [x] iPad: map opens full screen
- [x] Trip planner: trips, days, stops, reorder, optimize route
- [x] "Add to Trip" from map cards and tapped Apple places
- [x] Route lines between a day's stops, with walk times
- [x] Tour flies through a trip day by day
- [x] Campus Architecture collection (41 campuses, 202 buildings)
- [x] Landmark data audit: 181 map pins corrected, Queenstown quiz fixed, "Built 0" hidden

Still to do:
- [ ] Each day's route in its own colour (all days are orange today)
- [ ] "Suggest a day" with Apple Intelligence (reuse the existing itinerary engine)
- [ ] Translate the trip planner screens (English only today; campus screens are translated)
- [ ] TestFlight build and real-device testing (pins in 3D photo mode, iCloud sync, AR, events)
- [x] App Store screenshots: iPhone 6.9" and iPad 13" (in `screenshots/final/`)
- [ ] Fix screenshot 4's Apple Intelligence claim (show real AI text or change the headline)

## 2.5: Around the landmark + Vision Pro

iPhone/iPad (Apple data only, no partners needed):
- [x] Plan a trip anywhere: "My Trips" on the home screen, "New Trip Anywhere" searches Apple Maps for an area, stops are Apple Maps places (no stamps or quiz). Old 2.4 trips and places still load (unit-tested). Branch `feature/trip-anywhere`
- [ ] 3D "Tour This Trip" for anywhere trips (hidden today: the 3D map needs a Stamped city)
- [ ] Test anywhere trips on a real device, including iCloud sync with a 2.4 device
- [ ] "Stay" chip: hotels from Apple Maps alongside Food and Coffee
- [ ] Transit and walking times between trip stops (`MKDirections`)
- [ ] "Directions for this day" hands the ordered stops to Apple Maps

- [x] Power 4 campuses: 60 more (101 total), grouped by conference, nickname search, conference achievements. Branch `feature/p4-campuses`
- [ ] "Plan a Campus Visit": one-day trip of a campus's buildings in walking order
- [ ] Update the App Store text and screenshots for 101 campuses (2.4 text says 41)
  - Add to the description in every language: "Stamped! is not affiliated with or endorsed by any university. School names and colors are used only to identify them." (same text as Settings, already translated in Localizable.strings)

Vision Pro (shares the iPhone listing; separate review):
- [x] All 140 cities on a photoreal 3D map, landmark cards, iCloud stamps
- [x] Layered app icon, quiz, Want to Visit list, 24 MB download
- [x] 3D globe of stamped cities (volume window)
- [ ] Tap-any-place and trip plans in the big window
- [ ] Test on a real Vision Pro (or thoroughly in the simulator by hand)
- [x] Localization into the iPhone app's 9 languages
- [ ] Vision Pro App Store screenshots
- [ ] Add the visionOS platform in App Store Connect and submit

## 2.6: Tours and hotels (affiliate links)

Before coding: George applies to the partner programs (approval takes days to weeks).
- [ ] GetYourGuide or Viator: "Book a tour / skip-the-line tickets" on landmark cards (best fit)
- [ ] Booking.com or Expedia: "Hotels near this landmark", pre-searched for the area
- [ ] Optional: Skyscanner "Find flights to [city]" on trips with dates
- [ ] Commission disclosure in Settings and next to the buttons
- [ ] Privacy-friendly tap counts, to see which links people actually use

How it works: each button builds a URL with the affiliate ID and the place's location and opens it
in the in-app browser. No payments, accounts or stored booking data.

## Not doing
- In-app booking or payments
- Selling flight, train or bus tickets
- User accounts for bookings
- User-created landmarks visible to other users (needs a server and moderation)

## Ongoing housekeeping
- One feature branch per feature; merge to `main` when a version is approved
- Bump the widget's version and build together with the app's
- Commit the version bump before archiving, then tag the release (`git tag -a v2.4`)
- Move CHANGELOG "Unreleased" items under the new version when uploading
