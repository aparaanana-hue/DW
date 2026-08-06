"""Rotate every stair in a build file 180 degrees about Y, in place.

An Islands cframe is [x,y,z, Rx,Ry,Rz, Ux,Uy,Uz] - position, then the
RightVector and UpVector. A half turn about world Y negates the X and Z of
each, and leaves Y alone. Position is untouched: the stair spins on the spot.
"""
import json, sys, pathlib, collections

def half_turn(v):
    return [-v[0], v[1], -v[2]]

def main(paths):
    totals = collections.Counter()
    for p in paths:
        data = json.loads(pathlib.Path(p).read_text())
        n = 0
        for b in data["blocks"]:
            if "tair" not in b["blockType"]:
                continue
            c = b["cframe"]
            if len(c) != 9:
                raise SystemExit(f"{p}: unexpected cframe length {len(c)}")
            right, up = half_turn(c[3:6]), half_turn(c[6:9])
            b["cframe"] = c[:3] + right + up
            n += 1
        if n:
            pathlib.Path(p).write_text(json.dumps(data, separators=(",", ":")))
        totals[p] = n
        print(f"{n:>7} stairs  {p}")
    print(f"\n{sum(totals.values())} stairs turned across {len(paths)} files")

if __name__ == "__main__":
    main(sys.argv[1:])
