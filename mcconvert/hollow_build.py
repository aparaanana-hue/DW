"""Write the hollow twin of a build: the outer skin, with the inside dropped.

A block is kept only when it is the outermost occupied cell along one of the
six axes - the first thing you would meet coming in from outside. That is the
same rule as No Interior in the builder, so a build hollowed here looks like
the same build previewed with that toggle on.

It is deliberately not a "are all six neighbours filled" test. That only finds
solid fill: one doorway or open roof and every interior floor behind it counts
as exposed and stays.

    python3 hollow_build.py ../builds/solid/PinkPalace.json ../builds/hollow/PinkPalace.json
"""
import json
import pathlib
import sys


def outer_skin(blocks):
    cells = []
    x_lo, x_hi, y_lo, y_hi, z_lo, z_hi = {}, {}, {}, {}, {}, {}

    def stretch(lo, hi, k, v):
        if k not in lo or v < lo[k]:
            lo[k] = v
        if k not in hi or v > hi[k]:
            hi[k] = v

    for b in blocks:
        c = b["cframe"]
        x, y, z = round(c[0] / 3), round(c[1] / 3), round(c[2] / 3)
        cells.append((x, y, z))
        stretch(x_lo, x_hi, (y, z), x)
        stretch(y_lo, y_hi, (x, z), y)
        stretch(z_lo, z_hi, (x, y), z)

    kept = []
    for b, (x, y, z) in zip(blocks, cells):
        if (x == x_lo[(y, z)] or x == x_hi[(y, z)]
                or y == y_lo[(x, z)] or y == y_hi[(x, z)]
                or z == z_lo[(x, y)] or z == z_hi[(x, y)]):
            kept.append(b)
    return kept


def main():
    src = pathlib.Path(sys.argv[1])
    dst = pathlib.Path(sys.argv[2])
    blocks = json.loads(src.read_text())["blocks"]
    kept = outer_skin(blocks)
    dst.write_text(json.dumps({"blocks": kept}, separators=(",", ":")))
    pct = 100 * (len(blocks) - len(kept)) / len(blocks)
    print(f"{len(blocks):,} -> {len(kept):,} blocks "
          f"({pct:.1f}% dropped)  {dst}")


if __name__ == "__main__":
    main()
