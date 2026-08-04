"""Convert the IvyWood Manor Minecraft world into an Islands build JSON.

Minecraft is 1 block = 1 unit; Islands is 1 block = 3 studs. Coordinates are
emitted relative to the build's own corner so the file drops in anywhere, and
Y is kept relative to the build's base.
"""
import sys, os, json
from collections import Counter
import anvil as mcread
from blockmap import BULK, DROP, islands_name

# Repo root, so the script works from anywhere.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Bounding box of the IvyWood Manor build within its world.
X0, X1 = -52, 35
Y0, Y1 = 54, 94
Z0, Z1 = -76, 71

def main():
    blocks = []
    unmapped = Counter()
    kept = Counter()
    raw = []

    for x, y, z, name in mcread.iter_world(os.path.join(ROOT, "IvyWood Manor", "region")):
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

    if "--hollow" in sys.argv[1:]:
        occ = {tuple(v // 3 for v in b["cframe"][:3]) for b in blocks}
        sides = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
        before = len(blocks)
        blocks = [b for b in blocks if not all(
            (b["cframe"][0] // 3 + dx, b["cframe"][1] // 3 + dy, b["cframe"][2] // 3 + dz) in occ
            for dx, dy, dz in sides)]
        print(f"hollowed: {before} -> {len(blocks)}")

    name = "IvyWoodManorHollow" if "--hollow" in sys.argv[1:] else "IvyWoodManor"
    out = os.path.join(ROOT, "builds", name + ".json")
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
