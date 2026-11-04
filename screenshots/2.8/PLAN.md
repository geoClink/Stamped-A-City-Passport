# Stamped! 2.8 – iPhone App Store screenshots (plan)

Style: same as before, made with `screenshots/compose.py` (orange #F2743F, SF Pro Display Black, black device frame running off the bottom).
Size: iPhone 6.9" 1320 x 2868 (iPhone 17 Pro Max simulator, iOS 27.0, light mode, 9:41 status bar).
Raw captures go in `raw/`, framed shots in `iphone/`.

Story stays VISIT / DO / COLLECT / FLY / PLAN / TEST. One slot changes: PLAN now shows the new campus
Plan tab (College Facts, Upcoming Events, Game Day) instead of the day-by-day trip planner, because
that is the biggest new thing in 2.7/2.8 and it speaks to the college-visit audience. The old trip-planner
shot is captured too as a fallback (`05b`).

| # | Headline | What's on screen |
|---|----------|------------------|
| 01 | VISIT / 117 CAMPUSES / ON ONE ROAD TRIP | College list / campus list with school colors |
| 02 | DO / THE CAMPUS / TRADITIONS | A campus page (Michigan State) Landmarks tab: Traditions checklist + History |
| 03 | COLLECT / STAMPS IN / SCHOOL COLORS | Passport stamps in school colors |
| 04 | FLY / THROUGH CAMPUSES / IN 3D | Campus 3D map (Stanford or Michigan State) |
| 05 | PLAN / YOUR CAMPUS VISIT | Campus Plan tab: College Facts (Scorecard numbers), Upcoming Events, Game Day |
| 05b (alt) | PLAN / YOUR WHOLE TRIP, / DAY BY DAY | Trip planner day-by-day (old slot 5) |
| 05c (alt) | PLAN / EVENTS, FOOD / AND HOTELS | City Plan tab (Chicago): events + restaurants/hotels with street photos |
| 06 | TEST / YOUR ARCHITECTURE / SMARTS | Quiz, ideally a photo question |

Headline text change for the localization JSON: slot 1 "101 CAMPUSES" -> "117 CAMPUSES" (re-rendered 2026-11-02; was 112); slot 5 descriptor is new
and would need translating if chosen.

## Result (captured 2026-10-30)

Captured on the iPhone 17 Pro simulator (iOS 27.0, 1206 x 2622, light mode, 9:41) with a build of `main` (540302c);
compose.py scales the screen into the 1320 x 2868 (6.9") canvas. The Pro Max simulator could not be driven
(control access was not granted). Data was seeded into the simulator's app-group preferences (stamps, college list,
traditions) and restored afterwards.

| File (iphone/) | Headline | Raw (raw/) |
|---|---|---|
| 01-college-list.png | VISIT / 117 CAMPUSES / ON ONE ROAD TRIP | 01-college-list.png |
| 02-traditions.png | DO / THE CAMPUS / TRADITIONS (Michigan State, 5 of 10) | 02-traditions.png |
| 03-school-stamps.png | COLLECT / STAMPS IN / SCHOOL COLORS | 03-school-stamps.png |
| 04-fly-3d.png | FLY / THROUGH CAMPUSES / IN 3D (Stanford, Hoover Tower) | 04-fly-3d-stanford.png |
| 05-plan-campus-visit.png | PLAN / YOUR CAMPUS VISIT (College Facts + Upcoming Events, MSU) | 05-campus-plan-facts-events.png |
| 06-test-smarts.png | TEST / YOUR ARCHITECTURE / SMARTS (photo question, Stanford) | 06-quiz-photo.png |
| alt-04-fly-3d-card.png | FLY, with the Hoover Tower card open | alt-stanford-3d-card.png |
| alt-05-plan-food-stays.png | PLAN / FOOD AND STAYS / NEAR EVERY LANDMARK (Aqua Tower, Chicago) | alt-chicago-aqua-food-stays.png |

Not done: 05b trip-planner shot (old one is in final/iphone/02-plan-trips.png), city Plan tab (Chicago's events list
is all Balloon Museum time slots), iPad 13" set.
