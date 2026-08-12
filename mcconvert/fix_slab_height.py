"""Put slabs back on the block grid.

A real island capture has its slabs at exactly the same heights as its full
blocks, so Islands does not record which half of a cell a slab is in by where
it sits - upperBlock carries that. An earlier version of this script moved
slabs three quarters of a stud off the grid on the opposite theory; this undoes
it.

    python3 fix_slab_height.py ../builds/solid/*.json
"""
import json
import pathlib
import sys

from blockmap import unseat_slabs


def main(paths):
    total = 0
    for p in paths:
        path = pathlib.Path(p)
        data = json.loads(path.read_text())
        moved = unseat_slabs(data["blocks"])
        if moved:
            path.write_text(json.dumps(data, separators=(",", ":")))
            print(f"{moved:>7} put back on the grid  {p}")
        total += moved
    print(f"\n{total} blocks re-aligned across {len(paths)} files")


if __name__ == "__main__":
    main(sys.argv[1:])
