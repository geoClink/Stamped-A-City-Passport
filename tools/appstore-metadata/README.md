# App Store text uploader

Fills in the App Store product page for **every language at once** from the JSON files in `docs/app-store/localization/<version>/`. No more pasting 40 boxes by hand.

What it sets, per language:

| JSON field | App Store Connect box |
|---|---|
| `whats_new` | What's New in This Version |
| `promotional_text` | Promotional Text |
| `description` | Description |
| `keywords` | Keywords |
| `subtitle` | App Information → Subtitle (only while App Information is editable) |
| `--marketing-url` flag | Marketing URL |

Screenshots are not uploaded.

## One-time setup

1. **Make an API key.** App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → **+**. Name it "Metadata uploader", role **App Manager**.
2. **Download the `.p8` file** (Apple only lets you download it once) and move it to:
   ```
   ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
   ```
   Keep it outside the repo so it can never be committed. Never paste its contents anywhere.
3. **Save the two IDs** shown on that page in `~/.zshrc` (they aren't secret, but they're yours):
   ```
   export ASC_KEY_ID="ABC123XYZ"
   export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```
   Then open a new terminal tab.
4. **Install** (once):
   ```
   cd tools/appstore-metadata
   python3 -m venv venv
   ./venv/bin/pip install -r requirements.txt
   ```

## Every release

```
cd tools/appstore-metadata

# 1. Check the files only (no internet needed)
./venv/bin/python upload_metadata.py 2.5 --check-only

# 2. See exactly what would change in App Store Connect
./venv/bin/python upload_metadata.py 2.5

# 3. Send it
./venv/bin/python upload_metadata.py 2.5 --apply
```

Useful flags:

- `--marketing-url https://georgeclinkscalesdev.com/stamped-app.html` also sets the Marketing URL in every language.
- `--create-version` creates the version (e.g. 2.5) in App Store Connect if you haven't yet. Needs `--apply`.
- `--skip-subtitle` leaves the subtitle alone.

### Mac and Vision Pro

Mac and Vision Pro have their own version pages on the same app, with their own text folders
(`2.8-macos`, `2.8-visionos`). Pick the page with `--platform` and the folder with `--texts`:

```
./venv/bin/python upload_metadata.py 2.8 --platform macos --texts 2.8-macos
./venv/bin/python upload_metadata.py 2.8 --platform visionos --texts 2.8-visionos
```

The subtitle belongs to the whole app, so it's set from the iPhone run; the Mac and Vision Pro
folders don't include one.

### Screenshots

`--screenshots <folder>` uploads the PNGs in that folder (01.png, 02.png, ... in App Store order) to
the platform's usual slot (iPhone 6.9", Mac, or Apple Vision Pro; change it with `--display-type`).
A slot that already has screenshots is left alone unless you add `--replace-screenshots`.
`--skip-text` does screenshots only.

The script only sends text that's different from what's already there, and keeps going if one language fails, then lists the failures at the end.

## Tests

```
./venv/bin/pytest
```

They check the real 2.5 files fit Apple's limits and that only changed text gets sent. They never contact Apple.

If an API key is ever exposed, revoke it on the same App Store Connect page and make a new one.
