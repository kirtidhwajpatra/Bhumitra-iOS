#!/usr/bin/env python3
"""Render the 'Bhumitra' splash wordmark as a transparent PNG in the brand purple.

Output goes next to this script. The wordmark is drawn on a transparent
background so the splash's white (light) / black (dark) canvas shows through,
and so the existing shine-sweep gradient (masked to the image's alpha) works.
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
BRAND = (124, 58, 237, 255)   # #7C3AED electric violet, matches SplashScreenView.primaryBrandPurple

# Render at a generous size; the splash frames it to width 230pt, so a wide crisp
# master downsamples nicely on @2x/@3x.
W, H = 1200, 320
TEXT = "Bhumitra"

def load_font(size):
    candidates = [
        "/System/Library/Fonts/Supplemental/Avenir Next.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    for p in candidates:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()

def render(scale, filename):
    img = Image.new("RGBA", (W * scale, H * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    font = load_font(int(190 * scale))
    bbox = d.textbbox((0, 0), TEXT, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (W * scale - tw) / 2 - bbox[0]
    y = (H * scale - th) / 2 - bbox[1]
    d.text((x, y), TEXT, font=font, fill=BRAND)
    img.save(os.path.join(OUT, filename))
    print("wrote", filename, img.size)

render(1, "bhumitra_wordmark.png")
render(2, "bhumitra_wordmark@2x.png")
render(3, "bhumitra_wordmark@3x.png")
