"""Islands' flat-block colour palette, and the colour -> block matcher.

A port of the matcher in IAB.lua, so a converted model is coloured exactly the
way a converted image is. Two things are mirrored and have to stay in step:

    PALETTE  <- IAB.lua IMAGE_PALETTE   (the 91 rows and their RGB)
    to_oklab <- IAB.lua toOklab         (Bjorn Ottosson's sRGB -> OKLab)

It is deliberately not the full 386-block vocabulary. The comment above
IMAGE_PALETTE records why: matching against every block, with colours guessed
from a grey template, is what made images come out wrong. These are the flat
blocks, with their real in-game colours.

`python3 islands_palette.py --check` re-reads IAB.lua and asserts the table
below still matches it.
"""
import math
import re
import pathlib
import sys

# (name, r, g, b, group)
PALETTE = [
    # Solid
    ("whiteBlock", 236, 236, 236, "Solid"),
    ("blackBlock", 30, 30, 32, "Solid"),
    ("redBlock", 200, 45, 45, "Solid"),
    ("blueBlock", 45, 80, 200, "Solid"),
    ("cyanBlock", 55, 190, 205, "Solid"),
    ("pinkBlock", 235, 120, 175, "Solid"),
    ("orangeBlock", 230, 130, 40, "Solid"),
    ("purpleBlock", 130, 55, 180, "Solid"),
    ("yellowBlock", 235, 205, 55, "Solid"),
    ("lightGreenBlock", 120, 200, 90, "Solid"),
    ("darkGreenBlock", 45, 110, 55, "Solid"),
    # Wool
    ("woolWhite", 240, 240, 235, "Wool"),
    ("woolBlack", 45, 45, 48, "Wool"),
    ("woolRed", 190, 60, 55, "Wool"),
    ("woolBlue", 55, 90, 180, "Wool"),
    ("woolCyan", 80, 190, 200, "Wool"),
    ("woolPink", 235, 150, 190, "Wool"),
    ("woolOrange", 225, 145, 60, "Wool"),
    ("woolPurple", 135, 75, 175, "Wool"),
    ("woolYellow", 235, 210, 90, "Wool"),
    ("woolLightGreen", 140, 205, 110, "Wool"),
    ("woolDarkGreen", 60, 120, 65, "Wool"),
    # Clay
    ("clayWhite", 220, 210, 200, "Clay"),
    ("clayBlack", 55, 50, 50, "Clay"),
    ("clayRed", 175, 80, 60, "Clay"),
    ("clayBlue", 90, 110, 160, "Clay"),
    ("clayCyan", 110, 170, 175, "Clay"),
    ("clayPink", 220, 150, 150, "Clay"),
    ("clayOrange", 200, 120, 70, "Clay"),
    ("clayPurple", 140, 100, 150, "Clay"),
    ("clayYellow", 215, 185, 110, "Clay"),
    ("clayLightGreen", 150, 180, 120, "Clay"),
    ("clayDarkGreen", 90, 120, 80, "Clay"),
    # Neon
    ("neonWhite", 255, 255, 255, "Neon"),
    ("neonBlack", 40, 40, 45, "Neon"),
    ("neonRed", 255, 50, 50, "Neon"),
    ("neonBlue", 50, 90, 255, "Neon"),
    ("neonCyan", 40, 240, 240, "Neon"),
    ("neonPink", 255, 90, 200, "Neon"),
    ("neonOrange", 255, 140, 30, "Neon"),
    ("neonPurple", 180, 50, 240, "Neon"),
    ("neonYellow", 250, 240, 40, "Neon"),
    ("neonLightGreen", 120, 255, 90, "Neon"),
    ("neonDarkGreen", 30, 180, 60, "Neon"),
    # Pastel
    ("pastelPinkBlock", 245, 200, 215, "Pastel"),
    ("pastelBlueBlock", 190, 215, 240, "Pastel"),
    ("pastelGreenBlock", 200, 230, 190, "Pastel"),
    ("pastelPurpleBlock", 210, 195, 235, "Pastel"),
    ("pastelYellowBlock", 245, 235, 190, "Pastel"),
    ("pastelOrangeBlock", 245, 210, 175, "Pastel"),
    ("pastelRedBlock", 240, 180, 180, "Pastel"),
    # Wood
    ("woodPlank", 165, 120, 75, "Wood"),
    ("maplePlank", 175, 95, 65, "Wood"),
    ("birchPlank", 220, 205, 165, "Wood"),
    ("pinePlank", 115, 95, 70, "Wood"),
    ("hickoryPlank", 145, 105, 70, "Wood"),
    ("cherryBlossomPlank", 240, 185, 200, "Wood"),
    ("spiritPlank", 95, 200, 180, "Wood"),
    ("bambooBlock", 200, 190, 120, "Wood"),
    ("leavesBlock", 60, 140, 60, "Wood"),
    ("haybaleBlock", 210, 185, 80, "Wood"),
    # Stone
    ("marbleBlock", 235, 235, 240, "Stone"),
    ("slateBlock", 90, 100, 120, "Stone"),
    ("basalt", 60, 60, 66, "Stone"),
    ("granite", 150, 120, 115, "Stone"),
    ("andesite", 140, 140, 145, "Stone"),
    ("diorite", 210, 210, 215, "Stone"),
    ("stone", 140, 140, 145, "Stone"),
    ("cobblestoneBlock", 120, 120, 125, "Stone"),
    ("sandstone", 220, 200, 150, "Stone"),
    ("brick", 170, 80, 60, "Stone"),
    ("prismarineBlock", 70, 160, 150, "Stone"),
    # Natural
    ("grass", 95, 170, 75, "Natural"),
    ("grassDry", 200, 180, 95, "Natural"),
    ("sand", 225, 205, 150, "Natural"),
    ("snow", 245, 245, 250, "Natural"),
    ("ice", 175, 215, 245, "Natural"),
    ("mudBlock", 95, 70, 50, "Natural"),
    ("magmaBlock", 210, 80, 40, "Natural"),
    ("voidBlock", 60, 35, 95, "Natural"),
    # Ore
    ("goldBlock", 235, 200, 70, "Ore"),
    ("ironBlock", 200, 200, 205, "Ore"),
    ("diamondBlock", 150, 225, 235, "Ore"),
    ("coalBlock", 45, 45, 50, "Ore"),
    ("copperBlock", 200, 120, 70, "Ore"),
    ("amethystBlock", 150, 90, 200, "Ore"),
    ("rubyBlock", 190, 40, 60, "Ore"),
    ("opalBlock", 225, 230, 235, "Ore"),
    ("pearlBlock", 235, 230, 225, "Ore"),
    ("boneBlock", 235, 230, 215, "Ore"),
    ("honeycombBlock", 235, 185, 70, "Ore"),]

