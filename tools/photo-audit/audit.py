"""Audit every landmark photo the app loads from Wikipedia.

Usage (from tools/photo-audit):
    .venv/bin/python audit.py                 # writes reports/audit.json and reports/audit.md
    .venv/bin/python audit.py --label before  # writes reports/audit-before.json / .md

Each landmark lands in one category:
    no_article      none of the titles the app tries has a Wikipedia article
    disambiguation  the title lands on a "may refer to" page, so the photo is a guess at best
    no_photo        the article exists but has no usable photo
    logo_like       the photo looks like a logo, map, seal, flag or diagram
    far_away        the article's coordinates are more than 2 km from the landmark (likely the wrong place)
    ok              a real photo of (as far as we can tell) the right place
"""

import argparse
import json
from collections import Counter
from pathlib import Path
from urllib.parse import unquote

from wiki import (
    TOOL_DIR,
    Landmark,
    PhotoResult,
    WikiClient,
    app_photo,
    distance_km,
    load_landmarks,
    swift_logo_patterns,
    swift_title_overrides,
)

REPORTS_DIR = TOOL_DIR / "reports"
CATEGORIES = ["no_article", "disambiguation", "no_photo", "logo_like", "far_away", "ok"]

# Stricter than the app: anything matching these in the *file name* gets flagged.
# If the audit finds a new pattern worth filtering, add it to isLogoOrDiagram in Swift too.
SUSPICIOUS_FILENAME_PARTS = [".svg", "logo", "map", "seal", "flag", "coat_of_arms", "emblem", "diagram", "locator"]

MAX_DISTANCE_KM = 2.0


def file_name(url: str) -> str:
    """Last path component, decoded and lowercased, e.g. "chrysler_building_1.jpg"."""
    without_query = url.split("?", 1)[0]  # Wikipedia adds ?utm_source=... tracking params
    return unquote(without_query.rsplit("/", 1)[-1]).lower()


def categorize(landmark: Landmark, result: PhotoResult) -> tuple[str, float | None]:
    """Return (category, distance in km between article and landmark if known)."""
    distance = None
    if result.article_lat is not None and result.article_lon is not None:
        distance = distance_km(landmark.latitude, landmark.longitude, result.article_lat, result.article_lon)

    if result.title_tried is None:
        return "no_article", distance
    if result.page_type == "disambiguation":
        return "disambiguation", distance
    if result.photo_url is None:
        return "no_photo", distance
    if any(part in file_name(result.photo_url) for part in SUSPICIOUS_FILENAME_PARTS):
        return "logo_like", distance
    if distance is not None and distance > MAX_DISTANCE_KM:
        return "far_away", distance
    return "ok", distance


def write_markdown(path: Path, rows: list[dict[str, object]], counts: Counter[str], label: str) -> None:
    lines = [f"# Landmark photo audit ({label})", "", f"{len(rows)} landmarks checked.", ""]
    lines += ["| Category | Count |", "| --- | ---: |"]
    lines += [f"| {category} | {counts[category]} |" for category in CATEGORIES]
    for category in CATEGORIES:
        if category == "ok" or counts[category] == 0:
            continue
        lines += ["", f"## {category} ({counts[category]})", ""]
        for row in rows:
            if row["category"] != category:
                continue
            detail = f"article: {row['article_title']}" if row["article_title"] else "no article"
            if row["distance_km"] is not None:
                detail += f", {row['distance_km']:.1f} km away"
            if row["photo_url"]:
                detail += f", photo: `{file_name(str(row['photo_url']))}`"
            lines.append(f"- **{row['city']}** / {row['name']} ({detail})")
    path.write_text("\n".join(lines) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--label", default="", help="suffix for the report files, e.g. before / after")
    args = parser.parse_args()

    client = WikiClient()
    overrides = swift_title_overrides()
    logo_patterns = swift_logo_patterns()
    print(f"{len(overrides)} title overrides, app logo patterns: {logo_patterns}")

    rows: list[dict[str, object]] = []
    counts: Counter[str] = Counter()
    landmarks = load_landmarks()
    for index, landmark in enumerate(landmarks, start=1):
        result = app_photo(client, landmark.name, overrides.get(landmark.id), logo_patterns)
        category, distance = categorize(landmark, result)
        counts[category] += 1
        rows.append(
            {
                "city": landmark.city,
                "id": landmark.id,
                "name": landmark.name,
                "category": category,
                "title_tried": result.title_tried,
                "article_title": result.article_title,
                "photo_url": result.photo_url,
                "distance_km": round(distance, 2) if distance is not None else None,
            }
        )
        if index % 100 == 0:
            print(f"  {index}/{len(landmarks)} checked")
    client.save()

    REPORTS_DIR.mkdir(exist_ok=True)
    suffix = f"-{args.label}" if args.label else ""
    (REPORTS_DIR / f"audit{suffix}.json").write_text(json.dumps(rows, indent=2, ensure_ascii=False))
    write_markdown(REPORTS_DIR / f"audit{suffix}.md", rows, counts, args.label or "latest")

    print("")
    for category in CATEGORIES:
        print(f"{category:>15}: {counts[category]}")


if __name__ == "__main__":
    main()
