#!/usr/bin/env python3
"""Makes the 16 x 16 icons from art/input/:

  <skill>_Icon.webp    -> assets/icons/<skill's icon key>.png (plancha_Icon.webp
                          -> sk_plancha.png; the key is `icon` in skills.json)
  mask_<id>.webp       -> assets/icons/mask_<id>.png   (24 x 24; keeps the three
                          mask purples: the game recolors them per mask)
  tr_<id>.webp         -> assets/icons/tr_<id>.png (16 x 16, list rows) and
                          tr_<id>_big.png (48 x 48, info pop-up)
  up_<id>.webp         -> assets/icons/up_<id>.png     (upgrade icons)
  tl_<name>.webp       -> assets/icons/tl_<name>.png   (talent icons)

The names after the prefix must match ids in the data files; anything else is
skipped.

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
MASK_SIZE = 24  # the masks grid draws them bigger
PORTRAIT_SIZE = 48  # trainer portrait in the info pop-up
TILT = 30  # degrees, clockwise (head down and to the right)

skills = {s["id"]: s["icon"] for s in json.loads((ROOT / "assets/data/skills.json").read_text())["skills"]}


def _shrink(fig, w, h):
    """Shrinks to w x h taking, for each target pixel, the most common palette
    color of the block it covers (keeps the flat look of pixel art; averaging
    would blur two neighbouring colors into a third one)."""
    big = np.array(fig.resize((w * 8, h * 8), Image.BOX))
    idx = snap(big[:, :, :3], True)
    out = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            blk = idx[y * 8:(y + 1) * 8, x * 8:(x + 1) * 8].reshape(-1, 3)
            al = big[y * 8:(y + 1) * 8, x * 8:(x + 1) * 8, 3].reshape(-1)
            solid = al >= 128
            out[y, x, 3] = 255 if solid.mean() >= 0.5 else 0
            if solid.any():
                cols, counts = np.unique(blk[solid], axis=0, return_counts=True)
                out[y, x, :3] = cols[counts.argmax()]
    return Image.fromarray(out, "RGBA")


def build(path, key, tilt=False, pool=True, size=SIZE):
    img = remove_background(Image.open(path))
    box = img.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
    fig = img.crop(box)
    # A long flat figure would be only a few pixels tall: tilt it as if
    # diving downward so it fills more of the square.
    if tilt and fig.width > 1.8 * fig.height:
        fig = fig.rotate(-TILT, resample=Image.BICUBIC, expand=True)
        fig = fig.crop(fig.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox())
    scale = min(size / fig.width, size / fig.height)
    w, h = max(1, round(fig.width * scale)), max(1, round(fig.height * scale))
    # Objects keep flat colors (most common color per pixel); faces keep their
    # small features (eyes) with a smooth shrink snapped to the palette.
    a = np.array(_shrink(fig, w, h) if pool else fig.resize((w, h), Image.LANCZOS))
    alpha = np.where(a[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    rgb = snap(a[:, :, :3], True)
    rgb[(a[:, :, :3].astype(int).sum(axis=2) < 200) & edge_mask(alpha)] = PALETTE["ink"]
    rgb[alpha == 0] = 0
    canvas = np.zeros((size, size, 4), np.uint8)
    x, y = (size - w) // 2, (size - h) // 2
    canvas[y:y + h, x:x + w] = np.dstack([rgb, alpha])
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas, "RGBA").save(OUT / f"{key}.png")
    print(f"{path.name} -> assets/icons/{key}.png")


def _ids(file, key="id"):
    data = json.loads((ROOT / "assets/data" / file).read_text())
    items = [x for k, v in data.items() if isinstance(v, list) for x in v]
    out = set()
    for x in items:
        out.add(x[key])
        for n in x.get("nodes", []):  # talent branches
            out.add(n[key])
    return out


def main():
    masks = _ids("masks.json")
    trainers = _ids("trainers.json")
    upgrades = _ids("upgrades.json")
    talent_icons = set()
    for b in json.loads((ROOT / "assets/data/talents.json").read_text())["branches"]:
        talent_icons |= {n["icon"] for n in b["nodes"]}
    for p in sorted(INPUT.iterdir()):
        if p.suffix.lower() not in (".webp", ".png"):
            continue
        stem = p.stem
        m = re.match(r"(.+?)_icon$", stem, re.I)
        if m:
            skill = m.group(1).lower()
            if skill in skills:
                build(p, skills[skill], tilt=True)
            else:
                print(f"SKIP {p.name}: no skill '{skill}' in skills.json")
        elif stem.startswith("mask_") and stem[5:] in masks:
            build(p, stem, pool=False, size=MASK_SIZE)
        elif stem.startswith("tr_") and stem[3:] in trainers:
            build(p, stem, pool=False)  # list rows
            build(p, stem + "_big", pool=False, size=PORTRAIT_SIZE)  # info pop-up
        elif stem.startswith("up_") and stem[3:] in upgrades:
            build(p, stem)
        elif stem.startswith("tl_") and stem in talent_icons:
            build(p, stem)


if __name__ == "__main__":
    main()