GROUPS = ["Solid", "Wool", "Clay", "Neon", "Pastel", "Wood", "Stone",
          "Natural", "Ore"]


def _srgb_to_linear(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _cbrt(x):
    return math.copysign(abs(x) ** (1 / 3), x)


def to_oklab(r, g, b):
    """sRGB 0-255 -> OKLab. Perceptual, so nearest here means nearest by eye."""
    lr, lg, lb = _srgb_to_linear(r), _srgb_to_linear(g), _srgb_to_linear(b)

    l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
    m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
    s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb

    l_, m_, s_ = _cbrt(l), _cbrt(m), _cbrt(s)

    return (0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_)


def build(group_names=None):
    """The active palette: [(name, (r,g,b), L, a, b, group)].

    An empty or unmatched filter gives the whole table rather than nothing.
    """
    rows = PALETTE
    if group_names:
        wanted = {g.lower() for g in group_names}
        picked = [e for e in PALETTE if e[4].lower() in wanted]
        if picked:
            rows = picked
    out = []
    for name, r, g, b, group in rows:
        L, a, bb = to_oklab(r, g, b)
        out.append((name, (r, g, b), L, a, bb, group))
    return out


def nearest(pal, r, g, b):
    """The palette entry closest to this colour, by squared OKLab distance."""
    L, a, bb = to_oklab(r, g, b)
    best = None
    best_d = None
    for e in pal:
        dL, da, db = L - e[2], a - e[3], bb - e[4]
        d = dL * dL + da * da + db * db
        if best_d is None or d < best_d:
            best_d, best = d, e
    return best


def choose_limited(pal, colours, limit):
    """Cut the palette to the `limit` entries that actually get used most.

    Two passes, as in IAB.lua: tally which entry every colour would pick, keep
    the most popular, then let the caller match again against just those. A
    low limit gives the poster look.
    """
    if not limit or limit <= 0 or limit >= len(pal):
        return pal
    counts = {}
    for (r, g, b), n in colours.items():
        e = nearest(pal, r, g, b)
        counts[e[0]] = counts.get(e[0], 0) + n
    ranked = sorted(pal, key=lambda e: -counts.get(e[0], 0))
    return ranked[:limit]


class Matcher:
    """nearest(), memoised on the colour so a big model does not re-match
    millions of identical pixels."""

    def __init__(self, pal):
        self.pal = pal
        self._seen = {}

    def block(self, r, g, b):
        key = (r, g, b)
        hit = self._seen.get(key)
        if hit is None:
            hit = nearest(self.pal, r, g, b)[0]
            self._seen[key] = hit
        return hit


def _check():
    """Assert this table still matches IAB.lua's."""
    root = pathlib.Path(__file__).resolve().parent.parent
    src = (root / "IAB.lua").read_text()
    blk = src[src.index("local IMAGE_PALETTE = {"):
              src.index("-- The groups offered in the palette dropdown")]
    lua = [(n, int(r), int(g), int(b), grp) for n, r, g, b, grp in
           re.findall(r'\{\s*"([A-Za-z0-9_]+)",\s*(\d+),(\d+),(\d+),\s*"(\w+)"\s*\}', blk)]
    if lua == PALETTE:
        print(f"palette matches IAB.lua ({len(lua)} entries)")
    else:
        only_lua = [e for e in lua if e not in PALETTE]
        only_py = [e for e in PALETTE if e not in lua]
        print(f"MISMATCH: {len(only_lua)} only in IAB.lua, {len(only_py)} only here")
        for e in (only_lua + only_py)[:10]:
            print("  ", e)
        raise SystemExit(1)

    names = {b["blockType"] for b in
             __import__("json").loads((root / "blockpallete.json").read_text())["blocks"]}
    missing = [e[0] for e in PALETTE if e[0] not in names]
    print("not real Islands blocks:", missing or "none")


if __name__ == "__main__":
    if "--check" in sys.argv:
        _check()
    else:
        print(__doc__)
