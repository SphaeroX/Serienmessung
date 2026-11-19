"""Generates the store graphics for CycleScope (Google Play and App Store).

Input: the raw app screenshots in store/raw/<device>/<lang>/, rendered by
  flutter test tests/screenshots/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true
(device = phone or tablet), and the icons in assets/branding/.

Outputs (folder store/, ignored by git):
  store/googleplay/icon_512.png                       512 x 512, 32-bit PNG
  store/googleplay/<lang>/feature_graphic.png         1024 x 500, no alpha
  store/googleplay/<lang>/phone/NN_*.png              1080 x 1920 (9:16)
  store/googleplay/<lang>/tablet/NN_*.png             2064 x 2752 (7" and 10")
  store/appstore/icon_1024.png                        1024 x 1024, no alpha
  store/appstore/<lang>/iphone_6.9/NN_*.png           1320 x 2868
  store/appstore/<lang>/iphone_6.5/NN_*.png           1284 x 2778
  store/appstore/<lang>/ipad_13/NN_*.png              2064 x 2752

Every screenshot puts the app screen into a device frame under a caption.
The screenshots and graphics are saved as RGB PNG (no transparency).
The App Store captions do not mention the volume keys: on iOS the hardware
keys are not used for measuring.

Run from the repository root:  python tool/generate_store_assets.py
Requires Pillow.
"""

import glob
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "store")
RAW = os.path.join(STORE, "raw")
ICON_512 = os.path.join(ROOT, "assets", "branding", "app_icon_512.png")
ICON_1024 = os.path.join(ROOT, "assets", "branding", "app_icon_1024.png")

BG_TOP = (18, 127, 159)  # #127F9F, same as the app icon
BG_BOTTOM = (6, 58, 77)  # #063A4D
WHITE = (255, 255, 255)
SUBTLE = (196, 230, 241)
ACCENT = (255, 183, 77)  # orange segment of the icon

LANGS = ("en", "de")

# Caption per screenshot: (headline, subline). Keys are the raw file names.
CAPTIONS = {
    "en": {
        "01_line": ("Balance the whole line", "Bottleneck, line cycle time\nand output at a glance"),
        "02_simulation": ("Simulate failures", "See how many parts buffers\nand conveyors save"),
        "03_group": ("Design your line", "Parallel machines, buffers,\nconveyors and planned stops"),
        "04_recording_live": ("Measure blind", "Volume keys: next step,\nspecial time, start / stop"),
        "05_analysis": ("The real cycle time", "Mean, median or IQR\nwithout outliers"),
        "06_video_study": ("Time studies from video", "Mark the steps\nframe by frame"),
        "07_export": ("Reports in PDF & Excel", "Complete line report\nwith linked sheets"),
        "08_study_list": ("All studies in one place", "Offline, no account,\nno ads"),
    },
    "de": {
        "01_line": ("Die ganze Linie austakten", "Engpass, Linientakt und\nAusbringung auf einen Blick"),
        "02_simulation": ("Störungen simulieren", "Sieh, wie viele Teile Puffer\nund Transportbänder retten"),
        "03_group": ("Linie aufbauen", "Parallele Maschinen, Puffer,\nBänder und Sonderzyklen"),
        "04_recording_live": ("Blind messen", "Lautstärketasten: weiter,\nSonderzeit, Start / Stopp"),
        "05_analysis": ("Die reale Taktzeit", "Mittelwert, Median oder IQR\nohne Ausreißer"),
        "06_video_study": ("Zeitaufnahme aus Video", "Schritte Bild für Bild\nmarkieren"),
        "07_export": ("Reports als PDF & Excel", "Kompletter Linienbericht\nmit verknüpften Blättern"),
        "08_study_list": ("Alle Studien an einem Ort", "Offline, ohne Konto,\nohne Werbung"),
    },
}

