#!/usr/bin/env python3
"""Makes 16 x 16 skill icons from art/input/<skill>_Icon.(webp|png), for example
plancha_Icon.webp -> assets/icons/sk_plancha.png (the key comes from the skill's
`icon` field in skills.json).

Removes the flat background, crops to the drawing, fits it in 16 x 16 and snaps
every color to the 32-color palette.

  python3 tools/build_icons.py
"""
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_sprites import edge_mask, remove_background, snap  # noqa: E402
from palette import PALETTE  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
INPUT = ROOT / "art" / "input"
OUT = ROOT / "assets" / "icons"
SIZE = 16
TILT = 30  # degrees, clockwise (head down and to the right)

skills = {s["id"]: s["icon"] for s in json.loads((ROOT / "assets/data/skills.json").read_text())["skills"]}


def build(path, key):
    img = remove_background(Image.open(path))
    box = img.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
    fig = img.crop(box)
    # A long flat figure would be only a few pixels tall: tilt it as if
    # diving downward so it fills more of the square.
    if fig.width > 1.8 * fig.height:
        fig = fig.rotate(-TILT, resample=Image.BICUBIC, expand=True)
        fig = fig.crop(fig.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox())
    scale = min(SIZE / fig.width, SIZE / fig.height)
    w, h = max(1, round(fig.width * scale)), max(1, round(fig.height * scale))
    a = np.array(fig.resize((w, h), Image.LANCZOS))
    alpha = np.where(a[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    rgb = snap(a[:, :, :3], True)
    rgb[(a[:, :, :3].astype(int).sum(axis=2) < 200) & edge_mask(alpha)] = PALETTE["ink"]
    rgb[alpha == 0] = 0
    canvas = np.zeros((SIZE, SIZE, 4), np.uint8)
    x, y = (SIZE - w) // 2, (SIZE - h) // 2
    canvas[y:y + h, x:x + w] = np.dstack([rgb, alpha])
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas, "RGBA").save(OUT / f"{key}.png")
    print(f"{path.name} -> assets/icons/{key}.png")


def main():
    for p in sorted(INPUT.iterdir()):
        m = re.match(r"(.+?)_icon\.(webp|png)$", p.name, re.I)
        if not m:
            continue
        skill = m.group(1).lower()
        if skill in skills:
            build(p, skills[skill])
        else:
            print(f"SKIP {p.name}: no skill '{skill}' in skills.json")


if __name__ == "__main__":
    main()
