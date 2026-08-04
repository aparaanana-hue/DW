"""Convert the IvyWood Manor Minecraft world into an Islands build JSON.

Minecraft is 1 block = 1 unit; Islands is 1 block = 3 studs. Coordinates are
emitted relative to the build's own corner so the file drops in anywhere, and
Y is kept relative to the build's base.
"""
import sys, json
from collections import Counter
import mc_to_islands_read as mcread

X0, X1 = -52, 35
Y0, Y1 = 54, 94
Z0, Z1 = -76, 71

# Bulk terrain never carried over.
BULK = {
    "minecraft:stone", "minecraft:dirt", "minecraft:bedrock",
    "minecraft:andesite", "minecraft:diorite", "minecraft:granite",
    "minecraft:gravel", "minecraft:water", "minecraft:lava",
    "minecraft:coal_ore", "minecraft:iron_ore", "minecraft:gold_ore",
    "minecraft:diamond_ore", "minecraft:redstone_ore", "minecraft:lapis_ore",
    "minecraft:emerald_ore", "minecraft:infested_stone",
}

# Minecraft block -> Islands block. Chosen for closest colour/material; Islands
# has no wall/fence/pane/door/carpet primitives, so those become the nearest
# full block or slab.
MAP = {
    # stone and concrete
    "minecraft:smooth_stone": "stoneSmooth",
    "minecraft:stone_bricks": "stoneBrick",
    "minecraft:smooth_stone_slab": "stoneBrickSlab",
    "minecraft:stone_slab": "stoneBrickSlab",
    "minecraft:petrified_oak_slab": "oakSlab",
    "minecraft:cobblestone": "cobblestoneBlock",
    "minecraft:mossy_cobblestone": "mossyCobblestoneBlock",
    "minecraft:andesite_wall": "andesite",
    "minecraft:diorite_wall": "diorite",
    "minecraft:cobblestone_wall": "cobblestoneBlock",
    "minecraft:light_gray_concrete": "marbleSmooth",
    "minecraft:white_concrete": "whiteBlock",
    "minecraft:black_concrete": "blackBlock",
    "minecraft:gray_concrete": "slateSmooth",
    "minecraft:smooth_quartz": "marbleBlock",
    "minecraft:quartz_block": "marbleBlock",
    "minecraft:coal_block": "coalBlock",
    "minecraft:iron_block": "ironBlock",
    "minecraft:glowstone": "ledLight",
    "minecraft:sea_lantern": "ledLight",
    "minecraft:bricks": "brick",
    "minecraft:nether_bricks": "basaltBrick",
    "minecraft:nether_brick_stairs": "basaltBrickStair",
    "minecraft:nether_brick_slab": "basaltBrickSlab",
    "minecraft:nether_brick_fence": "basaltBrick",

    # sandstone
    "minecraft:smooth_sandstone": "sandstoneSmooth",
    "minecraft:smooth_sandstone_slab": "sandstoneSmoothSlab",
    "minecraft:smooth_sandstone_stairs": "stairSandstoneSmooth",
    "minecraft:sandstone": "sandstone",
    "minecraft:sandstone_wall": "sandstone",
    "minecraft:sandstone_slab": "sandstoneSlab",
    "minecraft:sandstone_stairs": "stairSandstone",
    "minecraft:chiseled_sandstone": "sandstoneBrick",
    "minecraft:cut_sandstone": "sandstoneBrick",
    "minecraft:red_sandstone": "sandstoneRed",

    # wood: spruce -> pine, dark oak -> hickory (closest tones Islands has)
    "minecraft:spruce_planks": "pinePlank",
    "minecraft:spruce_slab": "pineSlab",
    "minecraft:spruce_stairs": "stairPine",
    "minecraft:spruce_log": "woodPine",
    "minecraft:stripped_spruce_log": "woodPine",
    "minecraft:spruce_fence": "pinePlank",
    "minecraft:spruce_fence_gate": "pinePlank",
    "minecraft:spruce_door": "pinePlank",
    "minecraft:spruce_trapdoor": "pineSlab",
    "minecraft:spruce_pressure_plate": "pineSlab",
    "minecraft:spruce_sign": "pineSlab",
    "minecraft:spruce_wall_sign": "pineSlab",

    "minecraft:oak_planks": "woodPlank",
    "minecraft:oak_slab": "oakSlab",
    "minecraft:oak_stairs": "stairOak",
    "minecraft:oak_log": "wood",
    "minecraft:stripped_oak_log": "wood",
    "minecraft:oak_fence": "woodPlank",
    "minecraft:oak_fence_gate": "woodPlank",
    "minecraft:oak_door": "woodPlank",
    "minecraft:oak_trapdoor": "oakSlab",
    "minecraft:oak_pressure_plate": "oakSlab",
    "minecraft:oak_button": "oakSlab",
    "minecraft:oak_sign": "oakSlab",
    "minecraft:oak_wall_sign": "oakSlab",

    "minecraft:birch_planks": "birchPlank",
    "minecraft:birch_slab": "birchSlab",
    "minecraft:birch_stairs": "stairBirch",
    "minecraft:birch_log": "woodBirch",
    "minecraft:stripped_birch_log": "woodBirch",
    "minecraft:birch_fence": "birchPlank",
    "minecraft:birch_fence_gate": "birchPlank",
    "minecraft:birch_door": "birchPlank",
    "minecraft:birch_trapdoor": "birchSlab",
    "minecraft:birch_button": "birchSlab",

    "minecraft:dark_oak_planks": "hickoryPlank",
    "minecraft:dark_oak_slab": "hickorySlab",
    "minecraft:dark_oak_stairs": "stairHickory",
    "minecraft:dark_oak_log": "woodHickory",
    "minecraft:dark_oak_fence": "hickoryPlank",
    "minecraft:dark_oak_fence_gate": "hickoryPlank",
    "minecraft:dark_oak_door": "hickoryPlank",
    "minecraft:dark_oak_trapdoor": "hickorySlab",

    "minecraft:jungle_planks": "maplePlank",
    "minecraft:jungle_log": "woodMaple",
    "minecraft:acacia_planks": "maplePlank",
    "minecraft:acacia_log": "woodMaple",
    "minecraft:bookshelf": "hickoryPlank",
    "minecraft:crafting_table": "woodPlank",
    "minecraft:barrel": "pinePlank",
    "minecraft:chest": "woodPlank",
    "minecraft:trapped_chest": "woodPlank",
    "minecraft:ladder": "oakSlab",
    "minecraft:scaffolding": "bambooBlock",

    # leaves and plants
    "minecraft:oak_leaves": "leavesBlock",
    "minecraft:birch_leaves": "leavesBlock",
    "minecraft:spruce_leaves": "leavesBlock",
    "minecraft:jungle_leaves": "leavesMapleBlock",
    "minecraft:acacia_leaves": "leavesMapleBlock",
    "minecraft:dark_oak_leaves": "leavesBlock",
    "minecraft:vine": "leavesBlock",
    "minecraft:grass_block": "grass",
    "minecraft:grass_path": "grassDry",
    "minecraft:dirt_path": "grassDry",
    "minecraft:coarse_dirt": "mudBlock",
    "minecraft:podzol": "mudBlock",
    "minecraft:farmland": "mudBlock",
    "minecraft:hay_block": "haybaleBlock",
    "minecraft:pumpkin": "pumpkinHarvested",
    "minecraft:carved_pumpkin": "jackOLantern",
    "minecraft:jack_o_lantern": "jackOLantern",
    "minecraft:melon": "melonHarvested",
    "minecraft:mushroom_stem": "mushroomBlock",
    "minecraft:brown_mushroom_block": "mushroomBlock",
    "minecraft:red_mushroom_block": "mushroomBlock",
    "minecraft:cobweb": "woolWhite",

    # wool and carpet
    "minecraft:white_wool": "woolWhite",
    "minecraft:black_wool": "woolBlack",
    "minecraft:red_wool": "woolRed",
    "minecraft:blue_wool": "woolBlue",
    "minecraft:light_blue_wool": "woolCyan",
    "minecraft:cyan_wool": "woolCyan",
    "minecraft:green_wool": "woolDarkGreen",
    "minecraft:lime_wool": "woolLightGreen",
    "minecraft:yellow_wool": "woolYellow",
    "minecraft:orange_wool": "woolOrange",
    "minecraft:pink_wool": "woolPink",
    "minecraft:magenta_wool": "woolPink",
    "minecraft:purple_wool": "woolPurple",
    "minecraft:brown_wool": "clayOrange",
    "minecraft:gray_wool": "clayBlack",
    "minecraft:light_gray_wool": "clayWhite",

    "minecraft:white_carpet": "whiteSlab",
    "minecraft:black_carpet": "blackSlab",
    "minecraft:red_carpet": "redSlab",
    "minecraft:blue_carpet": "blueSlab",
    "minecraft:light_blue_carpet": "cyanSlab",
    "minecraft:cyan_carpet": "cyanSlab",
    "minecraft:green_carpet": "darkGreenSlab",
    "minecraft:lime_carpet": "lightGreenSlab",
    "minecraft:yellow_carpet": "yellowSlab",
    "minecraft:orange_carpet": "orangeSlab",
    "minecraft:pink_carpet": "pinkSlab",
    "minecraft:purple_carpet": "purpleSlab",
    "minecraft:gray_carpet": "blackSlab",
    "minecraft:light_gray_carpet": "whiteSlab",
    "minecraft:brown_carpet": "orangeSlab",

    # glass
    "minecraft:glass": "glassBlockChrome",
    "minecraft:glass_pane": "glassBlockChrome",
    "minecraft:white_stained_glass": "glassBlockChrome",
    "minecraft:white_stained_glass_pane": "glassBlockChrome",
    "minecraft:black_stained_glass": "glassBlockBlack",
    "minecraft:black_stained_glass_pane": "glassBlockBlack",
    "minecraft:blue_stained_glass_pane": "glassBlockBlue",
    "minecraft:red_stained_glass_pane": "glassBlockRed",
    "minecraft:green_stained_glass_pane": "glassBlockDarkGreen",
    "minecraft:lime_stained_glass_pane": "glassBlockLightGreen",
    "minecraft:yellow_stained_glass_pane": "glassBlockYellow",
    "minecraft:orange_stained_glass_pane": "glassBlockOrange",
    "minecraft:cyan_stained_glass_pane": "glassBlockCyan",
    "minecraft:pink_stained_glass_pane": "glassBlockPink",
    "minecraft:purple_stained_glass_pane": "glassBlockPurple",
    "minecraft:brown_stained_glass_pane": "glassBlockOrange",
    "minecraft:gray_stained_glass_pane": "glassBlockBlack",
    "minecraft:light_gray_stained_glass_pane": "glassBlockChrome",

    # lights and small props: nearest solid stand-in
    "minecraft:torch": "ledLight",
    "minecraft:wall_torch": "ledLight",
    "minecraft:lantern": "ledLight",
    "minecraft:soul_lantern": "ledLight",
    "minecraft:campfire": "magmaBlock",
    "minecraft:end_rod": "ledLight",
    "minecraft:iron_bars": "ironBlock",
    "minecraft:cauldron": "ironBlock",
    "minecraft:anvil": "ironBlock",
    "minecraft:furnace": "cobblestoneBlock",
    "minecraft:smoker": "pinePlank",
    "minecraft:blast_furnace": "ironBlock",
    "minecraft:stonecutter": "stoneSmooth",
    "minecraft:grindstone": "woodPlank",
    "minecraft:lectern": "woodPlank",
    "minecraft:composter": "woodPlank",
    "minecraft:bell": "goldBlock",
    "minecraft:player_head": "boneBlock",
    "minecraft:heavy_weighted_pressure_plate": "ironBlock",
    "minecraft:stone_button": "stoneSmooth",
    "minecraft:stone_pressure_plate": "stoneSmooth",
    "minecraft:flower_pot": "clayOrange",
    "minecraft:bed": "woolRed",
    "minecraft:white_bed": "woolWhite",
    "minecraft:red_bed": "woolRed",
    "minecraft:blue_bed": "woolBlue",
    "minecraft:green_bed": "woolDarkGreen",
    "minecraft:light_blue_wall_banner": "woolCyan",
    "minecraft:white_wall_banner": "woolWhite",
    "minecraft:item_frame": "woodPlank",
    "minecraft:painting": "woodPlank",

    # stragglers found on the first pass
    "minecraft:dark_oak_wall_sign": "hickorySlab",
    "minecraft:tripwire_hook": "oakSlab",
    "minecraft:spruce_button": "pineSlab",
    "minecraft:spruce_wood": "woodPine",
    "minecraft:oak_wood": "wood",
    "minecraft:birch_wood": "woodBirch",
    "minecraft:dark_oak_wood": "woodHickory",
    "minecraft:gold_block": "goldBlock",
    "minecraft:emerald_block": "amethystBlock",
    "minecraft:diamond_block": "diamondBlock",
    "minecraft:redstone_block": "redBlock",
    "minecraft:lapis_block": "blueBlock",
    "minecraft:smooth_quartz_slab": "marbleSlab",
    "minecraft:quartz_slab": "marbleSlab",
    "minecraft:jungle_door": "maplePlank",
    "minecraft:iron_door": "ironBlock",
    "minecraft:iron_trapdoor": "ironBlock",
    "minecraft:stone_stairs": "stairStoneBrick",
    "minecraft:repeating_command_block": "stoneSmooth",
    "minecraft:command_block": "stoneSmooth",
    "minecraft:lever": "oakSlab",
    "minecraft:brewing_stand": "ironBlock",
    "minecraft:enchanting_table": "voidStoneBlock",
    "minecraft:jukebox": "hickoryPlank",
    "minecraft:note_block": "woodPlank",
    "minecraft:beacon": "glassBlockChrome",
}

