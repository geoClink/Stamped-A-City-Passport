# App Store Readiness Checklist for Stamped!

This checklist summarizes the high-priority items to address before submitting Stamped! to the App Store.

1) Privacy & Permissions
- [x] NSCameraUsageDescription present in project settings / Info.plist.
- [x] NSPhotoLibraryUsageDescription added to build settings (project.pbxproj) — ensures permission prompt for saved photos.
- [x] NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription present for voice features.

2) App Metadata
- App name and bundle identifier configured in project settings.
- Marketing version and build numbers set (`MARKETING_VERSION = 1.1.0`).
- App category set to `public.app-category.travel`.

3) Icons & Launch Screens
- Ensure `AppIcon` asset catalog is present and contains all required sizes (iPhone/iPad/macCatalyst). If missing, add polished icons for each size.
- Ensure Launch Screen is configured (storyboard or SwiftUI-based). The project references generated launch screen keys.

4) Build Target & Compatibility
- Confirm minimum iOS target is acceptable for App Store submission. (`IPHONEOS_DEPLOYMENT_TARGET` appears set to 18.6 / 26.2 in some configs).

5) API Keys & Secrets
- Do not commit API keys in source. Use environment variables for local dev and CI secrets for build pipelines.
- `DefaultCurrencyService` reads `CURRENCY_API_KEY` and `CURRENCY_API_BASE_URL` from env or Info.plist.

6) Testing
- Run the app in Release configuration on device(s) to verify camera, photo library, and speech flows.
- Test offline behavior (converter uses fallback `offlineRates`).

7) Accessibility & Localization
- Strings to localize should be placed in `Localizable.strings` (not all strings are localized yet).
- Verify VoiceOver labels and accessibility hints.

8) App Store Screenshots & Description
- Prepare screenshots in `docs/screenshots/` and reference them in README.
- Prepare an App Store description and keywords. (I'll help craft one if you want.)

9) Legal & Licensing
- Decide on LICENSE file content (MIT or All Rights Reserved). If you keep MIT, ensure LICENSE file contains your name and year.

10) CI & Signing
- Ensure `DEVELOPMENT_TEAM` and provisioning settings are correct for App Store builds.
- Prepare CI to sign builds using secure keychains/certificates.


Optional improvements
- Move large static data (BuildingRegistry) to `Resources/*.json` to speed build times.
- Add unit tests for conversion math and currency service.
- Add telemetry/analytics (respecting privacy) if needed.


If you want, I can:
- Update the Info.plist with friendly privacy strings (done in project.pbxproj for permissions).
- Add README instructions for setting CURRENCY_API_KEY securely for local development and CI.
- Help with App Store listing text (title, subtitle, description, keywords) and screenshot layout.
- Prepare a small Release checklist with commands to build/sign/archive the app using `xcodebuild` or `xcrun`.

Which of the above do you want me to implement next?