# App Store: the hardware keys are Android only.
APPLE_OVERRIDES = {
    "en": {"04_recording_live": ("Measure on the shop floor", "Big buttons, the current\nstep always in view")},
    "de": {"04_recording_live": ("Messen direkt an der Linie", "Große Tasten, der aktuelle\nSchritt immer im Blick")},
}

FEATURE_TEXT = {
    "en": ("CycleScope", "Time studies, line balancing\nand line simulation", "REFA · MTM · Lean"),
    "de": ("CycleScope", "Zeitaufnahme, Austaktung\nund Liniensimulation", "REFA · MTM · Lean"),
}

# (folder, canvas size, raw device)
GOOGLE_TARGETS = [
    ("phone", (1080, 1920), "phone"),
    ("tablet", (2064, 2752), "tablet"),
]
APPLE_TARGETS = [
    ("iphone_6.9", (1320, 2868), "phone"),
    ("iphone_6.5", (1284, 2778), "phone"),
    ("ipad_13", (2064, 2752), "tablet"),
]


def font(bold, size):
    candidates = (
        ["segoeuib.ttf", "DejaVuSans-Bold.ttf", "Arial Bold.ttf"]
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
    # Soft light spot behind the caption.
    glow = Image.new("L", (width, height), 0)
    ImageDraw.Draw(glow).ellipse(
        [-width * 0.3, -height * 0.25, width * 1.3, height * 0.35], fill=60
    )
    glow = glow.filter(ImageFilter.GaussianBlur(width * 0.12))
    image.paste(Image.new("RGB", (width, height), (90, 190, 215)), (0, 0), glow)
    return image


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, image.width - 1, image.height - 1], radius, fill=255
    )
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def paste_with_shadow(canvas, image, x, y, radius, blur):
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + blur // 4, y + blur // 2, x + image.width + blur // 4, y + image.height + blur // 2],
        radius,
        fill=(0, 0, 0, 120),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(image, (x, y))


def fit_font(draw, text, bold, size, max_width):
    """Largest font up to [size] so every line of [text] fits [max_width]."""
    while size > 10:
        f = font(bold, size)
        box = draw.multiline_textbbox((0, 0), text, font=f, spacing=size * 0.2)
        if box[2] - box[0] <= max_width:
            return f
        size -= 2
    return font(bold, size)


def framed(source, caption, size):
    width, height = size
    unit = width / 1080  # layout scale relative to the Play phone canvas
    tablet = width / height > 0.6
    canvas = gradient(width, height).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    headline, subline = caption
    top = round(height * (0.055 if tablet else 0.06))
    title = fit_font(draw, headline, True, round(84 * unit * (0.8 if tablet else 1)), width * 0.88)
    draw.text((width / 2, top), headline, font=title, fill=WHITE, anchor="ma")
    title_h = draw.textbbox((0, 0), headline, font=title)[3]
    # Accent bar between headline and subline.
    bar_y = top + title_h + round(26 * unit)
    bar_w = round(90 * unit)
    draw.rounded_rectangle(
        [width / 2 - bar_w / 2, bar_y, width / 2 + bar_w / 2, bar_y + round(8 * unit)],
        round(4 * unit),
        fill=ACCENT,
    )
    sub = fit_font(draw, subline, False, round(46 * unit * (0.8 if tablet else 1)), width * 0.88)
    sub_y = bar_y + round(36 * unit)
    draw.multiline_text(
        (width / 2, sub_y),
        subline,
        font=sub,
        fill=SUBTLE,
        anchor="ma",
        align="center",
        spacing=round(10 * unit),
    )
    caption_bottom = draw.multiline_textbbox(
        (width / 2, sub_y), subline, font=sub, anchor="ma", spacing=round(10 * unit)
    )[3]

    shot = Image.open(source).convert("RGB")
    gap = round(60 * unit)
    bottom = round(height * 0.035)
    target_h = height - caption_bottom - gap - bottom
    target_w = round(shot.width * target_h / shot.height)
    if target_w > width * 0.86:
        target_w = round(width * 0.86)
        target_h = round(shot.height * target_w / shot.width)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)

    bezel = round((22 if tablet else 16) * unit)
    radius = round((40 if tablet else 64) * unit)
    frame = Image.new("RGB", (target_w + 2 * bezel, target_h + 2 * bezel), (20, 22, 26))
    frame = rounded(frame, radius)
    frame.alpha_composite(rounded(shot, max(1, radius - bezel)), (bezel, bezel))

    x = (width - frame.width) // 2
    y = height - frame.height - bottom
    paste_with_shadow(canvas, frame, x, y, radius, round(28 * unit))
    return canvas.convert("RGB")


