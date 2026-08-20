#!/usr/bin/env python3
"""Generate platform-specific app icons."""

from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "assets" / "icon"
MACOS_ICONSET = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MACOS_RESOURCES = ROOT / "macos" / "Runner" / "Resources"
SOURCE = ICON_DIR / "app_icon_source.png"
GENERAL = ICON_DIR / "app_icon.png"
MACOS = ICON_DIR / "app_icon_macos.png"

# iconutil naming: side => (1x name, 2x name when applicable)
ICONUTIL_SIZES = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

ASSET_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def squircle_mask(size: int, exponent: float = 5.0) -> np.ndarray:
    """Big Sur-style continuous corner mask used by modern macOS icons."""
    y, x = np.ogrid[:size, :size]
    center = (size - 1) / 2.0
    radius = size / 2.0
    nx = np.abs(x - center) / radius
    ny = np.abs(y - center) / radius
    return (nx**exponent + ny**exponent) <= 1.0


def soft_squircle_alpha(size: int, exponent: float = 5.0) -> Image.Image:
    """Apple-style macOS icon silhouette (~34% transparent corners)."""
    template = ICON_DIR / "macos_squircle_mask.png"
    if template.exists():
        tmpl = Image.open(template).convert("L")
        if tmpl.size != (size, size):
            tmpl = tmpl.resize((size, size), Image.Resampling.LANCZOS)
        return tmpl

    # Fallback approximating Apple icon grid + continuous corners
    y, x = np.ogrid[:size, :size]
    center = (size - 1) / 2.0
    radius = size * 0.45
    nx = np.abs(x - center) / radius
    ny = np.abs(y - center) / radius
    hard = (nx**2.2 + ny**2.2) <= 1.0
    alpha = Image.fromarray((hard.astype(np.float32) * 255).astype(np.uint8), mode="L")
    if size >= 64:
        alpha = alpha.filter(ImageFilter.GaussianBlur(radius=max(0.8, size / 700)))
    return alpha


def ensure_source() -> Image.Image:
    if SOURCE.exists():
        return Image.open(SOURCE).convert("RGBA")
    current = Image.open(GENERAL).convert("RGBA")
    # Flatten any previous transparent corners onto black
    flat = Image.new("RGBA", current.size, (0, 0, 0, 255))
    flat.paste(current, (0, 0), current.split()[3])
    flat.save(SOURCE)
    return flat


def flatten_on_black(source: Image.Image, size: int) -> Image.Image:
    src = source.resize((size, size), Image.Resampling.LANCZOS)
    base = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    base.paste(src, (0, 0), src.split()[3])
    return base


def apply_squircle(source: Image.Image, size: int) -> Image.Image:
    flat = flatten_on_black(source, size)
    mask = soft_squircle_alpha(size)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(flat, (0, 0), mask)
    return out


def generate_general_icon(source: Image.Image, size: int = 1024) -> Image.Image:
    return apply_squircle(source, size)


def generate_macos_icon(source: Image.Image, size: int = 1024) -> Image.Image:
    """Pre-masked transparent squircle — same approach as Cumora / TinyPng."""
    return apply_squircle(source, size)


def write_macos_assets(master: Image.Image) -> None:
    for side in ASSET_SIZES:
        resized = master.resize((side, side), Image.Resampling.LANCZOS)
        # Keep RGBA so asset catalog / icns preserve transparent corners
        resized.save(MACOS_ICONSET / f"app_icon_{side}.png", format="PNG")


def write_icns(master: Image.Image) -> Path:
    work = ROOT / "build" / "icon_work"
    iconset = work / "AppIcon.iconset"
    if work.exists():
        shutil.rmtree(work)
    iconset.mkdir(parents=True)

    for side, name in ICONUTIL_SIZES:
        master.resize((side, side), Image.Resampling.LANCZOS).save(
            iconset / name, format="PNG"
        )

    MACOS_RESOURCES.mkdir(parents=True, exist_ok=True)
    out = MACOS_RESOURCES / "AppIcon.icns"
    subprocess.run(
        ["iconutil", "-c", "icns", "-o", str(out), str(iconset)],
        check=True,
    )
    return out


def main() -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    source = ensure_source()

    # Keep source as opaque full-bleed artwork
    flat = flatten_on_black(source, 1024)
    flat.save(SOURCE)

    general = generate_general_icon(flat)
    general.save(GENERAL, format="PNG")

    macos = generate_macos_icon(flat)
    macos.save(MACOS, format="PNG")
    write_macos_assets(macos)
    icns = write_icns(macos)

    # Sanity: Cumora-like transparency
    a = macos.split()[3]
    data = list(a.getdata())
    transparent_pct = 100 * sum(1 for v in data if v == 0) / len(data)
    print(f"Updated {GENERAL}")
    print(f"Updated {MACOS}")
    print(f"Updated {MACOS_ICONSET}")
    print(f"Updated {icns} ({icns.stat().st_size} bytes)")
    print(f"macOS icon transparent%: {transparent_pct:.1f}")
    print(f"corner alpha: {a.getpixel((0, 0))} center alpha: {a.getpixel((512, 512))}")


if __name__ == "__main__":
    main()
