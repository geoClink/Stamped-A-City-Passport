"""Records every landmark's "Listen" story with Kokoro (voice af_heart).

Writes output/clips/<landmark id>.m4a and output/manifest.json. The manifest keeps the
SHA-256 of each story's text, so a later run only records stories whose text changed, and
the app only plays a clip whose text still matches (otherwise it uses the device voice).

The story text must match AudioStoryPlayer.story(for:) in the app exactly.

    HF_HUB_OFFLINE=1 .venv/bin/python -I record.py              # everything
    HF_HUB_OFFLINE=1 .venv/bin/python -I record.py --city Paris  # one city
    ... --shard 0/2 and --shard 1/2 in two terminals to go twice as fast
"""
import argparse, hashlib, json, os, subprocess, sys, tempfile, time
from pathlib import Path

HERE = Path(__file__).parent
REGISTRY = HERE.parent.parent / "Stamped! A City Passport" / "Resources" / "BuildingRegistry.json"
OUT = HERE / "output"
CLIPS = OUT / "clips"
VOICE = "af_heart"
SPACES = " \t   "


def known(value):
    value = (value or "").strip(SPACES)
    return None if not value or value.lower() == "unknown" else value


def story(b):
    facts = []
    if b.get("yearBuilt", 0) != 0:
        facts.append(f"Finished in {b['yearBuilt']}")
    if known(b.get("architect")):
        facts.append(f"designed by {known(b['architect'])}")
    if known(b.get("buildingStyle")):
        facts.append(f"in the {known(b['buildingStyle'])} style")
    facts_sentence = " " + ", ".join(facts) + "." if facts else ""
    return f"{b['name']}.{facts_sentence} {b['description']}"


def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def for_speech(text, fixes):
    # Spoken spellings for names Kokoro gets wrong; changes only the audio, not the hash
    for written, spoken in fixes.items():
        text = text.replace(written, spoken)
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--city")
    ap.add_argument("--shard", default="0/1")
    args = ap.parse_args()
    shard, shards = map(int, args.shard.split("/"))

    registry = json.load(open(REGISTRY))
    fixes = json.load(open(HERE / "pronunciations.json"))
    CLIPS.mkdir(parents=True, exist_ok=True)

    todo = []
    for city, buildings in registry.items():
        if args.city and city != args.city:
            continue
        for b in buildings:
            text = story(b)
            done = CLIPS / f"{b['id']}.json"
            if (CLIPS / f"{b['id']}.m4a").exists() and done.exists() and json.load(open(done))["sha256"] == sha(text):
                continue
            todo.append((city, b, text))
    todo = todo[shard::shards]
    print(f"{len(todo)} stories to record", flush=True)

    from kokoro import KPipeline
    import numpy as np, soundfile as sf
    pipe = KPipeline(lang_code="a", repo_id="hexgrad/Kokoro-82M")

    start = time.time()
    for n, (city, b, text) in enumerate(todo, 1):
        audio = np.concatenate([a for _, _, a in pipe(for_speech(text, fixes), voice=VOICE)])
        with tempfile.NamedTemporaryFile(suffix=".wav", dir=OUT, delete=False) as tmp:
            sf.write(tmp.name, audio, 24000)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name, "-ac", "1",
                        "-c:a", "aac", "-b:a", "48k", "-movflags", "+faststart",
                        str(CLIPS / f"{b['id']}.m4a")], check=True)
        os.remove(tmp.name)
        # Written last, so a clip cut off mid-run is recorded again next time
        json.dump({"city": city, "sha256": sha(text), "seconds": round(len(audio) / 24000, 1)},
                  open(CLIPS / f"{b['id']}.json", "w"))
        if n % 25 == 0 or n == len(todo):
            left = (time.time() - start) / n * (len(todo) - n) / 60
            print(f"{n}/{len(todo)}  about {left:.0f} min left", flush=True)

    # One manifest for all clips recorded so far
    manifest = {}
    for meta in sorted(CLIPS.glob("*.json")):
        manifest[meta.stem] = json.load(open(meta))
    json.dump(manifest, open(OUT / "manifest.json", "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    sys.exit(main())
