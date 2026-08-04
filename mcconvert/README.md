# Minecraft -> Islands converter

Turns Minecraft builds into Islands build files (`{ "blocks": [...] }` with
`cframe` arrays), ready to drop into `autoBuilder` and preview/build like any
other file. Output lands in `../builds/`.

1 Minecraft block = 3 studs. Every block is written with identity rotation and
anchored at the build's own corner, so a file drops in anywhere.

## Files

| file | what it does |
|---|---|
| `anvil.py` | Reads Minecraft Java world region files (`.mca`) — chunk headers, zlib, NBT, and the 1.13-1.15 packed `BlockStates` layout where entries straddle longs. |
| `blockmap.py` | Minecraft block -> Islands block. Shared by both converters. |
| `world_to_islands.py` | Converts a **world save**. Has to isolate the build from generated terrain, so it uses a hard-coded bounding box. |
| `schem_to_islands.py` | Converts a **Sponge `.schem`** schematic. Simpler — a schematic is already just the build. |

## Usage

```sh
cd mcconvert

# schematic (preferred when you have one)
python3 schem_to_islands.py path/to/build.schem OutputName
python3 schem_to_islands.py path/to/build.schem OutputName --hollow

# world save (bounding box is set at the top of the script)
python3 world_to_islands.py
python3 world_to_islands.py --hollow
```

### `--hollow`

Drops every block whose six neighbours are all filled. Those are invisible from
outside, so the build looks the same while costing far fewer blocks — on
Sapphire Lobby that is 582,730 -> 170,200 (70% off). Worth using for anything
large; skip it if you want the solid interior.

## Adding a build

A schematic needs no code change. A world save needs its bounding box: run
`world_to_islands.py` once, watch what it reports, and adjust `X0/X1`, `Y0/Y1`,
`Z0/Z1` at the top of the script.

If the run prints an `UNMAPPED` list, those block types had no Islands
equivalent and were skipped — add them to `MAP` in `blockmap.py`.

## What does not carry over

- **Rotation.** Stairs, logs and pillars all face one way; shape and colour are
  right, facing is not.
- **Shapes Islands lacks.** Walls, fences, panes, doors and carpets become the
  nearest full block or slab (carpets -> slabs, panes -> glass blocks, torches
  and lanterns -> LED light).
- **Tiny decorations.** Flowers, grass tufts and saplings are dropped rather
  than becoming full cubes that would look wrong. See `DROP` in `blockmap.py`.
