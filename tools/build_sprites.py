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
REQUIRED = ORDER[:5]  # idle, attack, hit, defeated, victory (kick is optional)
SKILL_CLIPS = BALANCE.get("skillClips", {})
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


def edge_mask(alpha):
    """Opaque pixels that touch a transparent one (the outline)."""
    opaque = alpha == 255
    pad = np.pad(opaque, 1)
    near_empty = ~pad[:-2, 1:-1] | ~pad[2:, 1:-1] | ~pad[1:-1, :-2] | ~pad[1:-1, 2:]
    return opaque & near_empty


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
    # Dark pixels on the outline become Ink (no wine/purple fringes); dark
    # clothing inside the figure keeps its own palette color.
    dark = a[:, :, :3].astype(int).sum(axis=2) < 200
    rgb[dark & edge_mask(alpha)] = PALETTE["ink"]
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


# ---- animation sheets: one 5 x 5 grid file per animation ----------------------
# Files whose name has an animation word (idle, punch/attack, hurt/hit,
# defeated, victory) and the character key (e.g. "player ... idle ... .png")
# are used instead of the single pose. Each is a 5 x 5 grid of frames; these
# frames are picked from each grid (data below), shrunk with one common scale
# so the character keeps its size, and put in the game's sheet layout.
ANIM_WORDS = {"idle": "idle", "punch": "attack", "attack": "attack", "hurt": "hit", "hit": "hit",
              "defeated": "defeated", "victory": "victory", "kick": "kick", "plancha": "plancha",
              "fury": "furia", "lucky": "suerte", "shout": "grito", "llave": "llave"}
PICK = {"idle": [0, 6, 12, 18], "attack": [6, 12, 19], "hit": [8, 12], "defeated": [10, 17, 22],
        "victory": [4, 16], "kick": [6, 9, 12, 17],
        "plancha": [3, 6, 8, 11, 13, 14, 18, 23],
        "furia": [1, 2, 3, 4, 5, 7, 10, 13, 16, 19, 22, 24],
        "suerte": [5, 8, 10, 11, 12, 13, 15, 17, 19, 20, 21, 24],
        "grito": [1, 5, 9, 10, 12, 13, 15, 16, 17, 19, 21, 24],
        "llave": [1, 2, 3, 6, 8, 11, 12, 13, 14, 16, 22, 24]}
GRID = 5


def anim_of(path):
    stem = path.stem.lower()
    for word, anim in ANIM_WORDS.items():
        if word in stem:
            return anim
    return None


def sheet_key(path):
    stem = path.stem.lower()
    if "player" in stem:
        return "player"
    for word in ANIM_WORDS:
        stem = stem.replace(word, "")
    stem = re.sub(r"photoroom|v\d+", "", stem)
    stem = re.sub(r"[^a-z0-9]+", "_", stem).strip("_")
    return stem if stem.startswith("opp_") else "opp_" + stem


def grid_cell(img, index):
    cw = img.width // GRID
    r, c = divmod(index, GRID)
    return img.crop((c * cw, r * cw, (c + 1) * cw, (r + 1) * cw)).convert("RGBA")


def bbox_of(img):
    return img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()


