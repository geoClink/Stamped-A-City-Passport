"""Upload App Preview videos (one per language) to a Mac or Apple Vision Pro version page.

Uses the same API key and client as upload_metadata.py. Dry run by default; --apply sends.

  ./venv/bin/python upload_previews.py 2.19 --platform macos    --videos ../../screenshots/2.19/preview/out/mac
  ./venv/bin/python upload_previews.py 2.19 --platform visionos --videos ../../screenshots/2.19/preview/out/vision --apply

The folder holds one video per language, named by locale: en-US.mp4, de-DE.mp4, ... A language's existing
preview in that slot is replaced. Apple processes each video after the upload; it can take a few minutes
before it shows in App Store Connect.
"""
import argparse
import os
import sys
from pathlib import Path

import upload_metadata as shared

# --platform value -> the preview slot Apple uses for it
PREVIEW_TYPES: dict[str, str] = {"macos": "DESKTOP", "visionos": "APPLE_VISION_PRO", "ios": "IPHONE_67"}
# The frame shown before the video plays (hours:minutes:seconds:frames). 6 s in = the old map is on screen.
POSTER_FRAME = "00:00:06:00"


class PreviewUploader(shared.AppStoreConnect):
    def preview_sets(self, localization_id: str) -> dict[str, dict]:
        """Return {preview type: set record} for a language on the version page."""
        records = self.request("GET", f"/appStoreVersionLocalizations/{localization_id}/appPreviewSets")["data"]
        return {record["attributes"]["previewType"]: record for record in records}

    def create_preview_set(self, localization_id: str, preview_type: str) -> dict:
        body = {
            "data": {
                "type": "appPreviewSets",
                "attributes": {"previewType": preview_type},
                "relationships": {
                    "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": localization_id}}
                },
            }
        }
        return self.request("POST", "/appPreviewSets", json=body)["data"]

    def previews_in_set(self, set_id: str) -> list[dict]:
        return self.request("GET", f"/appPreviewSets/{set_id}/appPreviews")["data"]

    def delete_preview(self, preview_id: str) -> None:
        self.request("DELETE", f"/appPreviews/{preview_id}")

    def upload_preview(self, set_id: str, path: Path) -> str:
        """Same three steps as a screenshot: reserve, send the bytes in the parts Apple asks for, confirm."""
        data = path.read_bytes()
        body = {
            "data": {
                "type": "appPreviews",
                "attributes": {"fileName": path.name, "fileSize": len(data), "mimeType": "video/mp4",
                               "previewFrameTimeCode": POSTER_FRAME},
                "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": set_id}}},
            }
        }
        reserved = self.request("POST", "/appPreviews", json=body)["data"]
        for operation in reserved["attributes"]["uploadOperations"]:
            headers = {header["name"]: header["value"] for header in operation["requestHeaders"]}
            chunk = data[operation["offset"]: operation["offset"] + operation["length"]]
            response = self.session.request(operation["method"], operation["url"], headers=headers, data=chunk, timeout=300)
            if response.status_code >= 400:
                raise RuntimeError(f"Uploading {path.name} failed ({response.status_code}): {response.text[:200]}")
        confirm = {
            "data": {
                "type": "appPreviews",
                "id": reserved["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": shared.file_checksum(data)},
            }
        }
        self.request("PATCH", f"/appPreviews/{reserved['id']}", json=confirm)
        return reserved["id"]


def main() -> int:
    parser = argparse.ArgumentParser(description="Upload one App Preview video per language.")
    parser.add_argument("version", help="App version, e.g. 2.19")
    parser.add_argument("--platform", choices=sorted(PREVIEW_TYPES), required=True)
    parser.add_argument("--videos", required=True, help="Folder with <locale>.mp4 files")
    parser.add_argument("--locales", help="Comma-separated locales to do (default: every video in the folder)")
    parser.add_argument("--apply", action="store_true", help="Really send (default only shows the plan)")
    args = parser.parse_args()

    folder = Path(args.videos)
    videos = {path.stem: path for path in sorted(folder.glob("*.mp4"))}
    if args.locales:
        videos = {locale: videos[locale] for locale in args.locales.split(",")}
    if not videos:
        raise SystemExit(f"No .mp4 files in {folder}")

    key_id, issuer_id = os.environ.get("ASC_KEY_ID"), os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer_id:
        raise SystemExit("Set ASC_KEY_ID and ASC_ISSUER_ID first")
    api = PreviewUploader(key_id, issuer_id, shared.read_private_key(key_id, os.environ.get("ASC_KEY_PATH")))
    app_id = api.find_app_id(shared.BUNDLE_ID)
    version_id = api.find_version_id(app_id, args.version, shared.PLATFORMS[args.platform])
    if version_id is None:
        raise SystemExit(f"Version {args.version} for {args.platform} doesn't exist in App Store Connect yet")
    localizations = api.version_localizations(version_id)
    preview_type = PREVIEW_TYPES[args.platform]

    print(("Sending" if args.apply else "Dry run (add --apply to send)") + f" — {args.platform} {args.version}, slot {preview_type}")
    failures = []
    for locale, path in videos.items():
        record = localizations.get(locale)
        if record is None:
            failures.append(f"{locale}: no such language on the page")
            continue
        try:
            existing_set = api.preview_sets(record["id"]).get(preview_type)
            old = api.previews_in_set(existing_set["id"]) if existing_set else []
            size_mb = path.stat().st_size / 1_000_000
            print(f"── {locale}: {'replace ' + str(len(old)) + ' old, ' if old else ''}upload {path.name} ({size_mb:.1f} MB)")
            if not args.apply:
                continue
            for preview in old:
                api.delete_preview(preview["id"])
            preview_set = existing_set or api.create_preview_set(record["id"], preview_type)
            api.upload_preview(preview_set["id"], path)
        except RuntimeError as error:
            failures.append(f"{locale}: {error}")
    if failures:
        print("\nFailed:\n  " + "\n  ".join(failures))
        return 1
    print("Done." if args.apply else "Plan only; nothing sent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
