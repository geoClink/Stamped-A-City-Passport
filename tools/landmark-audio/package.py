"""Packs the recorded stories into Apple-hosted asset packs, LandmarkAudio00–39.

Each city goes into the pack its name hashes to (same rule as AudioStoryPlayer.packID).
Inside a pack, a clip is LandmarkAudio/<landmark id>-<first 8 hex of the text's SHA-256>.m4a,
which is the path the app looks for. Clips whose text has changed since they were recorded
are left out (run record.py first).

    .venv/bin/python -I package.py          # writes output/packs/LandmarkAudioNN.aar
    .venv/bin/python -I package.py --dry    # only prints the pack sizes
"""
import argparse, hashlib, json, shutil, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from record import CLIPS, OUT, REGISTRY, sha, story  # noqa: E402

PACKS = 40   # must match AudioStoryPlayer.packCount; never change once packs are uploaded


def pack_id(city):
    digest = hashlib.sha256(city.encode("utf-8")).digest()
    return f"LandmarkAudio{int.from_bytes(digest[:4], 'big') % PACKS:02d}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()

    registry = json.load(open(REGISTRY))
    staging = OUT / "packs" / "staging"
    if staging.exists() and not args.dry:
        shutil.rmtree(staging)
    sizes, counts, missing = {}, {}, 0
    for city, buildings in registry.items():
        pid = pack_id(city)
        for b in buildings:
            text_sha = sha(story(b))
            clip, meta = CLIPS / f"{b['id']}.m4a", CLIPS / f"{b['id']}.json"
            if not (clip.exists() and meta.exists() and json.load(open(meta))["sha256"] == text_sha):
                missing += 1
                continue
            sizes[pid] = sizes.get(pid, 0) + clip.stat().st_size
            counts[pid] = counts.get(pid, 0) + 1
            if not args.dry:
                dest = staging / pid / "LandmarkAudio" / f"{b['id']}-{text_sha[:8]}.m4a"
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(clip, dest)

    for pid in sorted(sizes):
        print(f"{pid}: {counts[pid]} clips, {sizes[pid] / 1e6:.1f} MB")
    print(f"{sum(counts.values())} clips in {len(sizes)} packs, {sum(sizes.values()) / 1e6:.0f} MB; "
          f"{missing} landmarks not recorded (or text changed)")
    if args.dry:
        return

    for pid in sorted(sizes):
        manifest = {
            "assetPackID": pid,
            "downloadPolicy": {"onDemand": {}},
            "fileSelectors": [{"directorySource": f"staging/{pid}/LandmarkAudio",
                               "directoryDestination": "LandmarkAudio"}],
            "platforms": ["iOS", "macOS", "visionOS"],
        }
        path = OUT / "packs" / f"{pid}.json"
        json.dump(manifest, open(path, "w"), indent=1)
        subprocess.run(["xcrun", "ba-package", "package", path.name, "--output-path", f"{pid}.aar", "--quiet"],
                       cwd=OUT / "packs", check=True)
    print(f"Archives in {OUT / 'packs'}")


if __name__ == "__main__":
    sys.exit(main())