def build_skill_clip(key, name, grid, scale, ref_cell):
    """One row of frames for a skill animation (the player flying across the
    arena for the plancha), in cells of cellWidth x cellHeight from
    balance.json. The grid may be padded (a bigger cell than the other
    sheets): the scale is corrected by comparing its first (ready stance)
    frame with the same stance in a normal sheet."""
    cfg = SKILL_CLIPS[name]
    cw, ch = cfg["cellWidth"], cfg["cellHeight"]
    first = bbox_of(grid_cell(grid, 0))
    ref = bbox_of(ref_cell)
    f = scale * (ref[3] - ref[1]) / (first[3] - first[1])
    ground = first[3]
    out = Image.new("RGBA", (cw * cfg["frames"], ch), (0, 0, 0, 0))
    if cfg["travelFrames"] == 0:
        # Played where the fighter stands: one scale and one anchor (the ready
        # stance's center and feet) for every frame, so the body never jumps;
        # effects outside the cell are cut.
        anchor = (first[0] + first[2]) / 2
        for col, index in enumerate(PICK[name][: cfg["frames"]]):
            cell = grid_cell(grid, index)
            big = cell.resize((max(1, round(cell.width * f)), max(1, round(cell.height * f))), Image.BOX)
            a = np.array(big)
            alpha = np.where(a[:, :, 3] >= 128, 255, 0).astype(np.uint8)
            rgb = snap(a[:, :, :3], True)
            rgb[(a[:, :, :3].astype(int).sum(axis=2) < 200) & edge_mask(alpha)] = PALETTE["ink"]
            rgb[alpha == 0] = 0
            frame = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
            x0 = round(cw / 2 - anchor * f)
            y0 = round(ch - 1 - ground * f)
            tile = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
            tile.paste(frame, (x0, y0), frame)
            out.paste(tile, (col * cw, 0), tile)
        OUT.mkdir(parents=True, exist_ok=True)
        dest = OUT / f"{key}_{name}.png"
        out.save(dest)
        print(f"{key}: {name} -> {dest.relative_to(ROOT)} ({cfg['frames']} frames of {cw}x{ch}, in place)")
        return
    for col, index in enumerate(PICK[name][: cfg["frames"]]):
        cell = grid_cell(grid, index)
        box = bbox_of(cell)
        ff = min(f, (cw - 2) / (box[2] - box[0]), (ch - 2) / (box[3] - box[1]))
        small = cell.resize((max(1, round(cell.width * ff)), max(1, round(cell.height * ff))), Image.BOX)
        a = np.array(small)
        alpha = np.where(a[:, :, 3] >= 128, 255, 0).astype(np.uint8)
        rgb = snap(a[:, :, :3], True)
        rgb[(a[:, :, :3].astype(int).sum(axis=2) < 200) & edge_mask(alpha)] = PALETTE["ink"]
        rgb[alpha == 0] = 0
        frame = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
        nb = bbox_of(frame)
        ox = round((cw - (nb[2] - nb[0])) / 2 - nb[0])
        # Feet stay where they were relative to the ready stance, so jumps rise.
        oy = round((ch - 1) - (ground - box[3]) * ff - nb[3] + (box[3] * ff - nb[3]) * 0)
        oy = min(max(oy - (small.height - nb[3]) * 0, -nb[1]), ch - nb[3])
        out.paste(frame, (col * cw + ox, oy), frame)
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{key}_{name}.png"
    out.save(dest)
    print(f"{key}: {name} -> {dest.relative_to(ROOT)} ({cfg['frames']} frames of {cw}x{ch})")


def build_from_grids(key, files):
    size = SIZES[key]
    allow_mask = key == "player"
    grids = {anim_of(f): Image.open(f) for f in files}
    missing = [a for a in REQUIRED if a not in grids]
    if missing:
        print(f"SKIP {key}: missing animation files for {', '.join(missing)}")
        return False
    # Common scale and anchor from the standing (idle) frames.
    boxes = [bbox_of(grid_cell(grids["idle"], i)) for i in PICK["idle"]]
    height = max(b[3] - b[1] for b in boxes)
    cx = sum((b[0] + b[2]) / 2 for b in boxes) / len(boxes)
    bottom = max(b[3] for b in boxes)
    scale = (size - 4) / height
    # Rows: the five required clips, then the optional ones that have art.
    anims = REQUIRED + [a for a in ORDER[5:] if a in grids]
    out = Image.new("RGBA", (size * COLUMNS, size * len(anims)), (0, 0, 0, 0))
    if key == "player":
        ref = grid_cell(grids["punch" if "punch" in grids else "attack"], 0)
        for name in SKILL_CLIPS:
            if name in grids:
                build_skill_clip(key, name, grids[name], scale, ref)
    for row, anim in enumerate(anims):
        for col, index in enumerate(PICK[anim]):
            cell = grid_cell(grids[anim], index)
            f = scale
            box = bbox_of(cell)
            # A frame wider or taller than the cell (lying down) shrinks to fit.
            f = min(f, (size - 2) / (box[2] - box[0]), (size - 2) / (box[3] - box[1]))
            w, h = max(1, round(cell.width * f)), max(1, round(cell.height * f))
            small = cell.resize((w, h), Image.BOX)
            a = np.array(small)
            alpha = np.where(a[:, :, 3] >= 128, 255, 0).astype(np.uint8)
            rgb = snap(a[:, :, :3], allow_mask)
            rgb[(a[:, :, :3].astype(int).sum(axis=2) < 200) & edge_mask(alpha)] = PALETTE["ink"]
            rgb[alpha == 0] = 0
            frame = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
            # Same anchor as idle (feet on the bottom, body centered); lying or
            # shrunk frames are bottom-aligned and kept inside the cell.
            ox = round(size / 2 - cx * f)
            oy = round(size - 1 - bottom * f)
            if f != scale or anim == "defeated":
                nb = bbox_of(frame)
                ox = round((size - (nb[2] - nb[0])) / 2 - nb[0])
                oy = size - 1 - nb[3]
            nb = bbox_of(frame)
            ox = min(max(ox, -nb[0]), size - nb[2])
            oy = min(max(oy, -nb[1]), size - nb[3])
            out.paste(frame, (col * size + ox, row * size + oy), frame)
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{key}.png"
    out.save(dest)
    print(f"{key}: {len(files)} animation sheets -> {dest.relative_to(ROOT)} ({size}x{size} cells)")
    return True


