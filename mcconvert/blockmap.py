"""Minecraft block -> Islands block mapping, shared by both converters."""

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
    "minecraft:smooth_quartz": "marbleTiles",
    "minecraft:quartz_block": "marbleBlock",
    "minecraft:coal_block": "coalBlock",
    "minecraft:iron_block": "ironBlock",
    "minecraft:glowstone": "ledLight",
    "minecraft:sea_lantern": "opalBlock",
    "minecraft:bricks": "brick",
    "minecraft:nether_bricks": "basaltTiles",
    "minecraft:nether_brick_stairs": "basaltStair",
    "minecraft:nether_brick_slab": "basaltSlab",
    "minecraft:nether_brick_fence": "fenceHickory",

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
    "minecraft:spruce_fence": "fencePine",
    "minecraft:spruce_fence_gate": "fencePine",
    "minecraft:spruce_door": "doorPine",
    "minecraft:spruce_trapdoor": "trapDoorPineFlipped",
    "minecraft:spruce_pressure_plate": "pineSlab",
    "minecraft:spruce_sign": "signPostPine",
    "minecraft:spruce_wall_sign": "signPostPine",

    "minecraft:oak_planks": "woodPlank",
    "minecraft:oak_slab": "oakSlab",
    "minecraft:oak_stairs": "stairOak",
    "minecraft:oak_log": "wood",
    "minecraft:stripped_oak_log": "wood",
    "minecraft:oak_fence": "woodFence",
    "minecraft:oak_fence_gate": "woodFence",
    "minecraft:oak_door": "doorPine",
    "minecraft:oak_trapdoor": "trapDoorOakFlipped",
    "minecraft:oak_pressure_plate": "oakSlab",
    "minecraft:oak_button": "furnitureLampWall",
    "minecraft:oak_sign": "signPostOak",
    "minecraft:oak_wall_sign": "signPostOak",

    "minecraft:birch_planks": "birchPlank",
    "minecraft:birch_slab": "birchSlab",
    "minecraft:birch_stairs": "stairBirch",
    "minecraft:birch_log": "woodBirch",
    "minecraft:stripped_birch_log": "woodBirch",
    "minecraft:birch_fence": "fenceBirch",
    "minecraft:birch_fence_gate": "fenceBirch",
    "minecraft:birch_door": "doorPine2",
    "minecraft:birch_trapdoor": "trapDoorBirchFlipped",
    "minecraft:birch_button": "furnitureLampWall",

    "minecraft:dark_oak_planks": "hickoryPlank",
    "minecraft:dark_oak_slab": "hickorySlab",
    "minecraft:dark_oak_stairs": "stairHickory",
    "minecraft:dark_oak_log": "woodHickory",
    "minecraft:dark_oak_fence": "fenceHickory",
    "minecraft:dark_oak_fence_gate": "fenceHickory",
    "minecraft:dark_oak_door": "doorPine2",
    "minecraft:dark_oak_trapdoor": "trapDoorHickoryFlipped",

    "minecraft:jungle_planks": "maplePlank",
    "minecraft:jungle_log": "woodMaple",
    "minecraft:acacia_planks": "maplePlank",
    "minecraft:acacia_log": "woodMaple",
    "minecraft:bookshelf": "hickoryPlank",
    "minecraft:crafting_table": "workbench4",
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
    "minecraft:farmland": "soil",
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

    "minecraft:white_carpet": "carpet",
    "minecraft:black_carpet": "carpetBlack",
    "minecraft:red_carpet": "carpetRed",
    "minecraft:blue_carpet": "carpetBlue",
    "minecraft:light_blue_carpet": "carpetCyan",
    "minecraft:cyan_carpet": "carpetCyan",
    "minecraft:green_carpet": "carpetDarkGreen",
    "minecraft:lime_carpet": "carpetLightGreen",
    "minecraft:yellow_carpet": "carpetYellow",
    "minecraft:orange_carpet": "carpetOrange",
    "minecraft:pink_carpet": "carpetPink",
    "minecraft:purple_carpet": "carpetPurple",
    "minecraft:gray_carpet": "carpetBlack",
    "minecraft:light_gray_carpet": "carpet",
    "minecraft:brown_carpet": "carpetOrange",

    # glass
    "minecraft:glass": "glassBlock",
    "minecraft:glass_pane": "glassPane",
    "minecraft:white_stained_glass": "glassBlockChrome",
    "minecraft:white_stained_glass_pane": "glassPane",
    "minecraft:black_stained_glass": "glassBlockBlack",
    "minecraft:black_stained_glass_pane": "glassPaneBlack",
    "minecraft:blue_stained_glass_pane": "glassPaneBlue",
    "minecraft:red_stained_glass_pane": "glassPaneRed",
    "minecraft:green_stained_glass_pane": "glassPaneDarkGreen",
    "minecraft:lime_stained_glass_pane": "glassPaneLightGreen",
    "minecraft:yellow_stained_glass_pane": "glassPaneYellow",
    "minecraft:orange_stained_glass_pane": "glassPaneOrange",
    "minecraft:cyan_stained_glass_pane": "glassPaneCyan",
    "minecraft:pink_stained_glass_pane": "glassPanePink",
    "minecraft:purple_stained_glass_pane": "glassPanePurple",
    "minecraft:brown_stained_glass_pane": "glassPaneOrange",
    "minecraft:gray_stained_glass_pane": "glassPaneBlack",
    "minecraft:light_gray_stained_glass_pane": "glassPane",

    # lights and small props: nearest solid stand-in
    "minecraft:torch": "torch",
    "minecraft:wall_torch": "torch",
    "minecraft:lantern": "furnitureLampWall",
    "minecraft:soul_lantern": "furnitureLampWall",
    "minecraft:campfire": "magmaBlock",
    "minecraft:end_rod": "ledLight",
    "minecraft:iron_bars": "ironBlock",
    "minecraft:cauldron": "ironBlock",
    "minecraft:anvil": "ironBlock",
    "minecraft:furnace": "stoneTiles",
    "minecraft:smoker": "pinePlank",
    "minecraft:blast_furnace": "ironBlock",
    "minecraft:stonecutter": "stoneSmooth",
    "minecraft:grindstone": "woodPlank",
    "minecraft:lectern": "woodPlank",
    "minecraft:composter": "woodPlank",
    "minecraft:bell": "goldBlock",
    "minecraft:player_head": "boneBlock",
    "minecraft:heavy_weighted_pressure_plate": "ironBlock",
    "minecraft:stone_button": "furnitureLampWall",
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
    "minecraft:dark_oak_wall_sign": "signPostHickory",
    "minecraft:tripwire_hook": "oakSlab",
    "minecraft:spruce_button": "furnitureLampWall",
    "minecraft:spruce_wood": "woodPine",
    "minecraft:oak_wood": "wood",
    "minecraft:birch_wood": "woodBirch",
    "minecraft:dark_oak_wood": "woodHickory",
    "minecraft:gold_block": "goldBlock",
    "minecraft:emerald_block": "slimeBlockGreen",
    "minecraft:diamond_block": "diamondBlock",
    "minecraft:redstone_block": "rubyBlock",
    "minecraft:lapis_block": "buffalkorCrystalBlock",
    "minecraft:smooth_quartz_slab": "marbleSlab",
    "minecraft:quartz_slab": "marbleSlab",
    "minecraft:jungle_door": "doorPine2",
    "minecraft:iron_door": "doorIron",
    "minecraft:iron_trapdoor": "trapDoorIronFlipped",
    "minecraft:stone_stairs": "stairStoneBrick",
    "minecraft:repeating_command_block": "stoneSmooth",
    "minecraft:command_block": "stoneSmooth",
    "minecraft:lever": "oakSlab",
    "minecraft:brewing_stand": "ironBlock",
    "minecraft:enchanting_table": "voidStoneBlock",
    "minecraft:jukebox": "hickoryPlank",
    "minecraft:note_block": "woodPlank",
    "minecraft:beacon": "glassBlockChrome",

    # ── terracotta (1.13+) ────────────────────────────────────────────────
    "minecraft:terracotta": "clayOrange",
    "minecraft:white_terracotta": "clayWhite",
    "minecraft:black_terracotta": "clayBlack",
    "minecraft:gray_terracotta": "clayBlack",
    "minecraft:light_gray_terracotta": "clayWhite",
    "minecraft:red_terracotta": "clayRed",
    "minecraft:orange_terracotta": "clayOrange",
    "minecraft:yellow_terracotta": "clayYellow",
    "minecraft:lime_terracotta": "clayLightGreen",
    "minecraft:green_terracotta": "clayDarkGreen",
    "minecraft:cyan_terracotta": "clayCyan",
    "minecraft:light_blue_terracotta": "clayCyan",
    "minecraft:blue_terracotta": "clayBlue",
    "minecraft:purple_terracotta": "clayPurple",
    "minecraft:magenta_terracotta": "clayPink",
    "minecraft:pink_terracotta": "clayPink",
    "minecraft:brown_terracotta": "clayOrange",

    # ── concrete and concrete powder ──────────────────────────────────────
    "minecraft:red_concrete": "redBlock",
    "minecraft:orange_concrete": "orangeBlock",
    "minecraft:yellow_concrete": "yellowBlock",
    "minecraft:lime_concrete": "lightGreenBlock",
    "minecraft:green_concrete": "darkGreenBlock",
    "minecraft:cyan_concrete": "cyanBlock",
    "minecraft:light_blue_concrete": "cyanBlock",
    "minecraft:blue_concrete": "blueBlock",
    "minecraft:purple_concrete": "purpleBlock",
    "minecraft:magenta_concrete": "pinkBlock",
    "minecraft:pink_concrete": "pinkBlock",
    "minecraft:brown_concrete": "clayOrange",
    "minecraft:white_concrete_powder": "clayWhite",
    "minecraft:light_gray_concrete_powder": "clayWhite",
    "minecraft:gray_concrete_powder": "clayBlack",
    "minecraft:brown_concrete_powder": "pastelOrangeBlock",
    "minecraft:black_concrete_powder": "clayBlack",
    "minecraft:red_concrete_powder": "pastelRedBlock",
    "minecraft:orange_concrete_powder": "pastelOrangeBlock",
    "minecraft:lime_concrete_powder": "pastelGreenBlock",
    "minecraft:green_concrete_powder": "pastelGreenBlock",
    "minecraft:blue_concrete_powder": "pastelBlueBlock",
    "minecraft:light_blue_concrete_powder": "pastelBlueBlock",
    "minecraft:purple_concrete_powder": "pastelPurpleBlock",
    "minecraft:magenta_concrete_powder": "pastelPurpleBlock",
    "minecraft:pink_concrete_powder": "pastelPinkBlock",
    "minecraft:cyan_concrete_powder": "pastelBlueBlock",
    "minecraft:yellow_concrete_powder": "pastelYellowBlock",

    # ── nether / 1.16 woods ───────────────────────────────────────────────
    "minecraft:warped_planks": "spiritPlank",
    "minecraft:warped_slab": "spiritSlab",
    "minecraft:warped_stairs": "stairSpirit",
    "minecraft:warped_fence": "fenceSpirit",
    "minecraft:warped_fence_gate": "fenceSpirit",
    "minecraft:warped_door": "doorPine2",
    "minecraft:warped_trapdoor": "trapDoorSpiritFlipped",
    "minecraft:warped_button": "furnitureLampWall",
    "minecraft:warped_stem": "woodSpirit",
    "minecraft:warped_hyphae": "woodSpirit",
    "minecraft:stripped_warped_stem": "woodSpirit",
    "minecraft:warped_wart_block": "glowingMushroomCyanBlock",
    "minecraft:crimson_planks": "cherryBlossomPlank",
    "minecraft:crimson_slab": "cherryBlossomSlab",
    "minecraft:crimson_stairs": "stairCherryBlossom",
    "minecraft:crimson_fence": "fenceCherryBlossom",
    "minecraft:crimson_fence_gate": "fenceCherryBlossom",
    "minecraft:crimson_door": "doorPine2",
    "minecraft:crimson_trapdoor": "trapDoorMapleFlipped",
    "minecraft:crimson_button": "furnitureLampWall",
    "minecraft:crimson_stem": "woodCherryBlossom",
    "minecraft:crimson_hyphae": "woodCherryBlossom",
    "minecraft:stripped_crimson_stem": "woodCherryBlossom",
    "minecraft:nether_wart_block": "glowingMushroomPinkBlock",
    "minecraft:soul_soil": "mudBlock",
    "minecraft:soul_sand": "mudBlock",
    "minecraft:basalt": "basalt",
    "minecraft:polished_basalt": "basaltSmooth",
    "minecraft:smooth_basalt": "basaltSmooth",
    "minecraft:blackstone": "basalt",
    "minecraft:polished_blackstone": "basaltSmooth",
    "minecraft:polished_blackstone_bricks": "basaltBrick",
    "minecraft:polished_blackstone_stairs": "basaltBrickStair",
    "minecraft:polished_blackstone_slab": "basaltBrickSlab",
    "minecraft:polished_blackstone_button": "furnitureLampWall",
    "minecraft:polished_blackstone_wall": "basaltBrick",
    "minecraft:red_nether_bricks": "sandstoneRedBrick",
    "minecraft:red_nether_brick_wall": "sandstoneRedBrick",
    "minecraft:red_nether_brick_slab": "sandstoneRedBrickSlab",
    "minecraft:nether_portal": "voidBlock",
    "minecraft:bone_block": "boneBlock",
    "minecraft:chain": "ironBlock",
    "minecraft:hopper": "ironBlock",
    "minecraft:lodestone": "stoneSmooth",

    # ── polished / extra stone variants ───────────────────────────────────
    "minecraft:polished_andesite": "andesiteSmooth",
    "minecraft:polished_andesite_stairs": "andesiteStair",
    "minecraft:polished_andesite_slab": "andesiteSlab",
    "minecraft:andesite_stairs": "andesiteBrickStair",
    "minecraft:andesite_slab": "andesiteBrickSlab",
    "minecraft:polished_granite": "graniteSmooth",
    "minecraft:polished_granite_stairs": "graniteStair",
    "minecraft:polished_granite_slab": "graniteSlab",
    "minecraft:granite_stairs": "graniteStair",
    "minecraft:granite_slab": "graniteSlab",
    "minecraft:polished_diorite": "dioriteSmooth",
    "minecraft:polished_diorite_stairs": "dioriteStair",
    "minecraft:polished_diorite_slab": "dioriteSlab",
    "minecraft:diorite_stairs": "dioriteStair",
    "minecraft:diorite_slab": "dioriteSlab",
    "minecraft:stone_brick_slab": "stoneBrickSlab",
    "minecraft:stone_brick_stairs": "stairStoneBrick",
    "minecraft:stone_brick_wall": "stoneBrick",
    "minecraft:mossy_stone_bricks": "stoneBrickMossy",
    "minecraft:mossy_stone_brick_slab": "stoneBrickSlab",
    "minecraft:mossy_stone_brick_stairs": "stairStoneBrick",
    "minecraft:infested_mossy_stone_bricks": "stoneBrickMossy",
    "minecraft:infested_stone_bricks": "stoneBrick",
    "minecraft:chiseled_stone_bricks": "stoneCarved",
    "minecraft:cracked_stone_bricks": "stoneBrick",
    "minecraft:cobblestone_stairs": "cobblestoneStair",
    "minecraft:cobblestone_slab": "cobblestoneSlab",
    "minecraft:mossy_cobblestone_stairs": "cobblestoneStair",
    "minecraft:mossy_cobblestone_slab": "mossyCobblestoneSlab",
    "minecraft:mossy_cobblestone_wall": "mossyCobblestoneBlock",
    "minecraft:brick_stairs": "stairBrick",
    "minecraft:brick_slab": "brickSlab",
    "minecraft:brick_wall": "brick",
    "minecraft:smooth_quartz_stairs": "stairMarble",
    "minecraft:quartz_stairs": "stairMarble",
    "minecraft:quartz_pillar": "marblePillar",
    "minecraft:chiseled_quartz_block": "marbleCarved",
    "minecraft:cut_sandstone_slab": "sandstoneBrickSlab",
    "minecraft:chiseled_red_sandstone": "sandstoneRedBrick",
    "minecraft:cut_red_sandstone": "sandstoneRedBrick",
    "minecraft:red_sandstone_slab": "sandstoneRedSlab",
    "minecraft:red_sandstone_stairs": "stairSandstoneRed",
    "minecraft:smooth_red_sandstone": "sandstoneSmoothRed",
    "minecraft:smooth_red_sandstone_slab": "sandstoneSmoothRedSlab",
    "minecraft:prismarine": "prismarineBlock",
    "minecraft:prismarine_slab": "prismarineSlab",
    "minecraft:prismarine_stairs": "prismarineStair",
    "minecraft:prismarine_bricks": "prismarineBrick",
    "minecraft:prismarine_brick_slab": "prismarineBrickSlab",
    "minecraft:prismarine_brick_stairs": "prismarineBrickStair",
    "minecraft:dark_prismarine": "prismarineBrick",
    "minecraft:dark_prismarine_slab": "prismarineBrickSlab",
    "minecraft:dark_prismarine_stairs": "prismarineBrickStair",

    # ── remaining wood variants ───────────────────────────────────────────
    "minecraft:jungle_slab": "mapleSlab",
    "minecraft:jungle_stairs": "stairMaple",
    "minecraft:jungle_trapdoor": "trapDoorMapleFlipped",
    "minecraft:jungle_fence": "fenceMaple",
    "minecraft:jungle_button": "furnitureLampWall",
    "minecraft:acacia_slab": "mapleSlab",
    "minecraft:acacia_stairs": "stairMaple",
    "minecraft:acacia_trapdoor": "trapDoorMapleFlipped",
    "minecraft:acacia_fence": "fenceMaple",
    "minecraft:acacia_wood": "woodMaple",
    "minecraft:stripped_acacia_wood": "woodMaple",
    "minecraft:stripped_spruce_wood": "woodPine",
    "minecraft:stripped_oak_wood": "wood",
    "minecraft:stripped_birch_wood": "woodBirch",
    "minecraft:stripped_dark_oak_wood": "woodHickory",
    "minecraft:stripped_jungle_wood": "woodMaple",

    # ── remaining glass ───────────────────────────────────────────────────
    "minecraft:gray_stained_glass": "glassBlockBlack",
    "minecraft:light_gray_stained_glass": "glassBlockChrome",
    "minecraft:blue_stained_glass": "glassBlockBlue",
    "minecraft:red_stained_glass": "glassBlockRed",
    "minecraft:green_stained_glass": "glassBlockDarkGreen",
    "minecraft:lime_stained_glass": "glassBlockLightGreen",
    "minecraft:yellow_stained_glass": "glassBlockYellow",
    "minecraft:orange_stained_glass": "glassBlockOrange",
    "minecraft:cyan_stained_glass": "glassBlockCyan",
    "minecraft:light_blue_stained_glass": "glassBlockCyan",
    "minecraft:pink_stained_glass": "glassBlockPink",
    "minecraft:purple_stained_glass": "glassBlockPurple",
    "minecraft:magenta_stained_glass": "glassBlockPink",
    "minecraft:brown_stained_glass": "glassBlockOrange",
    "minecraft:tinted_glass": "glassBlockBlack",
    "minecraft:redstone_lamp": "ledLight",

    # ── coral (dead coral blocks are common as decorative stone) ───────────
    "minecraft:dead_brain_coral_block": "clayWhite",
    "minecraft:dead_fire_coral_block": "clayWhite",
    "minecraft:dead_bubble_coral_block": "clayWhite",
    "minecraft:dead_horn_coral_block": "clayWhite",
    "minecraft:dead_tube_coral_block": "clayWhite",
    "minecraft:brain_coral_block": "coralBlockPink",
    "minecraft:fire_coral_block": "coralBlockPink",
    "minecraft:bubble_coral_block": "coralBlockBlue",
    "minecraft:horn_coral_block": "coralBlockYellow",
    "minecraft:tube_coral_block": "coralBlockLightBlue",

    # ── mangrove (1.19) ───────────────────────────────────────────────────
    "minecraft:mangrove_slab": "cherryBlossomSlab",
    "minecraft:mangrove_stairs": "stairCherryBlossom",
    "minecraft:mangrove_fence": "fenceCherryBlossom",
    "minecraft:mangrove_fence_gate": "fenceCherryBlossom",
    "minecraft:mangrove_door": "doorPine2",
    "minecraft:mangrove_trapdoor": "trapDoorMapleFlipped",
    "minecraft:mangrove_button": "furnitureLampWall",
    "minecraft:mangrove_wood": "woodCherryBlossom",
    "minecraft:stripped_mangrove_wood": "woodCherryBlossom",
    "minecraft:mangrove_sign": "signPostCherryBlossom",
    "minecraft:mangrove_wall_sign": "signPostCherryBlossom",
    "minecraft:mangrove_roots": "woodCherryBlossom",
    "minecraft:muddy_mangrove_roots": "mudBlock",

    # ── cherry and bamboo (1.19-1.20) ─────────────────────────────────────
    "minecraft:cherry_wood": "woodCherryBlossom",
    "minecraft:stripped_cherry_wood": "woodCherryBlossom",
    "minecraft:cherry_slab": "cherryBlossomSlab",
    "minecraft:cherry_stairs": "stairCherryBlossom",
    "minecraft:cherry_fence": "fenceCherryBlossom",
    "minecraft:cherry_door": "doorPine2",
    "minecraft:cherry_trapdoor": "trapDoorMapleFlipped",
    "minecraft:bamboo": "bambooBlock",
    "minecraft:bamboo_slab": "bambooDriedBlock",
    "minecraft:bamboo_stairs": "bambooDriedBlock",
    "minecraft:bamboo_fence": "fenceMaple",
    "minecraft:bamboo_fence_gate": "fenceMaple",
    "minecraft:bamboo_door": "doorPine2",
    "minecraft:bamboo_trapdoor": "trapDoorMapleFlipped",
    "minecraft:bamboo_button": "furnitureLampWall",
    "minecraft:bamboo_sign": "signPostMaple",
    "minecraft:bamboo_wall_sign": "signPostMaple",
    "minecraft:bamboo_mosaic": "bambooDriedBlock",
    "minecraft:bamboo_mosaic_slab": "bambooDriedBlock",
    "minecraft:bamboo_mosaic_stairs": "bambooDriedBlock",

    # ── waxed copper mirrors the unwaxed blocks ───────────────────────────
    "minecraft:waxed_copper_block": "copperBlock",
    "minecraft:waxed_cut_copper": "copperBlock",
    "minecraft:waxed_cut_copper_slab": "copperBlock",
    "minecraft:waxed_cut_copper_stairs": "copperBlock",
    "minecraft:waxed_exposed_copper": "copperBlock",
    "minecraft:waxed_exposed_cut_copper": "copperBlock",
    "minecraft:waxed_exposed_cut_copper_slab": "copperBlock",
    "minecraft:waxed_exposed_cut_copper_stairs": "copperBlock",
    "minecraft:waxed_weathered_copper": "prismarineBlock",
    "minecraft:waxed_weathered_cut_copper": "prismarineBlock",
    "minecraft:waxed_weathered_cut_copper_slab": "prismarineSlab",
    "minecraft:waxed_weathered_cut_copper_stairs": "prismarineStair",
    "minecraft:waxed_oxidized_copper": "prismarineBlock",
    "minecraft:waxed_oxidized_cut_copper": "prismarineBlock",
    "minecraft:waxed_oxidized_cut_copper_slab": "prismarineSlab",
    "minecraft:waxed_oxidized_cut_copper_stairs": "prismarineStair",

    # ── mud bricks, netherrack, misc ──────────────────────────────────────
    "minecraft:mud_bricks_wall": "mudBlock",
    "minecraft:mud_brick_wall": "mudBlock",
    "minecraft:mud_brick_slab": "mudBlock",
    "minecraft:mud_brick_stairs": "mudBlock",
    "minecraft:mud": "mudBlock",
    "minecraft:netherrack": "magmaBlock",
    "minecraft:birch_wall_sign": "signPostBirch",
    "minecraft:birch_sign": "signPostBirch",
    "minecraft:jungle_sign": "signPostMaple",
    "minecraft:jungle_wall_sign": "signPostMaple",
    "minecraft:acacia_sign": "signPostMaple",
    "minecraft:acacia_wall_sign": "signPostMaple",
    "minecraft:cherry_sign": "signPostCherryBlossom",
    "minecraft:cherry_wall_sign": "signPostCherryBlossom",

    # ── remaining odds this pack turned up ────────────────────────────────
    "minecraft:fire_coral_fan": "coralBlockPink",
    "minecraft:brain_coral_fan": "coralBlockPink",
    "minecraft:horn_coral_fan": "coralBlockYellow",
    "minecraft:tube_coral_fan": "coralBlockLightBlue",
    "minecraft:bubble_coral_fan": "coralBlockBlue",
    "minecraft:dead_fire_coral_fan": "clayWhite",
    "minecraft:dead_brain_coral_fan": "clayWhite",
    "minecraft:dark_oak_shelf": "hickorySlab",
    "minecraft:bamboo_shelf": "bambooDriedBlock",
    "minecraft:warped_shelf": "spiritSlab",
    "minecraft:oak_shelf": "oakSlab",
    "minecraft:spruce_shelf": "pineSlab",
    "minecraft:birch_shelf": "birchSlab",
    "minecraft:iron_chain": "ironBlock",
    "minecraft:copper_chain": "copperBlock",
    "minecraft:dark_oak_button": "furnitureLampWall",
    "minecraft:purpur_block": "clayPurple",
    "minecraft:purpur_pillar": "clayPurple",
    "minecraft:purpur_stairs": "pastelPurpleStair",
    "minecraft:purpur_slab": "pastelPurpleSlab",
    "minecraft:end_stone": "sandstoneSmooth",
    "minecraft:end_stone_bricks": "sandstoneSmoothBrick",
    "minecraft:end_stone_brick_wall": "sandstoneSmoothBrick",
    "minecraft:end_stone_brick_slab": "sandstoneSmoothBrickSlab",
    "minecraft:end_stone_brick_stairs": "stairSandstoneSmoothBrick",
    "minecraft:chiseled_bookshelf": "hickoryPlank",
    "minecraft:loom": "woodPlank",
    "minecraft:cartography_table": "woodPlank",
    "minecraft:fletching_table": "woodPlank",
    "minecraft:smithing_table": "hickoryPlank",
    "minecraft:barrel_open": "pinePlank",
    "minecraft:mossy_stone_brick_wall": "stoneBrickMossy",
    "minecraft:red_nether_brick_stairs": "sandstoneRedBrick",
    "minecraft:red_nether_brick_slab": "sandstoneRedBrickSlab",
    "minecraft:pale_moss_carpet": "carpetLightGreen",
    "minecraft:pale_moss_block": "mossyBlock",
    "minecraft:pale_hanging_moss": "mossyBlock",
    "minecraft:candle": "clayWhite",
    "minecraft:white_candle": "clayWhite",
    "minecraft:black_candle": "clayBlack",
    "minecraft:gray_candle": "clayBlack",
    "minecraft:light_gray_candle": "clayWhite",
    "minecraft:red_candle": "clayRed",
    "minecraft:orange_candle": "clayOrange",
    "minecraft:yellow_candle": "clayYellow",
    "minecraft:brown_candle": "clayOrange",
    "minecraft:lime_candle": "clayLightGreen",
    "minecraft:green_candle": "clayDarkGreen",
    "minecraft:cyan_candle": "clayCyan",
    "minecraft:light_blue_candle": "clayCyan",
    "minecraft:blue_candle": "clayBlue",
    "minecraft:purple_candle": "clayPurple",
    "minecraft:magenta_candle": "clayPink",
    "minecraft:pink_candle": "clayPink",

    # ── deepslate ores (used as decorative speckled stone) ────────────────
    "minecraft:deepslate_coal_ore": "coalBlock",
    "minecraft:deepslate_iron_ore": "ironBlock",
    "minecraft:deepslate_copper_ore": "copperBlock",
    "minecraft:deepslate_gold_ore": "goldBlock",
    "minecraft:deepslate_diamond_ore": "diamondBlock",
    "minecraft:deepslate_emerald_ore": "slimeBlockGreen",
    "minecraft:deepslate_redstone_ore": "rubyBlock",
    "minecraft:deepslate_lapis_ore": "buffalkorCrystalBlock",
    "minecraft:nether_gold_ore": "goldBlock",
    "minecraft:nether_quartz_ore": "marbleBlock",
    "minecraft:ancient_debris": "basaltCarved",
    "minecraft:netherite_block": "basaltCarved",

    # ── misc blocks this pack used ────────────────────────────────────────
    "minecraft:stripped_warped_hyphae": "woodSpirit",
    "minecraft:stripped_crimson_hyphae": "woodCherryBlossom",
    "minecraft:stripped_pale_oak_wood": "woodBirch",
    "minecraft:honeycomb_block": "honeycombBlock",
    "minecraft:honey_block": "honeyBlock",
    "minecraft:sponge": "clayYellow",
    "minecraft:wet_sponge": "clayYellow",
    "minecraft:dried_kelp_block": "clayDarkGreen",
    "minecraft:lightning_rod": "copperBlock",
    "minecraft:dark_oak_pressure_plate": "hickorySlab",
    "minecraft:birch_pressure_plate": "birchSlab",
    "minecraft:jungle_pressure_plate": "mapleSlab",
    "minecraft:acacia_pressure_plate": "mapleSlab",
    "minecraft:exposed_cut_copper_slab": "copperBlock",
    "minecraft:exposed_cut_copper_stairs": "copperBlock",
    "minecraft:weathered_cut_copper_slab": "prismarineSlab",
    "minecraft:weathered_cut_copper_stairs": "prismarineStair",
    "minecraft:dead_tube_coral_fan": "clayWhite",
    "minecraft:dead_bubble_coral_fan": "clayWhite",
    "minecraft:dead_horn_coral_fan": "clayWhite",
    "minecraft:cocoa": "clayOrange",
    "minecraft:white_wall_banner": "woolWhite",
    "minecraft:black_wall_banner": "woolBlack",
    "minecraft:gray_wall_banner": "clayBlack",
    "minecraft:light_gray_wall_banner": "clayWhite",
    "minecraft:red_wall_banner": "woolRed",
    "minecraft:orange_wall_banner": "woolOrange",
    "minecraft:yellow_wall_banner": "woolYellow",
    "minecraft:lime_wall_banner": "woolLightGreen",
    "minecraft:green_wall_banner": "woolDarkGreen",
    "minecraft:cyan_wall_banner": "woolCyan",
    "minecraft:blue_wall_banner": "woolBlue",
    "minecraft:purple_wall_banner": "woolPurple",
    "minecraft:magenta_wall_banner": "woolPink",
    "minecraft:pink_wall_banner": "woolPink",
    "minecraft:brown_wall_banner": "clayOrange",

    # ── remaining odds ────────────────────────────────────────────────────
    "minecraft:beehive": "honeycombBlock",
    "minecraft:bee_nest": "honeycombBlock",
    "minecraft:jungle_wood": "woodMaple",
    "minecraft:decorated_pot": "clayOrange",
    "minecraft:sea_pickle": "glowingMushroomGreenBlock",
    "minecraft:brown_glazed_terracotta": "clayOrange",
    "minecraft:yellow_glazed_terracotta": "clayYellow",
    "minecraft:orange_glazed_terracotta": "clayOrange",
    "minecraft:lime_glazed_terracotta": "clayLightGreen",
    "minecraft:purple_glazed_terracotta": "clayPurple",
    "minecraft:magenta_glazed_terracotta": "clayPink",
    "minecraft:pink_glazed_terracotta": "clayPink",
    "minecraft:light_blue_glazed_terracotta": "clayCyan",
    "minecraft:weathered_copper_trapdoor": "trapDoorIronFlipped",
    "minecraft:exposed_copper_trapdoor": "trapDoorIronFlipped",
    "minecraft:oxidized_copper_trapdoor": "trapDoorIronFlipped",
    "minecraft:copper_trapdoor": "trapDoorIronFlipped",
    "minecraft:copper_door": "doorIron",
    "minecraft:copper_grate": "copperBlock",
    "minecraft:copper_bulb": "ledLight",
    "minecraft:ender_chest": "voidStoneBlock",
    "minecraft:skeleton_skull": "boneBlock",
    "minecraft:wither_skeleton_skull": "coalBlock",
    "minecraft:zombie_head": "clayDarkGreen",
    "minecraft:creeper_head": "clayLightGreen",
    "minecraft:dragon_head": "clayBlack",
    "minecraft:calibrated_sculk_sensor": "voidStoneCarved",
    "minecraft:sculk_sensor": "voidStoneCarved",
    "minecraft:sculk_shrieker": "voidStoneCarved",
    "minecraft:warped_pressure_plate": "spiritSlab",
    "minecraft:crimson_pressure_plate": "cherryBlossomSlab",
    "minecraft:crimson_wall_sign": "signPostCherryBlossom",
    "minecraft:crimson_sign": "signPostCherryBlossom",
    "minecraft:warped_wall_sign": "signPostSpirit",
    "minecraft:warped_sign": "signPostSpirit",
    "minecraft:oak_hanging_sign": "oakSlab",
    "minecraft:oak_wall_hanging_sign": "oakSlab",
    "minecraft:spruce_hanging_sign": "pineSlab",
    "minecraft:spruce_wall_hanging_sign": "pineSlab",
    "minecraft:birch_hanging_sign": "birchSlab",
    "minecraft:birch_wall_hanging_sign": "birchSlab",
    "minecraft:jungle_hanging_sign": "mapleSlab",
    "minecraft:jungle_wall_hanging_sign": "mapleSlab",
    "minecraft:acacia_hanging_sign": "mapleSlab",
    "minecraft:acacia_wall_hanging_sign": "mapleSlab",
    "minecraft:dark_oak_hanging_sign": "hickorySlab",
    "minecraft:dark_oak_wall_hanging_sign": "hickorySlab",
    "minecraft:mangrove_hanging_sign": "cherryBlossomSlab",
    "minecraft:cherry_hanging_sign": "cherryBlossomSlab",
    "minecraft:bamboo_hanging_sign": "bambooDriedBlock",
    "minecraft:crimson_hanging_sign": "cherryBlossomSlab",
    "minecraft:warped_hanging_sign": "spiritSlab",
    "minecraft:crimson_nylium": "glowingMushroomPinkBlock",
    "minecraft:warped_nylium": "glowingMushroomCyanBlock",
    "minecraft:target": "targetBlockWood",
    "minecraft:stripped_bamboo_block": "bambooDriedBlock",
    "minecraft:magma_block": "magmaBlock",
    "minecraft:water_cauldron": "ironBlock",
    "minecraft:lava_cauldron": "ironBlock",
    "minecraft:powder_snow_cauldron": "ironBlock",
    "minecraft:light_gray_bed": "clayWhite",
    "minecraft:gray_bed": "clayBlack",
    "minecraft:black_bed": "woolBlack",
    "minecraft:brown_bed": "clayOrange",
    "minecraft:cyan_bed": "woolCyan",
    "minecraft:light_blue_bed": "woolCyan",
    "minecraft:lime_bed": "woolLightGreen",
    "minecraft:magenta_bed": "woolPink",
    "minecraft:orange_bed": "woolOrange",
    "minecraft:pink_bed": "woolPink",
    "minecraft:purple_bed": "woolPurple",
    "minecraft:yellow_bed": "woolYellow",

    # ── redstone / utility ────────────────────────────────────────────────
    "minecraft:piston": "ironBlock",
    "minecraft:sticky_piston": "slimeBlockGreen",
    "minecraft:piston_head": "hickoryPlank",
    "minecraft:moving_piston": "ironBlock",
    "minecraft:observer": "slateSmooth",
    "minecraft:dispenser": "cobblestoneBlock",
    "minecraft:dropper": "cobblestoneBlock",
    "minecraft:daylight_detector": "hickorySlab",
    "minecraft:conduit": "prismarineBrick",
    "minecraft:heavy_core": "basaltCarved",
    "minecraft:suspicious_gravel": "cobblestoneBlock",
    "minecraft:suspicious_sand": "sand",
    "minecraft:dried_ghast": "boneBlock",

    # ── tuff bricks (1.21) ────────────────────────────────────────────────
    "minecraft:tuff_brick_slab": "andesiteBrickSlab",
    "minecraft:tuff_brick_stairs": "andesiteBrickStair",
    "minecraft:tuff_brick_wall": "andesiteBrick",
    "minecraft:chiseled_tuff": "andesiteCarved",
    "minecraft:chiseled_tuff_bricks": "andesiteCarved",
    "minecraft:polished_tuff_slab": "andesiteSlab",
    "minecraft:polished_tuff_stairs": "andesiteStair",
    "minecraft:polished_tuff_wall": "andesiteSmooth",

    # ── waxed copper odds ─────────────────────────────────────────────────
    "minecraft:waxed_weathered_copper_trapdoor": "trapDoorIronFlipped",
    "minecraft:waxed_exposed_copper_trapdoor": "trapDoorIronFlipped",
    "minecraft:waxed_oxidized_copper_trapdoor": "trapDoorIronFlipped",
    "minecraft:waxed_copper_trapdoor": "trapDoorIronFlipped",
    "minecraft:waxed_lightning_rod": "copperBlock",
    "minecraft:waxed_copper_chain": "copperBlock",
    "minecraft:waxed_oxidized_copper_chain": "prismarineBlock",
    "minecraft:waxed_weathered_copper_chain": "prismarineBlock",
    "minecraft:waxed_exposed_copper_chain": "copperBlock",
    "minecraft:oxidized_copper_chain": "prismarineBlock",
    "minecraft:weathered_copper_chain": "prismarineBlock",
    "minecraft:exposed_copper_chain": "copperBlock",

    # ── coral wall fans ───────────────────────────────────────────────────
    "minecraft:dead_horn_coral_wall_fan": "clayWhite",
    "minecraft:dead_bubble_coral_wall_fan": "clayWhite",
    "minecraft:dead_tube_coral_wall_fan": "clayWhite",
    "minecraft:dead_brain_coral_wall_fan": "clayWhite",
    "minecraft:dead_fire_coral_wall_fan": "clayWhite",
    "minecraft:dead_bubble_coral": "clayWhite",
    "minecraft:dead_horn_coral": "clayWhite",
    "minecraft:dead_tube_coral": "clayWhite",
    "minecraft:dead_brain_coral": "clayWhite",
    "minecraft:dead_fire_coral": "clayWhite",

    # ── banners and signs ─────────────────────────────────────────────────
    "minecraft:white_banner": "woolWhite",
    "minecraft:black_banner": "woolBlack",
    "minecraft:gray_banner": "clayBlack",
    "minecraft:light_gray_banner": "clayWhite",
    "minecraft:red_banner": "woolRed",
    "minecraft:orange_banner": "woolOrange",
    "minecraft:yellow_banner": "woolYellow",
    "minecraft:lime_banner": "woolLightGreen",
    "minecraft:green_banner": "woolDarkGreen",
    "minecraft:cyan_banner": "woolCyan",
    "minecraft:light_blue_banner": "woolCyan",
    "minecraft:blue_banner": "woolBlue",
    "minecraft:purple_banner": "woolPurple",
    "minecraft:magenta_banner": "woolPink",
    "minecraft:pink_banner": "woolPink",
    "minecraft:brown_banner": "clayOrange",
    "minecraft:pale_oak_sign": "signPostBirch",
    "minecraft:pale_oak_wall_sign": "signPostBirch",
    "minecraft:pale_oak_shelf": "birchSlab",
    "minecraft:pale_oak_hanging_sign": "birchSlab",
    "minecraft:dark_oak_sign": "signPostHickory",
    "minecraft:spruce_wall_hanging_sign": "pineSlab",
    "minecraft:wither_skeleton_wall_skull": "coalBlock",
    "minecraft:skeleton_wall_skull": "boneBlock",
    "minecraft:player_wall_head": "boneBlock",
    "minecraft:sulfur_wall": "clayYellow",
    "minecraft:sulfur_block": "clayYellow",

    # ── shapes the updated palette finally has ────────────────────────────
    "minecraft:oak_sapling": "sapling",
    "minecraft:spruce_sapling": "saplingPine",
    "minecraft:birch_sapling": "saplingBirch",
    "minecraft:jungle_sapling": "saplingMaple",
    "minecraft:acacia_sapling": "saplingMaple",
    "minecraft:dark_oak_sapling": "saplingHickory",
    "minecraft:mangrove_sapling": "saplingCherryBlossom",
    "minecraft:cherry_sapling": "saplingCherryBlossom",
    "minecraft:pale_oak_sapling": "saplingBirch",
    "minecraft:bamboo_sapling": "saplingMaple",
    "minecraft:warped_fungus": "saplingSpirit",
    "minecraft:crimson_fungus": "saplingCherryBlossom",
    "minecraft:grass": "tallGrass",
    "minecraft:short_grass": "tallGrass",
    "minecraft:tall_grass": "tallGrass",
    "minecraft:fern": "tallGrass",
    "minecraft:large_fern": "tallGrass",
    "minecraft:seagrass": "tallGrass",
    "minecraft:dead_bush": "saplingHickory",
    "minecraft:bamboo_pressure_plate": "trapDoorMapleFlipped",
    "minecraft:repeater": "stoneSmooth",
    "minecraft:comparator": "stoneSmooth",
    "minecraft:kelp": "tallGrass",
    "minecraft:kelp_plant": "tallGrass",
    "minecraft:big_dripleaf_stem": "tallGrass",
    "minecraft:tall_seagrass": "tallGrass",
    "minecraft:end_portal_frame": "voidStoneCarved",
    # flowers and small plants: Islands has no flower, so tall grass stands
    # in rather than losing the greenery altogether
    "minecraft:dandelion": "tallGrass",
    "minecraft:poppy": "tallGrass",
    "minecraft:blue_orchid": "tallGrass",
    "minecraft:allium": "tallGrass",
    "minecraft:azure_bluet": "tallGrass",
    "minecraft:oxeye_daisy": "tallGrass",
    "minecraft:cornflower": "tallGrass",
    "minecraft:lily_of_the_valley": "tallGrass",
    "minecraft:sunflower": "tallGrass",
    "minecraft:lilac": "tallGrass",
    "minecraft:rose_bush": "tallGrass",
    "minecraft:peony": "tallGrass",
    "minecraft:brown_mushroom": "tallGrass",
    "minecraft:red_mushroom": "tallGrass",
    "minecraft:sweet_berry_bush": "tallGrass",
    "minecraft:lily_pad": "carpetDarkGreen",

    # ── gaps found by auditing the map against vanilla ────────────────────
    "minecraft:magenta_carpet": "carpetPink",
    "minecraft:magenta_stained_glass_pane": "glassPanePink",
    "minecraft:acacia_button": "furnitureLampWall",
    "minecraft:cherry_button": "furnitureLampWall",
    "minecraft:cherry_fence_gate": "fenceCherryBlossom",
    "minecraft:cherry_pressure_plate": "cherryBlossomSlab",
    "minecraft:mangrove_pressure_plate": "cherryBlossomSlab",
    "minecraft:pale_oak_pressure_plate": "birchSlab",
    "minecraft:smooth_red_sandstone_stairs": "stairSandstoneSmoothRed",

    # resin, from the Pale Garden (1.21.4)
    "minecraft:resin_block": "clayOrange",
    "minecraft:resin_bricks": "sandstoneSmoothRedBrick",
    "minecraft:resin_brick_slab": "sandstoneSmoothRedBrickSlab",
    "minecraft:resin_brick_stairs": "stairSandstoneSmoothRedBrick",
    "minecraft:resin_brick_wall": "sandstoneSmoothRedBrick",
    "minecraft:chiseled_resin_bricks": "sandstoneSmoothRedBrick",
    "minecraft:creaking_heart": "woodBirch",

    # copper and the 1.21 additions
    "minecraft:chiseled_copper": "copperBlock",
    "minecraft:exposed_chiseled_copper": "copperBlock",
    "minecraft:weathered_chiseled_copper": "prismarineBlock",
    "minecraft:oxidized_chiseled_copper": "prismarineBlock",
    "minecraft:waxed_chiseled_copper": "copperBlock",
    "minecraft:crafter": "hickoryPlank",
    "minecraft:trial_spawner": "voidStoneCarved",
    "minecraft:vault": "voidStoneCarved",
    "minecraft:spawner": "voidStoneCobble",
    "minecraft:reinforced_deepslate": "slateCarved",

    # other solid blocks worth carrying
    "minecraft:slime_block": "slimeBlockGreen",
    "minecraft:tnt": "redBlock",
    "minecraft:cake": "woolWhite",
    "minecraft:dragon_egg": "voidStoneBlock",
    "minecraft:respawn_anchor": "voidStonePolished",
    "minecraft:turtle_egg": "boneBlock",
    "minecraft:budding_amethyst": "amethystBlock",
    "minecraft:infested_cobblestone": "cobblestoneBlock",
    "minecraft:infested_deepslate": "slateBlock",
    "minecraft:chiseled_red_sandstone_slab": "sandstoneRedBrickSlab",
    "minecraft:stripped_dark_oak_log": "woodHickory",
    "minecraft:stripped_jungle_log": "woodMaple",
    "minecraft:stripped_acacia_log": "woodMaple",
    "minecraft:stripped_mangrove_log": "woodCherryBlossom",
    "minecraft:stripped_cherry_log": "woodCherryBlossom",
    "minecraft:raw_gold_block": "goldBlock",
    "minecraft:raw_iron_block": "ironBlock",
    "minecraft:raw_copper_block": "copperBlock",
    "minecraft:shulker_box": "clayPurple",
    "minecraft:white_shulker_box": "clayWhite",
    "minecraft:black_shulker_box": "clayBlack",
    "minecraft:red_shulker_box": "clayRed",
    "minecraft:orange_shulker_box": "clayOrange",
    "minecraft:yellow_shulker_box": "clayYellow",
    "minecraft:lime_shulker_box": "clayLightGreen",
    "minecraft:green_shulker_box": "clayDarkGreen",
    "minecraft:cyan_shulker_box": "clayCyan",
    "minecraft:light_blue_shulker_box": "clayCyan",
    "minecraft:blue_shulker_box": "clayBlue",
    "minecraft:purple_shulker_box": "clayPurple",
    "minecraft:magenta_shulker_box": "clayPink",
    "minecraft:pink_shulker_box": "clayPink",
    "minecraft:brown_shulker_box": "clayOrange",
    "minecraft:gray_shulker_box": "clayBlack",
    "minecraft:light_gray_shulker_box": "clayWhite",
    "minecraft:light_blue_stained_glass_pane": "glassPaneCyan",
    "minecraft:acacia_door": "doorPine2",
    "minecraft:acacia_fence_gate": "fenceMaple",
    "minecraft:jungle_fence_gate": "fenceMaple",
    "minecraft:blackstone_slab": "basaltSlab",
    "minecraft:blackstone_stairs": "basaltStair",
    "minecraft:nether_brick_wall": "basaltTiles",
    "minecraft:redstone_torch": "ledLight",
    "minecraft:soul_torch": "torch",
    "minecraft:soul_wall_torch": "torch",
    "minecraft:redstone_wall_torch": "ledLight",
    "minecraft:ochre_froglight": "glowingMushroomGreenBlock",
    "minecraft:verdant_froglight": "glowingMushroomBlueBlock",
    "minecraft:pearlescent_froglight": "ledLight",
    "minecraft:shroomlight": "ledLight",
    "minecraft:deepslate": "slateBlock",
    "minecraft:polished_deepslate": "slateSmooth",
    "minecraft:deepslate_bricks": "slateBrick",
    "minecraft:deepslate_tiles": "slateTiles",
    "minecraft:chiseled_deepslate": "slateCarved",
    "minecraft:cobbled_deepslate": "slateBlock",
    "minecraft:calcite": "pearlBlock",
    "minecraft:tuff": "andesiteTiles",
    "minecraft:dripstone_block": "sandstoneSmooth",
    "minecraft:moss_block": "mossyBlock",
    "minecraft:rooted_dirt": "mudBlock",
    "minecraft:amethyst_block": "amethystBlock",
    "minecraft:copper_block": "copperBlock",
    "minecraft:oxidized_copper": "prismarineBlock",
    "minecraft:mud_bricks": "mudBlock",
    "minecraft:packed_mud": "mudBlock",

    # Natural stones. world_to_islands strips these via BULK before it gets
    # here; a schematic keeps them, because there they are deliberate.
    "minecraft:stone": "stone",
    "minecraft:andesite": "andesite",
    "minecraft:diorite": "diorite",
    "minecraft:granite": "granite",
    "minecraft:dirt": "mudBlock",
    "minecraft:gravel": "cobblestoneBlock",
    "minecraft:sand": "sand",
    "minecraft:red_sand": "sandstoneRed",
    "minecraft:clay": "clay",
    "minecraft:obsidian": "voidStoneBlock",
    "minecraft:crying_obsidian": "voidStonePolished",
    "minecraft:ice": "ice",
    "minecraft:packed_ice": "iceCompact",
    "minecraft:blue_ice": "iceCompact",
    "minecraft:snow_block": "snowCompact",
    "minecraft:water": "slimeBlockBlue",
    "minecraft:coal_ore": "coalBlock",
    "minecraft:iron_ore": "ironBlock",
    "minecraft:gold_ore": "goldBlock",
    "minecraft:diamond_ore": "diamondBlock",
    "minecraft:emerald_ore": "amethystBlock",
    "minecraft:redstone_ore": "redBlock",
    "minecraft:lapis_ore": "blueBlock",

    # 1.17+ odds and ends
    "minecraft:quartz_bricks": "marbleBrick",
    "minecraft:quartz_slab": "marbleSlab",
    "minecraft:azalea_leaves": "leavesBlock",
    "minecraft:flowering_azalea_leaves": "leavesBlock",
    "minecraft:azalea": "leavesBlock",
    "minecraft:flowering_azalea": "leavesBlock",
    "minecraft:mangrove_leaves": "leavesBlock",
    "minecraft:mangrove_planks": "cherryBlossomPlank",
    "minecraft:mangrove_log": "woodCherryBlossom",
    "minecraft:cherry_leaves": "leavesBlock",
    "minecraft:cherry_planks": "cherryBlossomPlank",
    "minecraft:cherry_log": "woodCherryBlossom",
    "minecraft:bamboo_planks": "bambooBlock",
    "minecraft:bamboo_block": "bambooBlock",
    "minecraft:moss_carpet": "carpetDarkGreen",
    "minecraft:big_dripleaf": "leavesBlock",
    "minecraft:glow_lichen": "mossyBlock",
    "minecraft:sculk": "voidBlock",
    "minecraft:sculk_catalyst": "voidStoneCarved",
    "minecraft:cracked_polished_blackstone_bricks": "basaltBrick",
    "minecraft:chiseled_polished_blackstone": "basaltCarved",
    "minecraft:gilded_blackstone": "basaltBrick",
    "minecraft:cracked_nether_bricks": "basaltTiles",
    "minecraft:chiseled_nether_bricks": "basaltCarved",
    "minecraft:cracked_deepslate_bricks": "slateBrick",
    "minecraft:cracked_deepslate_tiles": "slateTiles",

    # ── deepslate family (1.17+) ──────────────────────────────────────────
    "minecraft:deepslate_brick_slab": "slateBrickSlab",
    "minecraft:deepslate_brick_stairs": "stairSlateBrick",
    "minecraft:deepslate_brick_wall": "slateBrick",
    "minecraft:deepslate_tile_slab": "slateSlab",
    "minecraft:deepslate_tile_stairs": "stairSlate",
    "minecraft:deepslate_tile_wall": "slateTiles",
    "minecraft:polished_deepslate_slab": "slateSlab",
    "minecraft:polished_deepslate_stairs": "stairSlate",
    "minecraft:polished_deepslate_wall": "slateSmooth",
    "minecraft:cobbled_deepslate_slab": "slateSlab",
    "minecraft:cobbled_deepslate_stairs": "stairSlate",
    "minecraft:cobbled_deepslate_wall": "slateBlock",

    # ── blackstone family ─────────────────────────────────────────────────
    "minecraft:polished_blackstone_brick_stairs": "basaltBrickStair",
    "minecraft:polished_blackstone_brick_slab": "basaltBrickSlab",
    "minecraft:polished_blackstone_brick_wall": "basaltBrick",
    "minecraft:blackstone_wall": "basalt",
    "minecraft:polished_blackstone_pressure_plate": "basaltSlab",

    # ── pale oak (1.21.4) ─────────────────────────────────────────────────
    "minecraft:pale_oak_planks": "birchPlank",
    "minecraft:pale_oak_slab": "birchSlab",
    "minecraft:pale_oak_stairs": "stairBirch",
    "minecraft:pale_oak_log": "woodBirch",
    "minecraft:pale_oak_wood": "woodBirch",
    "minecraft:stripped_pale_oak_log": "woodBirch",
    "minecraft:pale_oak_fence": "fenceBirch",
    "minecraft:pale_oak_fence_gate": "fenceBirch",
    "minecraft:pale_oak_door": "doorPine2",
    "minecraft:pale_oak_trapdoor": "trapDoorBirchFlipped",
    "minecraft:pale_oak_button": "furnitureLampWall",
    "minecraft:pale_oak_leaves": "leavesBlock",

    # ── copper ────────────────────────────────────────────────────────────
    "minecraft:cut_copper": "copperBlock",
    "minecraft:cut_copper_slab": "copperBlock",
    "minecraft:cut_copper_stairs": "copperBlock",
    "minecraft:exposed_copper": "copperBlock",
    "minecraft:exposed_cut_copper": "copperBlock",
    "minecraft:weathered_copper": "prismarineBlock",
    "minecraft:weathered_cut_copper": "prismarineBlock",
    "minecraft:oxidized_cut_copper": "prismarineBlock",
    "minecraft:oxidized_cut_copper_slab": "prismarineSlab",
    "minecraft:oxidized_cut_copper_stairs": "prismarineStair",

    # ── misc walls and odds ───────────────────────────────────────────────
    "minecraft:tuff_wall": "andesiteTiles",
    "minecraft:tuff_bricks": "andesiteBrick",
    "minecraft:polished_tuff": "andesiteSmooth",
    "minecraft:tuff_slab": "andesiteBrickSlab",
    "minecraft:tuff_stairs": "andesiteBrickStair",
    "minecraft:prismarine_wall": "prismarineBlock",
    "minecraft:granite_wall": "granite",
    "minecraft:sandstone_wall_red": "sandstoneRed",
    "minecraft:red_sandstone_wall": "sandstoneRed",
    "minecraft:chipped_anvil": "ironBlock",
    "minecraft:damaged_anvil": "ironBlock",
    "minecraft:gray_glazed_terracotta": "clayBlack",
    "minecraft:white_glazed_terracotta": "clayWhite",
    "minecraft:black_glazed_terracotta": "clayBlack",
    "minecraft:blue_glazed_terracotta": "clayBlue",
    "minecraft:cyan_glazed_terracotta": "clayCyan",
    "minecraft:red_glazed_terracotta": "clayRed",
    "minecraft:green_glazed_terracotta": "clayDarkGreen",
    "minecraft:light_gray_glazed_terracotta": "clayWhite",
}

