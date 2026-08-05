"""Split Castle World into one Islands build file per castle.

The world holds several separate builds on generated terrain, so this walks it
once, keeps only placed blocks, clusters them by position, and writes each
cluster out on its own. Generated terrain (stone, dirt, trees, ore) is left
behind - only what the builder placed is carried over.

    python3 castleworld_to_islands.py [--hollow]
"""
import json, os, sys
from collections import Counter

import anvil
from blockmap import BULK, DROP, islands_name, parse_state, resolve

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGION = ("/Users/johnlawrencepena/Documents/Rice Hub /price-logger-bot/"
          "CastleWorld/CastleWorldData/region")

# Generated terrain: everything the world makes on its own. Anything else was
# placed by the builder and is part of a castle.
NATURAL = set(BULK) | {
    "minecraft:grass_block", "minecraft:coarse_dirt", "minecraft:podzol",
    "minecraft:sand", "minecraft:red_sand", "minecraft:sandstone", "minecraft:gravel",
    "minecraft:clay", "minecraft:deepslate", "minecraft:cobbled_deepslate",
    "minecraft:tuff", "minecraft:calcite", "minecraft:dripstone_block",
    "minecraft:pointed_dripstone", "minecraft:smooth_basalt", "minecraft:netherrack",
    "minecraft:oak_leaves", "minecraft:birch_leaves", "minecraft:spruce_leaves",
    "minecraft:jungle_leaves", "minecraft:acacia_leaves", "minecraft:dark_oak_leaves",
    "minecraft:azalea_leaves", "minecraft:flowering_azalea_leaves",
    "minecraft:mangrove_leaves", "minecraft:cherry_leaves",
    "minecraft:oak_log", "minecraft:birch_log", "minecraft:spruce_log",
    "minecraft:jungle_log", "minecraft:acacia_log", "minecraft:dark_oak_log",
    "minecraft:mangrove_log", "minecraft:cherry_log",
    "minecraft:grass", "minecraft:short_grass", "minecraft:tall_grass",
    "minecraft:fern", "minecraft:large_fern", "minecraft:dead_bush",
    "minecraft:vine", "minecraft:moss_block", "minecraft:moss_carpet",
    "minecraft:snow", "minecraft:snow_block", "minecraft:ice", "minecraft:packed_ice",
    "minecraft:blue_ice", "minecraft:water", "minecraft:lava", "minecraft:seagrass",
    "minecraft:tall_seagrass", "minecraft:kelp", "minecraft:kelp_plant",
    "minecraft:lily_pad", "minecraft:sugar_cane", "minecraft:cactus",
    "minecraft:dirt_path", "minecraft:mud", "minecraft:rooted_dirt",
    "minecraft:sculk", "minecraft:sculk_vein", "minecraft:glow_lichen",
    "minecraft:cobweb", "minecraft:magma_block", "minecraft:obsidian",
    "minecraft:copper_ore", "minecraft:deepslate_copper_ore",
    "minecraft:deepslate_iron_ore", "minecraft:deepslate_coal_ore",
    "minecraft:deepslate_gold_ore", "minecraft:deepslate_diamond_ore",
    "minecraft:deepslate_redstone_ore", "minecraft:deepslate_lapis_ore",
    "minecraft:deepslate_emerald_ore", "minecraft:budding_amethyst",
    "minecraft:amethyst_cluster", "minecraft:amethyst_block",
    "minecraft:dandelion", "minecraft:poppy", "minecraft:blue_orchid",
    "minecraft:allium", "minecraft:azure_bluet", "minecraft:oxeye_daisy",
    "minecraft:cornflower", "minecraft:lily_of_the_valley", "minecraft:sunflower",
    "minecraft:lilac", "minecraft:rose_bush", "minecraft:peony",
    "minecraft:brown_mushroom", "minecraft:red_mushroom", "minecraft:sweet_berry_bush",
    "minecraft:oak_sapling", "minecraft:spruce_sapling", "minecraft:birch_sapling",
}

CELL = 48          # clustering resolution, in blocks
MIN_CELL = 500     # a cell needs this many placed blocks to seed a cluster
MIN_BUILD = 5000   # ignore clusters smaller than this


def main():
    hollow = "--hollow" in sys.argv[1:]

    placed = []
    for x, y, z, state in anvil.iter_world(REGION):
        if parse_state(state)[0] in NATURAL:
            continue
        placed.append((x, y, z, state))
    print("placed blocks:", len(placed))

    # bucket into cells, then merge touching dense cells into clusters
    cells = {}
    for i, (x, _, z, _) in enumerate(placed):
        cells.setdefault((x // CELL, z // CELL), []).append(i)

    dense = {k for k, v in cells.items() if len(v) >= MIN_CELL}
    seen, clusters = set(), []
    for k in dense:
        if k in seen:
            continue
        stack, group = [k], []
        seen.add(k)
        while stack:
            c = stack.pop()
            group.append(c)
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    nb = (c[0] + dx, c[1] + dz)
                    if nb in dense and nb not in seen:
                        seen.add(nb)
                        stack.append(nb)
        clusters.append(group)

    clusters.sort(key=lambda g: -sum(len(cells[c]) for c in g))
    clusters = [g for g in clusters if sum(len(cells[c]) for c in g) >= MIN_BUILD]
    print("builds found:", len(clusters))

    os.makedirs(os.path.join(ROOT, "builds"), exist_ok=True)
    total_unmapped = Counter()

    for n, group in enumerate(clusters, 1):
        idxs = [i for c in group for i in cells[c]]
        blocks = []
        for i in idxs:
            x, y, z, state = placed[i]
            got = resolve(state)
            if got is None:
                name = parse_state(state)[0]
                if name not in DROP and not name.startswith("minecraft:potted_"):
                    total_unmapped[name] += 1
                continue
            target, rot, upper, doubled = got
            px, py, pz = x * 3, y * 3, z * 3
            blocks.append({
                "blockType": target, "upperBlock": upper,
                "cframe": [px, py, pz, *rot], "parts": [],
            })
            if doubled:
                blocks.append({
                    "blockType": target, "upperBlock": True,
                    "cframe": [px, py, pz, *rot], "parts": [],
                })
        if not blocks:
            continue

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
            blocks = [b for b in blocks if not all(
                (b["cframe"][0] // 3 + dx, b["cframe"][1] // 3 + dy, b["cframe"][2] // 3 + dz) in occ
                for dx, dy, dz in sides)]

        name = f"Castle{n}" + ("Hollow" if hollow else "")
        out = os.path.join(ROOT, "builds", name + ".json")
        with open(out, "w") as fh:
            json.dump({"blocks": blocks}, fh, separators=(",", ":"))
        sx = max(b["cframe"][0] for b in blocks) // 3 + 1
        sy = max(b["cframe"][1] for b in blocks) // 3 + 1
        sz = max(b["cframe"][2] for b in blocks) // 3 + 1
        print(f"  {name:18s} {len(blocks):>7d} blocks   {sx}x{sy}x{sz}")

    if total_unmapped:
        print("\nUNMAPPED (dropped):", sum(total_unmapped.values()))
        for k, v in total_unmapped.most_common(40):
            print(f"{v:8d}  {k}")


if __name__ == "__main__":
    main()
