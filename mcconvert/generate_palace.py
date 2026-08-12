"""Generate a gothic fantasy palace as an Islands build file.

Procedural, seeded and deterministic: the same seed gives the same palace, so
it can be tweaked and regenerated rather than being a one-off blob.

Everything is laid out in cells and multiplied by 3 on the way out, and every
block goes through Palace.put(), which keys on (cell, half). Two blocks can
never land in one slot, so the file cannot contain the overlaps that come out
of a Minecraft conversion. Stairs take their rotation from blockmap.FACING_ROT,
so they follow the same convention as converted builds, and no stair or full
block is ever flagged upperBlock - only slabs are half-height in Islands.

    python3 generate_palace.py ../builds/solid/PinkPalace.json
"""
import json
import math
import pathlib
import random
import sys

from blockmap import FACING_ROT, IDENTITY, is_slab, seat_slabs

CELL = 3

# ── palette ─────────────────────────────────────────────────────────────────
# Cool greys for the mass, marble for the light trims, pink glass and glowing
# mushroom for the enchanted glow.
DARK = "slateBrick"           # main walls
DARK_ALT = "slateTiles"       # weathering speckle through the walls
DARKEST = "slateSmooth"       # plinths, recesses, shadow lines
CARVED = "slateCarved"        # panel centres
LIGHT = "marbleSmooth"        # cornices, trims, window frames
LIGHT_ALT = "marbleBrick"     # string courses
PILLAR = "marblePillar"       # pilasters, colonnades
ACCENT = "basaltBrick"        # buttress spines, spire ribs
ROOF = "basaltSmooth"         # tower roofs
ROOF_ALT = "slateBlock"       # roof banding
FLOOR = "marbleTiles"         # terraces and walkways
FLOOR_ALT = "andesiteSmooth"  # walkway banding
GLASS = "glassBlockPink"      # cathedral windows
GLASS_PANE = "glassPanePink"  # tracery
GLOW = "glowingMushroomPinkBlock"   # hidden behind the glass
LAMP = "torch"                # path and balcony lanterns
CHAIN = "ironBlock"
WATER = "ice"                 # Islands has no water block; ice reads as the falls
WATER_DEEP = "iceCompact"
MOSS = "mossyBlock"
MOSS_STONE = "stoneBrickMossy"

SLAB_LIGHT = "marbleSlab"
SLAB_DARK = "slateBrickSlab"
SLAB_ROOF = "basaltSlab"

STAIR_LIGHT = "stairMarble"
STAIR_DARK = "stairSlateBrick"
STAIR_ROOF = "basaltStair"

TRUNK = "woodCherryBlossom"
BLOSSOM = ("pastelPinkBlock", "pinkBlock", "clayPink")
GROUND = "grass"

# Facings, as blockmap names. north is -Z.
NORTH, EAST, SOUTH, WEST = "north", "east", "south", "west"
OPPOSITE = {NORTH: SOUTH, SOUTH: NORTH, EAST: WEST, WEST: EAST}


class Palace:
    def __init__(self, seed=7):
        # (x, y, z, upper) -> block dict. The key is the reason nothing can
        # overlap: a cell has one lower half and one upper half, no more.
        self.cells = {}
        self.rng = random.Random(seed)

    # ── primitives ──────────────────────────────────────────────────────────
    def put(self, x, y, z, block, facing=None, upper=False, force=False):
        """Place one block. Later calls lose unless force is set."""
        if block is None:
            return
        slab = is_slab(block)
        upper = bool(upper) and slab
        lo, hi = (x, y, z, False), (x, y, z, True)

        # A full block fills the cell, so it needs both halves. A slab needs
        # its own half, and needs the cell free of any full block - a slab
        # sharing a cell with one is exactly the overlap this file must not
        # contain. force clears whatever is in the way.
        wanted = (lo, hi) if not slab else ((hi,) if upper else (lo,))
        blocking = [k for k in (lo, hi) if k in self.cells]
        if slab and not upper:
            blocking = [k for k in blocking
                        if k == lo or not is_slab(self.cells[k]["blockType"])]
        elif slab and upper:
            blocking = [k for k in blocking
                        if k == hi or not is_slab(self.cells[k]["blockType"])]

        if blocking:
            if not force:
                return
            for k in blocking:
                del self.cells[k]

        key = wanted[0] if slab else lo
        rot = FACING_ROT[facing] if facing else IDENTITY
        self.cells[key] = {
            "blockType": block,
            "upperBlock": upper,
            "cframe": [x * CELL, y * CELL, z * CELL, *rot],
            "parts": [],
        }

    def fill(self, x0, x1, y0, y1, z0, z1, block, facing=None):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    self.put(x, y, z, block, facing)

    def speckle(self, x, y, z, main, alt, chance=0.16):
        """Weathering: mostly `main`, occasionally `alt`."""
        self.put(x, y, z, alt if self.rng.random() < chance else main)

    def disc(self, cx, cz, r, inner=0):
        for x in range(cx - r, cx + r + 1):
            for z in range(cz - r, cz + r + 1):
                d = math.hypot(x - cx, z - cz)
                if inner - 0.5 <= d <= r + 0.35:
                    yield x, z

    def ring(self, cx, cz, r):
        """The cells whose centres straddle a circle of radius r."""
        seen = set()
        steps = max(16, int(2 * math.pi * r * 2))
        for i in range(steps):
            a = 2 * math.pi * i / steps
            x = cx + round(math.cos(a) * r)
            z = cz + round(math.sin(a) * r)
            if (x, z) not in seen:
                seen.add((x, z))
                yield x, z

    def blocks(self):
        return list(self.cells.values())


