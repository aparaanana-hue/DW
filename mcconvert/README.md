# Islands build-file converters

Turns Minecraft builds — and 3D models — into Islands build files (`{ "blocks": [...] }` with
`cframe` arrays), ready to drop into `autoBuilder` and preview/build like any
other file. Output lands in `../builds/solid/` (hollowed-out versions of the
same builds live alongside it in `../builds/hollow/`, without the `Hollow`
name suffix).

1 Minecraft block = 3 studs. Blocks are anchored at the build's own corner, so
a file drops in anywhere.

Orientation carries over: an Islands cframe is `[x, y, z, Rx,Ry,Rz, Ux,Uy,Uz]`
— position, then the RightVector and UpVector. Identity looks toward -Z, which
is Minecraft north, so a stair's `facing` becomes a rotation about Y, a log's
`axis` tips the up-vector, and `half=top` / `type=top` set `upperBlock`. A
double slab is written as both halves so it fills its cell.

## Files

| file | what it does |
|---|---|
| `anvil.py` | Reads Minecraft Java world region files (`.mca`) — chunk headers, zlib, NBT, and the 1.13-1.15 packed `BlockStates` layout where entries straddle longs. |
| `blockmap.py` | Minecraft block -> Islands block. Shared by both converters. |
| `world_to_islands.py` | Converts a **world save**. Has to isolate the build from generated terrain, so it uses a hard-coded bounding box. |
| `schem_to_islands.py` | Converts a **Sponge `.schem`** schematic, version 2 or 3. Simpler — a schematic is already just the build. |
| `legacy_schematic_to_islands.py` | Converts an **old MCEdit `.schematic`**, which stores numeric block ids plus 4-bit metadata instead of a name palette. |
| `world_build_to_islands.py` | Converts one build sitting in a world — a flat "build world" with a floor plane, say. Takes the region folder plus `--miny`/`--maxy` to cut the floor off. |
| `litematic_to_islands.py` | Converts a **Litematica `.litematic`**. Same packing as pre-1.16, and a region's Size sign only says which corner `Position` is. |
| `model_to_islands.py` | Converts a **3D model** (`.glb`). Voxelises the mesh and colours each block by sampling the model's own textures. Sized by a block budget rather than a scale factor. |
| `glb.py` | Reads a `.glb` — the chunk header, the glTF JSON, node transforms, vertex accessors and the embedded textures. Hand-parsed like `anvil.py`, so the only dependency is numpy. |
| `islands_palette.py` | The 91 flat Islands blocks with their real colours, and nearest-colour matching in OKLab. A port of `IMAGE_PALETTE` in `IAB.lua`, so a converted model is coloured like a converted image. `--check` re-reads IAB.lua and asserts the two still agree. |
| `castleworld_to_islands.py` | Castle World holds several builds in one world, so it clusters the placed blocks and writes one file per castle. |

## Usage

```sh
cd mcconvert

# litematica
python3 litematic_to_islands.py path/to/build.litematic OutputName

# schematic (preferred when you have one)
python3 schem_to_islands.py path/to/build.schem OutputName
python3 schem_to_islands.py path/to/build.schem OutputName --hollow

# world save (bounding box is set at the top of the script)
python3 world_to_islands.py
python3 world_to_islands.py --hollow

# one build in a world, cutting off the floor plane below y=-48
python3 world_build_to_islands.py path/to/region OutputName --miny -48

# one build standing in scenery: skip terrain, keep only the largest
# connected structure, and drop the blocks the "water" is faked with
python3 world_build_to_islands.py path/to/region OutputName \
    --natural --largest --drop blue_stained_glass

# a world holding several builds, above a floor plane: one file each
python3 world_build_to_islands.py path/to/region OutputName \
    --natural --miny -59 --split

# a 3D model, sized to a block budget
python3 model_to_islands.py ../models/thing.glb OutputName --blocks 80000

# ...or to an exact height, filled solid, from one block type
python3 model_to_islands.py ../models/thing.glb OutputName \
    --height 120 --solid --single slateBrick

# muted stone only, capped at 12 distinct blocks
python3 model_to_islands.py ../models/thing.glb OutputName \
    --palette Stone,Clay --simplify 12
```

## 3D models

`model_to_islands.py` takes **GLB**. It is one self-contained binary file with
the mesh, materials and textures inside, and its container is simple enough to
read with `struct` and `json`. A `.gltf` scatters the same data across external
`.bin` and image files; `.fbx` has no dependable pure-Python reader. If a site
offers several texture sizes, take the 1k one — 2k detail is finer than a block
grid can show.

Unlike the Minecraft converters this one writes **both** files itself:
`../builds/solid/<Name>.json` and `../builds/hollow/<Name>.json`.

Sizing is a budget, not a scale. `--blocks 80000` measures the model at one
resolution, extrapolates (a surface grows with the square of the grid, a solid
volume with the cube), and refines — four passes, landing within a percent or
two. Ask for fewer blocks to get a coarser model of the same thing; that is the
accuracy dial.

