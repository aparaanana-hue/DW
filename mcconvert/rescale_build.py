"""Shrink a build by merging blocks together, so a big one fits a budget.

Hollowing removes what you cannot see. When a build is already hollow - a
castle of thin walls, say - there is nothing left to remove, and the only way
to make it smaller is to make it *smaller*. Surface area grows with the square
of size, so halving a build's dimensions leaves about a quarter of the blocks.

Each group of cells becomes one block, and the block type that covered most of
that group wins, along with its rotation. Rotations survive because they travel
with the winning block rather than being reset - so stairs still face the way
the majority of them faced.

    python3 rescale_build.py <in.json> <out.json> --factor 1.5
    python3 rescale_build.py <in.json> <out.json> --blocks 80000

--blocks searches for the factor that lands nearest a budget, hollowing as it
goes, which is usually what you actually want.
"""
import collections
import json
import math
import pathlib
import sys

from hollow_build import outer_skin

CELL = 3


def rescale(blocks, factor):
    """Merge every `factor` cells along each axis into one block."""
    if factor <= 1.0:
        return list(blocks)

    groups = collections.defaultdict(collections.Counter)
    for b in blocks:
        c = b["cframe"]
        key = (math.floor(c[0] / CELL / factor),
               math.floor(c[1] / CELL / factor),
               math.floor(c[2] / CELL / factor))
        # the whole block - type, rotation, half - votes as one thing, so a
        # winning stair keeps the direction it was facing
        groups[key][(b["blockType"], tuple(c[3:]), bool(b.get("upperBlock")))] += 1

    out = []
    for (x, y, z), tally in groups.items():
        (name, rot, upper), _ = tally.most_common(1)[0]
        out.append({
            "blockType": name,
            "upperBlock": upper,
            "cframe": [x * CELL, y * CELL, z * CELL, *rot],
            "parts": [],
        })
    return out


def anchor(blocks):
    mnx = min(b["cframe"][0] for b in blocks)
    mny = min(b["cframe"][1] for b in blocks)
    mnz = min(b["cframe"][2] for b in blocks)
    for b in blocks:
        c = b["cframe"]
        c[0] -= mnx
        c[1] -= mny
        c[2] -= mnz
    return blocks


def extent(blocks):
    xs = [b["cframe"][0] // CELL for b in blocks]
    ys = [b["cframe"][1] // CELL for b in blocks]
    zs = [b["cframe"][2] // CELL for b in blocks]
    return max(xs) + 1, max(ys) + 1, max(zs) + 1


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    blocks = json.loads(src.read_text())["blocks"]

    def arg(flag, cast=float):
        if flag in sys.argv:
            return cast(sys.argv[sys.argv.index(flag) + 1])
        return None

    target = arg("--blocks", int)
    factor = arg("--factor")

    if target:
        # Surface grows with the square of the factor, so start from that and
        # refine. Three or four measurements land within a percent or two.
        best = None
        f = math.sqrt(len(outer_skin(blocks)) / target)
        for _ in range(5):
            f = max(1.0, min(8.0, f))
            got = outer_skin(rescale(blocks, f))
            n = len(got)
            print(f"  1/{f:.2f} -> {n:,} blocks")
            if best is None or (n <= target and n > best[1]) or \
               (best[1] > target and n < best[1]):
                best = (f, n, got)
            if n <= target and n >= target * 0.9:
                break
            f = f * math.sqrt(n / target)
        factor, count, kept = best
        print(f"\nchose 1/{factor:.2f}")
    else:
        factor = factor or 1.5
        kept = outer_skin(rescale(blocks, factor))

    kept = anchor(kept)
    dst.write_text(json.dumps({"blocks": kept}, separators=(",", ":")))
    w, h, d = extent(kept)
    print(f"{len(blocks):,} -> {len(kept):,} blocks   {w}x{h}x{d}   {dst}")


if __name__ == "__main__":
    main()
