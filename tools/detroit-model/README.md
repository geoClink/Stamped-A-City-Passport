# Detroit 3D model asset pack (Vision Pro)

The Vision Pro app doesn't bundle the Detroit 3D model. Bundling it made the
app download about 355 MB; without it the app is about 24 MB. Instead the
model is an Apple-hosted **asset pack** called `Detroit3D`. When someone opens
Detroit's map, the toolbar shows "Download Detroit in 3D (≈38 MB)". One tap
and the system downloads the pack from Apple (code: `Tally-AVP/CityModelStore.swift`).

The iPhone/iPad app still bundles the full model from `Packages/output/`.

## Files

| File | What it is |
| --- | --- |
| `shrink_detroit.py` | Makes a smaller copy of `Packages/output/detroit.usdz` (352 MB → about 60 MB). |
| `Detroit3D.json` | The asset pack manifest: its ID, download policy (on demand), and which file goes in it. |
| `output/` | Build output, git-ignored: `detroit.usdz` (shrunk) and `Detroit3D.aar` (the pack). |

## 1. Shrink the model

Needs Python 3 with a virtual environment (from the repo root):

```bash
python3 -m venv tools/detroit-model/.venv
source tools/detroit-model/.venv/bin/activate
pip install usd-core trimesh numpy pillow
python tools/detroit-model/shrink_detroit.py
```

This writes `tools/detroit-model/output/detroit.usdz`. The original is only read.

## 2. Package the asset pack

`ba-package` resolves paths in the manifest against the current folder, so run
it from this folder:

```bash
cd tools/detroit-model
xcrun ba-package package Detroit3D.json --output-path output/Detroit3D.aar
```

## 3. Upload it to App Store Connect

Upload `output/Detroit3D.aar` with the Transporter app, or from Terminal
(the Apple ID is the app's numeric ID from App Store Connect → App Information):

```bash
xcrun altool --upload-asset-pack output/Detroit3D.aar --apple-id <app's numeric Apple ID>
```

Check it with `xcrun altool --list-asset-packs --apple-id <same ID>`, and make
sure the pack is ready in App Store Connect before submitting the build. The
asset pack ID must stay `Detroit3D`; it has to match `assetPackIDs` in
`CityModelStore.swift` and `assetPackID` in `Detroit3D.json`.

## Testing without the App Store

Builds can't download Apple-hosted packs until the pack is uploaded. To test
the downloaded path locally, Xcode's Background Assets mock server
(`xcrun ba-serve`) can serve `output/Detroit3D.aar` to a debug build.
