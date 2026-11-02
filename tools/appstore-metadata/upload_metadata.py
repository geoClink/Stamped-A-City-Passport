"""
Upload the App Store product page text for every language in one go.

Reads the JSON files in docs/app-store/localization/<version>/ (one per
App Store Connect locale) and fills in, for that version:
  - What's New, Promotional Text, Description and Keywords (version page)
  - Subtitle (App Information page)
  - Marketing URL, if you pass --marketing-url

By default it only shows what WOULD change. Add --apply to really send it.

Usage:
  python upload_metadata.py 2.5
  python upload_metadata.py 2.5 --apply
  python upload_metadata.py 2.5 --apply --marketing-url https://georgeclinkscalesdev.com/stamped-app.html

Mac and Vision Pro share the same app record, so the same script fills their pages too.
Add --platform and, to upload screenshots, --screenshots pointing at a folder of PNGs:
  python upload_metadata.py 2.5 --platform macos --screenshots store-screenshots/mac-vision/final/mac-1440x900_2880x1800
  python upload_metadata.py 1.0 --platform visionos --texts 2.5 --screenshots store-screenshots/mac-vision/final/vision-pro_3840x2160
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path

import jwt
import requests

API_ROOT = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "name.GeorgeClinkscales.Stamped--A-City-Passport"
REPO_ROOT = Path(__file__).resolve().parents[2]
LOCALIZATION_ROOT = REPO_ROOT / "docs" / "app-store" / "localization"

# JSON field name -> (App Store Connect attribute name, character limit)
VERSION_FIELDS: dict[str, tuple[str, int]] = {
    "whats_new": ("whatsNew", 4000),
    "promotional_text": ("promotionalText", 170),
    "description": ("description", 4000),
    "keywords": ("keywords", 100),
}
SUBTITLE_LIMIT = 30

# --platform value -> the name App Store Connect uses
PLATFORMS: dict[str, str] = {"ios": "IOS", "macos": "MAC_OS", "visionos": "VISION_OS"}
# The screenshot slot each platform's set goes into (Apple calls it the "display type")
DEFAULT_DISPLAY_TYPES: dict[str, str] = {
    "ios": "APP_IPHONE_67",            # iPhone 6.9" (1320x2868)
    "macos": "APP_DESKTOP",            # Mac 1440x900 or 2880x1800
    "visionos": "APP_APPLE_VISION_PRO",  # Apple Vision Pro 3840x2160
}
MAX_SCREENSHOTS_PER_SET = 10
SCREENSHOT_SUFFIXES = {".png", ".jpg", ".jpeg"}

# An App Information record in one of these states is the live one and can't be edited.
LOCKED_APP_INFO_STATES = {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"}


# ---------- Reading and checking the JSON files ----------

def load_locale_files(version: str) -> dict[str, dict]:
    """Return {locale: json contents} for every <locale>.json in the version's folder."""
    folder = LOCALIZATION_ROOT / version
    if not folder.is_dir():
        raise SystemExit(f"No folder for version {version}: {folder}")

    locale_texts: dict[str, dict] = {}
    for json_path in sorted(folder.glob("*.json")):
        contents = json.loads(json_path.read_text(encoding="utf-8"))
        # The file name is the locale (en-US.json -> en-US); the "locale" field must agree
        locale = json_path.stem
        if contents.get("locale", locale) != locale:
            raise SystemExit(f"{json_path.name} says locale {contents['locale']!r}, expected {locale!r}")
        locale_texts[locale] = contents

    if not locale_texts:
        raise SystemExit(f"No .json files in {folder}")
    return locale_texts


def find_problems(locale_texts: dict[str, dict]) -> list[str]:
    """List every missing field or text over Apple's limit. Empty list means all good."""
    problems: list[str] = []
    for locale, contents in locale_texts.items():
        for json_field, (_, limit) in VERSION_FIELDS.items():
            text = contents.get(json_field)
            if not text:
                problems.append(f"{locale}: {json_field} is missing")
            elif len(text) > limit:
                problems.append(f"{locale}: {json_field} is {len(text)} characters (limit {limit})")

        subtitle = contents.get("subtitle", "")
        if len(subtitle) > SUBTITLE_LIMIT:
            problems.append(f"{locale}: subtitle is {len(subtitle)} characters (limit {SUBTITLE_LIMIT})")
    return problems


