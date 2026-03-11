# Stamped! — A City Passport

TL;DR
A SwiftUI app that lets users collect “passport” stamps while exploring city sites. This repository contains the Stamped! iOS app (and a sample/tutorial subproject) built with Swift and SwiftUI.

Features
- City list and detail views with interactive passport stamps
- Passport gallery and stamp views
- Quiz and onboarding flows
- Local models and a lightweight MVVM-like structure
- Managers for haptics, sound, speech, camera, and visit tracking

Screenshots
- (Add screenshots to `Assets.xcassets` and reference them here.)

Repository layout (top-level)
- `Stamped! A City Passport/` — main app folder (project root)
  - `Stamped__A_City_PassportApp.swift` — app entry point
  - `Assets.xcassets/` — app images & colors
  - `CityListView/` — city list UI and view model
  - `Itinerary/` — itinerary service and logic
  - `Managers/` — Accessibility, CameraPicker, HapticManager, SoundManager, SpeechManager, VisitManager
  - `Models/` — building/city models and view models
  - `OnBoardingView/` — onboarding UI and view model
  - `PassportGallery/` — gallery UI
  - `PassportStampView/` — stamp UI and view model
  - `PassportView/` — passport UI and components
  - `QuizView/` — quiz UI and view model
  - `SettingsView/` — settings UI and view model
  - `Stamped! A City Passport.xcodeproj/` — Xcode project

- `AirBnBTutorial/` — separate sample project (can be removed or kept as reference)

Requirements
- Xcode 14+ (or the latest stable Xcode matching your toolchain)
- Swift 5.7+ (check project settings if unsure)
- iOS 15+ deployment target (confirm in project settings)

Build & run (open in Xcode)
1. Open Terminal and change to the project root:

   cd "/Users/georgeclinkscales/Documents/Swift/Stamped! A City Passport"

2. Open the Xcode project:

   open "Stamped! A City Passport.xcodeproj"

3. In Xcode: choose a simulator or device, select the app scheme, then Build (Cmd-B) and Run (Cmd-R).

Testing
- There are no dedicated test targets by default. Add an Xcode test target and place unit/UI tests under `*Tests` when ready.
- Quick manual checks:
  - Launch the app in Simulator and navigate City List -> City Detail -> Stamp -> Passport Gallery.
  - Test camera/speech features on a real device where relevant.

Contributing
1. Fork the repository and create a branch: `feature/your-feature` or `fix/issue-123`.
2. Keep commits small and include tests for new logic where appropriate.
3. Open a pull request with a clear description and testing steps.

Coding style & notes
- Follows SwiftUI idioms and lightweight MVVM-style view models (`*View-ViewModel.swift`).
- Keep folder and naming conventions consistent.

License
- Suggested: MIT License. Add `LICENSE` with your name and year if you want to apply it to the repo.

Placeholders to update
- Author: George Clinkscales
- Repository URL: https://github.com/geoClink/Stamped-A-City-Passport

Support / Issues
- Use the repository Issues page to report bugs or request features: https://github.com/geoClink/Stamped-A-City-Passport/issues

Acknowledgements
- Credit any third-party assets, icons, or libraries used in the project.

---

Author: George Clinkscales
Repository: https://github.com/geoClink/Stamped-A-City-Passport
