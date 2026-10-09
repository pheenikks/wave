#!/usr/bin/env python3
"""Regenerate the procedural textures in assets/. Needs Pillow and numpy."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets"
rng = np.random.default_rng(7)


def grain(size=256):
    """Tileable film grain: mid-grey noise carried in the alpha channel."""
    n = rng.normal(0, 1, (size, size))
    val = np.where(n > 0, 255, 0).astype(np.uint8)
    a = np.clip(np.abs(n) * 70, 0, 255).astype(np.uint8)
    img = np.dstack([val, val, val, a])
    Image.fromarray(img, "RGBA").save(OUT / "grain.png")


def wear(w=160, h=640):
    """Scuffs, creases and edge whitening for tape boxes (white on transparent)."""
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    # long hairline scratches
    for _ in range(46):
        x, y = rng.integers(0, w), rng.integers(0, h)
        ln = int(rng.integers(8, 120))
        dx = int(rng.integers(-6, 7))
        d.line([(x, y), (x + dx, y + ln)], fill=int(rng.integers(40, 130)), width=1)
    # sideways rubs
    for _ in range(26):
        x, y = rng.integers(-20, w), rng.integers(0, h)
        ln = int(rng.integers(10, 70))
        d.line([(x, y), (x + ln, y + int(rng.integers(-3, 4)))], fill=int(rng.integers(30, 110)), width=1)
    # specks
    for _ in range(420):
        x, y = rng.integers(0, w), rng.integers(0, h)
        img.putpixel((int(x), int(y)), int(rng.integers(60, 220)))
    img = img.filter(ImageFilter.GaussianBlur(0.45))
    # worn corners and edges
    edge = Image.new("L", (w, h), 0)
    e = ImageDraw.Draw(edge)
    for _ in range(520):
        side = rng.integers(0, 4)
        t = abs(rng.normal(0, 1))
        if side == 0:
            x, y = t * 3, rng.integers(0, h)
        elif side == 1:
            x, y = w - 1 - t * 3, rng.integers(0, h)
        elif side == 2:
            x, y = rng.integers(0, w), t * 5
        else:
            x, y = rng.integers(0, w), h - 1 - t * 5
        r = rng.uniform(0.3, 1.4)
        e.ellipse([x - r, y - r, x + r, y + r], fill=int(rng.integers(70, 210)))
    edge = edge.filter(ImageFilter.GaussianBlur(0.7))
    a = np.maximum(np.asarray(img), np.asarray(edge))
    # soft blotches so the wear is uneven
    blot = rng.normal(0, 1, (h // 16, w // 16))
    blot = np.asarray(Image.fromarray(((blot - blot.min()) / np.ptp(blot) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)) / 255.0
    a = (a * (0.45 + 0.75 * blot)).clip(0, 255).astype(np.uint8)
    white = np.full_like(a, 255)
    Image.fromarray(np.dstack([white, white, white, a]), "RGBA").save(OUT / "wear.png")


def shadow(size=96, pad=32):
    """Soft drop shadow for 9-slice use (BorderImage, border = pad)."""
    img = Image.new("L", (size, size), 0)
    ImageDraw.Draw(img).rectangle([pad, pad, size - pad - 1, size - pad - 1], fill=255)
    img = img.filter(ImageFilter.GaussianBlur(pad / 2.6))
    black = Image.new("L", (size, size), 0)
    Image.merge("RGBA", [black, black, black, img]).save(OUT / "shadow.png")


def vignette(size=256):
    y, x = np.mgrid[0:size, 0:size]
    d = np.hypot((x - size / 2) / (size / 2), (y - size / 2) / (size / 2))
    a = (np.clip((d - 0.55) / 0.9, 0, 1) ** 1.6 * 255).astype(np.uint8)
    z = np.zeros_like(a)
    Image.fromarray(np.dstack([z, z, z, a]), "RGBA").save(OUT / "vignette.png")


def scanlines():
    img = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    for x in range(4):
        img.putpixel((x, 2), (0, 0, 0, 255))
        img.putpixel((x, 3), (0, 0, 0, 150))
    img.save(OUT / "scanlines.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    grain(); wear(); shadow(); vignette(); scanlines()
    print("textures written to", OUT)
