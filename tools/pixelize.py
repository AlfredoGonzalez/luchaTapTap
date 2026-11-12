#!/usr/bin/env python3
"""Turns AI-generated or hand-drawn art into game-ready pixel art.

Two commands:

  cell      one image -> one frame (a cell of 48x48 or 64x64)
  sheet     a folder of frames -> the sprite sheet the game loads

  python3 tools/pixelize.py cell art/source/aguacate/idle_0.png out/idle_0.png --size 48
  python3 tools/pixelize.py sheet out/ assets/sprites/opp_mr_aguacate.png --size 48

`cell` crops to the figure, fits it inside the cell (nearest-neighbor, whole
pixels, feet on the bottom row), snaps every color to the 32-color palette,
makes alpha 0 or 255 and adds a 1-pixel Ink outline. Mask colors (Night Purple,
Violet, Lilac) are kept out of the result unless --mask is given, so only
masks and the player can use them.

`sheet` expects files named <animation>_<n>.png (idle_0.png, attack_2.png ...)
and lays them out one row per animation in the order of balance.json.
Always run tools/validate_sprite.py on the result and look at it: the
conversion is mechanical, the art direction is yours.

Needs Pillow and numpy.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette import MASK_SLOTS, PALETTE  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


def snap(rgb, allowed):
    names = list(allowed)
    table = np.array([PALETTE[n] for n in names], dtype=np.int32)
    flat = rgb.reshape(-1, 3).astype(np.int32)
    # Squared distance to every palette color, pick the nearest.
    d = ((flat[:, None, :] - table[None, :, :]) ** 2).sum(axis=2)
    out = table[d.argmin(axis=1)]
    return out.reshape(rgb.shape).astype(np.uint8)


def outline(a):
    opaque = a[:, :, 3] == 255
    pad = np.pad(opaque, 1)
    near = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    a[near & ~opaque] = list(PALETTE["ink"]) + [255]
    return a


def cell(src, dst, size, allow_mask, no_outline, threshold):
    img = Image.open(src).convert("RGBA")
    bbox = img.getchannel("A").point(lambda v: 255 if v >= threshold else 0).getbbox()
    if bbox is None:
        raise SystemExit(f"{src}: the image has no visible pixels (is the background transparent?)")
    img = img.crop(bbox)
    # Leave room for the outline: it adds a pixel on every side.
    room = size - (0 if no_outline else 2)
    scale = min(room / img.width, room / img.height)
    w, h = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    img = img.resize((w, h), Image.LANCZOS)
    a = np.array(img)
    alpha = np.where(a[:, :, 3] >= threshold, 255, 0).astype(np.uint8)
    allowed = [n for n in PALETTE if allow_mask or n not in MASK_SLOTS]
    rgb = snap(a[:, :, :3], allowed)
    rgb[alpha == 0] = 0
    frame = np.dstack([rgb, alpha])
    canvas = np.zeros((size, size, 4), dtype=np.uint8)
    x = (size - w) // 2
    y = size - h - (0 if no_outline else 1)
    canvas[y:y + h, x:x + w] = frame
    if not no_outline:
        canvas = outline(canvas)
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas).save(dst)
    print(f"{dst}  {size}x{size}")


def sheet(folder, dst, size):
    balance = json.loads((ROOT / "assets/data/balance.json").read_text())["animations"]
    order, clips = balance["order"], balance["clips"]
    columns = max(clips[a]["frames"] for a in order)
    out = Image.new("RGBA", (size * columns, size * len(order)), (0, 0, 0, 0))
    for row, anim in enumerate(order):
        for col in range(clips[anim]["frames"]):
            f = Path(folder) / f"{anim}_{col}.png"
            if not f.exists():
                raise SystemExit(f"missing frame {f}")
            frame = Image.open(f).convert("RGBA")
            if frame.size != (size, size):
                raise SystemExit(f"{f} is {frame.size}, expected {size}x{size}")
            out.paste(frame, (col * size, row * size))
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)
    print(f"{dst}  {out.width}x{out.height}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("cell")
    c.add_argument("source")
    c.add_argument("dest")
    c.add_argument("--size", type=int, choices=(48, 64), default=48)
    c.add_argument("--mask", action="store_true", help="allow the reserved mask colors")
    c.add_argument("--no-outline", action="store_true")
    c.add_argument("--alpha-threshold", type=int, default=128)
    s = sub.add_parser("sheet")
    s.add_argument("folder")
    s.add_argument("dest")
    s.add_argument("--size", type=int, choices=(48, 64), default=48)
    args = p.parse_args()
    if args.cmd == "cell":
        cell(args.source, args.dest, args.size, args.mask, args.no_outline, args.alpha_threshold)
    else:
        sheet(args.folder, args.dest, args.size)


if __name__ == "__main__":
    main()
