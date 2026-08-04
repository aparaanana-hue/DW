"""Read a Minecraft Java world (Anvil) and yield placed blocks.

Handles both chunk layouts:

  1.13-1.15  Level.Sections, Palette/BlockStates, bits packed contiguously so
             an entry may straddle two longs.
  1.16-1.17  same layout, but entries no longer straddle: each long is padded.
  1.18+      sections (lowercase) at the root, block_states.palette /
             block_states.data, and Y extends down to -64.
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


def unpack_states(longs, bits, count=4096, spanning=True):
    """Decode a packed block-state array.

    spanning=True  is the 1.13-1.15 layout, where an entry may straddle longs.
    spanning=False is 1.16+, where each long holds floor(64/bits) entries and
    the leftover high bits are padding.
    """
    out = []
    mask = (1 << bits) - 1
    u = [(int(v) & 0xFFFFFFFFFFFFFFFF) for v in longs]   # to unsigned 64-bit
    if not u:
        return out

    if spanning:
        total = len(u) * 64
        for i in range(count):
            start = i * bits
            if start + bits > total:
                break
            li, off = start // 64, start % 64
            val = (u[li] >> off) & mask
            if off + bits > 64:
                val |= (u[li + 1] << (64 - off)) & mask
            out.append(val)
    else:
        per_long = 64 // bits
        for word in u:
            for k in range(per_long):
                if len(out) >= count:
                    return out
                out.append((word >> (k * bits)) & mask)
    return out


AIR = {"minecraft:air", "minecraft:cave_air", "minecraft:void_air"}


def chunk_blocks(root):
    """Yield (x, y, z, block_name) in world coords for one chunk."""
    dv = int(root.get("DataVersion", 0))
    spanning = dv < 2529          # 2529 = 1.16, where packing stopped straddling
    lvl = root["Level"] if "Level" in root else root

    # 1.18+ renamed things and moved the palette one level deeper
    if "sections" in root:
        sections = root["sections"]
        cx, cz = int(root["xPos"]), int(root["zPos"])
        new_layout = True
    elif "Sections" in lvl:
        sections = lvl["Sections"]
        cx, cz = int(lvl["xPos"]), int(lvl["zPos"])
        new_layout = False
    else:
        return

    for sec in sections:
        if new_layout:
            bs = sec.get("block_states")
            if bs is None or "palette" not in bs:
                continue
            pal = [str(p["Name"]) for p in bs["palette"]]
            data = bs.get("data")
        else:
            if "Palette" not in sec or "BlockStates" not in sec:
                continue
            pal = [str(p["Name"]) for p in sec["Palette"]]
            data = sec["BlockStates"]

        n = len(pal)
        if n == 0:
            continue
        ybase = int(sec["Y"]) * 16

        # A single-entry palette carries no data array: the whole section is
        # that one block.
        if n == 1 or data is None or len(data) == 0:
            if pal[0] in AIR:
                continue
            for i in range(4096):
                yield (cx * 16 + (i & 15), ybase + (i >> 8), cz * 16 + ((i >> 4) & 15), pal[0])
            continue

        bits = max(4, (n - 1).bit_length())
        for i, v in enumerate(unpack_states(data, bits, spanning=spanning)):
            if v >= n:
                continue
            name = pal[v]
            if name in AIR:
                continue
            yield (cx * 16 + (i & 15), ybase + (i >> 8), cz * 16 + ((i >> 4) & 15), name)


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