def screenshot_files(folder: Path) -> list[Path]:
    """The PNG/JPG files in a folder, in name order (01.png, 02.png, ...). That order is the App Store order."""
    if not folder.is_dir():
        raise SystemExit(f"No screenshot folder: {folder}")
    files = sorted(path for path in folder.iterdir() if path.suffix.lower() in SCREENSHOT_SUFFIXES)
    if not files:
        raise SystemExit(f"No .png or .jpg files in {folder}")
    if len(files) > MAX_SCREENSHOTS_PER_SET:
        raise SystemExit(f"{folder} has {len(files)} screenshots; Apple allows at most {MAX_SCREENSHOTS_PER_SET}")
    return files


def file_checksum(data: bytes) -> str:
    """Apple checks the upload against an MD5 of the file."""
    return hashlib.md5(data).hexdigest()


# ---------- Talking to App Store Connect ----------

class AppStoreConnect:
    """A tiny wrapper around the App Store Connect REST API."""

    def __init__(self, key_id: str, issuer_id: str, private_key: str) -> None:
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.private_key = private_key
        self.session = requests.Session()

    def _token(self) -> str:
        # Apple wants a short-lived JWT signed with your .p8 key (20 minutes max)
        now = int(time.time())
        payload = {"iss": self.issuer_id, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
        return jwt.encode(payload, self.private_key, algorithm="ES256", headers={"kid": self.key_id})

    def request(self, method: str, path: str, **kwargs) -> dict:
        url = path if path.startswith("http") else f"{API_ROOT}{path}"
        headers = {"Authorization": f"Bearer {self._token()}"}
        response = self.session.request(method, url, headers=headers, timeout=30, **kwargs)
        if response.status_code >= 400:
            # Apple returns a list of errors with a readable "detail"
            try:
                details = "; ".join(error.get("detail", "") for error in response.json().get("errors", []))
            except ValueError:
                details = response.text
            raise RuntimeError(f"{method} {path} failed ({response.status_code}): {details}")
        return response.json() if response.content else {}

    def find_app_id(self, bundle_id: str) -> str:
        apps = self.request("GET", "/apps", params={"filter[bundleId]": bundle_id})["data"]
        if not apps:
            raise SystemExit(f"No app with bundle ID {bundle_id} on this account")
        return apps[0]["id"]

    def find_version_id(self, app_id: str, version: str, platform: str = "IOS") -> str | None:
        versions = self.request(
            "GET",
            f"/apps/{app_id}/appStoreVersions",
            params={"filter[versionString]": version, "filter[platform]": platform},
        )["data"]
        return versions[0]["id"] if versions else None

    def create_version(self, app_id: str, version: str, platform: str = "IOS") -> str:
        body = {
            "data": {
                "type": "appStoreVersions",
                "attributes": {"platform": platform, "versionString": version},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        }
        return self.request("POST", "/appStoreVersions", json=body)["data"]["id"]

    def version_localizations(self, version_id: str) -> dict[str, dict]:
        """Return {locale: localization record} for the version."""
        records = self.request(
            "GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations", params={"limit": 50}
        )["data"]
        return {record["attributes"]["locale"]: record for record in records}

    def editable_app_info(self, app_id: str) -> tuple[str | None, dict[str, dict]]:
        """Return (App Information id, {locale: record}) for the one that's still editable, or (None, {})."""
        app_infos = self.request("GET", f"/apps/{app_id}/appInfos")["data"]
        for app_info in app_infos:
            attributes = app_info["attributes"]
            # Newer API versions call it "state", older ones "appStoreState"
            state = attributes.get("state") or attributes.get("appStoreState")
            if state not in LOCKED_APP_INFO_STATES:
                records = self.request("GET", f"/appInfos/{app_info['id']}/appInfoLocalizations")["data"]
                return app_info["id"], {record["attributes"]["locale"]: record for record in records}
        return None, {}

    def add_app_info_language(self, app_info_id: str, locale: str, attributes: dict) -> dict:
        """Add a language under App Information (Apple needs this before the version page can use it)."""
        body = {
            "data": {
                "type": "appInfoLocalizations",
                "attributes": {"locale": locale, **attributes},
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": app_info_id}}},
            }
        }
        return self.request("POST", "/appInfoLocalizations", json=body)["data"]

    # Screenshots: each language has one "set" per device slot, each set holds up to 10 images

    def screenshot_sets(self, localization_id: str) -> dict[str, dict]:
        """Return {display type: set record} for a language on the version page."""
        records = self.request("GET", f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")["data"]
        return {record["attributes"]["screenshotDisplayType"]: record for record in records}

    def create_screenshot_set(self, localization_id: str, display_type: str) -> dict:
        body = {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": localization_id}}
                },
            }
        }
        return self.request("POST", "/appScreenshotSets", json=body)["data"]

    def screenshots_in_set(self, set_id: str) -> list[dict]:
        return self.request("GET", f"/appScreenshotSets/{set_id}/appScreenshots", params={"limit": 50})["data"]

    def delete_screenshot(self, screenshot_id: str) -> None:
        self.request("DELETE", f"/appScreenshots/{screenshot_id}")

    def upload_screenshot(self, set_id: str, path: Path) -> str:
        """Upload one image in Apple's three steps: reserve a slot, send the bytes, confirm with a checksum."""
        data = path.read_bytes()
        body = {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": path.name, "fileSize": len(data)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
            }
        }
        reserved = self.request("POST", "/appScreenshots", json=body)["data"]
        # Apple answers with one or more upload "operations": a URL plus the byte range to send to it
        for operation in reserved["attributes"]["uploadOperations"]:
            headers = {header["name"]: header["value"] for header in operation["requestHeaders"]}
            chunk = data[operation["offset"]: operation["offset"] + operation["length"]]
            response = self.session.request(operation["method"], operation["url"], headers=headers, data=chunk, timeout=120)
            if response.status_code >= 400:
                raise RuntimeError(f"Uploading {path.name} failed ({response.status_code}): {response.text[:200]}")
        confirm = {
            "data": {
                "type": "appScreenshots",
                "id": reserved["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": file_checksum(data)},
            }
        }
        self.request("PATCH", f"/appScreenshots/{reserved['id']}", json=confirm)
        return reserved["id"]


