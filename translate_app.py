#!/usr/bin/env python3
"""
translate_app.py — batch-translate Stamped! A City Passport

Translates:
  1. en.lproj/Localizable.strings  →  {lang}.lproj/Localizable.strings
  2. en.lproj/CityDetails.json     →  {lang}.lproj/CityDetails.json
     (falls back to Resources/CityDetails.json if not moved yet)

Setup:
    python3 -m venv .venv
    source .venv/bin/activate
    pip install deep-translator

Run:
    python3 translate_app.py
"""

import json
import re
import time
from pathlib import Path
from deep_translator import GoogleTranslator

# ── Configuration ──────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).parent / "Stamped! A City Passport"

# lproj folder name → Google Translate language code
LANGUAGES: dict[str, str] = {
    "de":      "de",    # German
    "es":      "es",    # Spanish
    "fr":      "fr",    # French
    "it":      "it",    # Italian
    "ja":      "ja",    # Japanese
    "ko":      "ko",    # Korean
    "pt":      "pt",    # Portuguese
    "zh-Hans": "zh-CN", # Simplified Chinese
}

# CityDetails.json fields that are human-readable text (translate these)
# airportCode, airportName, currencyCode are codes/proper nouns — leave them alone
TRANSLATABLE_CITY_FIELDS = {
    "nickname",
    "funFact",
    "language",
    "airportInfo",
    "languageInfo",
    "currencyInfo",
    "transportation",
    "transportationFact",
}

# ── Helpers ────────────────────────────────────────────────────────────────────

def translate_text(text: str, target_lang: str) -> str:
    """Translate a single string. Retries once on failure, falls back to English."""
    if not text.strip():
        return text
    try:
        time.sleep(0.1)  # stay under Google's rate limit
        return GoogleTranslator(source="en", target=target_lang).translate(text)
    except Exception as error:
        print(f"    ⚠ Error ({error}), retrying...")
        time.sleep(2)
        try:
            return GoogleTranslator(source="en", target=target_lang).translate(text)
        except Exception:
            return text  # keep English rather than crash


def parse_strings_file(path: Path) -> list[tuple[str, str, str]]:
    """
    Return (raw_line, key, value) for each line.
    Comment and blank lines come back as (raw_line, "", "").
    """
    pattern = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
    entries: list[tuple[str, str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            entries.append((line, match.group(1), match.group(2)))
        else:
            entries.append((line, "", ""))
    return entries


def write_strings_file(path: Path, entries: list[tuple[str, str, str]]) -> None:
    lines: list[str] = []
    for raw, key, value in entries:
        if key:
            escaped_value = value.replace("\\", "\\\\").replace('"', '\\"')
            lines.append(f'"{key}" = "{escaped_value}";')
        else:
            lines.append(raw)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ── Translation tasks ──────────────────────────────────────────────────────────

def translate_strings(lproj_lang: str, google_lang: str) -> None:
    src = PROJECT_ROOT / "en.lproj" / "Localizable.strings"
    dst = PROJECT_ROOT / f"{lproj_lang}.lproj" / "Localizable.strings"
    dst.parent.mkdir(exist_ok=True)

    entries = parse_strings_file(src)
    translatable = [(i, key, value) for i, (_, key, value) in enumerate(entries) if key]
    print(f"  Translating {len(translatable)} UI strings...")

    result = list(entries)
    for count, (i, key, value) in enumerate(translatable, 1):
        translated_value = translate_text(value, google_lang)
        result[i] = (result[i][0], key, translated_value)
        if count % 25 == 0:
            print(f"    {count}/{len(translatable)} strings done")

    write_strings_file(dst, result)
    print(f"  ✓ Localizable.strings → {dst.relative_to(PROJECT_ROOT.parent)}")


def translate_city_details(lproj_lang: str, google_lang: str) -> None:
    # Accept the file from either location
    src = PROJECT_ROOT / "en.lproj" / "CityDetails.json"
    if not src.exists():
        src = PROJECT_ROOT / "Resources" / "CityDetails.json"
    if not src.exists():
        print("  ⚠ CityDetails.json not found — skipping")
        return

    dst = PROJECT_ROOT / f"{lproj_lang}.lproj" / "CityDetails.json"
    dst.parent.mkdir(exist_ok=True)

    city_data: dict[str, dict[str, str]] = json.loads(src.read_text(encoding="utf-8"))
    print(f"  Translating {len(city_data)} cities...")

    result: dict[str, dict[str, str]] = {}
    for count, (city_name, fields) in enumerate(city_data.items(), 1):
        translated_fields: dict[str, str] = {}
        for field, value in fields.items():
            if field in TRANSLATABLE_CITY_FIELDS and isinstance(value, str) and value:
                translated_fields[field] = translate_text(value, google_lang)
            else:
                translated_fields[field] = value  # codes stay unchanged
        result[city_name] = translated_fields
        if count % 15 == 0:
            print(f"    {count}/{len(city_data)} cities done")

    dst.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  ✓ CityDetails.json → {dst.relative_to(PROJECT_ROOT.parent)}")


# ── Entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    print("Stamped! Translation Script")
    print("=" * 44)
    print(f"Languages: {', '.join(LANGUAGES)}\n")

    for lproj_lang, google_lang in LANGUAGES.items():
        print(f"[{lproj_lang}]")
        translate_strings(lproj_lang, google_lang)
        translate_city_details(lproj_lang, google_lang)
        print()

    print("All done. Review each file before submitting to the App Store.")
    print("Machine translation is a first draft — have a native speaker check it.")


if __name__ == "__main__":
    main()
