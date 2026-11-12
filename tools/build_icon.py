#!/usr/bin/env python3
"""Makes the app icons from art/input/AppIcon.(webp|png): the Android launcher
icons (all densities) and the web icons / favicon.

  python3 tools/build_icon.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
src = next(p for p in (ROOT / "art/input/AppIcon.webp", ROOT / "art/input/AppIcon.png") if p.exists())
img = Image.open(src).convert("RGB")
side = min(img.size)
img = img.crop(((img.width - side) // 2, (img.height - side) // 2, (img.width - side) // 2 + side, (img.height - side) // 2 + side))


def save(path, size, pad=0.0):
    icon = img.resize((round(size * (1 - 2 * pad)),) * 2, Image.LANCZOS)
    if pad:  # maskable: keep the art inside the safe zone on the icon's own edge color
        canvas = Image.new("RGB", (size, size), img.getpixel((2, 2)))
        canvas.paste(icon, ((size - icon.width) // 2,) * 2)
        icon = canvas
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    icon.save(path)
    print(path.relative_to(ROOT), size)


res = ROOT / "android/app/src/main/res"
for folder, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    save(res / f"mipmap-{folder}" / "ic_launcher.png", size)
web = ROOT / "web"
save(web / "icons/Icon-192.png", 192)
save(web / "icons/Icon-512.png", 512)
save(web / "icons/Icon-maskable-192.png", 192, pad=0.1)
save(web / "icons/Icon-maskable-512.png", 512, pad=0.1)
save(web / "favicon.png", 32)