# ---------- Working out what changes ----------

def changed_attributes(current: dict, wanted: dict) -> dict:
    """Keep only the attributes whose text is different from what's already in App Store Connect."""
    return {name: value for name, value in wanted.items() if (current.get(name) or "") != value}


def wanted_version_attributes(contents: dict, marketing_url: str | None, support_url: str | None = None) -> dict:
    attributes = {api_name: contents[json_field] for json_field, (api_name, _) in VERSION_FIELDS.items()}
    if marketing_url:
        attributes["marketingUrl"] = marketing_url
    # Apple requires a Support URL in every language; we reuse the English one
    if support_url:
        attributes["supportUrl"] = support_url
    return attributes


def new_app_info_attributes(english_attributes: dict, subtitle: str | None) -> dict:
    """App Information for a new language: the English app name and privacy URL, plus the translated subtitle."""
    attributes = {"name": english_attributes["name"]}
    if english_attributes.get("privacyPolicyUrl"):
        attributes["privacyPolicyUrl"] = english_attributes["privacyPolicyUrl"]
    if subtitle:
        attributes["subtitle"] = subtitle
    return attributes


def screenshot_plan(existing_names: list[str], wanted_names: list[str], replace: bool) -> tuple[list[str], list[str]]:
    """Return (names to delete, names to upload). An existing set is left alone unless --replace-screenshots."""
    if existing_names and not replace:
        return [], []
    return list(existing_names), list(wanted_names)


def short_preview(text: str) -> str:
    one_line = text.replace("\n", " ⏎ ")
    return one_line if len(one_line) <= 70 else f"{one_line[:67]}..."


# ---------- Main ----------

def read_private_key(key_id: str, key_path: str | None) -> str:
    path = Path(key_path).expanduser() if key_path else Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{key_id}.p8"
    if not path.is_file():
        raise SystemExit(f"Can't find your API key file at {path}")
    return path.read_text()