Every block it writes is a full cube with identity rotation, placed through a
map keyed on the cell, so its output cannot contain overlapping blocks.

A rigged model is posed from its skeleton. `POSITION` in a glTF holds the
*bind* pose - arms out, the T-pose - and the pose you see in a viewer lives in
the joint node transforms. Reading positions alone gives a T-pose no matter
what the model looks like, so `JOINTS_0`/`WEIGHTS_0` and the inverse bind
matrices are applied.

Textures: PNG works out of the box. **JPEG needs Pillow** (`pip install
Pillow`) — without it those materials fall back to their flat base colour and
it says so. Draco- or meshopt-compressed meshes are refused by name rather than
silently producing nothing; re-export without compression.

### `--hollow`

Drops every block whose six neighbours are all filled. Those are invisible from
outside, so the build looks the same while costing far fewer blocks — on
Sapphire Lobby that is 723,652 -> 107,137 (85% off). Worth using for anything
large; skip it if you want the solid interior.

## Converted builds

| build | blocks | hollow | size | source |
|---|---|---|---|---|
| IvyWoodManor | 45,643 | 36,800 | 88x38x148 |
| SapphireLobby | 723,939 | 107,238 | 137x165x162 |
| ShenronDragon | 20,202 | 20,177 | 135x124x88 |
| Phoenix | 24,912 | 24,572 | 124x131x38 |
| Angel | 23,828 | 23,802 | 188x118x48 |
| Luffy | 13,624 | 13,584 | 82x118x46 |
| DragonSlayer | 32,473 | 32,185 | 148x124x79 |
| AngelV14 | 58,112 | 57,687 | 168x160x66 |
| Epsilon | 34,135 | — | 91x164x103 |
| Castle1 | 707,563 | 644,472 | 245x384x245 |
| Castle2 | 567,097 | 496,312 | 238x380x247 |
| Castle3 | 222,855 | 214,481 | 655x265x768 |
| Castle4 | 102,462 | 94,012 | 173x333x225 |
| Castle5 | 33,047 | 30,773 | 104x126x117 |
| ADragon | 33,408 | 32,769 | 150x118x78 |
| FDragonV2 | 32,676 | 32,446 | 108x120x87 |
| Dragon | 241,013 | 237,287 | 704x258x466 |
| WoFBateau | 468,448 | 420,077 | 505x239x195 |
| BigBoat | 31,377 | 29,109 | 65x123x154 |
| AsianSanctum | 171,401 | 167,037 | 159x170x232 |
| EarlyWorks1..12 | 819,291 total | — | largest 203x279x235 |
| GadangBigHouse | 340,590 | 115,957 | 158x116x113 |
| HeavenlyShelter | 109,375 | 102,984 | 201x77x99 |
| ViribusUnitis | 17,125 | 16,170 | 153x56x29 |
| SquidGame | 286,481 | 279,200 | 351x120x341 |
| Bellagio | 180,381 | 177,509 | 251x140x184 |
| Airship | 1,026,835 | 253,961 | 263x207x699 |
| RebirthEaster | 12,423 | 11,136 | 50x51x94 |
| SomethingSomething | 43,932 | 28,828 | 95x103x95 |
| Lavria | 730,123 | 339,754 | 331x107x331 |
| DreamSpawn | 25,687 | 22,514 | 79x151x79 |
| PinkPalace | 83,717 | 31,843 | 160x128x181 | generated, not converted |
| FemaleTitan | 79,860 | 42,361 | 108x290x113 | from a .glb model, posed from its skeleton |

`world_to_islands.py` strips generated terrain via `BULK`; `schem_to_islands.py`
does not, because in a schematic every block was placed on purpose. Only air and
bedrock are skipped there.

## Adding a build

A schematic needs no code change. A world save needs its bounding box: run
`world_to_islands.py` once, watch what it reports, and adjust `X0/X1`, `Y0/Y1`,
`Z0/Z1` at the top of the script.

If the run prints an `UNMAPPED` list, those block types had no Islands
equivalent and were skipped — add them to `MAP` in `blockmap.py`.

## What does not carry over

- **Stair corner shapes.** Facing and upside-down are carried over, but
  Minecraft's inner/outer corner stairs become straight ones — Islands has no
  corner variant.

If stairs come out consistently turned the wrong way, `FACING_OFFSET` in
`blockmap.py` rotates every facing block together: 1 is a quarter turn, 2 a
half turn. It is derived from vanilla's blockstate files (which rotate stairs
from an east-facing base), so 0 should be right.
- **Shapes Islands lacks.** Walls, fences, panes, doors and carpets become the
  nearest full block or slab (carpets -> slabs, panes -> glass blocks, torches
  and lanterns -> LED light).
- **Tiny decorations.** Flowers, grass tufts and saplings are dropped rather
  than becoming full cubes that would look wrong. See `DROP` in `blockmap.py`.
