"""Check the 2.10 App Store text against Apple's limits, for iPhone/iPad, Mac and Vision Pro.

Run from the repo root:
    python3 docs/app-store/localization/2.10/check_limits.py

It prints one table per platform with the length of every field and exits with 1 if anything
is over a limit. Keywords are counted in bytes (UTF-8), because a Japanese, Korean or Chinese
character takes 3 bytes, and they must not have a space right after a comma. No internet needed.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

LOCALIZATION_ROOT = Path(__file__).resolve().parent.parent
FOLDERS = {"iPhone/iPad": "2.10", "Mac": "2.10-macos", "Vision Pro": "2.10-visionos"}
LOCALES = ["en-US", "de-DE", "es-ES", "es-MX", "fr-FR", "it", "ja", "ko", "pt-BR", "zh-Hans"]

# Field -> limit. Keywords are bytes, everything else characters.
LIMITS = {"subtitle": 30, "promotional_text": 170, "keywords": 100, "whats_new": 4000, "description": 4000}
APP_NAME = "Stamped! A City Passport"   # 30-character limit, same in every language
NAME_LIMIT = 30


def measure(field: str, text: str) -> int:
    # Apple's keyword limit is 100 bytes; the other fields are counted in characters
    return len(text.encode("utf-8")) if field == "keywords" else len(text)


def keyword_problems(keywords: str) -> list[str]:
    problems = []
    if ", " in keywords:
        problems.append("keywords have a space after a comma")
    terms = keywords.split(",")
    if any(not term.strip() for term in terms):
        problems.append("keywords have an empty term")
    lowered = [term.lower() for term in terms]
    if len(set(lowered)) != len(lowered):
        problems.append("keywords repeat a term")
    return problems


def main() -> int:
    all_problems: list[str] = []
    if len(APP_NAME) > NAME_LIMIT:
        all_problems.append(f"app name is {len(APP_NAME)} characters")
    print(f"App name: {APP_NAME!r} = {len(APP_NAME)}/{NAME_LIMIT}\n")

    for platform, folder in FOLDERS.items():
        print(f"## {platform}  ({folder}/)")
        # The subtitle lives on App Information, shared by every platform, so only the iOS files carry it
        fields = [field for field in LIMITS if platform == "iPhone/iPad" or field != "subtitle"]
        print("| locale | " + " | ".join(f"{field} (/{LIMITS[field]})" for field in fields) + " | OK |")
        print("|---" * (len(fields) + 2) + "|")
        for locale in LOCALES:
            path = LOCALIZATION_ROOT / folder / f"{locale}.json"
            if not path.is_file():
                all_problems.append(f"{folder}/{locale}.json is missing")
                continue
            contents = json.loads(path.read_text(encoding="utf-8"))
            row_problems = []
            if contents.get("locale") != locale:
                row_problems.append("locale field doesn't match the file name")
            cells = []
            for field in fields:
                text = contents.get(field)
                if not text:
                    row_problems.append(f"{field} is missing")
                    cells.append("–")
                    continue
                size = measure(field, text)
                if size > LIMITS[field]:
                    row_problems.append(f"{field} is {size} (limit {LIMITS[field]})")
                cells.append(str(size))
            row_problems += keyword_problems(contents.get("keywords", ""))
            print(f"| {locale} | " + " | ".join(cells) + f" | {'✓' if not row_problems else '✗'} |")
            all_problems += [f"{folder}/{locale}: {problem}" for problem in row_problems]
        print()

    if all_problems:
        print("Problems:")
        for problem in all_problems:
            print(f"  ✗ {problem}")
        return 1
    print("Every field in every language is within Apple's limits.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