def main() -> int:
    parser = argparse.ArgumentParser(description="Upload App Store text for every language.")
    parser.add_argument("version", help="App version, e.g. 2.5 (also the folder name under docs/app-store/localization)")
    parser.add_argument("--apply", action="store_true", help="Really send the changes (default only shows them)")
    parser.add_argument("--platform", choices=sorted(PLATFORMS), default="ios", help="Which App Store page: ios (default), macos or visionos")
    parser.add_argument("--texts", help="Use the JSON files from this version folder instead (e.g. --texts 2.5 for a 1.0 visionOS page)")
    parser.add_argument("--skip-text", action="store_true", help="Don't touch any text; only handle screenshots")
    parser.add_argument("--screenshots", help="Folder of PNG/JPG files to upload (01.png, 02.png, ... in App Store order)")
    parser.add_argument("--display-type", help="Screenshot slot to fill (default depends on --platform: APP_IPHONE_67, APP_DESKTOP or APP_APPLE_VISION_PRO)")
    parser.add_argument("--screenshot-locales", help="Comma-separated locales to give the screenshots to (default: every language on the page)")
    parser.add_argument("--replace-screenshots", action="store_true", help="Delete what's already in the slot before uploading")
    parser.add_argument("--create-version", action="store_true", help="Create the version in App Store Connect if it doesn't exist yet")
    parser.add_argument("--marketing-url", help="Also set this Marketing URL for every language")
    parser.add_argument("--skip-subtitle", action="store_true", help="Don't touch the subtitle")
    parser.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID"), help="API Key ID (or set ASC_KEY_ID)")
    parser.add_argument("--issuer-id", default=os.environ.get("ASC_ISSUER_ID"), help="Issuer ID (or set ASC_ISSUER_ID)")
    parser.add_argument("--key-path", default=os.environ.get("ASC_KEY_PATH"), help="Path to the .p8 file (default ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8)")
    parser.add_argument("--check-only", action="store_true", help="Only check the JSON files; don't contact Apple")
    args = parser.parse_args()

    platform = PLATFORMS[args.platform]
    display_type = args.display_type or DEFAULT_DISPLAY_TYPES[args.platform]
    screenshots = screenshot_files(Path(args.screenshots).expanduser()) if args.screenshots else []
    if args.screenshots:
        print(f"Found {len(screenshots)} screenshots for the {display_type} slot: {', '.join(file.name for file in screenshots)}")

    # 1. Check the files before touching anything online
    locale_texts: dict[str, dict] = {}
    if not args.skip_text:
        locale_texts = load_locale_files(args.texts or args.version)
        problems = find_problems(locale_texts)
        print(f"Found {len(locale_texts)} languages for {args.texts or args.version}: {', '.join(locale_texts)}")
        if problems:
            print("\nFix these first:")
            for problem in problems:
                print(f"  ✗ {problem}")
            return 1
        print("All texts are under Apple's limits.")
    if args.check_only:
        return 0

    if not args.key_id or not args.issuer_id:
        raise SystemExit("Missing --key-id / --issuer-id (or the ASC_KEY_ID / ASC_ISSUER_ID environment variables)")

    api = AppStoreConnect(args.key_id, args.issuer_id, read_private_key(args.key_id, args.key_path))

    # 2. Find the app and the version
    app_id = api.find_app_id(BUNDLE_ID)
    version_id = api.find_version_id(app_id, args.version, platform)
    if version_id is None:
        if not (args.create_version and args.apply):
            raise SystemExit(
                f"Version {args.version} for {args.platform} doesn't exist in App Store Connect yet. "
                "Create it there, or run again with --create-version --apply."
            )
        version_id = api.create_version(app_id, args.version, platform)
        print(f"Created version {args.version} for {args.platform}")

    existing_version_records = api.version_localizations(version_id)
    if args.skip_text:
        # No JSON files in play, so the languages are whatever the page already has
        locale_texts = {locale: {} for locale in existing_version_records}
    screenshot_locales = set(args.screenshot_locales.split(",")) if args.screenshot_locales else set(locale_texts)
    app_info_id, existing_app_info_records = api.editable_app_info(app_id)
    if app_info_id is None:
        print("Note: App Information isn't editable right now, so subtitles and new languages there will be skipped.")
    # New languages copy the app name and privacy policy URL from English
    source_app_info = existing_app_info_records.get("en-US") or next(iter(existing_app_info_records.values()), None)
    english_version = existing_version_records.get("en-US")
    support_url = english_version["attributes"].get("supportUrl") if english_version else None

    mode = "Sending" if args.apply else "Dry run (nothing is sent; add --apply to send)"
    print(f"\n{mode} — {args.platform} page, version {args.version}\n")

    change_count = 0
    failures: list[str] = []

    for locale, contents in locale_texts.items():
        print(f"── {locale}")
        subtitle = None if (args.skip_subtitle or args.skip_text) else contents.get("subtitle")
        record = existing_version_records.get(locale)
        try:
            if args.skip_text:
                pass
            # App Information first: Apple needs the language there before the version page can use it
            app_info_record = existing_app_info_records.get(locale)
            if app_info_record is None and app_info_id and source_app_info:
                new_attributes = new_app_info_attributes(source_app_info["attributes"], subtitle)
                print(f"   + add language to App Information ({', '.join(new_attributes)})")
                change_count += 1
                if args.apply:
                    api.add_app_info_language(app_info_id, locale, new_attributes)
                    # Apple creates an empty version page for the new language on its own,
                    # so re-read them and update that page instead of adding a second one
                    existing_version_records = api.version_localizations(version_id)
            elif app_info_record and subtitle and not args.skip_text:
                subtitle_changes = changed_attributes(app_info_record["attributes"], {"subtitle": subtitle})
                if subtitle_changes:
                    print(f"   ~ subtitle: {subtitle}")
                    change_count += 1
                    if args.apply:
                        body = {"data": {"type": "appInfoLocalizations", "id": app_info_record["id"], "attributes": subtitle_changes}}
                        api.request("PATCH", f"/appInfoLocalizations/{app_info_record['id']}", json=body)

            # Version page text
            wanted = wanted_version_attributes(contents, args.marketing_url, support_url) if not args.skip_text else {}
            record = existing_version_records.get(locale)
            if args.skip_text:
                pass
            elif record is None:
                # This language isn't on the version yet, so add it
                print(f"   + add language with {', '.join(wanted)}")
                change_count += 1
                if args.apply:
                    body = {
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "attributes": {"locale": locale, **wanted},
                            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
                        }
                    }
                    record = api.request("POST", "/appStoreVersionLocalizations", json=body)["data"]
            else:
                changes = changed_attributes(record["attributes"], wanted)
                for name, value in changes.items():
                    print(f"   ~ {name}: {short_preview(value)}")
                if not changes:
                    print("   = version text already up to date")
                change_count += len(changes)
                if changes and args.apply:
                    body = {"data": {"type": "appStoreVersionLocalizations", "id": record["id"], "attributes": changes}}
                    api.request("PATCH", f"/appStoreVersionLocalizations/{record['id']}", json=body)

            # Screenshots for this language
            if screenshots and locale in screenshot_locales:
                if record is None:
                    print(f"   · screenshots: language isn't on the page yet (dry run), would upload {len(screenshots)}")
                    change_count += len(screenshots)
                else:
                    sets = api.screenshot_sets(record["id"])
                    screenshot_set = sets.get(display_type)
                    existing_names = [shot["attributes"]["fileName"] for shot in api.screenshots_in_set(screenshot_set["id"])] if screenshot_set else []
                    to_delete, to_upload = screenshot_plan(existing_names, [file.name for file in screenshots], args.replace_screenshots)
                    if not to_upload:
                        print(f"   = {display_type} already has {len(existing_names)} screenshots (add --replace-screenshots to replace them)")
                    else:
                        if to_delete:
                            print(f"   - remove {len(to_delete)} old screenshots from {display_type}")
                        print(f"   + upload {len(to_upload)} screenshots to {display_type}: {', '.join(to_upload)}")
                        change_count += len(to_delete) + len(to_upload)
                        if args.apply:
                            if screenshot_set is None:
                                screenshot_set = api.create_screenshot_set(record["id"], display_type)
                            for shot in api.screenshots_in_set(screenshot_set["id"]):
                                api.delete_screenshot(shot["id"])
                            for file in screenshots:
                                api.upload_screenshot(screenshot_set["id"], file)
                                print(f"     ✓ {file.name}")
        except RuntimeError as error:
            # Keep going with the other languages, then report
            print(f"   ✗ {error}")
            failures.append(locale)

    print()
    if failures:
        print(f"Finished with errors in: {', '.join(failures)}")
        return 1
    verb = "Sent" if args.apply else "Would send"
    print(f"{verb} {change_count} change(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
