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
from blockmap import DROP, islands_name, modern_name, legacy_orientation as orientation

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Legacy numeric id (and metadata where it matters) -> modern block name, which
# blockmap then resolves to an Islands block. Only ids worth carrying over.
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
        json.dump({"blocks": blocks}, fh, separators=(",", ":"))

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