def feature_graphic(lang):
    width, height = 1024, 500
    name, tagline, tags = FEATURE_TEXT[lang]
    canvas = gradient(width, height).convert("RGBA")

    icon = Image.open(ICON_512).convert("RGBA").resize((120, 120), Image.LANCZOS)
    paste_with_shadow(canvas, rounded(icon, 28), 64, 50, 28, 12)

    draw = ImageDraw.Draw(canvas)
    draw.text((64, 250), name, font=font(True, 66), fill=WHITE, anchor="ls")
    draw.multiline_text((66, 280), tagline, font=font(False, 32), fill=SUBTLE, spacing=8)
    draw.rounded_rectangle([66, 380, 66 + 70, 386], 3, fill=ACCENT)
    draw.text((66, 404), tags, font=font(True, 24), fill=WHITE)

    # Two app screens on the right, cut off by the bottom edge.
    for i, (key, x, y) in enumerate((("02_simulation", 760, 120), ("01_line", 560, 70))):
        raw = os.path.join(RAW, "phone", lang, f"{key}.png")
        shot = Image.open(raw).convert("RGB")
        w = 220
        h = round(shot.height * w / shot.width)
        shot = shot.resize((w, h), Image.LANCZOS)
        frame = Image.new("RGB", (w + 16, h + 16), (20, 22, 26))
        frame = rounded(frame, 30)
        frame.alpha_composite(rounded(shot, 22), (8, 8))
        paste_with_shadow(canvas, frame, x, y, 30, 16)
    return canvas.convert("RGB")


def write_set(base, lang, targets, captions):
    for folder, size, device in targets:
        out_dir = os.path.join(base, lang, folder)
        os.makedirs(out_dir, exist_ok=True)
        for old in glob.glob(os.path.join(out_dir, "*.png")):
            os.remove(old)
        for source in sorted(glob.glob(os.path.join(RAW, device, lang, "*.png"))):
            key = os.path.splitext(os.path.basename(source))[0]
            caption = captions.get(key)
            if caption is None:
                print(f"skipped (no caption): {source}")
                continue
            framed(source, caption, size).save(os.path.join(out_dir, f"{key}.png"))


def main():
    if not os.path.isdir(RAW):
        raise SystemExit(
            "store/raw is missing; render it first:\n"
            "  flutter test tests/screenshots/store_screenshots_test.dart "
            "--dart-define=STORE_SCREENSHOTS=true"
        )
    google = os.path.join(STORE, "googleplay")
    apple = os.path.join(STORE, "appstore")
    os.makedirs(google, exist_ok=True)
    os.makedirs(apple, exist_ok=True)
    Image.open(ICON_512).convert("RGBA").save(os.path.join(google, "icon_512.png"))
    shutil.copyfile(ICON_1024, os.path.join(apple, "icon_1024.png"))

    for lang in LANGS:
        os.makedirs(os.path.join(google, lang), exist_ok=True)
        feature_graphic(lang).save(os.path.join(google, lang, "feature_graphic.png"))
        write_set(google, lang, GOOGLE_TARGETS, CAPTIONS[lang])
        write_set(apple, lang, APPLE_TARGETS, {**CAPTIONS[lang], **APPLE_OVERRIDES[lang]})
    print(f"Store graphics written to {google} and {apple}")


if __name__ == "__main__":
    main()