# ── the build ───────────────────────────────────────────────────────────────
PLATFORM_R = 52
WALL_R = 46
KEEP = 12            # keep half-width, so 25 cells across
BRIDGE_HALF = 4


def platform(p):
    """A circular island: paved top, moulded rim, and a corbelled underside
    that tapers to a point so it reads as floating rather than sliced off."""
    # paved top, banded in rings so it is not one flat sheet
    for x, z in p.disc(0, 0, PLATFORM_R):
        d = math.hypot(x, z)
        if d > PLATFORM_R - 1.2:
            p.put(x, 0, z, LIGHT)
        elif int(d) % 7 in (0, 1):
            p.put(x, 0, z, FLOOR_ALT)
        else:
            p.speckle(x, 0, z, FLOOR, LIGHT_ALT, 0.10)
    # soil under the paving, so the rim has thickness
    for x, z in p.disc(0, 0, PLATFORM_R):
        p.speckle(x, -1, z, DARK, DARK_ALT)

    # moulded rim: a cornice of stairs facing out, then the taper
    for x, z in p.ring(0, 0, PLATFORM_R):
        p.put(x, 1, z, LIGHT)
    for x, z in p.ring(0, 0, PLATFORM_R + 1):
        p.put(x, 0, z, SLAB_LIGHT, upper=True)

    depth = 0
    r = PLATFORM_R
    while r > 2:
        depth += 1
        r -= 1 if depth % 2 else 2
        y = -1 - depth
        for x, z in p.disc(0, 0, r, inner=max(0, r - 2)):
            p.speckle(x, y, z, DARKEST if depth % 5 == 0 else DARK, DARK_ALT)
    # close the point
    for y in range(-1 - depth, -1 - depth - 3, -1):
        p.put(0, y, 0, DARKEST)


def curtain_wall(p):
    """A low battlemented wall around the terrace, with pilasters and lamps."""
    for i, (x, z) in enumerate(p.ring(0, 0, WALL_R)):
        # leave the gate open where the bridge lands
        if z < -WALL_R + 6 and abs(x) <= BRIDGE_HALF + 2:
            continue
        for y in range(1, 4):
            p.speckle(x, y, z, DARK, DARK_ALT)
        p.put(x, 4, z, SLAB_LIGHT, upper=True)
        if i % 4 == 0:                      # merlon
            p.put(x, 4, z, LIGHT, force=True)
            p.put(x, 5, z, DARKEST)
        if i % 12 == 0:                     # lamp post
            for y in range(4, 7):
                p.put(x, y, z, PILLAR, force=True)
            p.put(x, 7, z, GLOW, force=True)
            p.put(x, 8, z, SLAB_LIGHT, upper=True, force=True)


