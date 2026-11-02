"""Compose an App Store screenshot: orange background, headline, device frame bleeding off the bottom.

Usage: python3 compose.py iphone|ipad|ipad-full source.png VERB "DESCRIPTOR LINE 1|LINE 2" out.png [locale]

The optional locale (e.g. ja, ko, zh-Hans) picks a font with those letters; Latin languages use
SF Pro Display Black. A headline too wide or too tall for the page is shrunk until it fits;
one that already fits is drawn exactly as before. 2.8/render_locales.py calls compose() for
every language.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ORANGE = (0xF2, 0x74, 0x3F)
WHITE = (255, 255, 255)
BEZEL = (18, 18, 20)
FONT = "/Library/Fonts/SF-Pro-Display-Black.otf"

# The heaviest macOS font that has each script's letters: (file, face index in the collection)
CJK_FONTS = {
    "ja": ("/System/Library/Fonts/ヒラギノ角ゴシック W9.ttc", 0),
    "ko": ("/System/Library/Fonts/AppleSDGothicNeo.ttc", 16),        # Heavy
    "zh-Hans": ("/System/Library/Fonts/Hiragino Sans GB.ttc", 2),    # W6
}

LAYOUTS = {
    # canvas, verb size, descriptor size, verb top, frame outer width, frame top, bezel, outer corner radius
    "iphone": dict(canvas=(1320, 2868), verb=250, desc=96, verb_top=200, frame_w=1060, frame_top=760, bezel=24, radius=170),
    "ipad": dict(canvas=(2064, 2752), verb=300, desc=118, verb_top=200, frame_w=1640, frame_top=840, bezel=30, radius=80),
    # 2.8: the whole iPad fits on the page, so the bottom of the screen (Apple Maps
    # attribution, buttons) isn't cut off. Screen 1404 x 1872, 60 px margin below.
    "ipad-full": dict(canvas=(2064, 2752), verb=280, desc=110, verb_top=170, frame_w=1464, frame_top=760, bezel=30, radius=80),
}


def font_for(locale, size):
    """SF Pro Display Black, or a CJK font for Japanese, Korean and Chinese."""
    path, index = CJK_FONTS.get(locale or "", (FONT, 0))
    return ImageFont.truetype(path, size, index=index)


def centered_text(draw, text, font, y, width):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    draw.text(((width - (right - left)) / 2 - left, y - top), text, font=font, fill=WHITE)
    return y + (bottom - top)


def text_width(draw, text, font):
    left, _, right, _ = draw.textbbox((0, 0), text, font=font)
    return right - left


def fitted_size(draw, texts, size, max_width, locale):
    """The design size, or smaller (2% at a time) until the widest text fits max_width."""
    scale = 1.0
    while scale > 0.4 and max(text_width(draw, text, font_for(locale, round(size * scale))) for text in texts) > max_width:
        scale -= 0.02
    return round(size * scale)


def headline_height(draw, verb, lines, verb_font, desc_font, desc_px, gap_before, gap_between):
    """Total height of the headline, laid out like draw_headline."""
    height = 0
    for index, (text, font) in enumerate([(verb, verb_font)] + [(line, desc_font) for line in lines]):
        _, top, _, bottom = draw.textbbox((0, 0), text, font=font)
        gap = 0 if index == 0 else int(desc_px * (gap_before if index == 1 else gap_between))
        height += gap + (bottom - top)
    return height


def draw_headline(canvas, verb, lines, verb_size, desc_size, verb_top, max_width, max_bottom,
                  locale=None, gap_before=0.45, gap_between=0.22):
    """Big verb, then descriptor lines, centred. A verb or descriptor wider than max_width is
    shrunk on its own; if the whole headline would then run below max_bottom, both shrink
    together. A headline that already fits is drawn at the design size, unchanged.
    Returns the smallest scale used (1.0 = the design size)."""
    draw = ImageDraw.Draw(canvas)
    verb_px = fitted_size(draw, [verb], verb_size, max_width, locale)
    desc_px = fitted_size(draw, lines, desc_size, max_width, locale) if lines else desc_size
    while True:
        verb_font, desc_font = font_for(locale, verb_px), font_for(locale, desc_px)
        if verb_top + headline_height(draw, verb, lines, verb_font, desc_font, desc_px, gap_before, gap_between) <= max_bottom \
                or desc_px < desc_size * 0.4:
            break
        verb_px, desc_px = round(verb_px * 0.98), round(desc_px * 0.98)
    y = centered_text(draw, verb, verb_font, verb_top, canvas.width)
    y += int(desc_px * gap_before)
    for line in lines:
        y = centered_text(draw, line, desc_font, y, canvas.width) + int(desc_px * gap_between)
    return min(verb_px / verb_size, desc_px / desc_size)


def compose(kind, source, verb, lines, out, locale=None):
    layout = LAYOUTS[kind]
    width, height = layout["canvas"]
    canvas = Image.new("RGB", (width, height), ORANGE)

    # Headline: big verb, then one or two descriptor lines; at least 60 px of side margin
    # and 40 px of space above the device
    scale = draw_headline(canvas, verb, lines, layout["verb"], layout["desc"], layout["verb_top"],
                          max_width=width - 120, max_bottom=layout["frame_top"] - 40, locale=locale)

    # Screen scaled to fit inside the bezel
    shot = Image.open(source).convert("RGB")
    bezel = layout["bezel"]
    screen_w = layout["frame_w"] - 2 * bezel
    screen_h = round(shot.height * screen_w / shot.width)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)
    frame_h = screen_h + 2 * bezel
    frame_x = (width - layout["frame_w"]) // 2
    frame_y = layout["frame_top"]
    radius = layout["radius"]

    # Soft shadow behind the device
    shadow = Image.new("L", (width, height), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (frame_x, frame_y + 30, frame_x + layout["frame_w"], frame_y + frame_h + 30), radius, fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))
    canvas.paste(Image.new("RGB", (width, height), (90, 35, 15)), (0, 0), shadow)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((frame_x, frame_y, frame_x + layout["frame_w"], frame_y + frame_h), radius, fill=BEZEL)
    mask = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, screen_w, screen_h), radius - bezel, fill=255)
    canvas.paste(shot, (frame_x + bezel, frame_y + bezel), mask)

    canvas.save(out, "PNG")
    return scale


def main():
    kind, source, verb, descriptor, out = sys.argv[1:6]
    locale = sys.argv[6] if len(sys.argv) > 6 else None
    compose(kind, source, verb, descriptor.split("|"), out, locale)


if __name__ == "__main__":
    main()
