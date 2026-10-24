"""Turn the latest audit into a to-do list for fixing photos by hand.

Usage (from tools/photo-audit, after audit.py --label after):
    .venv/bin/python manual_review.py
Writes reports/manual-review.md.
"""

import json
from typing import Any

from audit import REPORTS_DIR
from find_titles import APPLE_RETAIL_MARKERS


def is_apple_store(name: str) -> bool:
    return any(marker in name for marker in APPLE_RETAIL_MARKERS)


def main() -> None:
    before: list[dict[str, Any]] = json.loads((REPORTS_DIR / "audit-before.json").read_text())
    after: list[dict[str, Any]] = json.loads((REPORTS_DIR / "audit-after.json").read_text())
    flagged = [row for row in after if row["category"] != "ok"]

    no_photo = [r for r in flagged if r["category"] in ("no_article", "disambiguation", "no_photo", "skipped") and not is_apple_store(r["name"])]
    apple = [r for r in flagged if is_apple_store(r["name"])]
    far_away = sorted((r for r in flagged if r["category"] == "far_away" and not is_apple_store(r["name"])), key=lambda r: -r["distance_km"])
    logo_like = [r for r in flagged if r["category"] == "logo_like"]

    def ok_count(rows: list[dict[str, Any]]) -> int:
        return sum(row["category"] == "ok" for row in rows)

    lines = [
        "# Landmark photos: manual review",
        "",
        f"OK photos: {ok_count(before)} before, {ok_count(after)} after (of {len(after)} landmarks).",
        "",
        f"## 1. No usable photo ({len(no_photo)})",
        "",
        "No Wikipedia article (or only a \"may refer to\" page) could be matched safely. Options: find the",
        "article by hand and add it to `titleOverrides`, or add a photo to the asset catalog.",
        "",
    ]
    for row in no_photo:
        found = f" (lands on: {row['article_title']})" if row["article_title"] else ""
        lines.append(f"- [ ] **{row['city']}** / {row['name']} `{row['id']}` - {row['category']}{found}")

    lines += ["", f"## 2. Apple Stores ({len(apple)})", "",
              "Individual stores have no Wikipedia articles. These need an asset-catalog photo, or an",
              "override pointing at the mall or street the store is on, if that's acceptable.", ""]
    lines += [f"- [ ] **{row['city']}** / {row['name']} `{row['id']}` - {row['category']}" for row in apple]

    lines += ["", f"## 3. Article is far from the registry coordinates ({len(far_away)})", "",
              "Most of these are the right article and the *registry* coordinates are wrong (which also",
              "misplaces the map pin). Check the lat/lon in BuildingRegistry.json first.", ""]
    lines += [f"- [ ] {row['distance_km']:.1f} km - **{row['city']}** / {row['name']} `{row['id']}` -> {row['article_title']}" for row in far_away]

    lines += ["", f"## 4. Flagged as logo-like, but fine ({len(logo_like)})", "",
              "Real photos whose file name happens to mention a flag. No action needed.", ""]
    lines += [f"- **{row['city']}** / {row['name']}" for row in logo_like]

    (REPORTS_DIR / "manual-review.md").write_text("\n".join(lines) + "\n")
    print(f"no photo: {len(no_photo)}, apple: {len(apple)}, far away: {len(far_away)}, logo-like: {len(logo_like)}")


if __name__ == "__main__":
    main()
