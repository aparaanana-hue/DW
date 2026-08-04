"""Read a Minecraft Java 1.14 world (Anvil) and yield placed blocks.

1.14 packs BlockStates as a long array where entries are contiguous and may
span across longs (the non-spanning layout only arrives in 1.16).
"""
import io, os, struct, zlib, glob
from collections import Counter
import nbtlib

SECTOR = 4096


def read_region(path):
    """Yield (chunk_x, chunk_z, nbt_root) for every chunk present."""
    with open(path, "rb") as f:
        header = f.read(SECTOR)
        if len(header) < SECTOR:
            return
        for i in range(1024):
            off, cnt = struct.unpack_from(">I", header, i * 4)[0] >> 8, header[i * 4 + 3]
            if off == 0 or cnt == 0:
                continue
            f.seek(off * SECTOR)
            raw = f.read(cnt * SECTOR)
            if len(raw) < 5:
                continue
            length = struct.unpack_from(">I", raw, 0)[0]
            comp = raw[4]
            data = raw[5:5 + length - 1]
            try:
                if comp == 1:
                    data = zlib.decompress(data, 47)
                elif comp == 2:
                    data = zlib.decompress(data)
                else:
                    continue
            except Exception:
                continue
            try:
                root = nbtlib.File.from_fileobj(io.BytesIO(data))
            except Exception as ex:
                raise
            yield (i % 32, i // 32, root)


def unpack_states(longs, bits, count=4096):
    """1.13-1.15 packing: contiguous bits, entries may straddle longs."""
    out = []
    mask = (1 << bits) - 1
    # normalise to unsigned 64-bit
    u = [(int(v) & 0xFFFFFFFFFFFFFFFF) for v in longs]
    total = len(u) * 64
    for i in range(count):
        start = i * bits
        if start + bits > total:
            break
        li, off = start // 64, start % 64
        val = (u[li] >> off) & mask
        if off + bits > 64:  # straddles into the next long
            got = 64 - off
            val |= (u[li + 1] << got) & mask
        out.append(val)
    return out


def chunk_blocks(root):
    """Yield (x, y, z, block_name) in world coords for one chunk."""
    lvl = root["Level"] if "Level" in root else root
    if "Sections" not in lvl:
        return
    cx, cz = int(lvl["xPos"]), int(lvl["zPos"])
    for sec in lvl["Sections"]:
        if "Palette" not in sec or "BlockStates" not in sec:
            continue
        pal = []
        for p in sec["Palette"]:
            pal.append(str(p["Name"]))
        n = len(pal)
        if n <= 1 and (n == 0 or pal[0] == "minecraft:air"):
            continue
        bits = max(4, (n - 1).bit_length())
        idx = unpack_states(sec["BlockStates"], bits)
        ybase = int(sec["Y"]) * 16
        for i, v in enumerate(idx):
            if v >= n:
                continue
            name = pal[v]
            if name == "minecraft:air" or name == "minecraft:cave_air" or name == "minecraft:void_air":
                continue
            y = ybase + (i >> 8)
            z = (i >> 4) & 15
            x = i & 15
            yield (cx * 16 + x, y, cz * 16 + z, name)


def iter_world(region_dir):
    for path in sorted(glob.glob(os.path.join(region_dir, "*.mca"))):
        for _, _, root in read_region(path):
            yield from chunk_blocks(root)


if __name__ == "__main__":
    import sys
    d = sys.argv[1] if len(sys.argv) > 1 else "IvyWood Manor/region"
    counts = Counter()
    n = 0
    minx = miny = minz = 10**9
    maxx = maxy = maxz = -10**9
    for x, y, z, name in iter_world(d):
        counts[name] += 1
        n += 1
        if x < minx: minx = x
        if y < miny: miny = y
        if z < minz: minz = z
        if x > maxx: maxx = x
        if y > maxy: maxy = y
        if z > maxz: maxz = z
    print("total non-air blocks:", n)
    print("bounds x", minx, maxx, "y", miny, maxy, "z", minz, maxz)
    print("\ntop 40 block types:")
    for name, c in counts.most_common(40):
        print(f"{c:9d}  {name}")
