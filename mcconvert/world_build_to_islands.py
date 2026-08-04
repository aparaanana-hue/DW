"""Convert a build sitting in a Minecraft world into an Islands build file.

For worlds that hold one build rather than a whole landscape - a flat "build
world" with a floor plane, say. Give it the region folder and a Y floor to cut
the plane off at; everything above is taken as the build.

    python3 world_build_to_islands.py <region_dir> <OutputName> [options]

      --miny N     ignore everything below this Y (default: no limit)
      --maxy N     ignore everything above this Y
      --drop NAME  ignore this block entirely, repeatable (floor material)
      --hollow     drop blocks whose six neighbours are all filled
"""
import json, os, sys
from collections import Counter

import anvil
from blockmap import DROP, parse_state, resolve

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def arg(flag, default=None, cast=str):
    if flag in sys.argv:
        return cast(sys.argv[sys.argv.index(flag) + 1])
    return default


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    region, outname = sys.argv[1], sys.argv[2]
    miny = arg("--miny", None, int)
    maxy = arg("--maxy", None, int)
    hollow = "--hollow" in sys.argv
    drop = {d if d.startswith("minecraft:") else "minecraft:" + d
            for d in sys.argv[sys.argv.index("--drop") + 1:sys.argv.index("--drop") + 2]} \
        if "--drop" in sys.argv else set()
    # allow --drop more than once
    drop = set()
    for i, a in enumerate(sys.argv):
        if a == "--drop" and i + 1 < len(sys.argv):
            d = sys.argv[i + 1]
            drop.add(d if d.startswith("minecraft:") else "minecraft:" + d)

    raw = []
    for x, y, z, state in anvil.iter_world(region):
        if miny is not None and y < miny:
            continue
        if maxy is not None and y > maxy:
            continue
        if parse_state(state)[0] in drop:
            continue
        raw.append((x, y, z, state))
    if not raw:
        print("nothing found in that range")
        return
    print("blocks in range:", len(raw))

    mnx = min(b[0] for b in raw)
    mny = min(b[1] for b in raw)
    mnz = min(b[2] for b in raw)

    blocks = []
    kept = Counter()
    unmapped = Counter()
    for x, y, z, state in raw:
        got = resolve(state)
        if got is None:
            name = parse_state(state)[0]
            if name not in DROP and not name.startswith("minecraft:potted_"):
                unmapped[name] += 1
            continue
        target, rot, upper, doubled = got
        kept[target] += 1
        px, py, pz = (x - mnx) * 3, (y - mny) * 3, (z - mnz) * 3
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
    with open(out, "w") as f:
        json.dump({"blocks": blocks}, f)

    sx = max(b["cframe"][0] for b in blocks) // 3 + 1
    sy = max(b["cframe"][1] for b in blocks) // 3 + 1
    sz = max(b["cframe"][2] for b in blocks) // 3 + 1
    print("wrote", out)
    print(f"blocks: {len(blocks)}   size: {sx} x {sy} x {sz}")
    print("\ntop Islands blocks used:")
    for n, c in kept.most_common(20):
        print(f"{c:8d}  {n}")
    if unmapped:
        print("\nUNMAPPED (dropped):", sum(unmapped.values()))
        for n, c in unmapped.most_common(30):
            print(f"{c:8d}  {n}")


if __name__ == "__main__":
    main()
