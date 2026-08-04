"""Convert a Litematica .litematic schematic into an Islands build file.

Litematica packs each region's blocks as palette indices in a long array, with
entries allowed to straddle longs (the pre-1.16 layout), ordered y, then z,
then x. A region's Size may be negative, which only says which way Position
faces - the array itself always runs positively from the region's minimum
corner, so the indices are used as-is.

    python3 litematic_to_islands.py <file.litematic> <OutputName> [--hollow]
"""
import gzip, io, json, os, sys
from collections import Counter

import nbtlib
from anvil import unpack_states
from blockmap import DROP, base_of, resolve

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

AIR = {"minecraft:air", "minecraft:cave_air", "minecraft:void_air"}


def state_string(entry):
    name = str(entry["Name"])
    props = entry.get("Properties")
    if not props:
        return name
    inner = ",".join(f"{k}={str(props[k])}" for k in sorted(props.keys()))
    return f"{name}[{inner}]"


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

    blocks = []
    kept = Counter()
    unmapped = Counter()
    total_cells = 0

    for region_name, region in f["Regions"].items():
        size = region["Size"]
        sx, sy, sz = int(size["x"]), int(size["y"]), int(size["z"])
        ax, ay, az = abs(sx), abs(sy), abs(sz)
        # Position is just one corner; the block array runs positively from the
        # region minimum either way, so offset by the smaller end.
        pos = region["Position"]
        px, py_, pz = int(pos["x"]), int(pos["y"]), int(pos["z"])
        ox = px if sx > 0 else px + sx + 1
        oy = py_ if sy > 0 else py_ + sy + 1
        oz = pz if sz > 0 else pz + sz + 1

        pal = [state_string(p) for p in region["BlockStatePalette"]]
        n = len(pal)
        if n == 0:
            continue
        bits = max(2, (n - 1).bit_length())
        vol = ax * ay * az
        total_cells += vol
        idx = unpack_states(region["BlockStates"], bits, count=vol, spanning=True)

        for i, v in enumerate(idx):
            if v >= n:
                continue
            state = pal[v]
            if state.split("[", 1)[0] in AIR:
                continue
            got = resolve(state)
            if got is None:
                name = base_of(state)
                if name not in DROP and not name.startswith("minecraft:potted_"):
                    unmapped[name] += 1
                continue
            target, rot, upper, doubled = got
            # Litematica order: y, then z, then x
            y = i // (ax * az)
            rem = i % (ax * az)
            z = rem // ax
            x = rem % ax
            wx, wy, wz = ox + x, oy + y, oz + z
            kept[target] += 1
            blocks.append({
                "blockType": target, "upperBlock": upper,
                "cframe": [wx, wy, wz, *rot], "parts": [],
            })
            if doubled:
                kept[target] += 1
                blocks.append({
                    "blockType": target, "upperBlock": True,
                    "cframe": [wx, wy, wz, *rot], "parts": [],
                })

    if not blocks:
        print("nothing converted")
        return

    # re-anchor to the build's own corner and scale to studs
    mnx = min(b["cframe"][0] for b in blocks)
    mny = min(b["cframe"][1] for b in blocks)
    mnz = min(b["cframe"][2] for b in blocks)
    for b in blocks:
        c = b["cframe"]
        c[0] = (c[0] - mnx) * 3
        c[1] = (c[1] - mny) * 3
        c[2] = (c[2] - mnz) * 3

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

    sxx = max(b["cframe"][0] for b in blocks) // 3 + 1
    syy = max(b["cframe"][1] for b in blocks) // 3 + 1
    szz = max(b["cframe"][2] for b in blocks) // 3 + 1
    print("wrote", out)
    print(f"blocks: {len(blocks)}   size: {sxx} x {syy} x {szz}   (cells scanned {total_cells})")
    print("\ntop Islands blocks used:")
    for name, c in kept.most_common(20):
        print(f"{c:8d}  {name}")
    if unmapped:
        print("\nUNMAPPED (dropped):", sum(unmapped.values()))
        for name, c in unmapped.most_common(30):
            print(f"{c:8d}  {name}")


if __name__ == "__main__":
    main()