# Small decorations with no sensible block equivalent: dropped rather than
# turned into a full cube that would look wrong.
DROP = {
    "minecraft:grass", "minecraft:tall_grass", "minecraft:fern", "minecraft:large_fern",
    "minecraft:dandelion", "minecraft:poppy", "minecraft:blue_orchid", "minecraft:allium",
    "minecraft:azure_bluet", "minecraft:oxeye_daisy", "minecraft:cornflower",
    "minecraft:lily_of_the_valley", "minecraft:sunflower", "minecraft:lilac",
    "minecraft:rose_bush", "minecraft:peony", "minecraft:dead_bush",
    "minecraft:brown_mushroom", "minecraft:red_mushroom", "minecraft:sugar_cane",
    "minecraft:wheat", "minecraft:carrots", "minecraft:potatoes", "minecraft:beetroots",
    "minecraft:sweet_berry_bush", "minecraft:lily_pad", "minecraft:snow",
    "minecraft:oak_sapling", "minecraft:spruce_sapling", "minecraft:birch_sapling",
    "minecraft:rail", "minecraft:redstone_wire", "minecraft:tripwire",
    "minecraft:air", "minecraft:cave_air", "minecraft:void_air",
}


def islands_name(mc):
    if mc in DROP:
        return None
    if mc in MAP:
        return MAP[mc]
    # potted_* -> the pot, so the decoration still reads as an object
    if mc.startswith("minecraft:potted_"):
        return "clayOrange"
    return None


