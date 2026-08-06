"""Turn every stair in a build file about Y, in place.

An Islands cframe is [x,y,z, Rx,Ry,Rz, Ux,Uy,Uz] - position, then the
RightVector and UpVector. Turning them turns the stair; the position is left
alone, so each one spins on the spot.

  python3 rotate_stairs.py --left 1 ../builds/solid/*.json

--left counts quarter turns anticlockwise seen from above, --right the other
way. Keep this in step with FACING_OFFSET in blockmap.py: a build converted
before an offset change needs the same turn applied to catch up.
"""
import argparse, json, pathlib


def quarter_left(v):
    """(x, y, z) turned 90 degrees anticlockwise about Y."""
    return [v[2], v[1], -v[0]]


def turn(v, times):
    for _ in range(times % 4):
        v = quarter_left(v)
    return v


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--left", type=int, help="quarter turns anticlockwise")
    g.add_argument("--right", type=int, help="quarter turns clockwise")
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()

    times = args.left if args.left is not None else -args.right
    if times % 4 == 0:
        raise SystemExit("that is a whole turn - nothing to do")

    total = 0
    for p in args.files:
        path = pathlib.Path(p)
        data = json.loads(path.read_text())
        n = 0
        for b in data["blocks"]:
            if "tair" not in b["blockType"]:
                continue
            c = b["cframe"]
            if len(c) != 9:
                raise SystemExit(f"{p}: unexpected cframe length {len(c)}")
            b["cframe"] = c[:3] + turn(c[3:6], times) + turn(c[6:9], times)
            n += 1
        if n:
            path.write_text(json.dumps(data, separators=(",", ":")))
        total += n
        print(f"{n:>7} stairs  {p}")
    print(f"\n{total} stairs turned across {len(args.files)} files")


if __name__ == "__main__":
    main()