def bridge(p):
    """The approach: a paved span on arched piers, railed and lit."""
    z_start, z_end = -PLATFORM_R - 1, -PLATFORM_R - 34
    for z in range(z_end, z_start + 1):
        for x in range(-BRIDGE_HALF, BRIDGE_HALF + 1):
            if abs(x) == BRIDGE_HALF:
                p.put(x, 0, z, LIGHT)
                for y in range(1, 3):
                    p.put(x, y, z, DARK)
                p.put(x, 3, z, SLAB_LIGHT, upper=True)
            elif abs(x) == BRIDGE_HALF - 1:
                p.put(x, 0, z, FLOOR_ALT)
            else:
                p.speckle(x, 0, z, FLOOR, LIGHT_ALT, 0.08)
            p.speckle(x, -1, z, DARK, DARK_ALT)

        # lamps along the rail
        if (z - z_end) % 8 == 0:
            for sx in (-BRIDGE_HALF, BRIDGE_HALF):
                for y in range(3, 6):
                    p.put(sx, y, z, PILLAR, force=True)
                p.put(sx, 6, z, GLOW, force=True)
                p.put(sx, 7, z, SLAB_LIGHT, upper=True, force=True)

        # piers with pointed arches between them
        if (z - z_end) % 11 == 0:
            for x in range(-BRIDGE_HALF, BRIDGE_HALF + 1):
                for y in range(-2, -14, -1):
                    inset = (abs(y) - 2) // 5
                    if abs(x) >= BRIDGE_HALF - 1 - inset:
                        p.speckle(x, y, z, DARK, DARKEST, 0.2)
            for k in range(1, 5):
                for sx in (-1, 1):
                    p.put(sx * (BRIDGE_HALF - k + 1), -1 - k, z,
                          STAIR_DARK, EAST if sx < 0 else WEST)


def window(p, x, y, z, facing, height=5, w=1):
    """A pointed light: glass with a hidden glow behind it and a stone frame."""
    dx, dz = FACE_STEP[facing]
    for k in range(height):
        for o in range(-w, w + 1):
            ox, oz = (o, 0) if dx == 0 else (0, o)
            # taper to a point at the top two courses
            if k >= height - 2 and abs(o) > max(0, w - (k - (height - 3))):
                continue
            p.put(x + ox, y + k, z + oz, GLASS, force=True)
            # glow tucked behind, inside the wall
            p.put(x + ox - dx, y + k, z + oz - dz, GLOW)
    # tracery: a mullion up the middle of the wider lights, and a transom
    if w >= 1:
        for k in range(height - 2):
            p.put(x, y + k, z, GLASS_PANE, force=True)
        for o in range(-w, w + 1):
            ox, oz = (o, 0) if dx == 0 else (0, o)
            p.put(x + ox, y + height - 3, z + oz, GLASS_PANE, force=True)

    # frame
    for k in range(-1, height + 1):
        for o in (-w - 1, w + 1):
            ox, oz = (o, 0) if dx == 0 else (0, o)
            p.put(x + ox, y + k, z + oz, LIGHT, force=True)
    for o in range(-w - 1, w + 2):
        ox, oz = (o, 0) if dx == 0 else (0, o)
        p.put(x + ox, y - 1, z + oz, LIGHT, force=True)
        p.put(x + ox, y + height, z + oz, LIGHT, force=True)
        p.put(x + ox, y + height + 1, z + oz, SLAB_LIGHT, upper=True)


FACE_STEP = {NORTH: (0, -1), SOUTH: (0, 1), EAST: (1, 0), WEST: (-1, 0)}