def main():
    blocks = []
    unmapped = Counter()
    kept = Counter()
    raw = []

    for x, y, z, name in mcread.iter_world("IvyWood Manor/region"):
        if not (X0 <= x <= X1 and Y0 <= y <= Y1 and Z0 <= z <= Z1):
            continue
        if name in BULK:
            continue
        raw.append((x, y, z, name))

    # anchor at the build's own minimum corner so the file is position-independent
    mnx = min(b[0] for b in raw)
    mny = min(b[1] for b in raw)
    mnz = min(b[2] for b in raw)

    for x, y, z, name in raw:
        target = islands_name(name)
        if target is None:
            if name not in DROP and not name.startswith("minecraft:potted_"):
                unmapped[name] += 1
            continue
        kept[target] += 1
        # 1 Minecraft block = 3 studs in Islands; identity rotation
        blocks.append({
            "blockType": target,
            "upperBlock": False,
            "cframe": [(x - mnx) * 3, (y - mny) * 3, (z - mnz) * 3, 1, 0, 0, 0, 1, 0],
            "parts": [],
        })

    out = "IvyWoodManor.json"
    with open(out, "w") as f:
        json.dump({"blocks": blocks}, f)

    print("wrote", out)
    print("blocks:", len(blocks))
    print("size (blocks): %d x %d x %d" % (
        max(b[0] for b in raw) - mnx + 1,
        max(b[1] for b in raw) - mny + 1,
        max(b[2] for b in raw) - mnz + 1))
    print("\ntop Islands blocks used:")
    for n, c in kept.most_common(25):
        print(f"{c:8d}  {n}")
    if unmapped:
        print("\nUNMAPPED (dropped):")
        for n, c in unmapped.most_common(40):
            print(f"{c:8d}  {n}")


if __name__ == "__main__":
    main()
