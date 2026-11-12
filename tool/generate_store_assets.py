"""Generates the Google Play store graphics for CycleScope.

Outputs (folder store/, ignored by git):
  - store/graphics/icon_512.png                 app icon, 512 x 512
  - store/graphics/feature_graphic_<lang>.png   feature graphic, 1024 x 500, no alpha
  - store/screenshots/<lang>/phone_NN_*.png     phone screenshots, 1080 x 1920 (9:16)

The phone screenshots wrap the app screenshots from screenshots/<lang>/
(rendered by tests/screenshots) in a branded frame with a caption. The raw
app screenshots are 1078 x 2398, which Google Play rejects (the long side may
be at most twice the short side), so they cannot be uploaded directly.

Run from the repository root:  python tool/generate_store_assets.py
Requires Pillow. Regenerate after updating the app screenshots.
"""

import glob
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "store")
ICON = os.path.join(ROOT, "assets", "branding", "app_icon_512.png")

BG_TOP = (18, 127, 159)  # #127F9F, same as the app icon
BG_BOTTOM = (7, 70, 92)  # #07465C
WHITE = (255, 255, 255)
SUBTLE = (205, 235, 244)

SHOT_W, SHOT_H = 1080, 1920
FEATURE_W, FEATURE_H = 1024, 500

CAPTIONS = {
    "en": {
        "01_study_list": "All your time studies\nin one place",
        "02_new_study": "Define work steps\nin seconds",
        "03_recording_live": "Measure blind with\nthe volume keys",
        "04_cycles": "Review and correct\nevery cycle",
        "05_analysis": "Step times and the\nreal cycle time",
        "06_video_study": "Mark steps in a video,\nframe by frame",
        "07_settings": "HM, seconds or TMU,\nyour way",
    },
    "de": {
        "01_study_list": "Alle Zeitaufnahmen\nan einem Ort",
        "02_new_study": "Arbeitsschritte\nin Sekunden anlegen",
        "03_recording_live": "Blind messen mit\nden Lautstärketasten",
        "04_cycles": "Jeden Zyklus prüfen\nund korrigieren",
        "05_analysis": "Schrittzeiten und\nreale Taktzeit",
        "06_video_study": "Schritte im Video\nBild für Bild markieren",
        "07_settings": "HM, Sekunden oder TMU,\nwie du willst",
    },
}

FEATURE_TEXT = {
    "en": ("CycleScope", "Time study stopwatch\nfor REFA & MTM"),
    "de": ("CycleScope", "Zeitaufnahme-Stoppuhr\nfür REFA & MTM"),
}


def font(bold, size):
    candidates = (
        ["segoeuib.ttf", "seguisb.ttf", "DejaVuSans-Bold.ttf", "Arial Bold.ttf"]
        if bold
        else ["segoeui.ttf", "DejaVuSans.ttf", "Arial.ttf"]
    )
    for name in candidates:
        for folder in ("C:/Windows/Fonts", "/usr/share/fonts/truetype/dejavu", ""):
            try:
                return ImageFont.truetype(os.path.join(folder, name), size)
            except OSError:
                continue
    return ImageFont.load_default(size)


def gradient(width, height):
    image = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(1, height - 1)
        colour = tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM))
        draw.line([(0, y), (width, y)], fill=colour)
    return image


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, image.width - 1, image.height - 1], radius, fill=255
    )
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def paste_with_shadow(canvas, image, x, y, radius):
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 6, y + 18, x + image.width + 6, y + image.height + 18],
        radius,
        fill=(0, 0, 0, 110),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(image, (x, y))


def phone_screenshot(source, caption):
    canvas = gradient(SHOT_W, SHOT_H).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    title = font(True, 76)
    draw.multiline_text(
        (SHOT_W / 2, 180),
        caption,
        font=title,
        fill=WHITE,
        anchor="mm",
        align="center",
        spacing=14,
    )

    shot = Image.open(source).convert("RGB")
    target_h = 1560
    target_w = round(shot.width * target_h / shot.height)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)

    bezel = 14
    frame = Image.new("RGB", (target_w + 2 * bezel, target_h + 2 * bezel), (18, 18, 20))
    frame = rounded(frame, 58)
    frame.alpha_composite(rounded(shot, 46), (bezel, bezel))

    x = (SHOT_W - frame.width) // 2
    y = SHOT_H - frame.height - 40
    paste_with_shadow(canvas, frame, x, y, 58)
    return canvas.convert("RGB")


def feature_graphic(lang):
    name, tagline = FEATURE_TEXT[lang]
    canvas = gradient(FEATURE_W, FEATURE_H).convert("RGBA")

    icon = Image.open(ICON).convert("RGBA").resize((300, 300), Image.LANCZOS)
    icon = rounded(icon, 66)
    paste_with_shadow(canvas, icon, 90, (FEATURE_H - 300) // 2, 66)

    draw = ImageDraw.Draw(canvas)
    draw.text((440, 175), name, font=font(True, 86), fill=WHITE, anchor="lm")
    draw.multiline_text(
        (442, 300),
        tagline,
        font=font(False, 44),
        fill=SUBTLE,
        anchor="lm",
        spacing=10,
    )
    return canvas.convert("RGB")


def main():
    graphics = os.path.join(STORE, "graphics")
    os.makedirs(graphics, exist_ok=True)
    Image.open(ICON).convert("RGBA").resize((512, 512), Image.LANCZOS).save(
        os.path.join(graphics, "icon_512.png")
    )

    for lang, captions in CAPTIONS.items():
        feature_graphic(lang).save(os.path.join(graphics, f"feature_graphic_{lang}.png"))

        out_dir = os.path.join(STORE, "screenshots", lang)
        os.makedirs(out_dir, exist_ok=True)
        for old in glob.glob(os.path.join(out_dir, "*.png")):
            os.remove(old)
        for source in sorted(glob.glob(os.path.join(ROOT, "screenshots", lang, "*.png"))):
            key = os.path.splitext(os.path.basename(source))[0]
            caption = captions.get(key)
            if caption is None:
                print(f"skipped (no caption): {source}")
                continue
            phone_screenshot(source, caption).save(
                os.path.join(out_dir, f"phone_{key}.png")
            )
    print(f"Store graphics written to {STORE}")


if __name__ == "__main__":
    main()
