"""Renders every 2.8 App Store screenshot set in every App Store language.

Run from the screenshots/ folder:  python3 2.8/render_locales.py [locale ...]

Reads the headline text from 2.8/headlines.json ({locale: {set: [{verb, lines}, ...]}}) and writes
  2.8/<set>/<locale>/01.png, 02.png, ...   (set = iphone, ipad, mac, vision)
  2.8/contact-sheets/<locale>.jpg          (every set of one language, for a quick check)
The app's screens are the English raw captures; only the headline changes per language.
Folder-per-locale is what tools/appstore-metadata/upload_metadata.py --screenshots expects.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from compose import compose, font_for  # noqa: E402  (screenshots/ is added to the path above)
from compose_wide import compose_wide  # noqa: E402

HERE = "2.8"
WINDOW_CROP = (640, 440, 3200, 1880)   # the Vision Pro app window, without most of the room

# What goes under each headline, in order. Portrait sets: (layout, raw screen).
# Mac: the main window, then the extra windows laid over it. Vision: (scene, crop or None).
SETS = {
    "iphone": [("iphone", f"{HERE}/raw/{name}.png") for name in [
        "01-college-list", "02-traditions", "03-school-stamps",
        "04-fly-3d-stanford", "05-campus-plan-facts-events", "06-quiz-photo"]],
    "ipad": [("ipad-full", f"{HERE}/raw-ipad/{name}.png") for name in [
        "01-sidebar-campus-page", "02-world-map", "03-passport-countries",
        "04-landmark-listen", "05-stays-near-here", "06-trip-planner"]],
    "mac": [[f"{HERE}/raw-mac/{name}.png" for name in windows] for windows in [
        ["01-main-chicago-3d"],
        ["01-main-chicago-3d", "win-world-map"],
        ["01-main-chicago-3d", "win-trips"],
        ["01-main-chicago-3d", "win-my-journey", "win-achievements"],
        ["01-main-chicago-3d", "win-quiz"]]],
    "vision": [
        (f"{HERE}/raw-vision/01-colosseum-card.png", WINDOW_CROP),
        (f"{HERE}/raw-vision/02-panorama-360.png", None),
        (f"{HERE}/raw-vision/03-city-tour.png", WINDOW_CROP),
        (f"{HERE}/raw-vision/04-city-list.png", WINDOW_CROP)],
}


def missing_letters(text, locale):
    """Letters the locale's font has no glyph for (they would draw as empty boxes)."""
    font = font_for(locale, 60)

    def drawn(letter):
        image = Image.new("L", (120, 120), 0)
        ImageDraw.Draw(image).text((20, 10), letter, font=font, fill=255)
        return image.tobytes()

    notdef = drawn("\U0010FFFD")
    return [letter for letter in set(text) if not letter.isspace() and drawn(letter) == notdef]


def render(locale, headlines):
    shrunk, problems = [], []
    for set_name, sources in SETS.items():
        entries = headlines[set_name]
        if len(entries) != len(sources):
            problems.append(f"{set_name}: {len(entries)} headlines for {len(sources)} images")
            continue
        folder = f"{HERE}/{set_name}/{locale}"
        os.makedirs(folder, exist_ok=True)
        for number, (entry, source) in enumerate(zip(entries, sources), start=1):
            out = f"{folder}/{number:02d}.png"
            verb, lines = entry["verb"], entry["lines"]
            missing = missing_letters(verb + "".join(lines), locale)
            if missing:
                problems.append(f"{out}: font has no glyph for {''.join(sorted(missing))}")
            if set_name in ("iphone", "ipad"):
                layout, raw = source
                scale = compose(layout, raw, verb, lines, out, locale)
            elif set_name == "mac":
                scale = compose_wide("mac", verb, lines, out, source, locale=locale)
            else:
                raw, crop = source
                scale = compose_wide("vision", verb, lines, out, [raw], crop, locale=locale)
            if scale < 1:
                shrunk.append(f"{out} (text at {scale:.0%})")
    return shrunk, problems


def contact_sheet(locale):
    """One image per language: a row per set, with the language code on top."""
    rows = []
    for set_name in SETS:
        folder = f"{HERE}/{set_name}/{locale}"
        files = sorted(name for name in os.listdir(folder) if name.endswith(".png"))
        thumbs = []
        for name in files:
            image = Image.open(f"{folder}/{name}").convert("RGB")
            thumbs.append(image.resize((round(image.width * 520 / image.height), 520), Image.LANCZOS))
        row = Image.new("RGB", (sum(thumb.width for thumb in thumbs) + 20 * len(thumbs), 540), "white")
        x = 10
        for thumb in thumbs:
            row.paste(thumb, (x, 10))
            x += thumb.width + 20
        rows.append(row)
    sheet = Image.new("RGB", (max(row.width for row in rows), 80 + sum(row.height for row in rows)), "white")
    ImageDraw.Draw(sheet).text((20, 15), locale, fill="black",
                               font=ImageFont.truetype("/Library/Fonts/SF-Pro-Display-Black.otf", 50))
    y = 80
    for row in rows:
        sheet.paste(row, (0, y))
        y += row.height
    os.makedirs(f"{HERE}/contact-sheets", exist_ok=True)
    sheet.save(f"{HERE}/contact-sheets/{locale}.jpg", quality=82)


def main():
    with open(f"{HERE}/headlines.json", encoding="utf-8") as file:
        all_headlines = json.load(file)
    locales = sys.argv[1:] or list(all_headlines)
    for locale in locales:
        shrunk, problems = render(locale, all_headlines[locale])
        contact_sheet(locale)
        print(f"{locale}: done" + (f"; shrunk to fit: {', '.join(shrunk)}" if shrunk else ""))
        for problem in problems:
            print(f"  PROBLEM {problem}")


if __name__ == "__main__":
    main()
