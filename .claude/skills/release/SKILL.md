---
name: release
description: 'Ship Stamped! A City Passport to iOS, Mac and Vision Pro: version bump, Europeana key removal, archive, upload, App Store text in every language and submission. Use when George says release, ship, submit, new build or bump the version.'
---

# Release Stamped!

## Rules

- George commits, pushes and merges. Work goes on `release/<version>` and merges by pull request. Give commands one per block, with explicit file paths.
- Read App Store Connect freely. Ask for a yes before uploads, version changes or submissions, saying exactly what will change.
- Never print the contents of `Stamped--A-City-Passport-Info.plist`, `Secrets.plist` or `Secrets.swift`. Don't search or cat them. Refer to them by path only.

## 1. Work out what's shipping

Read live: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the project file (the 8 app targets share them, the 6 at 1.0 / 1 are not part of a bump), `git log` since the last version commit, and all three platforms in App Store Connect. A version can't be created while an older one blocks it. Tell George what's new, the numbers and what's blocked.

## 2. Test

Run the unit tests and a Release build. Real-device checks go on George's list.

## 3. Remove Europeana before archiving

The Europeana key must not ship. Remove it from both gitignored `Secrets.plist` files (`Stamped! A City Passport/Resources` and `Tally-AVP`), archive, check the archive doesn't hold it, then restore it. Build 17 shipped with it by mistake and had to be expired. Don't skip this, and don't upload until the check passes.

## 4. Archive and upload

This Mac can do release builds. Schemes: "Stamped! A City Passport" (iOS and native Mac) and "Tally-AVP" (Vision Pro). Export with `-allowProvisioningUpdates` and no `-authenticationKey` flags: the API key fails with a cloud signing error, and the Apple account in Xcode works. The 0-byte `detroit.usdz` is harmless.

## 5. Store text and screenshots

Text is in `docs/app-store/localization/<version>/`, one file per language. Upload with `tools/appstore-metadata/upload_metadata.py` (`--texts <version>-<platform> --create-version`, `--screenshots`), reading its README first. Marketing leads with Then & Now and Time Walk. Screenshots use the simulator "Stamped Shots iPhone".

## 6. Submit

Export compliance: no non-exempt encryption. New in-app purchases must go with an app version, and the API can't attach first-time ones, so plan that in App Store Connect.

## 7. After

Update the release setup note in memory. Say plainly what wasn't tested and what only George can do.
