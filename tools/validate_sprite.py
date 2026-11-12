#!/usr/bin/env python3
"""Checks sprite sheets against the art rules (Visual Style Guide, Tech Spec 3).

  python3 tools/validate_sprite.py                 # every PNG under assets/sprites
  python3 tools/validate_sprite.py file.png ...    # only these

Rules checked for each sheet:
  * the size is columns x rows of square cells (cell 48 or 64, from the
    opponent's `size` in opponents.json; the player is 48), with one row per
    animation and as many columns as the longest animation (balance.json);
  * alpha is only 0 or 255 (no soft edges);
  * every visible pixel is one of the 32 palette colors;
  * Night Purple, Violet and Lilac (reserved for masks) appear only in the
    player sheet and mask art;
  * cells for frames an animation does not have are empty.
Exit code 1 when anything fails, so it can run in CI.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette import MASK_SLOTS, PALETTE  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "data"
SPRITES = ROOT / "assets" / "sprites"
PLAYER_KEY = "player"


def load_rules():
    balance = json.loads((DATA / "balance.json").read_text())
    anims = balance["animations"]
    order = anims["order"]
    frames = [anims["clips"][a]["frames"] for a in order]
    sizes = {PLAYER_KEY: 48}
    for o in json.loads((DATA / "opponents.json").read_text())["opponents"]:
        sizes[o["sprite"]] = o["size"]
    return order, frames, sizes


def validate(path, order, frames, sizes):
    errors = []
    key = path.stem
    if key not in sizes:
        return [f"{path.name}: no sprite key '{key}' in the data (opponents.json) and it is not '{PLAYER_KEY}'"]
    cell = sizes[key]
    img = Image.open(path)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
        errors.append("the PNG is not RGBA (convert it: transparent background needs an alpha channel)")
    a = np.array(img)
    expected = (cell * max(frames), cell * len(order))
    if (img.width, img.height) != expected:
        errors.append(
            f"size is {img.width}x{img.height}, expected {expected[0]}x{expected[1]} "
            f"({max(frames)} columns x {len(order)} rows of {cell}x{cell} cells)"
        )
        return [f"{path.name}: {e}" for e in errors]
    alpha = a[:, :, 3]
    soft = np.count_nonzero((alpha != 0) & (alpha != 255))
    if soft:
        errors.append(f"{soft} pixels have partial transparency (alpha must be 0 or 255)")
    visible = alpha == 255
    palette = {v: n for n, v in PALETTE.items()}
    rgb = a[:, :, :3]
    packed = (rgb[:, :, 0].astype(np.int64) << 16) | (rgb[:, :, 1].astype(np.int64) << 8) | rgb[:, :, 2]
    palette_packed = {(r << 16) | (g << 8) | b: n for n, (r, g, b) in PALETTE.items()}
    used = np.unique(packed[visible])
    off = [int(v) for v in used if int(v) not in palette_packed]
    if off:
        sample = ", ".join(f"#{v:06X}" for v in off[:5])
        errors.append(f"{len(off)} colors are not in the palette (for example {sample})")
    if key != PLAYER_KEY and not key.startswith("mask_"):
        reserved = [n for n in MASK_SLOTS if any(palette_packed.get(int(v)) == n for v in used)]
        if reserved:
            errors.append(f"uses mask-only colors: {', '.join(reserved)}")
    for row, anim in enumerate(order):
        for col in range(frames[row], max(frames)):
            block = alpha[row * cell:(row + 1) * cell, col * cell:(col + 1) * cell]
            if block.any():
                errors.append(f"row {row + 1} ({anim}) has art in unused column {col + 1}")
    return [f"{path.name}: {e}" for e in errors]


def main(argv):
    order, frames, sizes = load_rules()
    files = [Path(p) for p in argv] if argv else sorted(SPRITES.rglob("*.png"))
    if not files:
        print("no sprites found")
        return 0
    failed = 0
    for f in files:
        problems = validate(f, order, frames, sizes)
        if problems:
            failed += 1
            print("FAIL " + "\n     ".join(problems))
        else:
            print(f"ok   {f.relative_to(ROOT) if f.is_absolute() and ROOT in f.parents else f}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
