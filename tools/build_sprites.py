#!/usr/bin/env python3
"""Builds game-ready sprite sheets from the source images in art/input/.

For each image: removes the flat background, crops to the figure, shrinks it
to the cell size (48, or 64 for bosses), snaps every color to the 32-color
palette, makes alpha 0/255, derives the five animations from the single pose
(bob, lunge, recoil, fall, hop) and writes assets/sprites/<key>.png.
Then run tools/validate_sprite.py (done automatically at the end).

  python3 tools/build_sprites.py [name ...]
"""
import json
import re
import subprocess
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette import MASK_SLOTS, PALETTE  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
INPUT = ROOT / "art" / "input"
OUT = ROOT / "assets" / "sprites"
BALANCE = json.loads((ROOT / "assets/data/balance.json").read_text())["animations"]
ORDER = BALANCE["order"]
COLUMNS = max(BALANCE["clips"][a]["frames"] for a in ORDER)
SIZES = {"player": 48}
for o in json.loads((ROOT / "assets/data/opponents.json").read_text())["opponents"]:
    SIZES[o["sprite"]] = o["size"]


def key_of(path):
    stem = path.stem
    if stem.lower() == "player":
        return "player"
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", stem).lower().replace("-", "_").replace(" ", "_")
    s = re.sub(r"[^a-z0-9_]", "", s)
    return s if s.startswith("opp_") else "opp_" + s


def remove_background(img, tol=48):
    """Flood fill from the border: pixels close to the border color and connected to it become transparent."""
    a = np.array(img.convert("RGBA")).astype(np.int32)
    if (a[:, :, 3] < 250).any():  # already has transparency
        return img.convert("RGBA")
    h, w = a.shape[:2]
    border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    bg = np.median(border, axis=0)
    close = (np.abs(a[:, :, :3] - bg).sum(axis=2) <= tol)
    seen = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if close[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if close[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and close[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    out = a.copy()
    out[seen] = [*PALETTE["ink"], 0]
    out[~seen, 3] = 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def snap(rgb, allow_mask):
    names = [n for n in PALETTE if allow_mask or n not in MASK_SLOTS]
    table = np.array([PALETTE[n] for n in names], dtype=np.int32)
    flat = rgb.reshape(-1, 3).astype(np.int32)
    d = ((flat[:, None, :] - table[None, :, :]) ** 2).sum(axis=2)
    return table[d.argmin(axis=1)].reshape(rgb.shape).astype(np.uint8)


def to_cell(img, size, allow_mask):
    bbox = img.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
    fig = img.crop(bbox)
    margin_x, margin_top, margin_bottom = 4, 3, 1
    scale = min((size - 2 * margin_x) / fig.width, (size - margin_top - margin_bottom) / fig.height)
    w, h = max(1, round(fig.width * scale)), max(1, round(fig.height * scale))
    fig = fig.resize((w, h), Image.BOX)
    a = np.array(fig)
    alpha = np.where(a[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    rgb = snap(a[:, :, :3], allow_mask)
    # Dark outline pixels all become Ink (no wine/purple fringes).
    dark = a[:, :, :3].astype(int).sum(axis=2) < 200
    rgb[dark] = PALETTE["ink"]
    rgb[alpha == 0] = 0
    canvas = np.zeros((size, size, 4), np.uint8)
    x, y = (size - w) // 2, size - margin_bottom - h
    canvas[y:y + h, x:x + w] = np.dstack([rgb, alpha])
    return Image.fromarray(canvas, "RGBA")


def shifted(cell, dx, dy):
    out = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    out.paste(cell, (dx, dy))
    return out


def fallen(cell, tilt):
    size = cell.width
    big = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    big.paste(cell, (size // 2, size // 2))
    big = big.rotate(-tilt, resample=Image.NEAREST, center=(size, size + size // 2))
    part = big.crop(big.getbbox())
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = min(max(0, (size - part.width) // 2 - size // 12), size - part.width)
    out.paste(part, (x, size - 1 - part.height))
    return out


def frames_for(cell):
    s = cell.width
    k = max(1, round(s / 48))
    return {
        "idle": [shifted(cell, 0, 0), shifted(cell, 0, k), shifted(cell, 0, k), shifted(cell, 0, 0)],
        "attack": [shifted(cell, -2 * k, 0), shifted(cell, 3 * k, 0), shifted(cell, k, 0)],
        "hit": [shifted(cell, -3 * k, k), shifted(cell, -2 * k, 0)],
        "defeated": [fallen(cell, 25), fallen(cell, 55), fallen(cell, 85)],
        "victory": [shifted(cell, 0, -2 * k), shifted(cell, 0, 0)],
    }


def build(path):
    key = key_of(path)
    if key not in SIZES:
        print(f"SKIP {path.name}: '{key}' is not 'player' or an opponent in opponents.json")
        return False
    size = SIZES[key]
    img = remove_background(Image.open(path))
    cell = to_cell(img, size, allow_mask=(key == "player"))
    frames = frames_for(cell)
    sheet = Image.new("RGBA", (size * COLUMNS, size * len(ORDER)), (0, 0, 0, 0))
    for row, anim in enumerate(ORDER):
        for col in range(BALANCE["clips"][anim]["frames"]):
            sheet.paste(frames[anim][col], (col * size, row * size))
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{key}.png"
    sheet.save(dest)
    print(f"{path.name} -> {dest.relative_to(ROOT)} ({size}x{size} cells)")
    return True


def main(names):
    files = sorted(p for p in INPUT.iterdir() if p.suffix.lower() in (".png", ".webp", ".jpg", ".jpeg"))
    if names:
        files = [p for p in files if p.stem in names or key_of(p) in names]
    built = [p for p in files if build(p)]
    if built:
        subprocess.run([sys.executable, str(Path(__file__).parent / "validate_sprite.py"),
                        *[str(OUT / f"{key_of(p)}.png") for p in built]])


if __name__ == "__main__":
    main(sys.argv[1:])
