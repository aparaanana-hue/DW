"""Convert a Sponge .schem schematic into an Islands build JSON.

A schematic is already just the build - no terrain to isolate - so this is a
straight walk of its block array. Sponge v2 stores BlockData as varint indices
into a palette, ordered y, then z, then x.

    python3 schem_to_islands.py <file.schem> <OutputName> [--hollow]

--hollow drops blocks whose six neighbours are all filled. They are invisible
from outside, so the build looks identical while costing far fewer blocks.
"""
import gzip, io, json, os, sys
from collections import Counter

import nbtlib
from blockmap import BULK, DROP, islands_name

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read_varints(data):
    """Sponge packs BlockData as a stream of unsigned LEB128 varints."""
    out = []
    val = 0
    shift = 0
    for byte in data:
        b = byte & 0xFF
        val |= (b & 0x7F) << shift
        if b & 0x80:
            shift += 7
        else:
            out.append(val)
            val = 0
            shift = 0
    return out


def load_schem(path):
    raw = open(path, "rb").read()
    if raw[:2] == b"\x1f\x8b":                    # gzip magic
        raw = gzip.decompress(raw)
    f = nbtlib.File.from_fileobj(io.BytesIO(raw))
    root = f["Schematic"] if "Schematic" in f else f
    return root


def base_name(state):
    """'minecraft:oak_stairs[facing=north]' -> 'minecraft:oak_stairs'."""
    return state.split("[", 1)[0]


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    src, outname = sys.argv[1], sys.argv[2]
    hollow = "--hollow" in sys.argv[3:]

    root = load_schem(src)
    W, H, L = int(root["Width"]), int(root["Height"]), int(root["Length"])

    # palette maps blockstate string -> index; invert it
    by_index = {}
    for state, idx in root["Palette"].items():
        by_index[int(idx)] = base_name(str(state))

    indices = read_varints(bytes(root["BlockData"]))
    expected = W * H * L
    if len(indices) != expected:
        print(f"warning: {len(indices)} blocks decoded, expected {expected}")

    blocks = []
    kept = Counter()
    unmapped = Counter()
    skipped_air = 0

    # Sponge v2 order: index = y*W*L + z*W + x
    for i, pi in enumerate(indices):
        name = by_index.get(pi)
        if name is None:
            continue
        if name in ("minecraft:air", "minecraft:cave_air", "minecraft:void_air"):
            skipped_air += 1
            continue
        if name in BULK:
            continue
        target = islands_name(name)
        if target is None:
            if name not in DROP and not name.startswith("minecraft:potted_"):
                unmapped[name] += 1
            continue
        y = i // (W * L)
        rem = i % (W * L)
        z = rem // W
        x = rem % W
        kept[target] += 1
        # 1 Minecraft block = 3 studs; identity rotation
        blocks.append({
            "blockType": target,
            "upperBlock": False,
            "cframe": [x * 3, y * 3, z * 3, 1, 0, 0, 0, 1, 0],
            "parts": [],
        })

    if not blocks:
        print("nothing converted")
        return

    # re-anchor to the build's own corner so the file drops in anywhere
    mnx = min(b["cframe"][0] for b in blocks)
    mny = min(b["cframe"][1] for b in blocks)
    mnz = min(b["cframe"][2] for b in blocks)
    for b in blocks:
        c = b["cframe"]
        c[0] -= mnx
        c[1] -= mny
        c[2] -= mnz

    if hollow:
        occ = {(b["cframe"][0] // 3, b["cframe"][1] // 3, b["cframe"][2] // 3) for b in blocks}
        sides = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
        before = len(blocks)
        blocks = [
            b for b in blocks
            if not all(
                (b["cframe"][0] // 3 + dx, b["cframe"][1] // 3 + dy, b["cframe"][2] // 3 + dz) in occ
                for dx, dy, dz in sides
            )
        ]
        print(f"hollowed: {before} -> {len(blocks)} blocks "
              f"({before - len(blocks)} enclosed blocks dropped)")

    os.makedirs(os.path.join(ROOT, "builds"), exist_ok=True)
    out = os.path.join(ROOT, "builds", outname + ".json")
    with open(out, "w") as f:
        json.dump({"blocks": blocks}, f)

    print("wrote", out)
    print("blocks:", len(blocks))
    print("schematic size (blocks): %d x %d x %d" % (W, H, L))
    print("\ntop Islands blocks used:")
    for n, c in kept.most_common(25):
        print(f"{c:8d}  {n}")
    if unmapped:
        print("\nUNMAPPED (dropped):", sum(unmapped.values()))
        for n, c in unmapped.most_common(60):
            print(f"{c:8d}  {n}")


if __name__ == "__main__":
    main()
