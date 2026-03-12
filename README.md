# Stamped! — A City Passport

A SwiftUI iOS app for discovering and "collecting" architectural landmarks across cities. Users navigate a curated city library, mark buildings as visited, collect digital passport stamps, save photos to their passport entries, and track progress by city and country.

> About
>
> Stamped! is a lightweight travel and architecture app built with SwiftUI that helps users explore cities via curated itineraries and collect illustrated passport stamps as they visit landmarks. Designed for offline-first use with accessible UI options (high-contrast, reduced motion) and local persistence, the app is ideal for travel enthusiasts who want a playful way to track and celebrate architecture discoveries.

This README was generated from the repository source (entry point: `GlobalDiscoveryApp` in `Stamped__A_City_PassportApp.swift`) and reflects the app structure, managers, persistence, and accessibility features implemented in the code.

Table of contents
- Features
- Architecture & notable files
- Persistence & storage
- Permissions
- Build & run (Xcode)
- Quick testing checklist
- Accessibility
- Contributing
- Suggested license
- Contact


Features
- Browse cities grouped by continent and country with a searchable sidebar (`CityListView`).
- City detail pages and curated architectural itineraries (uses `Building` and `BuildingRegistry`).
- Passport stamping: earn an illustrated stamp when marking a landmark as visited (`PassportStampView`, `PassportGalleryView`).
- Save a photo per building using the camera or photo library (`CameraPicker`) and persist it to app Documents.
- Local progress tracking (visited landmarks and saved images) with persistence via `UserDefaults` and stored JPGs (`GlobalProgressManager`).
- Audio and haptic feedback support (configurable in Settings) via `SoundManager` and `HapticManager`.
- Onboarding flow that gates first-run experience (`OnboardingView` + `OnboardingViewModel`).
- Offline-ready: the app keeps a local library of cities and itineraries in code (no remote backend required by default).


Architecture & notable files
- App entry:
  - `Stamped! A City Passport/Stamped__A_City_PassportApp.swift` — App entry using `GlobalDiscoveryApp` with an `AppDelegate` to force orientation on iPad and onboarding state stored via `@AppStorage("hasSeenOnboarding")`.

- Models:
  - `Models/Model.swift` — `CityLocation` types (City, Country, Continent) and helpers.
  - `Models/Building.swift` — `Building` model for each landmark.
  - `Models/CityData.swift` — city details and localized metadata (nicknames, airport, fun facts).
  - `Models/BuildingRegistry.swift` — mapping of `City` to `[Building]` (city-specific itineraries).

- State & Persistence:
  - `Managers/VisitManager.swift` (GlobalProgressManager) — central progress store; tracks `visitedIDs: Set<String>` and `userImages: [String: UIImage]`; persists visited IDs in `UserDefaults` and saves images as JPEG files in the app Documents directory.
  - `SettingsView/SettingsView-ViewModel.swift` — various `@AppStorage` flags (sound, haptics, high contrast, reduce motion, metric units) and app reset logic.

- UI & Flows:
  - `CityListView/CityListView.swift` — main navigation and city browser.
  - `CityListView/CityDetailView/` — detail content for a selected city (itinerary, map, landmarks).
  - `PassportStampView/` — UI for the stamp card and celebratory view when a building is stamped.
  - `PassportGallery/PassportGalleryView.swift` — shows user's collected stamps grouped by country.
  - `OnBoardingView/` — onboarding steps and logic.
  - `SettingsView/` — toggles for motion, contrast, haptics, sound and the danger zone to reset the app.

- Managers & Helpers:
  - `Managers/CameraPicker.swift` — wrapper to use `UIImagePickerController` for camera/photo library.
  - `Managers/SoundManager.swift` — plays system sounds and handles speech synthesis for greetings.
  - `Managers/HapticManager.swift` — central haptic triggers with persisted setting.
  - `Managers/SpeechManager.swift` — (if present) higher-level speech helper wrappers.


Persistence & storage details
- Visited IDs: the app stores visited building IDs in `UserDefaults` under key `GlobalVisitedBuildingsKey`.
- Saved photos: photos taken or chosen for a building are saved as `BuildingID.jpg` in the app's Documents directory and loaded back into `GlobalProgressManager.userImages` on startup.
- Settings: toggles like `haptics_enabled`, `is_sound_enabled`, `high_contrast_mode`, `reduce_motion`, and `use_metric_units` are persisted using `@AppStorage` (backed by `UserDefaults`).
- Reset: `SettingsViewModel.resetAllContent()` clears the user defaults for this bundle and removes saved images via `GlobalProgressManager.resetAllProgress()`.


Permissions
- Camera / Photo Library: the app uses `UIImagePickerController` and will need the appropriate Info.plist keys if you exercise the camera or photo library at runtime. Add these keys to your target Info.plist before publishing:
  - NSCameraUsageDescription
  - NSPhotoLibraryUsageDescription
  - NSPhotoLibraryAddUsageDescription (if saving back to photos)
- Microphone: only required if you add audio recording features; speech synthesis itself does not need mic permission.


Build & run (Xcode)
1. Open the project in Xcode (match Xcode version to your local toolchain):

```bash
cd "/Users/georgeclinkscales/Documents/Swift/Stamped! A City Passport"
open "Stamped! A City Passport.xcodeproj"
```

2. Select the `Stamped! A City Passport` scheme (or `main` app target), choose a simulator/device, Build (Cmd-B), and Run (Cmd-R).
3. First run shows the onboarding flow (toggle `hasSeenOnboarding` via Settings or complete onboarding to proceed to the City List).

Notes:
- If the project uses a minimum iOS deployment or Swift version incompatible with your Xcode, Xcode will prompt to update settings/convert the project.
- Add camera/photo usage strings in Info.plist before using photo capture on device.


Quick testing checklist
- Launch app in Simulator: navigate City List -> select a city -> open a building -> mark as visited -> view the `StampCelebrationView`.
- Open Passport: use the floating passport button on the City List to open `PassportGalleryView` and inspect collected stamps.
- Settings: toggle Sound/Haptics/High contrast/Reduce motion and verify UI behavior.
- Reset: in Settings -> Reset All Content, test the two-step alert and confirm progress/image clearing.
- Camera: test camera/photo flows on a physical device (simulator often lacks camera hardware).


Accessibility
- Respect for reduce motion: the UI disables or simplifies animations when system or app `reduce_motion` is enabled.
- High-contrast mode: `high_contrast_mode` toggles alternate colors and stronger contrast throughout UI components.
- Accessibility labels: key views like `PassportStampView` set `accessibilityLabel` and `accessibilityValue` for screen readers.
- Voice: `SoundManager` can speak greetings in localized languages for several countries.


Contributing
- Fork the repository and open a PR against `main`.
- Keep changes small and descriptive — include tests where applicable.
- Naming convention: view/view model pairs follow `Something-ViewModel.swift` and `Something.swift` patterns.
- If you add new persisted values, add tests or manual migration steps for existing `UserDefaults` keys.

Suggested License
- MIT is a good, permissive option for this project. Create a `LICENSE` file with MIT text and your name/year.

License: [MIT](LICENSE)  
`Licensed under the MIT License — see LICENSE file for details.`

Contact
- Author: George Clinkscales
- Repo: https://github.com/geoClink/Stamped-A-City-Passport


---