def keep_storey(p, half, y0, y1, window_every=6, win_h=5):
    """One stacked section of the keep: walls with pilasters, recessed panels,
    pointed windows, and a cornice on top. Nothing is left flat."""
    for y in range(y0, y1 + 1):
        for t in range(-half, half + 1):
            for sign in (-1, 1):
                # the two wall planes, walked as (moving coord, fixed coord)
                for x, z, facing in ((t, sign * half, SOUTH if sign > 0 else NORTH),
                                     (sign * half, t, EAST if sign > 0 else WEST)):
                    pilaster = (t + half) % window_every == 0 or abs(t) == half
                    if pilaster:
                        p.put(x, y, z, PILLAR)
                    elif (y - y0) % 5 == 0:
                        p.put(x, y, z, LIGHT_ALT)      # string course
                    elif 1 <= (t + half) % window_every <= 2:
                        p.put(x, y, z, CARVED)         # recessed panel
                    else:
                        p.speckle(x, y, z, DARK, DARK_ALT)

    # An inner skin one cell in, so the walls have thickness. Without it a
    # recess or a window reveal is a hole straight through a paper wall.
    inner = half - 1
    for y in range(y0, y1 + 1):
        for t in range(-inner, inner + 1):
            for sign in (-1, 1):
                p.put(t, y, sign * inner, DARKEST if (y - y0) % 5 == 0 else DARK)
                p.put(sign * inner, y, t, DARKEST if (y - y0) % 5 == 0 else DARK)

    # windows, centred in each bay, on all four faces
    span = range(-half + window_every, half - 2, window_every)
    for t in span:
        for sign in (-1, 1):
            window(p, t, y0 + 2, sign * half, SOUTH if sign > 0 else NORTH, win_h)
            window(p, sign * half, y0 + 2, t, EAST if sign > 0 else WEST, win_h)

    # cornice: a light band, an oversailing course of stairs, a slab lip
    for t in range(-half - 1, half + 2):
        for sign in (-1, 1):
            for x, z, out in ((t, sign * (half + 1), SOUTH if sign > 0 else NORTH),
                              (sign * (half + 1), t, EAST if sign > 0 else WEST)):
                p.put(x, y1 + 1, z, STAIR_LIGHT, OPPOSITE[out])
                p.put(x, y1 + 2, z, SLAB_LIGHT, upper=True)
    for t in range(-half, half + 1):
        for sign in (-1, 1):
            p.put(t, y1 + 1, sign * half, LIGHT)
            p.put(sign * half, y1 + 1, t, LIGHT)


def balcony(p, cx, cz, y, r=3, facing=SOUTH):
    """A corbelled terrace hanging off a wall, railed and lamplit."""
    for x in range(cx - r, cx + r + 1):
        for z in range(cz - r, cz + r + 1):
            if math.hypot(x - cx, z - cz) > r + 0.3:
                continue
            p.put(x, y, z, FLOOR, force=True)
            edge = math.hypot(x - cx, z - cz) > r - 0.7
            if edge:
                p.put(x, y + 1, z, PILLAR)
                p.put(x, y + 2, z, SLAB_LIGHT, upper=True)
    # corbels underneath
    for x in range(cx - r + 1, cx + r):
        p.put(x, y - 1, cz + r - 1, STAIR_LIGHT, facing)
    p.put(cx, y + 1, cz + r - 1, GLOW, force=True)
    # chains hanging from the corbels
    for x in (cx - r + 1, cx + r - 1):
        for k in range(1, 6):
            p.put(x, y - 1 - k, cz + r - 1, CHAIN)
        p.put(x, y - 7, cz + r - 1, GLOW)