# Small decorations with no sensible block equivalent: dropped rather than
# turned into a full cube that would look wrong.
DROP = {
    "minecraft:large_fern",
                "minecraft:dead_bush",
    "minecraft:sugar_cane",
    "minecraft:wheat", "minecraft:carrots", "minecraft:potatoes", "minecraft:beetroots",
    "minecraft:snow",
        "minecraft:rail", "minecraft:redstone_wire", "minecraft:tripwire",
    "minecraft:air", "minecraft:cave_air", "minecraft:void_air",
    "minecraft:light",          # invisible light source, nothing to place
    "minecraft:fire",
    "minecraft:bush", "minecraft:hanging_roots",
    "minecraft:small_dripleaf", "minecraft:pink_petals", "minecraft:torchflower",
    "minecraft:pitcher_plant", "minecraft:spore_blossom", "minecraft:cave_vines",
    "minecraft:cave_vines_plant", "minecraft:twisting_vines", "minecraft:weeping_vines",
    "minecraft:mangrove_propagule", "minecraft:seagrass",
    "minecraft:firefly_bush", "minecraft:twisting_vines_plant",
    "minecraft:small_amethyst_bud", "minecraft:medium_amethyst_bud",
    "minecraft:warped_roots", "minecraft:crimson_roots", "minecraft:nether_sprouts",
    "minecraft:leaf_litter", "minecraft:cactus_flower", "minecraft:wildflowers",
            "minecraft:soul_fire", "minecraft:resin_clump", "minecraft:sea_pickle",
    "minecraft:pointed_dripstone", "minecraft:sea_pickle_single",
    "minecraft:large_amethyst_bud", "minecraft:amethyst_cluster",
    "minecraft:weeping_vines_plant", "minecraft:white_tulip", "minecraft:red_tulip",
    "minecraft:orange_tulip", "minecraft:pink_tulip", "minecraft:wither_rose",
    "minecraft:barrier", "minecraft:structure_void",
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




# ── orientation ─────────────────────────────────────────────────────────────
# An Islands cframe is [x, y, z, Rx, Ry, Rz, Ux, Uy, Uz]: position, then the
# RightVector and UpVector. Identity looks toward -Z, which is Minecraft north,
# so a stair's `facing` becomes a rotation about Y.
IDENTITY = (1, 0, 0, 0, 1, 0)

# Vanilla's own blockstate files rotate stairs from an EAST-facing base model:
# east y=0, south y=90, west y=180, north y=270. Minecraft turns clockwise seen
# from above and Roblox turns counter-clockwise, so the sign flips on the way
# across. Treating north as the base (the obvious-looking choice) puts every
# stair in a build a quarter turn out.
QUARTER_TURNS = [
    (1, 0, 0, 0, 1, 0),     # 0
    (0, 0, 1, 0, 1, 0),     # 90
    (-1, 0, 0, 0, 1, 0),    # 180
    (0, 0, -1, 0, 1, 0),    # 270
]

# Turn the whole build if Islands' stair model faces some other way than the
# vanilla base: 1 adds 90 degrees, 2 adds 180, and so on.
#
# Each step of this turns the build a further quarter turn clockwise seen from
# above, so 3 is one quarter turn to the left of the vanilla base. Islands'
# stair models sit a quarter turn left of where vanilla's do; anything else put
# converted stairs in the wall or backwards.
FACING_OFFSET = 1

_FACING_STEPS = {"east": 0, "south": 1, "west": 2, "north": 3}
FACING_ROT = {
    name: QUARTER_TURNS[(step + FACING_OFFSET) % 4]
    for name, step in _FACING_STEPS.items()
}

# Logs and pillars lie along their axis; tip the up-vector to match.
AXIS_ROT = {
    "y": (1, 0, 0, 0, 1, 0),
    "x": (0, 1, 0, 1, 0, 0),
    "z": (1, 0, 0, 0, 0, 1),
}


def is_slab(target):
    """Islands slabs are the only half-height blocks."""
    return "slab" in target.lower()


def _sanitise(target, upper, doubled):
    """Only a slab can sit in half a cell.

    Minecraft says `half=top` for an upside-down stair, and a legacy double
    slab of stone maps to plain stone here. Neither is half-height in Islands,
    and a full block flagged upperBlock gets shoved into the cell above - the
    stairs and blocks that looked embedded in each other. A doubled entry is
    only a second half when there is a half to double.
    """
    if not is_slab(target):
        return False, False
    return upper, doubled


def parse_state(state):
    """'minecraft:oak_stairs[facing=north,half=top]' -> (name, {props})."""
    if "[" not in state:
        return state, {}
    base, rest = state.split("[", 1)
    props = {}
    for kv in rest.rstrip("]").split(","):
        if "=" in kv:
            k, v = kv.split("=", 1)
            props[k] = v
    return base, props


def resolve(state):
    """Full block state -> (islands_name, rotation, upperBlock, doubled).

    `doubled` marks a double slab, which needs both halves placing to fill the
    cell. Returns None when the block has no Islands equivalent.
    """
    base, props = parse_state(state)
    target = islands_name(base)
    if target is None:
        return None

    rot = IDENTITY
    upper = False
    doubled = False

    facing = props.get("facing")
    if facing in FACING_ROT:
        rot = FACING_ROT[facing]
    else:
        axis = props.get("axis")
        if axis in AXIS_ROT:
            rot = AXIS_ROT[axis]

    # stairs sit in the upper half when half=top; slabs when type=top
    if props.get("half") == "top":
        upper = True
    slab = props.get("type")
    if slab == "top":
        upper = True
    elif slab == "double":
        doubled = True

    upper, doubled = _sanitise(target, upper, doubled)
    return target, rot, upper, doubled


# ── legacy numeric ids (1.12 and earlier) ────────────────────────────────────
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
    31: "grass", 37: "dandelion", 38: "poppy", 39: "brown_mushroom",
    40: "red_mushroom", 68: "oak_wall_sign", 111: "lily_pad",
    140: "flower_pot", 143: "oak_button", 144: "skeleton_skull",
    175: "tall_grass",
    25: "note_block", 33: "piston", 34: "piston_head",
    66: "rail", 71: "iron_door", 97: "infested_stone_bricks",
    120: "end_portal_frame", 138: "beacon",
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
    51: "fire", 64: "oak_door", 77: "stone_button",
    107: "oak_fence_gate", 145: "anvil", 154: "hopper",
    183: "spruce_fence_gate", 184: "birch_fence_gate", 185: "jungle_fence_gate",
    186: "dark_oak_fence_gate", 187: "acacia_fence_gate",
    188: "spruce_fence", 189: "birch_fence", 190: "jungle_fence",
    191: "dark_oak_fence", 192: "acacia_fence",
    193: "spruce_door", 194: "birch_door", 195: "jungle_door",
    196: "acacia_door", 197: "dark_oak_door",
    251: {i: c + "_concrete" for i, c in enumerate(WOOL)},
    252: {i: c + "_concrete_powder" for i, c in enumerate(WOOL)},
}


