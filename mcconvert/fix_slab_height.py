"""Seat slabs in the half of the cell they belong to.

Islands records which half a slab is in by where it sits, not by the
upperBlock flag - see partToBlockEntry in IAB.lua, which reads a block back as
upper when a half-height part is above the cell centre. Builds written dead on
the grid have every slab in neither half, and the game seats them low, so
roofs come out a slab short and full of gaps.

    python3 fix_slab_height.py ../builds/solid/*.json
"""
import json
import pathlib
import sys

from blockmap import seat_slabs


def main(paths):
    total = 0
    for p in paths:
        path = pathlib.Path(p)
        data = json.loads(path.read_text())
        moved = seat_slabs(data["blocks"])
        if moved:
            path.write_text(json.dumps(data, separators=(",", ":")))
        total += moved
        if moved:
            print(f"{moved:>7} slabs seated  {p}")
    print(f"\n{total} slabs seated across {len(paths)} files")


if __name__ == "__main__":
    main(sys.argv[1:])
