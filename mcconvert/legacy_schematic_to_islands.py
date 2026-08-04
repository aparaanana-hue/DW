"""Convert an old MCEdit .schematic (numeric block IDs) into an Islands build.

The pre-1.13 format stores a flat `Blocks` byte array of numeric ids plus a
parallel `Data` array of 4-bit metadata (which carries colour and variant), in
y, z, x order. `.schem` files use a name palette instead - use
schem_to_islands.py for those.

    python3 legacy_schematic_to_islands.py <file.schematic> <OutputName> [--hollow]
"""
import gzip, io, json, os, sys
from collections import Counter

import nbtlib
from blockmap import DROP, islands_name, IDENTITY, FACING_ROT

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Legacy numeric id (and metadata where it matters) -> modern block name, which
# blockmap then resolves to an Islands block. Only ids worth carrying over.
WOOL = ["white", "orange", "magenta", "light_blue", "yellow", "lime", "pink", "gray",
        "light_gray", "cyan", "purple", "blue", "brown", "green", "red", "black"]
WOODS = ["oak", "spruce", "birch", "jungle", "acacia", "dark_oak"]

LEGACY = {
    1: {0: "stone", 1: "granite", 2: "polished_granite", 3: "diorite",
        4: "polished_diorite", 5: "andesite", 6: "polished_andesite"},
    2: "grass_block", 3: "dirt", 4: "cobblestone",
    5: {i: w + "_planks" for i, w in enumerate(WOODS)},
    7: "bedrock", 8: "water", 9: "water", 10: "lava", 11: "lava",
    12: {0: "sand", 1: "red_sand"}, 13: "gravel",
    14: "gold_ore", 15: "iron_ore", 16: "coal_ore",
    17: {i: w + "_log" for i, w in enumerate(WOODS[:4])},
    18: "oak_leaves", 20: "glass", 21: "lapis_ore", 22: "lapis_block",
    24: {0: "sandstone", 1: "chiseled_sandstone", 2: "smooth_sandstone"},
    30: "cobweb",
    35: {i: c + "_wool" for i, c in enumerate(WOOL)},
    41: "gold_block", 42: "iron_block",
    43: {0: "stone", 1: "sandstone", 3: "cobblestone", 4: "bricks",
         5: "stone_bricks", 6: "nether_bricks", 7: "quartz_block"},
    44: {0: "smooth_stone_slab", 1: "sandstone_slab", 3: "cobblestone_slab",
         4: "brick_slab", 5: "stone_brick_slab", 6: "nether_brick_slab",
         7: "quartz_slab"},
    45: "bricks", 47: "bookshelf", 48: "mossy_cobblestone", 49: "obsidian",
    50: "torch", 53: "oak_stairs", 54: "chest", 56: "diamond_ore",
    57: "diamond_block", 58: "crafting_table", 65: "ladder",
    67: "cobblestone_stairs", 73: "redstone_ore", 74: "redstone_ore",
    79: "ice", 80: "snow_block", 82: "clay", 85: "oak_fence",
    86: "pumpkin", 87: "netherrack", 88: "soul_sand", 89: "glowstone",
    91: "jack_o_lantern",
    95: {i: c + "_stained_glass" for i, c in enumerate(WOOL)},
    98: {0: "stone_bricks", 1: "mossy_stone_bricks", 2: "cracked_stone_bricks",
         3: "chiseled_stone_bricks"},
    101: "iron_bars", 102: "glass_pane", 106: "vine",
    108: "brick_stairs", 109: "stone_brick_stairs", 112: "nether_bricks",
    113: "nether_brick_fence", 114: "nether_brick_stairs",
    121: "end_stone", 123: "redstone_lamp", 124: "redstone_lamp",
    125: {i: w + "_planks" for i, w in enumerate(WOODS)},
    126: {i: w + "_slab" for i, w in enumerate(WOODS)},
    128: "sandstone_stairs", 129: "emerald_ore", 133: "emerald_block",
    134: "spruce_stairs", 135: "birch_stairs", 136: "jungle_stairs",
    139: {0: "cobblestone_wall", 1: "mossy_cobblestone_wall"},
    152: "redstone_block",
    155: {0: "quartz_block", 1: "chiseled_quartz_block", 2: "quartz_pillar"},
    156: "quartz_stairs",
    159: {i: c + "_terracotta" for i, c in enumerate(WOOL)},
    160: {i: c + "_stained_glass_pane" for i, c in enumerate(WOOL)},
    161: "acacia_leaves",
    162: {0: "acacia_log", 1: "dark_oak_log"},
    163: "acacia_stairs", 164: "dark_oak_stairs",
    168: {0: "prismarine", 1: "prismarine_bricks", 2: "dark_prismarine"},
    169: "sea_lantern", 170: "hay_block",
    171: {i: c + "_carpet" for i, c in enumerate(WOOL)},
    172: "terracotta", 173: "coal_block", 174: "packed_ice",
    179: "red_sandstone", 180: "red_sandstone_stairs",
    181: "red_sandstone_slab", 182: "red_sandstone_slab",
    198: "end_rod", 201: "purpur_block", 202: "quartz_pillar",
    203: "purpur_stairs", 205: "purpur_slab", 206: "end_stone_bricks",
    208: "dirt_path", 213: "magma_block", 214: "nether_wart_block",
    215: "red_nether_bricks", 216: "bone_block",
    251: {i: c + "_concrete" for i, c in enumerate(WOOL)},
    252: {i: c + "_concrete_powder" for i, c in enumerate(WOOL)},
}


