#!/usr/bin/env python3
"""Makes the tutorial coach's portrait frames from art/input/coach*.webp.

  coach.webp   (mouth closed) -> assets/ui/coach_0.png
  coach1.webp  (mouth open)   -> assets/ui/coach_1.png

Both are 40 x 40, transparent, palette colors only. The game alternates them
while the coach talks.

  python3 tools/build_coach.py
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_sprites import remove_background, to_cell  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
INPUT = ROOT / "art" / "input"
OUT = ROOT / "assets" / "ui"
SIZE = 40
FRAMES = ["coach", "coach1"]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(FRAMES):
        src = next((p for p in (INPUT / f"{name}.webp", INPUT / f"{name}.png") if p.exists()), None)
        if src is None:
            print(f"missing {name}")
            continue
        cell = to_cell(remove_background(Image.open(src)), SIZE, allow_mask=False)
        dest = OUT / f"coach_{i}.png"
        cell.save(dest)
        print(f"{src.name} -> {dest.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