# Pre-1.13 stair metadata: low two bits are the facing, bit 2 flips it upside
# down. Slab metadata uses bit 3 for the top half.
STAIR_IDS = {53, 67, 108, 109, 114, 128, 134, 135, 136, 156, 163, 164, 180, 203}
SLAB_IDS = {44, 126, 182}
STAIR_FACING = {0: "east", 1: "west", 2: "south", 3: "north"}


def legacy_orientation(bid, data):
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



def resolve_legacy(token):
    """'legacy:98:1' -> (islands_name, rotation, upperBlock, doubled)."""
    _, sid, sdata = token.split(":")
    bid, data = int(sid), int(sdata)
    name = modern_name(bid, data)
    if name is None:
        return None
    target = islands_name(name)
    if target is None:
        return None
    rot, upper, doubled = legacy_orientation(bid, data)
    upper, doubled = _sanitise(target, upper, doubled)
    return target, rot, upper, doubled


def resolve_any(state):
    """resolve() for either format: a 1.13+ state string or a legacy token."""
    if state.startswith("legacy:"):
        return resolve_legacy(state)
    return resolve(state)


def base_of(state):
    """Modern block name for either format, for terrain tests."""
    if state.startswith("legacy:"):
        _, sid, sdata = state.split(":")
        return modern_name(int(sid), int(sdata)) or ""
    return parse_state(state)[0]


# Blocks the world generator makes on its own, shared by the world converters.
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
    "minecraft:grass", "minecraft:short_grass",     "minecraft:fern", "minecraft:large_fern", "minecraft:dead_bush",
    "minecraft:vine", "minecraft:moss_block", "minecraft:snow", "minecraft:snow_block",
    "minecraft:ice", "minecraft:packed_ice", "minecraft:blue_ice",
    "minecraft:water", "minecraft:lava", "minecraft:seagrass", "minecraft:kelp", "minecraft:sugar_cane", "minecraft:cactus",
    "minecraft:dirt_path", "minecraft:mud", "minecraft:rooted_dirt",
    "minecraft:cobweb", "minecraft:magma_block", "minecraft:obsidian", "minecraft:poppy",     "minecraft:azure_bluet",     "minecraft:brown_mushroom",     "minecraft:oak_sapling", "minecraft:spruce_sapling",
}
