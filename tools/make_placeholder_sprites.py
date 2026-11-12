#!/usr/bin/env python3
"""Draws the placeholder fighter sprite sheets into assets/sprites/placeholder/.

One PNG per sprite key, one row per animation in the order given by
balance.json `animations` (idle, attack, hit, defeated, victory), one column per
frame. Only palette colors, alpha 0 or 255. Final art goes in assets/sprites/
with the same file names; the game prefers it over the placeholder.

Usage: python3 tools/make_placeholder_sprites.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette import PALETTE as P  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "placeholder"
BALANCE = json.loads((ROOT / "assets/data/balance.json").read_text())
ANIMS = BALANCE["animations"]["order"]
COLUMNS = max(BALANCE["animations"]["clips"][a]["frames"] for a in ANIMS)


def c(name):
    return P[name] + (255,)


class Pose:
    def __init__(self, bob=0, lean=0, arm="guard", legs=0, tilt=0):
        self.bob, self.lean, self.arm, self.legs, self.tilt = bob, lean, arm, legs, tilt


POSES = {
    "idle": [Pose(0, 0, "guard"), Pose(1, 0, "guard2"), Pose(1, 0, "guard"), Pose(0, 0, "guard2")],
    "attack": [Pose(0, -2, "back"), Pose(0, 4, "punch", legs=1), Pose(0, 1, "guard")],
    "hit": [Pose(1, -4, "back"), Pose(0, -2, "back")],
    "defeated": [Pose(1, -3, "back", tilt=25), Pose(3, -4, "back", tilt=55), Pose(6, -4, "limp", tilt=85)],
    "victory": [Pose(0, 0, "up"), Pose(1, 0, "up2")],
}


def figure(size, theme, pose):
    """One upright fighter facing right on a size x size transparent canvas."""
    s = size / 48.0
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def r(x0, y0, x1, y1, color):
        d.rectangle(
            [round((x0 + pose.lean) * s), round((y0 + pose.bob) * s),
             round((x1 + pose.lean) * s) - 1, round((y1 + pose.bob) * s) - 1],
            fill=c(color) if isinstance(color, str) else color,
        )

    skin, body, trunks, boots = theme["skin"], theme["body"], theme["trunks"], theme["boots"]
    # Legs and boots.
    spread = pose.legs
    r(15 - spread, 33, 22 - spread, 44, skin)
    r(26 + spread, 33, 33 + spread, 44, skin)
    r(14 - spread, 41, 23 - spread, 46, boots)
    r(25 + spread, 41, 34 + spread, 46, boots)
    # Back arm.
    back_y = {"up": 4, "up2": 6}.get(pose.arm, 18)
    r(9, back_y, 15, back_y + 12 if pose.arm not in ("up", "up2") else back_y + 14, skin)
    # Torso and trunks.
    r(14, 16, 34, 32, body)
    if theme.get("belly"):
        r(18, 20, 30, 29, theme["belly"])
    r(14, 28, 34, 36, trunks)
    r(14, 28, 34, 30, theme.get("belt", trunks))
    # Front arm.
    if pose.arm == "punch":
        r(34, 20, 46, 25, skin)
        r(44, 19, 48, 26, theme.get("glove", skin))
    elif pose.arm == "back":
        r(34, 20, 39, 30, skin)
    elif pose.arm == "limp":
        r(34, 26, 38, 38, skin)
    elif pose.arm in ("up", "up2"):
        r(34, 3 if pose.arm == "up" else 5, 40, 17, skin)
        r(33, 1 if pose.arm == "up" else 3, 41, 6, theme.get("glove", skin))
    else:
        r(34, 17 if pose.arm == "guard" else 19, 41, 23 if pose.arm == "guard" else 25, skin)
        r(40, 16 if pose.arm == "guard" else 18, 44, 25 if pose.arm == "guard" else 27, theme.get("glove", skin))
    # Head.
    head = theme["head"]
    r(17, 3, 31, 16, head[1])
    r(17, 13, 31, 16, head[0])  # shadow band
    r(17, 3, 22, 7, head[2])  # light corner
    r(23, 7, 26, 10, "white")  # eyes
    r(27, 7, 30, 10, "white")
    r(25, 8, 26, 10, "ink")
    r(29, 8, 30, 10, "ink")
    if theme.get("hat"):
        hat = theme["hat"]
        r(11, 1, 37, 4, hat)
        r(17, -4, 31, 2, hat)
    if theme.get("extra"):
        theme["extra"](r)
    return img


def outline(img):
    a = np.array(img)
    opaque = a[:, :, 3] == 255
    pad = np.pad(opaque, 1)
    near = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    edge = near & ~opaque
    a[edge] = list(P["ink"]) + [255]
    return Image.fromarray(a)


def pose_frame(size, theme, pose):
    img = figure(size, theme, pose)
    if pose.tilt:
        # Fall backwards: rotate around the feet, then lie on the floor line.
        big = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
        big.paste(img, (size // 2, size // 2))
        big = big.rotate(-pose.tilt, resample=Image.NEAREST, center=(size, size + size // 2))
        part = big.crop(big.getbbox())
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        x = min(max(0, (size - part.width) // 2 - size // 12), size - part.width)
        img.paste(part, (x, size - 1 - part.height))
    return outline(img)


THEMES = {
    "player": dict(
        size=48, skin=("skin_mid"), body="skin_mid", trunks="lucha_red", boots="white", belt="sun_yellow",
        glove="lucha_red", head=("night_purple", "violet", "lilac"),
    ),
    "opp_mr_aguacate": dict(
        size=48, skin="nopal", body="nopal", belly="lime", trunks="forest", boots="chocolate",
        glove="forest", head=("forest", "nopal", "lime"),
        extra=lambda r: r(21, 21, 27, 27, "chocolate"),
    ),
    "opp_el_tamal_mortal": dict(
        size=48, skin="sand", body="sand", belly="skin_light", trunks="chocolate", boots="skin_deep",
        glove="skin_deep", head=("skin_deep", "sand", "bone"),
        extra=lambda r: (r(14, 22, 34, 23, "skin_deep"), r(14, 26, 34, 27, "skin_deep")),
    ),
    "opp_el_taquero_cosmico": dict(
        size=48, skin="skin_deep", body="burnt_orange", belly="marigold", trunks="navy", boots="royal",
        glove="marigold", head=("wine", "burnt_orange", "marigold"), hat=None,
        extra=lambda r: (r(20, 18, 22, 20, "sun_yellow"), r(26, 24, 28, 26, "sky")),
    ),
    "opp_el_mariachi_furioso": dict(
        size=64, skin="skin_light", body="wine", belly="ink", trunks="ink", boots="chocolate",
        glove="white", head=("skin_deep", "skin_light", "blush"), hat="ink",
        extra=lambda r: [r(22, 18 + 3 * i, 24, 20 + 3 * i, "sun_yellow") for i in range(4)],
    ),
}


def look(skin, body, belly, trunks, boots, glove, head, hat=None, size=48, extra=None):
    return dict(size=size, skin=skin, body=body, belly=belly, trunks=trunks, boots=boots, glove=glove,
                head=head, hat=hat, extra=extra)


# Placeholder looks for the rest of the launch roster. Opponents never use the
# mask-only colors (Night Purple, Violet, Lilac).
THEMES.update({
    "opp_la_abuela_fantasma": look("fog", "white", "bone", "dust", "slate", "fog", ("dust", "fog", "white")),
    "opp_dona_chela_tornado": look("skin_mid", "pink", "blush", "magenta", "wine", "pink", ("wine", "pink", "blush")),
    "opp_el_churro_veloz": look("skin_light", "marigold", "sun_yellow", "chocolate", "burnt_orange", "sand", ("burnt_orange", "marigold", "sun_yellow")),
    "opp_don_pinata": look("skin_mid", "coral", "sun_yellow", "royal", "teal", "sun_yellow", ("wine", "coral", "pink")),
    "opp_la_marchanta_loca": look("skin_deep", "teal", "aqua", "chocolate", "forest", "aqua", ("forest", "teal", "aqua")),
    "opp_el_nopal_gigante": look("nopal", "nopal", "mint", "forest", "chocolate", "lime", ("forest", "nopal", "lime")),
    "opp_el_chicharron_crujiente": look("skin_deep", "skin_deep", "sand", "chocolate", "chocolate", "sand", ("chocolate", "skin_deep", "sand")),
    "opp_la_senora_gelatina": look("aqua", "aqua", "white", "teal", "sky", "white", ("teal", "aqua", "white")),
    "opp_el_tianguista_turbo": look("skin_mid", "royal", "sky", "navy", "white", "sky", ("navy", "royal", "sky")),
    "opp_el_rey_del_tianguis": look("skin_deep", "wine", "marigold", "ink", "chocolate", "marigold", ("chocolate", "skin_deep", "skin_mid"), hat="marigold", size=64),
    "opp_el_astronauta_azteca": look("skin_mid", "white", "fog", "royal", "dust", "sky", ("dust", "white", "sky")),
    "opp_la_catrina_electrica": look("bone", "magenta", "pink", "ink", "wine", "bone", ("ink", "bone", "white"), hat="ink"),
    "opp_el_robot_luchador": look("dust", "dust", "fog", "slate", "ink", "fog", ("slate", "dust", "fog")),
    "opp_el_dragon_de_papel": look("lucha_red", "lucha_red", "sun_yellow", "wine", "wine", "coral", ("wine", "lucha_red", "coral")),
    "opp_el_gallo_de_oro": look("marigold", "marigold", "sun_yellow", "burnt_orange", "burnt_orange", "sun_yellow", ("burnt_orange", "marigold", "sun_yellow")),
    "opp_la_sirena_del_ring": look("teal", "navy", "sky", "teal", "aqua", "aqua", ("navy", "teal", "aqua")),
    "opp_el_emperador_obsidiana": look("slate", "ink", "dust", "wine", "ink", "dust", ("ink", "slate", "dust"), hat="wine", size=64),
})




def sheet(key, theme):
    size = theme["size"]
    cells = Image.new("RGBA", (size * COLUMNS, size * len(ANIMS)), (0, 0, 0, 0))
    for row, anim in enumerate(ANIMS):
        frames = ANIMS and BALANCE["animations"]["clips"][anim]["frames"]
        for col in range(frames):
            pose = POSES[anim][col]
            cells.paste(pose_frame(size, theme, pose), (col * size, row * size))
    return cells


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key, theme in THEMES.items():
        theme = dict(theme)
        for slot in ("skin", "body", "trunks", "boots", "glove", "belt", "belly"):
            pass
        path = OUT / f"{key}.png"
        sheet(key, theme).save(path)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
