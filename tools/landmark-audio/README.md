# Landmark audio (Kokoro recordings)

Every landmark's **Listen** story, recorded ahead of time with the Kokoro voice `af_heart`
on this Mac. The app plays the recording when its city's pack is on the device, and the
device voice otherwise (offline, iOS older than 26.4, a pack not released yet, or text
changed since recording). See `AudioStoryPlayer.swift`.

| File | What it is |
| --- | --- |
| `record.py` | Records each story to `output/clips/<landmark id>.m4a` (AAC 48 kbps mono). Skips stories whose text hasn't changed. |
| `package.py` | Builds the 40 Apple-hosted asset packs, `output/packs/LandmarkAudio00.aar` … `39.aar`. |
| `pronunciations.json` | Spoken spellings for names Kokoro says wrong, e.g. `{"Sacré-Cœur": "Sacray Kur"}`. Changes the audio only. |
| `output/` | Git-ignored: clips, manifest, packs, logs. |

## Set up once

```bash
uv venv -p 3.12 .venv
uv pip install -p .venv/bin/python kokoro soundfile "en_core_web_sm @ https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl"
```

The Kokoro model (about 330 MB) downloads into `~/.cache/huggingface` the first time;
after that, run with `HF_HUB_OFFLINE=1`. Keep this folder's path short: espeak, which
Kokoro uses for pronunciation, fails when its data folder path is too long.

## Each release that changes landmark text

```bash
HF_HUB_OFFLINE=1 .venv/bin/python -I record.py
.venv/bin/python -I package.py
```

Recording everything from scratch takes several hours (`--shard 0/2` and `--shard 1/2` in
two terminals halves it). After that, only edited or new stories are recorded.

Upload the packs that changed with Transporter, or:

```bash
xcrun altool --api-key <key ID> --api-issuer <issuer ID> --upload-asset-pack output/packs/LandmarkAudio07.aar --apple-id 6759680336
```

The `--api-key` and `--api-issuer` options must come first: after the command, altool
ignores them and says authentication is missing.

## Rules that must not change

- **40 packs.** `PACKS` in `package.py` and `packCount` in `AudioStoryPlayer.swift` must
  match. Changing the number moves cities between packs. Apple allows 100–200 packs per app,
  and IDs can never be reused, even after archiving.
- A city's pack is the first 4 bytes of SHA-256 of its name, mod 40. A clip's path in the
  pack is `LandmarkAudio/<id>-<first 8 hex of SHA-256 of the story text>.m4a`. The app
  computes both itself, so the story text in `record.py` must match `story(for:)` in the app.
