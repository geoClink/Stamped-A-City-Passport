# Partner applications: ready-to-paste text

Text for the hotel, ticket and tour partner forms. Change anything that's out of date (user numbers especially) before you submit. All of these programs are free to join.

## The basics (most forms ask for these)

- **App name:** Stamped! A City Passport
- **Platform:** iOS app (iPhone and iPad), plus a Vision Pro version in progress
- **App Store link:** https://apps.apple.com/us/app/stamped-a-city-passport/id6759680336
- **Category:** Travel
- **Audience:** Travellers and architecture fans visiting cities, and students and families touring college campuses
- **Where users are:** Mostly the US, with cities across Europe, Asia, Africa, South America and Oceania
- **Monthly users:** _fill in from App Store Connect → Analytics_
- **Languages:** English, German, Spanish, French, Italian, Japanese, Korean, Portuguese, Simplified Chinese
- **Promotional methods:** In-app links (no paid ads, no email lists, no coupon sites)

## Short description (about 50 words)

Stamped! is a travel app for exploring cities through their architecture. It covers 140 cities and 101 college campuses. Users follow landmark maps and walking tours, collect a digital passport stamp at each building, and plan multi-day trips and college road trips, with places to stay and things to do along the way.

## Longer description (for "Tell us about your website/app")

Stamped! A City Passport turns a city visit into a collection. Each city and campus has a curated list of landmark buildings, a 3D map, walking tours, and a digital passport where users collect a stamp for every building they visit.

Users also plan trips in the app: day-by-day itineraries for a city, or a college road trip across several campuses. Planning a trip is where they need somewhere to stay and something to do in the evening, which is where your listings fit.

## How the links appear (per program)

### Hotels: Booking.com / Expedia Group / Travelpayouts / Stay22

> A "Find Hotels" button appears in the trip planner for each city and campus on a trip (with the trip's check-in and check-out dates filled in), and as "Check Prices" on hotel place cards on the city map. The button opens your site's hotel search for that destination and dates in the user's browser. Stamped! doesn't take bookings or payments itself. A "Stamped! may earn a commission" note is shown next to the links.

### Event tickets: SeatGeek (API key and partner program)

> Each city page has an "Upcoming Events" section showing concerts, sports, theatre and family events within 25 miles over the next 60 days. Landmark and venue cards on the map show events at that venue. Each event links to its ticket page on your site. Event data is credited ("Event data from Ticketmaster and SeatGeek") and Stamped! doesn't sell tickets itself.
>
> **For the API key form (seatgeek.com/account/develop), "App description":** Shows upcoming events near city landmarks in a travel app, with links to buy tickets on SeatGeek. About 1 request per city page view, cached for 2 hours.

### Tours and attraction tickets: GetYourGuide / Viator / Tiqets

> Stamped! is built around landmark buildings and walking tours: museums, cathedrals, towers, campuses. We'd like to show bookable tours and skip-the-line tickets for the landmark the user is looking at, and for the cities on their trip itinerary, linking to your booking page. Users see these while planning a trip and while standing at the building.

### Ticketmaster affiliate program (via Impact)

> Stamped! already shows Ticketmaster events through the Discovery API on every city page and on venue cards in the map. We'd like to use tracked links for the "Get Tickets" buttons.

## After you're approved

Paste the ID or key into the chat and say which program it's for. Where each one goes:

| Program | What you get | Where it goes |
|---|---|---|
| Booking.com | Affiliate ID (`aid`) | `HotelPartner.affiliateID` in `Hotels/HotelLinks.swift` |
| Expedia / Hotels.com | Affiliate ID and link format | Same file; the link parameter still needs filling in |
| Travelpayouts / Stay22 | Partner ID and link format | Needs a small code change to use their links |
| SeatGeek API | Client ID | `SEATGEEK_CLIENT_ID` in `Stamped--A-City-Passport-Info.plist` (on the Mac you archive from), next to `TICKETMASTER_API_KEY` |
| SeatGeek partner | Partner ID | `SeatGeekPartner.affiliateID` in `Managers/SeatGeekService.swift` |
| GetYourGuide / Viator | Partner ID and API key | New code, to be built once approved |
