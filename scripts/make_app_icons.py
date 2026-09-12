"""Generate the app's launcher icons, splash art and in-app logo from zu_logo.jpeg.

The source is a flat two-colour lockup — a bus glyph above a "zu rahbar"
wordmark, green on near-black — photographed as a JPEG, so it carries
compression noise around every edge. Everything here derives from that one
file rather than from hand-edited binaries, so a new logo means rerunning this
script, not redrawing five PNGs by hand.

    .venv/bin/python scripts/make_app_icons.py

Run it from the repo root; it writes into app/assets/brand/ and
app/android/app/src/main/res/.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "zu_logo.jpeg"
BRAND_DIR = ROOT / "app" / "assets" / "brand"
RES_DIR = ROOT / "app" / "android" / "app" / "src" / "main" / "res"

GREEN = (165, 209, 156)
GROUND = (17, 22, 16)

# Below this colour distance from the background, a pixel is JPEG noise.
NOISE_FLOOR = 45

# Launcher icon sizes per density bucket, and the 108dp adaptive-icon canvas
# that Android masks down to whatever shape the launcher uses.
LEGACY_PX = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE_PX = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

# Android may crop an adaptive icon to a circle, so only the middle ~66% is
# guaranteed visible. Keep the glyph well inside that.
ADAPTIVE_GLYPH_FRACTION = 0.46
LEGACY_GLYPH_FRACTION = 0.68


def load_marks() -> Image.Image:
    """The logo's green marks as a clean RGBA image, background dropped.

    Alpha comes from how far each pixel sits from the background colour, which
    keeps the antialiased edges smooth instead of stair-stepping them the way a
    hard threshold would.
    """
    source = Image.open(SOURCE).convert("RGB")
    ground_sum = sum(GROUND)

    def alpha_of(pixel: tuple[int, int, int]) -> int:
        red, green, blue = pixel
        if red + green + blue <= ground_sum:
            return 0
        distance = abs(red - GROUND[0]) + abs(green - GROUND[1]) + abs(blue - GROUND[2])
        # JPEG noise leaves a few units of distance all over the background.
        # Left in, it is invisible but still counts as content, and getbbox()
        # then returns the whole frame and every crop below scales the art to
        # nothing. Drop anything that faint outright.
        if distance < NOISE_FLOOR:
            return 0
        return min(255, int(distance * 255 / 180))

    alpha = Image.new("L", source.size)
    alpha.putdata([alpha_of(pixel) for pixel in source.getdata()])
    marks = Image.new("RGBA", source.size, GREEN + (0,))
    marks.putalpha(alpha)
    return marks


def fit(image: Image.Image, canvas: int, fraction: float, background=None) -> Image.Image:
    """Centre `image` on a square canvas, scaled to `fraction` of its width."""
    trimmed = image.crop(image.getbbox())
    target = max(1, int(canvas * fraction))
    scale = min(target / trimmed.width, target / trimmed.height)
    resized = trimmed.resize(
        (max(1, round(trimmed.width * scale)), max(1, round(trimmed.height * scale))),
        Image.LANCZOS,
    )
    out = Image.new("RGBA", (canvas, canvas), (background + (255,)) if background else (0, 0, 0, 0))
    out.alpha_composite(resized, ((canvas - resized.width) // 2, (canvas - resized.height) // 2))
    return out


def write(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"  {path.relative_to(ROOT)}  {image.width}x{image.height}")


def main() -> int:
    if not SOURCE.exists():
        print(f"missing {SOURCE}", file=sys.stderr)
        return 1

    marks = load_marks()
    # The wordmark sits below a clear horizontal gap; everything above it is the
    # bus. Splitting on that gap avoids hardcoding pixel rows for one image.
    bbox = marks.getbbox()
    rows = [any(marks.getpixel((x, y))[3] > 40 for x in range(bbox[0], bbox[2], 3))
            for y in range(marks.height)]
    gaps = [y for y in range(bbox[1], bbox[3]) if not rows[y]]
    split = gaps[len(gaps) // 2] if gaps else bbox[3]
    glyph = marks.crop((bbox[0], bbox[1], bbox[2], split))
    glyph = glyph.crop(glyph.getbbox())

    print("in-app art:")
    write(fit(marks, 1024, 0.92), BRAND_DIR / "zu_logo.png")
    write(fit(glyph, 512, 0.92), BRAND_DIR / "zu_bus.png")

    print("launcher icons:")
    for bucket, size in LEGACY_PX.items():
        write(fit(glyph, size, LEGACY_GLYPH_FRACTION, background=GROUND),
              RES_DIR / f"mipmap-{bucket}" / "ic_launcher.png")
    for bucket, size in ADAPTIVE_PX.items():
        write(fit(glyph, size, ADAPTIVE_GLYPH_FRACTION),
              RES_DIR / f"drawable-{bucket}" / "ic_launcher_foreground.png")

    print("splash art:")
    for bucket, size in ADAPTIVE_PX.items():
        write(fit(marks, size * 2, 0.9),
              RES_DIR / f"drawable-{bucket}" / "launch_logo.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