# ---- extra poses for a single-pose character (bosses) -------------------------
# Next to `<key>.webp`, a boss may have `<key>-defeated.webp` (lying knocked
# out) and `<key>-victory.webp` (celebrating), drawn at the same scale as the
# main pose, and a punch grid (any file whose name has "punch" and starts with
# the character's name). These replace the derived rows.
ATTACK_PICK = {
    "opp_el_mariachi_furioso": (5, [3, 5, 6]),
    "opp_el_rey_del_tianguis": (5, [5, 6, 10]),
    "opp_el_emperador_obsidiana": (7, [9, 22, 24]),
}


def figure_scale(img, size):
    """The scale to_cell uses for [img] (background already removed)."""
    bbox = img.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    return min((size - 8) / w, (size - 4) / h)


def pose_cell(img, scale, size, allow_mask, anchor_x=None):
    """[img] cropped, shrunk by [scale] (less if it would not fit), snapped to
    the palette and placed in a cell with the feet on the bottom. [anchor_x]
    (in source pixels) lands on the cell's center; else it is centered."""
    a_full = img.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    bbox = a_full.getbbox()
    fig = img.crop(bbox)
    f = min(scale, (size - 2) / fig.width, (size - 2) / fig.height)
    w, h = max(1, round(fig.width * f)), max(1, round(fig.height * f))
    small = fig.resize((w, h), Image.BOX)
    a = np.array(small)
    alpha = np.where(a[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    rgb = snap(a[:, :, :3], allow_mask)
    rgb[(a[:, :, :3].astype(int).sum(axis=2) < 200) & edge_mask(alpha)] = PALETTE["ink"]
    rgb[alpha == 0] = 0
    frame = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
    if anchor_x is None:
        x = (size - w) // 2
    else:
        x = round(size / 2 - (anchor_x - bbox[0]) * f)
    x = min(max(x, 0), size - w)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(frame, (x, size - 1 - h), frame)
    return out


def clear_background(path, tol=60):
    """Like remove_background, but also clears background-colored pixels in
    closed gaps (between an arm and the head) that the flood fill misses."""
    src = Image.open(path).convert("RGBA")
    a = np.array(src).astype(np.int32)
    border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    bg = np.median(border, axis=0)
    out = np.array(remove_background(src))
    close = np.abs(a[:, :, :3] - bg).sum(axis=2) <= tol
    out[close, 3] = 0
    return Image.fromarray(out, "RGBA")


def extra_poses(key, size, scale, allow_mask):
    """Rows built from the extra pose files of [key], by animation name."""
    rows = {}
    base = key[len("opp_"):] if key.startswith("opp_") else key
    for p in INPUT.iterdir():
        if p.suffix.lower() not in (".png", ".webp", ".jpg", ".jpeg"):
            continue
        k = key_of(p)
        k = k[len("opp_"):] if k.startswith("opp_") else k
        if not k.startswith(base) or k == base:
            continue
        rest = k[len(base):]
        img = None
        if "defeated" in rest:
            img = clear_background(p)
            # Lying down, the body is as long as it was tall: fill the width.
            ko = pose_cell(img, size, size, allow_mask)
            rows["defeated"] = ("pose", ko)
        elif "victory" in rest:
            img = clear_background(p)
            v = pose_cell(img, scale, size, allow_mask)
            rows["victory"] = ("pose", v)
    # Punch grid: its name has "punch" and starts with the character's name.
    if key in ATTACK_PICK:
        grid_n, picks = ATTACK_PICK[key]
        words = base.split("_")
        for p in INPUT.iterdir():
            stem = re.sub(r"[^a-z0-9]+", "_", p.stem.lower())
            if "punch" in stem and stem.startswith("_".join(words)):
                grid = Image.open(p).convert("RGBA")
                cw = grid.width // grid_n
                cell = lambda i: grid.crop(((i % grid_n) * cw, (i // grid_n) * cw, (i % grid_n + 1) * cw, (i // grid_n + 1) * cw))
                first = cell(0)
                fb = bbox_of(first)
                # The grid's ready stance has the main pose's height in the cell.
                f = (size - 4) / (fb[3] - fb[1])
                anchor = (fb[0] + fb[2]) / 2
                rows["attack"] = ("frames", [pose_cell(cell(i), f, size, allow_mask, anchor_x=anchor) for i in picks])
                break
    return rows


def build(path):
    key = key_of(path)
    if key not in SIZES:
        print(f"SKIP {path.name}: '{key}' is not 'player' or an opponent in opponents.json")
        return False
    size = SIZES[key]
    img = remove_background(Image.open(path))
    cell = to_cell(img, size, allow_mask=(key == "player"))
    frames = frames_for(cell)
    k = max(1, round(size / 48))
    extras = extra_poses(key, size, figure_scale(img, size), key == "player")
    if "defeated" in extras:
        # Two frames of the fall, then the knocked-out pose.
        frames["defeated"] = [fallen(cell, 30), fallen(cell, 60), extras["defeated"][1]]
    if "victory" in extras:
        v = extras["victory"][1]
        frames["victory"] = [shifted(v, 0, -k), v]
    if "attack" in extras:
        frames["attack"] = extras["attack"][1]
    if extras:
        print(f"{key}: own art for {', '.join(sorted(extras))}")
    # A single pose gives the five required rows; the kick row is optional.
    rows = [a for a in ORDER if a in frames]
    sheet = Image.new("RGBA", (size * COLUMNS, size * len(rows)), (0, 0, 0, 0))
    for row, anim in enumerate(rows):
        for col in range(BALANCE["clips"][anim]["frames"]):
            sheet.paste(frames[anim][col], (col * size, row * size))
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{key}.png"
    sheet.save(dest)
    print(f"{path.name} -> {dest.relative_to(ROOT)} ({size}x{size} cells)")
    return True


def main(names):
    files = sorted(p for p in INPUT.iterdir() if p.suffix.lower() in (".png", ".webp", ".jpg", ".jpeg"))
    # Animation grids first: any file with an animation word in its name.
    grids = {}
    for p in files:
        if anim_of(p) and not p.stem.lower().startswith(("loading", "background", "logo")):
            grids.setdefault(sheet_key(p), []).append(p)
    built_keys = []
    for key, fs in grids.items():
        if names and key not in names:
            continue
        if key in SIZES and build_from_grids(key, fs):
            built_keys.append(key)
    skip = {p for fs in grids.values() for p in fs}
    singles = [p for p in files if p not in skip and (not names or p.stem in names or key_of(p) in names)]
    singles = [p for p in singles if key_of(p) not in built_keys]
    built_keys += [key_of(p) for p in singles if build(p)]
    if built_keys:
        subprocess.run([sys.executable, str(Path(__file__).parent / "validate_sprite.py"),
                        *[str(OUT / f"{k}.png") for k in built_keys]])


if __name__ == "__main__":
    main(sys.argv[1:])
