"""Clear upperBlock on anything that is not a slab, and drop the duplicates
that flag left behind.

Only a slab is half-height in Islands - IAB reads a saved block as upper only
when its part is under 2.9 studs tall. Minecraft's `half=top` (an upside-down
stair) and its legacy double slabs, which map to full blocks here, were both
coming through as upperBlock. A full-height block flagged that way is placed
half a cell up, inside whatever is above it.

    python3 fix_upper_blocks.py ../builds/solid/*.json
"""
import json, pathlib, sys, collections

from blockmap import is_slab


def main(paths):
    cleared = dupes = 0
    for p in paths:
        path = pathlib.Path(p)
        data = json.loads(path.read_text())
        blocks = data["blocks"]

        n = 0
        for b in blocks:
            if b.get("upperBlock") is True and not is_slab(b["blockType"]):
                b["upperBlock"] = False
                n += 1

        # Clearing the flag can leave two entries in one cell and half - the
        # legacy double-slab path emitted a lower and an upper of the same
        # block. Keep the first of any such pair.
        seen, kept, d = set(), [], 0
        for b in blocks:
            c = b["cframe"]
            k = (round(c[0] / 3), round(c[1] / 3), round(c[2] / 3),
                 b.get("upperBlock") is True)
            if k in seen:
                d += 1
                continue
            seen.add(k)
            kept.append(b)

        if n or d:
            data["blocks"] = kept
            path.write_text(json.dumps(data, separators=(",", ":")))
        cleared += n
        dupes += d
        print(f"{n:>7} cleared {d:>6} dupes  {p}")

    print(f"\n{cleared} flags cleared, {dupes} duplicate blocks dropped, "
          f"across {len(paths)} files")


if __name__ == "__main__":
    main(sys.argv[1:])
