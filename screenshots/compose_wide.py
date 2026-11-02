"""Compose a landscape App Store screenshot (Mac or Apple Vision Pro) in the same look as compose.py:
orange background, big white verb, one descriptor line, the app below it (all of it on the page).
compose_wide() is also called by 2.8/render_locales.py for every language.

Usage:
  python3 compose_wide.py mac  VERB "DESCRIPTOR" out.png main_window.png [extra_window.png ...]
  python3 compose_wide.py vision VERB "DESCRIPTOR" out.png scene.png [crop=x0,y0,x1,y1]

Mac: the whole main window sits centred under the headline (nothing cut off); each extra window (a World Map, trip or
quiz window) is laid over it, lower and to the right, the way it opens on a real Mac.
Vision: the simulator's scene (minus its top 300 px) is shown as one rounded picture.
Window captures are `screencapture -l <id> -o` PNGs, whose transparent corners are kept.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

from compose import ORANGE, draw_headline  # same colour, fonts and headline fitting as the iPhone/iPad sets

SHADOW = (90, 35, 15)

LAYOUTS = {
    # canvas, verb size, descriptor size, verb top, main picture width, picture top
    "mac": dict(canvas=(2880, 1800), verb=190, desc=92, verb_top=90, main_w=2040, main_top=470),
    "vision": dict(canvas=(3840, 2160), verb=230, desc=110, verb_top=110, main_w=3100, main_top=590),
}


def rounded(image, radius):
    """The picture with rounded corners (alpha), keeping any transparency it already has."""
    image = image.convert("RGBA")
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width, image.height), radius, fill=255)
    alpha = Image.composite(image.getchannel("A"), mask, mask)
    image.putalpha(alpha)
    return image


def paste_with_shadow(canvas, picture, x, y, blur=40, offset=28, strength=120):
    """Soft shadow under the picture's own shape, then the picture."""
    shadow_mask = Image.new("L", canvas.size, 0)
    shadow_mask.paste(picture.getchannel("A").point(lambda a: strength if a > 0 else 0), (x, y + offset))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", canvas.size, SHADOW), (0, 0), shadow_mask)
    canvas.paste(picture, (x, y), picture)


def compose_wide(kind, verb, lines, out, pictures, crop=None, locale=None):
    layout = LAYOUTS[kind]
    width, height = layout["canvas"]
    canvas = Image.new("RGB", (width, height), ORANGE)

    # Headline: big verb, then the descriptor (normally one line), shrunk only if it
    # wouldn't fit between 100 px side margins and above the app
    headline_scale = draw_headline(canvas, verb, lines, layout["verb"], layout["desc"], layout["verb_top"],
                                   max_width=width - 200, max_bottom=layout["main_top"] - 40,
                                   locale=locale, gap_before=0.4)

    # Main window (or Vision scene), scaled to the layout width (or less, so it fits the height)
    main = Image.open(pictures[0]).convert("RGBA")
    if kind == "vision":
        # Drop the top of the scene (ceiling or sky) so the whole picture, down to the
        # panorama's credit card at the bottom, fits under the headline
        main = main.crop(crop or (0, 300, main.width, main.height))
    scale = min(layout["main_w"] / main.width, (height - layout["main_top"] - 50) / main.height)
    main = main.resize((round(main.width * scale), round(main.height * scale)), Image.LANCZOS)
    if kind == "vision":
        main = rounded(main, 60)
    main_x = (width - main.width) // 2
    main_y = layout["main_top"]
    paste_with_shadow(canvas, main, main_x, main_y)

    # Extra Mac windows, at the same scale as the main one, stepped down and to the right
    for index, path in enumerate(pictures[1:]):
        window = Image.open(path).convert("RGBA")
        window = window.resize((round(window.width * scale), round(window.height * scale)), Image.LANCZOS)
        right_edge = main_x + main.width + 220 - index * 160
        x = min(right_edge - window.width, width - window.width - 40)
        # Whole window on the page, so its Apple Maps attribution is never cut off
        y = min(main_y + 200 + index * 100, height - window.height - 30)
        paste_with_shadow(canvas, window, x, y, blur=50, offset=34, strength=150)

    canvas.save(out, "PNG")
    return headline_scale


def main():
    kind, verb, descriptor, out = sys.argv[1:5]
    # An optional "crop=x0,y0,x1,y1" (Vision only) zooms in on part of the scene, e.g. the app window
    crop = None
    pictures = []
    for argument in sys.argv[5:]:
        if argument.startswith("crop="):
            crop = tuple(int(value) for value in argument[5:].split(","))
        else:
            pictures.append(argument)
    compose_wide(kind, verb, descriptor.split("|"), out, pictures, crop)


if __name__ == "__main__":
    main()
