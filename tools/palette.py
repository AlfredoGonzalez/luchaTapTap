"""The 32-color master palette, read from lib/core/palette.dart so the Python
tools and the game can never disagree."""
import re
from pathlib import Path

_DART = Path(__file__).resolve().parent.parent / "lib" / "core" / "palette.dart"


def _snake(name):
    return re.sub(r"([A-Z])", lambda m: "_" + m.group(1).lower(), name)


def load():
    text = _DART.read_text()
    colors = {}
    for name, value in re.findall(r"static const int (\w+) = 0xFF([0-9A-Fa-f]{6});", text):
        v = int(value, 16)
        colors[_snake(name)] = ((v >> 16) & 255, (v >> 8) & 255, v & 255)
    if len(colors) != 32:
        raise SystemExit(f"palette.dart should define 32 colors, found {len(colors)}")
    return colors


PALETTE = load()
# Reserved for masks: shadow, base, light (Visual Style Guide).
MASK_SLOTS = ("night_purple", "violet", "lilac")
