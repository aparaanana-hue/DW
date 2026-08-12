"""Write the Lua copy of the block table that IAB.lua uses.

The in-game converter needs the same Minecraft -> Islands mapping the offline
converters use. Rather than keeping a second copy by hand - which is how the
two would come to disagree - the Lua table is generated from blockmap.py and
pasted into IAB.lua.

    python3 export_blockmap.py > mcmap.lua

Then replace the MC_MAP / MC_DROP / MC_FACING block in IAB.lua with the output.
"""
import sys

import blockmap


def emit(title, pairs, fmt):
    print(title + " = {")
    line = "   "
    for k in sorted(pairs):
        piece = fmt(k, pairs[k] if isinstance(pairs, dict) else None)
        if len(line) + len(piece) > 118:
            print(line)
            line = "   "
        line += piece
    print(line)
    print("}")


def short(name):
    return name[len("minecraft:"):] if name.startswith("minecraft:") else name


def main():
    print("-- Generated from mcconvert/blockmap.py. Do not hand-edit: run")
    print("-- mcconvert/export_blockmap.py to rebuild it when the table changes.")
    emit("MC_MAP", blockmap.MAP, lambda k, v: ' ["%s"]="%s",' % (short(k), v))
    emit("MC_DROP", {k: True for k in blockmap.DROP},
         lambda k, v: ' ["%s"]=true,' % short(k))
    print("MC_FACING = {")
    for name in ("north", "east", "south", "west"):
        print("    %s = { %s }," % (name, ", ".join(str(x) for x in blockmap.FACING_ROT[name])))
    print("}")
    print("MC_AXIS = {")
    for k, v in blockmap.AXIS_ROT.items():
        print("    %s = { %s }," % (k, ", ".join(str(x) for x in v)))
    print("}")
    print("MC_IDENTITY = { %s }" % ", ".join(str(x) for x in blockmap.IDENTITY))


if __name__ == "__main__":
    main()
