"""Convert a build sitting in a Minecraft world into an Islands build file.

For worlds that hold one build rather than a whole landscape - a flat "build
world" with a floor plane, say. Give it the region folder and a Y floor to cut
the plane off at; everything above is taken as the build.

    python3 world_build_to_islands.py <region_dir> <OutputName> [options]

      --miny N     ignore everything below this Y (default: no limit)
      --maxy N     ignore everything above this Y
      --drop NAME  ignore this block entirely, repeatable (floor material)
      --natural    ignore generated terrain (stone, dirt, trees, water, ore)
      --largest    keep only the largest connected structure, so a single build
                   comes out without the dock or scenery around it
      --split      a world holding several builds: cluster them by position and
                   write one file each, named OutputName1, OutputName2, ...
      --min N      with --split, ignore clusters smaller than this (default 3000)
      --hollow     drop blocks whose six neighbours are all filled
"""
import json, os, sys
from collections import Counter

import anvil
from blockmap import DROP, NATURAL, base_of, parse_state, resolve_any, seat_slabs

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
    skip_natural = "--natural" in sys.argv
    largest = "--largest" in sys.argv
    split = "--split" in sys.argv
    minsize = arg("--min", 3000, int)
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
        base = base_of(state)
        if base in drop:
            continue
        if skip_natural and base in NATURAL:
            continue
        raw.append((x, y, z, state))
    if not raw:
        print("nothing found in that range")
        return
    print("blocks in range:", len(raw))

    if largest:
        # 26-connectivity, so railings and props resting on a deck stay with it
        occ = {(b[0], b[1], b[2]): b for b in raw}
        nbrs = [(dx, dy, dz)
                for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)
                if (dx, dy, dz) != (0, 0, 0)]
        seen, best = set(), None
        for start in occ:
            if start in seen:
                continue
            stack, comp = [start], []
            seen.add(start)
            while stack:
                cx, cy, cz = stack.pop()
                comp.append((cx, cy, cz))
                for dx, dy, dz in nbrs:
                    n = (cx + dx, cy + dy, cz + dz)
                    if n in occ and n not in seen:
                        seen.add(n)
                        stack.append(n)
            if best is None or len(comp) > len(best):
                best = comp
        raw = [occ[p] for p in best]
        print("largest structure:", len(raw))

    def emit(rows, name):
        mnx = min(b[0] for b in rows)
        mny = min(b[1] for b in rows)
        mnz = min(b[2] for b in rows)
        blocks = []
        kept = Counter()
        for x, y, z, state in rows:
            got = resolve_any(state)
            if got is None:
                nm = base_of(state)
                if nm not in DROP and not nm.startswith("minecraft:potted_"):
                    unmapped[nm] += 1
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
        if not blocks:
            return None

        if hollow:
            occ = {tuple(v // 3 for v in b["cframe"][:3]) for b in blocks}
            sides = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
            blocks = [b for b in blocks if not all(
                (b["cframe"][0] // 3 + dx, b["cframe"][1] // 3 + dy, b["cframe"][2] // 3 + dz) in occ
                for dx, dy, dz in sides)]

        os.makedirs(os.path.join(ROOT, "builds"), exist_ok=True)
        out = os.path.join(ROOT, "builds", name + ".json")
        # slabs record their half by position, not by the flag alone
        seat_slabs(blocks)

        with open(out, "w") as fh:
            json.dump({"blocks": blocks}, fh, separators=(",", ":"))
        sx = max(b["cframe"][0] for b in blocks) // 3 + 1
        sy = max(b["cframe"][1] for b in blocks) // 3 + 1
        sz = max(b["cframe"][2] for b in blocks) // 3 + 1
        print(f"  {name:24s} {len(blocks):>7d} blocks   {sx}x{sy}x{sz}")
        return kept

    unmapped = Counter()

    if split:
        # bucket by position, then merge touching dense cells into one build
        CELL = 32
        cells = {}
        for i, b in enumerate(raw):
            cells.setdefault((b[0] // CELL, b[2] // CELL), []).append(i)
        dense = {k for k, v in cells.items() if len(v) >= 200}
        seen, groups = set(), []
        for k in dense:
            if k in seen:
                continue
            stack, grp = [k], []
            seen.add(k)
            while stack:
                c = stack.pop()
                grp.append(c)
                for dx in (-1, 0, 1):
                    for dz in (-1, 0, 1):
                        nb = (c[0] + dx, c[1] + dz)
                        if nb in dense and nb not in seen:
                            seen.add(nb)
                            stack.append(nb)
            groups.append(grp)
        groups.sort(key=lambda g: -sum(len(cells[c]) for c in g))
        groups = [g for g in groups if sum(len(cells[c]) for c in g) >= minsize]
        print("builds found:", len(groups))
        suffix = "Hollow" if hollow else ""
        for n, g in enumerate(groups, 1):
            rows = [raw[i] for c in g for i in cells[c]]
            emit(rows, f"{outname}{n}{suffix}")
    else:
        kept = emit(raw, outname)
        if kept:
            print("\ntop Islands blocks used:")
            for n, c in kept.most_common(20):
                print(f"{c:8d}  {n}")

    if unmapped:
        print("\nUNMAPPED (dropped):", sum(unmapped.values()))
        for n, c in unmapped.most_common(30):
            print(f"{c:8d}  {n}")


if __name__ == "__main__":
    main()