# Pre-1.13 stair metadata: low two bits are the facing, bit 2 flips it upside
# down. Slab metadata uses bit 3 for the top half.
STAIR_IDS = {53, 67, 108, 109, 114, 128, 134, 135, 136, 156, 163, 164, 180, 203}
SLAB_IDS = {44, 126, 182}
STAIR_FACING = {0: "east", 1: "west", 2: "south", 3: "north"}


def orientation(bid, data):
    """(rotation, upperBlock, doubled) for a legacy id/metadata pair."""
    if bid in STAIR_IDS:
        return FACING_ROT[STAIR_FACING[data & 3]], bool(data & 4), False
    if bid in SLAB_IDS:
        return IDENTITY, bool(data & 8), False
    if bid in (43, 125, 181):          # double slabs fill the whole cell
        return IDENTITY, False, True
    if bid in (17, 162):               # logs: bits 2-3 carry the axis
        axis = (data >> 2) & 3
        if axis == 1:
            return (0, 1, 0, 1, 0, 0), False, False
        if axis == 2:
            return (1, 0, 0, 0, 0, 1), False, False
    return IDENTITY, False, False


def modern_name(bid, data):
    e = LEGACY.get(bid)
    if e is None:
        return None
    if isinstance(e, dict):
        e = e.get(data) or e.get(data & 7) or e.get(0)
        if e is None:
            return None
    return "minecraft:" + e


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    src, outname = sys.argv[1], sys.argv[2]
    hollow = "--hollow" in sys.argv[3:]

    raw = open(src, "rb").read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    f = nbtlib.File.from_fileobj(io.BytesIO(raw))
    root = f["Schematic"] if "Schematic" in f else f

    W, H, L = int(root["Width"]), int(root["Height"]), int(root["Length"])
    ids = bytes(bytearray(b & 0xFF for b in root["Blocks"]))
    meta = bytes(bytearray(b & 0xFF for b in root["Data"]))

    blocks = []
    kept = Counter()
    unmapped = Counter()

    # legacy order: index = y*W*L + z*W + x
    for i, bid in enumerate(ids):
        if bid == 0:
            continue
        name = modern_name(bid, meta[i] & 0xF)
        if name is None:
            unmapped[f"id {bid}"] += 1
            continue
        if name == "minecraft:bedrock":
            continue
        target = islands_name(name)
        if target is None:
            if name not in DROP:
                unmapped[name] += 1
            continue
        y = i // (W * L)
        rem = i % (W * L)
        z = rem // W
        x = rem % W
        kept[target] += 1
        rot, upper, doubled = orientation(bid, meta[i] & 0xF)
        px, py, pz = x * 3, y * 3, z * 3
        blocks.append({
            "blockType": target, "upperBlock": upper,
            "cframe": [px, py, pz, *rot], "parts": [],
        })
        if doubled:
            kept[target] += 1
            blocks.append({
                "blockType": target, "upperBlock": True,
                "cframe": [px, py, pz, *rot], "parts": [],
            })

    if not blocks:
        print("nothing converted")
        return

    mnx = min(b["cframe"][0] for b in blocks)
    mny = min(b["cframe"][1] for b in blocks)
    mnz = min(b["cframe"][2] for b in blocks)
    for b in blocks:
        c = b["cframe"]
        c[0] -= mnx
        c[1] -= mny
        c[2] -= mnz

    if hollow:
        occ = {tuple(v // 3 for v in b["cframe"][:3]) for b in blocks}
        sides = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
        before = len(blocks)
        blocks = [b for b in blocks if not all(
            (b["cframe"][0] // 3 + dx, b["cframe"][1] // 3 + dy, b["cframe"][2] // 3 + dz) in occ
            for dx, dy, dz in sides)]
        print(f"hollowed: {before} -> {len(blocks)}")

    os.makedirs(os.path.join(ROOT, "builds"), exist_ok=True)
    out = os.path.join(ROOT, "builds", outname + ".json")
    with open(out, "w") as fh:
        json.dump({"blocks": blocks}, fh)

    print("wrote", out)
    print("blocks:", len(blocks))
    print("schematic size (blocks): %d x %d x %d" % (W, H, L))
    print("\ntop Islands blocks used:")
    for n, c in kept.most_common(20):
        print(f"{c:8d}  {n}")
    if unmapped:
        print("\nUNMAPPED (dropped):", sum(unmapped.values()))
        for n, c in unmapped.most_common(30):
            print(f"{c:8d}  {n}")


if __name__ == "__main__":
    main()
