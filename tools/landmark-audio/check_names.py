"""Flags recordings where Kokoro may have mispronounced the landmark's name.

Transcribes the opening of each clip (where the name is spoken) with Whisper and compares
it with the name. A low match means Kokoro probably said it wrong, or Whisper misheard:
listen to the flagged clips, then add a spoken spelling to pronunciations.json and run
record.py again: it re-records only the clips whose spoken text changed.

    .venv/bin/python -I check_names.py            # writes output/name-check.tsv
    .venv/bin/python -I check_names.py --city Paris
"""
import argparse, difflib, json, re, subprocess, sys, unicodedata
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from record import CLIPS, OUT, REGISTRY  # noqa: E402

MODEL = "mlx-community/whisper-large-v3-turbo"


def plain(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9 ]+", " ", text.lower()).split()


def match(name, heard):
    """How well the start of what Whisper heard matches the name, 0 to 1"""
    want, got = " ".join(plain(name)), plain(heard)
    best = 0.0
    for n in range(1, min(len(got), len(want.split()) + 3) + 1):
        best = max(best, difflib.SequenceMatcher(None, want, " ".join(got[:n])).ratio())
    return best


def audio(path, seconds):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-t", str(seconds), "-i", str(path),
                          "-f", "s16le", "-ac", "1", "-ar", "16000", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--city")
    ap.add_argument("--below", type=float, default=0.7)
    args = ap.parse_args()
    import mlx_whisper

    registry = json.load(open(REGISTRY))
    rows = []
    for city, buildings in registry.items():
        if args.city and city != args.city:
            continue
        for b in buildings:
            clip = CLIPS / f"{b['id']}.m4a"
            if not clip.exists():
                continue
            seconds = 2.5 + 0.45 * len(b["name"].split())
            heard = mlx_whisper.transcribe(audio(clip, seconds), path_or_hf_repo=MODEL, language="en",
                                           condition_on_previous_text=False)["text"].strip()
            rows.append((match(b["name"], heard), city, b["id"], b["name"], heard))
            if len(rows) % 100 == 0:
                print(f"{len(rows)} checked", flush=True)

    rows.sort()
    with open(OUT / "name-check.tsv", "w") as f:
        f.write("score\tcity\tid\tname\theard\n")
        for r in rows:
            f.write(f"{r[0]:.2f}\t{r[1]}\t{r[2]}\t{r[3]}\t{r[4]}\n")
    flagged = [r for r in rows if r[0] < args.below]
    print(f"{len(rows)} checked, {len(flagged)} below {args.below}; list in output/name-check.tsv")


if __name__ == "__main__":
    sys.exit(main())