def tower(p, cx, cz, r, y0, y1, spire=14, band=6):
    """A round tower with banded courses, arrow lights, and a steep spire."""
    for y in range(y0, y1 + 1):
        for x, z in p.ring(cx, cz, r):
            if (y - y0) % band == 0:
                p.put(x, y, z, LIGHT_ALT)
            elif (y - y0) % band == 1:
                p.put(x, y, z, DARKEST)
            else:
                p.speckle(x, y, z, DARK, DARK_ALT)
        # ribs on the cardinal points, so the drum is not a smooth tube
        for dx, dz in ((r, 0), (-r, 0), (0, r), (0, -r)):
            p.put(cx + dx, y, cz + dz, PILLAR, force=True)

    # tall lights on the four faces, upper half of the drum
    for facing, (dx, dz) in FACE_STEP.items():
        wx, wz = cx + dx * r, cz + dz * r
        window(p, wx, y0 + (y1 - y0) // 2, wz, facing, height=4, w=0)

    # machicolated head: oversailing stairs, then a walkway
    for x, z in p.ring(cx, cz, r + 1):
        a = math.atan2(z - cz, x - cx)
        facing = (EAST if abs(math.cos(a)) > abs(math.sin(a)) and math.cos(a) > 0
                  else WEST if abs(math.cos(a)) > abs(math.sin(a))
                  else SOUTH if math.sin(a) > 0 else NORTH)
        p.put(x, y1 + 1, z, STAIR_LIGHT, OPPOSITE[facing])
        p.put(x, y1 + 2, z, LIGHT)
    for x, z in p.disc(cx, cz, r):
        p.put(x, y1 + 3, z, FLOOR)

    # spire: a cone of stairs over a ribbed core, finial on top
    for k in range(spire):
        rr = max(0.0, r * (1 - k / spire))
        if rr < 0.6:
            break
        y = y1 + 4 + k
        for x, z in p.ring(cx, cz, rr):
            a = math.atan2(z - cz, x - cx)
            facing = (EAST if abs(math.cos(a)) > abs(math.sin(a)) and math.cos(a) > 0
                      else WEST if abs(math.cos(a)) > abs(math.sin(a))
                      else SOUTH if math.sin(a) > 0 else NORTH)
            p.put(x, y, z, STAIR_ROOF if k % 4 else ROOF_ALT, OPPOSITE[facing])
        for dx, dz in ((int(rr), 0), (-int(rr), 0), (0, int(rr)), (0, -int(rr))):
            p.put(cx + dx, y, cz + dz, ACCENT, force=True)
    top = y1 + 4 + spire
    for k in range(3):
        p.put(cx, top + k, cz, PILLAR, force=True)
    p.put(cx, top + 3, cz, GLOW, force=True)
    p.put(cx, top + 4, cz, SLAB_LIGHT, upper=True, force=True)


def buttress(p, x0, z0, x1, z1, y_top, y_bot):
    """A flying buttress: an outer pier and a raking arch back to the wall."""
    steps = max(abs(x1 - x0), abs(z1 - z0))
    if steps == 0:
        return
    # pier
    for y in range(1, y_bot + 1):
        taper = (y * 2) // max(1, y_bot)
        p.speckle(x1, y, z1, DARK, DARKEST, 0.25)
        for d in range(1, 3 - taper):
            p.put(x1 + (1 if x1 else 0) * d, y, z1 + (1 if z1 else 0) * d, DARK)
    p.put(x1, y_bot + 1, z1, LIGHT)
    for k in range(3):
        p.put(x1, y_bot + 2 + k, z1, PILLAR)
    p.put(x1, y_bot + 5, z1, GLOW)
    p.put(x1, y_bot + 6, z1, SLAB_LIGHT, upper=True)

    # the arch itself, rising as it returns to the wall
    for i in range(steps + 1):
        f = i / steps
        x = round(x0 + (x1 - x0) * f)
        z = round(z0 + (z1 - z0) * f)
        y = round(y_top - (y_top - y_bot) * (f ** 1.7))
        p.put(x, y, z, ACCENT, force=True)
        p.put(x, y - 1, z, SLAB_DARK, upper=True)
        if i % 3 == 0:
            p.put(x, y + 1, z, LIGHT)


def grand_entrance(p):
    """A vaulted portal on the bridge side, under a rose of pink glass."""
    z = -KEEP
    for k in range(9):                      # the pointed opening
        w = max(0, 5 - (k * k) // 9)
        for x in range(-w, w + 1):
            p.put(x, 1 + k, z, None)
            p.cells.pop((x, 1 + k, z, False), None)
        for sx in (-w - 1, w + 1):
            p.put(sx, 1 + k, z, LIGHT, force=True)
            p.put(sx, 1 + k, z - 1, PILLAR, force=True)
    # recessed archivolts
    for d in range(1, 4):
        for k in range(9):
            w = max(0, 5 - (k * k) // 9)
            for sx in (-w - 1 - d, w + 1 + d):
                p.put(sx, 1 + k, z, DARKEST if d % 2 else LIGHT, force=True)
    # rose window above the door
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            d = math.hypot(dx, dy)
            if d <= 4.2:
                p.put(dx, 15 + dy, z, GLASS if d <= 3.2 else LIGHT, force=True)
                if d <= 3.2:
                    p.put(dx, 15 + dy, z + 1, GLOW)
    # ceremonial stair down to the terrace
    for k in range(4):
        for x in range(-6, 7):
            p.put(x, 1 - 0, z - 1 - k, STAIR_LIGHT, NORTH)
            p.put(x, 0, z - 1 - k, FLOOR)


def cloister(p, r=36, y=1, h=6):
    """An open arcade ringing the terrace: piers, pointed arches between them,
    a vaulted walkway behind, and a parapet over the top."""
    piers = []
    for i, (x, z) in enumerate(p.ring(0, 0, r)):
        if z < -r + 8 and abs(x) <= BRIDGE_HALF + 3:
            continue           # leave the gate approach clear
        if i % 5 == 0:
            piers.append((x, z))

    for x, z in piers:
        a = math.atan2(z, x)
        ix, iz = round(x - math.cos(a) * 3), round(z - math.sin(a) * 3)
        for k in range(h):
            p.put(x, y + k, z, PILLAR if k else DARKEST)
            p.put(ix, y + k, iz, PILLAR if k else DARKEST)
        # capital, then the vault back to the inner pier
        p.put(x, y + h, z, LIGHT)
        p.put(ix, y + h, iz, LIGHT)
        for t in range(4):
            mx = round(x - math.cos(a) * t)
            mz = round(z - math.sin(a) * t)
            p.put(mx, y + h + 1, mz, SLAB_LIGHT, upper=True)
            p.put(mx, y + h + 2, mz, FLOOR)
        p.put(x, y + h + 3, z, LIGHT)
        p.put(x, y + h + 4, z, SLAB_LIGHT, upper=True)

    # the arches spanning between neighbouring piers
    for (x0, z0), (x1, z1) in zip(piers, piers[1:] + piers[:1]):
        if math.hypot(x1 - x0, z1 - z0) > 8:
            continue
        steps = max(abs(x1 - x0), abs(z1 - z0))
        for i in range(1, steps):
            f = i / steps
            mx = round(x0 + (x1 - x0) * f)
            mz = round(z0 + (z1 - z0) * f)
            rise = int(round(2 * math.sin(math.pi * f)))
            p.put(mx, y + h - rise, mz, LIGHT)
            p.put(mx, y + h - rise + 1, mz, STAIR_LIGHT,
                  NORTH if abs(mz) > abs(mx) else EAST)
            p.put(mx, y + h + 3, mz, DARK)
            p.put(mx, y + h + 4, mz, SLAB_LIGHT, upper=True)
        # paved walkway under the arcade
        for t in range(1, 4):
            p.put(round(x0 - math.cos(math.atan2(z0, x0)) * t), y - 1,
                  round(z0 - math.sin(math.atan2(z0, x0)) * t), FLOOR, force=True)


def islet(p, cx, cz, r, y):
    """A smaller rock floating off the main island, wooded and lit."""
    for x, z in p.disc(cx, cz, r):
        p.put(x, y, z, GROUND, force=True)
        p.speckle(x, y - 1, z, DARK, MOSS_STONE, 0.3)
    d = 0
    rr = r
    while rr > 1:
        d += 1
        rr -= 1 if d % 2 else 2
        for x, z in p.disc(cx, cz, rr, inner=max(0, rr - 2)):
            p.speckle(x, y - 1 - d, z, DARK, DARK_ALT, 0.2)
    for _ in range(max(1, r // 2)):
        tx = cx + p.rng.randint(-r + 2, r - 2)
        tz = cz + p.rng.randint(-r + 2, r - 2)
        cherry_tree(p, tx, tz, p.rng.randint(5, 8))
    for x, z in p.ring(cx, cz, r - 1):
        if p.rng.random() < 0.12:
            p.put(x, y + 1, z, PILLAR, force=True)
            p.put(x, y + 2, z, GLOW, force=True)


def cascades(p):
    """Water spilling off the rim into basins below. Islands has no water
    block, so the falls and pools are ice - the closest thing to it."""
    for a_deg in (35, 145, 215, 325):
        a = math.radians(a_deg)
        ex, ez = round(math.cos(a) * (PLATFORM_R - 1)), round(math.sin(a) * (PLATFORM_R - 1))
        # a notch in the rim for the water to leave by
        for dx in (-2, -1, 0, 1, 2):
            ox, oz = (dx, 0) if abs(math.cos(a)) < abs(math.sin(a)) else (0, dx)
            p.put(ex + ox, 0, ez + oz, WATER, force=True)
            p.put(ex + ox, -1, ez + oz, WATER_DEEP, force=True)
        # the fall, drifting outward as it drops
        for k in range(1, 26):
            f = k / 25
            fx = round(ex + math.cos(a) * f * 5)
            fz = round(ez + math.sin(a) * f * 5)
            for dx in (-1, 0, 1):
                ox, oz = (dx, 0) if abs(math.cos(a)) < abs(math.sin(a)) else (0, dx)
                p.put(fx + ox, -1 - k, fz + oz, WATER if k % 3 else WATER_DEEP, force=True)
        # basin at the foot
        bx, bz = round(ex + math.cos(a) * 5), round(ez + math.sin(a) * 5)
        for x, z in p.disc(bx, bz, 6):
            p.put(x, -27, z, WATER_DEEP, force=True)
            p.put(x, -28, z, MOSS)
        for x, z in p.ring(bx, bz, 7):
            p.put(x, -27, z, MOSS_STONE, force=True)
            p.put(x, -26, z, MOSS)


def bastion(p, a_deg, r=4):
    """A drum bastion set into the curtain wall."""
    a = math.radians(a_deg)
    cx, cz = round(math.cos(a) * WALL_R), round(math.sin(a) * WALL_R)
    tower(p, cx, cz, r, 1, 12, spire=10, band=4)


def cherry_tree(p, x, z, h):
    """Trunk, a couple of limbs, and a loose pink canopy."""
    for y in range(1, h + 1):
        p.put(x, y, z, TRUNK)
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        if p.rng.random() < 0.6:
            p.put(x + dx, h - 1, z + dz, TRUNK)
    r = 3 if h < 7 else 4
    for dx in range(-r, r + 1):
        for dy in range(-1, r):
            for dz in range(-r, r + 1):
                d = math.hypot(dx, dy * 1.5, dz)
                if d <= r + p.rng.random() * 0.8 - 0.4:
                    p.put(x + dx, h + dy, z + dz,
                          BLOSSOM[p.rng.randrange(len(BLOSSOM))])


def gardens(p):
    """Trees, lanterned walkways and flower beds on the open terrace."""
    taken = []

    def clear(x, z, pad):
        if math.hypot(x, z) > PLATFORM_R - 5 or math.hypot(x, z) < 20:
            return False
        if abs(x) <= BRIDGE_HALF + 3 and z < -20:
            return False
        return all(math.hypot(x - ox, z - oz) > pad for ox, oz in taken)

    for _ in range(6000):
        if len(taken) >= 300:
            break
        x = p.rng.randint(-PLATFORM_R, PLATFORM_R)
        z = p.rng.randint(-PLATFORM_R, PLATFORM_R)
        if not clear(x, z, 6):
            continue
        taken.append((x, z))
        for dx in range(-3, 4):
            for dz in range(-3, 4):
                d = math.hypot(dx, dz)
                if d <= 2.2:
                    p.put(x + dx, 0, z + dz, GROUND, force=True)
                elif d <= 3.2:
                    # a kerbed bed of blossom around the roots
                    p.put(x + dx, 0, z + dz, MOSS, force=True)
                    if p.rng.random() < 0.35:
                        p.put(x + dx, 1, z + dz,
                              BLOSSOM[p.rng.randrange(len(BLOSSOM))])
        cherry_tree(p, x, z, p.rng.randint(5, 9))

    # ring walkway with lanterns
    for i, (x, z) in enumerate(p.ring(0, 0, 30)):
        p.put(x, 0, z, FLOOR_ALT, force=True)
        if i % 9 == 0:
            for y in range(1, 4):
                p.put(x, y, z, PILLAR, force=True)
            p.put(x, 4, z, GLOW, force=True)
            p.put(x, 5, z, SLAB_LIGHT, upper=True, force=True)

    # radial paths from the keep to the ring
    for a in range(8):
        ang = math.pi * 2 * a / 8 + math.pi / 8
        for t in range(16, 31):
            x, z = round(math.cos(ang) * t), round(math.sin(ang) * t)
            for o in (-1, 0, 1):
                p.put(x + o, 0, z, FLOOR, force=True)


def build(seed=7):
    p = Palace(seed)

    platform(p)
    curtain_wall(p)
    bridge(p)

    # the keep: three stacked sections, each stepped in
    keep_storey(p, KEEP, 1, 16, window_every=6, win_h=6)
    keep_storey(p, KEEP - 2, 19, 32, window_every=5, win_h=5)
    keep_storey(p, KEEP - 4, 35, 46, window_every=4, win_h=4)

    # terraces on the setbacks, so each section has a walkable ledge
    for half, y in ((KEEP - 1, 18), (KEEP - 3, 34)):
        for x in range(-half, half + 1):
            for z in range(-half, half + 1):
                if max(abs(x), abs(z)) >= half - 1:
                    p.put(x, y, z, FLOOR)
                    if max(abs(x), abs(z)) == half:
                        p.put(x, y + 1, z, SLAB_LIGHT, upper=True)

    # Floors inside the keep, and a spiral stair climbing the whole height.
    # It is hidden from outside, but the brief asked for a genuine building.
    for half, y in ((KEEP - 1, 1), (KEEP - 1, 9), (KEEP - 1, 17),
                    (KEEP - 3, 25), (KEEP - 3, 33), (KEEP - 5, 41)):
        for x in range(-half + 1, half):
            for z in range(-half + 1, half):
                if math.hypot(x, z) < 5:
                    continue          # the stairwell
                p.put(x, y, z, FLOOR if (x + z) % 2 else FLOOR_ALT)
    for k in range(1, 46):
        a = k * math.pi / 6
        sx, sz = round(math.cos(a) * 4), round(math.sin(a) * 4)
        facing = (EAST if abs(math.cos(a)) > abs(math.sin(a)) and math.cos(a) > 0
                  else WEST if abs(math.cos(a)) > abs(math.sin(a))
                  else SOUTH if math.sin(a) > 0 else NORTH)
        p.put(sx, k, sz, STAIR_LIGHT, facing, force=True)
        p.put(sx, k - 1, sz, LIGHT, force=True)
        p.put(0, k, 0, PILLAR, force=True)

    grand_entrance(p)

    # corner turrets hugging the keep, and outer towers on the terrace
    for sx in (-1, 1):
        for sz in (-1, 1):
            tower(p, sx * KEEP, KEEP * sz, 3, 1, 40, spire=12, band=5)
            tower(p, sx * 30, sz * 30, 5, 1, 22, spire=14, band=6)
    # gate towers flanking the bridge landing
    for sx in (-1, 1):
        tower(p, sx * 11, -38, 4, 1, 18, spire=12, band=5)

    # flying buttresses from the keep out to piers on the terrace
    for sx in (-1, 1):
        for t in (-6, 6):
            buttress(p, sx * (KEEP - 4), t, sx * 20, t, 40, 12)
            buttress(p, t, sx * (KEEP - 4), t, sx * 20, 40, 12)

    # royal balconies on the upper sections
    for sx in (-1, 1):
        balcony(p, sx * (KEEP - 3), 0, 33, r=3, facing=EAST if sx > 0 else WEST)
    balcony(p, 0, KEEP - 1, 33, r=4, facing=SOUTH)

    # the central spire, crowning everything
    tower(p, 0, 0, 6, 47, 62, spire=20, band=6)

    # a stepped-down outer terrace, so the island edge is not one clean drop
    for step in (1, 2, 3):
        rr = PLATFORM_R - 2 - step * 2
        for x, z in p.ring(0, 0, rr):
            if z < -rr + 8 and abs(x) <= BRIDGE_HALF + 3:
                continue
            p.put(x, 0, z, LIGHT, force=True)
            p.put(x, 1, z, SLAB_LIGHT, upper=True)

    cloister(p)
    for a in (60, 120, 240, 300):
        bastion(p, a)
    cascades(p)
    # satellite rocks, so the palace sits in an archipelago rather than alone
    for i, (ang, dist, rr, yy) in enumerate((
            (20, 74, 9, -4), (95, 82, 7, -9), (168, 70, 11, -2),
            (250, 88, 8, -12), (300, 76, 10, -6))):
        a = math.radians(ang)
        islet(p, round(math.cos(a) * dist), round(math.sin(a) * dist), rr, yy)
    gardens(p)
    return p


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                       else "../builds/solid/PinkPalace.json")
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    p = build(seed)
    blocks = p.blocks()

    # shift so the whole thing sits at or above y = 0, like a converted build
    miny = min(b["cframe"][1] for b in blocks)
    minx = min(b["cframe"][0] for b in blocks)
    minz = min(b["cframe"][2] for b in blocks)
    for b in blocks:
        b["cframe"][0] -= minx
        b["cframe"][1] -= miny
        b["cframe"][2] -= minz

    # slabs record their half by position, not by the flag alone
    seat_slabs(blocks)

    out.write_text(json.dumps({"blocks": blocks}, separators=(",", ":")))

    import collections
    kinds = collections.Counter(b["blockType"] for b in blocks)
    print(f"{len(blocks):,} blocks -> {out}")
    print(f"{len(kinds)} block types, top:")
    for k, n in kinds.most_common(12):
        print(f"   {k:26} {n:,}")


if __name__ == "__main__":
    main()
