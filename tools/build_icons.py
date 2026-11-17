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
  shop_<name>.webp     -> assets/icons/shop_<name>.png (store items; `icon` in shop.json)
  ui_<name>.webp       -> assets/icons/ui_<name>.png   (trophy, chest, goal, boost;
                          ui_boost also as ui_boost_8.png for the calendar)
  lucky_belt.webp      -> assets/icons/lucky_belt.png  (the lucky pickup in the arena)
  nav_<tab>.webp       -> assets/icons/nav_<tab>.png   (bottom tabs: upgrades, skills,
                          masks, talents, shop; drawn as a silhouette unless selected)

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


def strip_tile(img, tol=70, rounds=4):
    """Removes a square tile drawn behind the figure (a dark or cream box the
    image generator sometimes adds): while the edge of the figure is all one
    color, that color is flood-filled away from the edge."""
    from collections import deque
    a = np.array(img).copy()
    # The magenta halo the background removal leaves around a box.
    rgb = a[:, :, :3].astype(int)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    # Magenta at any brightness (red and blue alike, little green); the
    # palette's own magenta (#D12FA0) has much less blue and is kept.
    a[(r > g + 60) & (b > g + 60) & (np.abs(r - b) < 30), 3] = 0
    for _ in range(rounds):
        alpha = a[:, :, 3] > 0
        ys, xs = np.nonzero(alpha)
        if len(xs) == 0:
            break
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        ring = np.concatenate([a[y0, x0:x1 + 1, :3], a[y1, x0:x1 + 1, :3], a[y0:y1 + 1, x0, :3], a[y0:y1 + 1, x1, :3]]).astype(int)
        ring_alpha = np.concatenate([alpha[y0, x0:x1 + 1], alpha[y1, x0:x1 + 1], alpha[y0:y1 + 1, x0], alpha[y0:y1 + 1, x1]])
        if ring_alpha.mean() < 0.6:
            break  # not a box: the figure itself touches the edge here and there
        med = np.median(ring[ring_alpha], axis=0)
        if (np.abs(ring[ring_alpha] - med).sum(axis=1) <= tol).mean() < 0.7:
            break
        close = alpha & (np.abs(a[:, :, :3].astype(int) - med).sum(axis=2) <= tol)
        seen = np.zeros(alpha.shape, bool)
        q = deque()
        for y in range(y0, y1 + 1):
            for x in (x0, x1):
                if close[y, x] and not seen[y, x]:
                    seen[y, x] = True; q.append((y, x))
        for x in range(x0, x1 + 1):
            for y in (y0, y1):
                if close[y, x] and not seen[y, x]:
                    seen[y, x] = True; q.append((y, x))
        while q:
            y, x = q.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < a.shape[0] and 0 <= nx < a.shape[1] and close[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; q.append((ny, nx))
        a[seen, 3] = 0
    return Image.fromarray(a, "RGBA")


def build(path, key, tilt=False, pool=True, size=SIZE, tile=False):
    img = remove_background(Image.open(path))
    if tile:
        img = strip_tile(img)
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


def silhouette(key):
    """The unselected look of a tab icon: the light parts of the picture in
    Fog, the dark lines left empty, so details (eyes, a coin) still read."""
    a = np.array(Image.open(OUT / f"{key}.png").convert("RGBA"))
    rgb = a[:, :, :3].astype(int)
    # Only the outline color (Ink) is left empty; dark reds stay part of it.
    dark = np.abs(rgb - np.array(PALETTE["ink"])).sum(axis=2) < 40
    out = np.zeros_like(a)
    keep = (a[:, :, 3] > 0) & ~dark
    out[keep] = [*PALETTE["fog"], 255]
    Image.fromarray(out, "RGBA").save(OUT / f"{key}_off.png")
    print(f"  -> assets/icons/{key}_off.png (silhouette)")


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
    shop_icons = {i["icon"] for i in json.loads((ROOT / "assets/data/shop.json").read_text())["items"]}
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
        elif stem.startswith("shop_") and stem in shop_icons:
            build(p, stem, tile=True)
        elif stem.startswith("nav_"):
            build(p, stem, tile=True)
            silhouette(stem)
        elif stem.startswith("ui_"):
            build(p, stem, tile=True)
            if stem == "ui_boost":
                build(p, stem + "_8", size=8, tile=True)
        elif stem == "lucky_belt":
            build(p, stem)


if __name__ == "__main__":
    main()
