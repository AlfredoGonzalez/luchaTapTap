#!/usr/bin/env python3
"""Builds the background and logo images from art/input/.

  LoadingBack.png    -> assets/backgrounds/loading_<0..3>.png (270 x 480, animated:
                        the crowd jumps, the spotlights blink)
  Background_Arena<N> -> assets/backgrounds/arena_<N>_180.png and arena_<N>_270.png
                        (the fight arena of league N; the 270 one is for wide screens)
  logov2.webp        -> assets/ui/logo.png (transparent, palette colors)

All colors are snapped to the 32-color palette. Backgrounds may use the mask
colors (purple); sprites may not.
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette import PALETTE  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
INPUT = ROOT / "art" / "input"
BG = ROOT / "assets" / "backgrounds"
UI = ROOT / "assets" / "ui"
NAMES = list(PALETTE)
TABLE = np.array([PALETTE[n] for n in NAMES], dtype=np.int32)
FRAMES = 4
ARENA_HEIGHT = 270  # tallest arena zone on the biggest canvas


def snap(rgb):
    flat = rgb.reshape(-1, 3).astype(np.int32)
    d = ((flat[:, None, :] - TABLE[None, :, :]) ** 2).sum(axis=2)
    return d.argmin(axis=1).reshape(rgb.shape[:2])  # palette index per pixel


def quantize(img):
    idx = snap(np.array(img.convert("RGB")))
    return idx


def to_rgb(idx):
    return TABLE[idx].astype(np.uint8)


def resize_q(img, size):
    return quantize(img.convert("RGB").resize(size, Image.BOX))


def p(name):
    return NAMES.index(name)


# ---------------------------------------------------------------- loading

DIM = {  # lit color -> dimmer color (spotlight "off")
    "sun_yellow": "marigold", "marigold": "burnt_orange", "bone": "sand", "white": "bone",
    "sand": "skin_deep", "skin_light": "skin_mid", "blush": "pink", "burnt_orange": "wine",
}


def loading_frames(src):
    w, h = 270, 480
    base = resize_q(src, (w, h))
    out = []
    lamp_zone = (slice(int(h * 0.17), int(h * 0.50)),)
    dim_map = np.arange(len(NAMES))
    for a, b in DIM.items():
        dim_map[p(a)] = p(b)
    crowd_back = (int(h * 0.40), int(h * 0.56))   # small heads behind the ring
    crowd_front = (int(h * 0.80), h)              # big heads in front
    group = 9
    jump = [0, 1, 2, 1]
    for f in range(FRAMES):
        idx = base.copy()
        # Spotlights: left ones and right ones blink out of phase.
        zone = idx[lamp_zone[0]]
        left = np.zeros(zone.shape, bool)
        left[:, : w // 2] = True
        off_left = f in (0, 1)
        off_right = f in (2, 3)
        dimmed = dim_map[zone]
        use = (left & off_left) | (~left & off_right)
        idx[lamp_zone[0]] = np.where(use, dimmed, zone)
        # Crowd: column groups jump up and down out of phase.
        for (y0, y1), amp in ((crowd_back, 1), (crowd_front, 2)):
            band = base[y0:y1].copy()
            for gi, x0 in enumerate(range(0, w, group)):
                dy = jump[(f + gi) % 4] * amp // 2 if amp == 1 else jump[(f + gi) % 4] * amp // 2
                dy = min(dy, amp * 2)
                cols = band[:, x0:x0 + group]
                moved = np.empty_like(cols)
                if dy == 0:
                    moved = cols
                else:
                    moved[: cols.shape[0] - dy] = cols[dy:]
                    moved[cols.shape[0] - dy:] = cols[-1:]
                idx[y0:y1, x0:x0 + group] = moved
        out.append(idx)
    return out


# ------------------------------------------------------------------ arena

# Where to cut each league's source picture (left, top, right, bottom): from
# the wall down to a little below the ropes, as in the mockup. The width fixes
# the scale, so a taller cut only adds scenery above the ring.
ARENA_CROPS = {1: (0, 295, 572, 640), 2: (0, 200, 572, 777), 3: (0, 150, 572, 760)}


def arena(src, order):
    crop = src.crop(ARENA_CROPS[order]).convert("RGB")
    for width in (180, 270):
        h = round(crop.height * width / crop.width)
        idx = resize_q(crop, (width, h))
        # Pad the top with the wall color so tall canvases never stretch pixels.
        wall = np.bincount(idx[0]).argmax()
        pad = np.full((max(0, ARENA_HEIGHT - h), width), wall, dtype=idx.dtype)
        idx = np.vstack([pad, idx])[-ARENA_HEIGHT:]
        Image.fromarray(to_rgb(idx), "RGB").save(BG / f"arena_{order}_{width}.png")
        print(f"arena_{order}_{width}.png {width}x{idx.shape[0]}")


# ------------------------------------------------------------------- logo

def logo(src, target_w=150):
    a = np.array(src.convert("RGB")).astype(int)
    h, w = a.shape[:2]
    bg = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), axis=0)
    close = np.abs(a - bg).sum(axis=2) <= 40
    seen = np.zeros((h, w), bool)
    q = deque([(y, x) for x in range(w) for y in (0, h - 1) if close[y, x]] +
              [(y, x) for y in range(h) for x in (0, w - 1) if close[y, x]])
    for y, x in q:
        seen[y, x] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and close[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    rgba = np.dstack([a.astype(np.uint8), np.where(seen, 0, 255).astype(np.uint8)])
    rgba[seen, :3] = PALETTE["ink"]
    img = Image.fromarray(rgba, "RGBA")
    img = img.crop(img.getchannel("A").getbbox())
    th = round(img.height * target_w / img.width)
    img = img.resize((target_w, th), Image.BOX)
    r = np.array(img)
    alpha = np.where(r[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    rgb = to_rgb(snap(r[:, :, :3]))
    rgb[alpha == 0] = 0
    UI.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.dstack([rgb, alpha]), "RGBA").save(UI / "logo.png")
    print(f"logo.png {target_w}x{th}")


def main():
    BG.mkdir(parents=True, exist_ok=True)
    src = INPUT / "LoadingBack.png"
    if src.exists():
        for i, idx in enumerate(loading_frames(Image.open(src))):
            Image.fromarray(to_rgb(idx), "RGB").save(BG / f"loading_{i}.png")
        print("loading_0..3.png 270x480")
    for order in ARENA_CROPS:
        for ext in ("webp", "png"):
            path = INPUT / f"Background_Arena{order}.{ext}"
            if path.exists():
                arena(Image.open(path), order)
                break
    for name in ("logov2.webp", "logov2.png"):
        if (INPUT / name).exists():
            logo(Image.open(INPUT / name))
            break


if __name__ == "__main__":
    main()
