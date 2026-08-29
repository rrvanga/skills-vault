#!/usr/bin/env python3
"""Minimal HTML -> PNG renderer with blind verification + auto-crop.

Usage:  python3 render_and_verify.py input.html output.png [width] [viewport_height]

Requires: chromium (headless) + Pillow.

The render is deterministic for identical input (no timestamps), so it pairs
with a `git diff --quiet` commit-on-change cron (silent no-op when unchanged).
"""
import subprocess
import sys
from pathlib import Path


def render(html_path, png_path, width=1400, viewport_h=3400):
    html_path = Path(html_path)
    png_path = Path(png_path)
    subprocess.run(
        [
            "chromium",
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--disable-dev-shm-usage",
            "--hide-scrollbars",
            f"--window-size={width},{viewport_h}",
            f"--screenshot={png_path}",
            html_path.resolve().as_uri(),
        ],
        check=True,
    )


def verify_and_crop(png_path, bg=(238, 241, 246), pad=28):
    from PIL import Image

    img = Image.open(png_path).convert("RGB")
    w, h = img.size
    if w < 100 or h < 100:
        raise SystemExit(f"render too small: {w}x{h}")

    # Downsampled color census: a healthy render has many distinct colors.
    small = img.resize((max(1, w // 20), max(1, h // 20)))
    colors = small.getcolors(maxcolors=100_000) or []
    if len(colors) < 20:
        raise SystemExit(f"likely blank: only {len(colors)} distinct colors")

    # Crop trailing uniform-background rows (render viewport is oversized).
    px = img.load()
    assert px is not None, "image has no pixel data"

    def row_has_content(y):
        return any(px[x, y] != bg for x in range(0, w, 5))

    bottom = h - 1
    while bottom > 0 and not row_has_content(bottom):
        bottom -= 1
    new_h = min(h, bottom + 1 + pad)
    if new_h < h:
        img.crop((0, 0, w, new_h)).save(png_path)

    print(f"verified: {w}x{new_h}, {len(colors)} sampled colors")


if __name__ == "__main__":
    html = sys.argv[1]
    png = sys.argv[2]
    width = int(sys.argv[3]) if len(sys.argv) > 3 else 1400
    vh = int(sys.argv[4]) if len(sys.argv) > 4 else 3400
    render(html, png, width, vh)
    verify_and_crop(png)
