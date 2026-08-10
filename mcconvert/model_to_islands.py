"""Turn a 3D model (.glb) into an Islands build file.

The 3D counterpart of the image converter: a mesh goes in, blocks come out,
coloured by sampling the model's own textures and matching each colour to the
nearest Islands block in OKLab - the same palette and the same metric the
image converter uses, so the two produce consistent-looking builds.

Size it by how many blocks you want rather than by a scale factor, and it
picks the grid to land near that. Fewer blocks is a coarser model of the same
thing, so this is the accuracy dial.

    python3 model_to_islands.py <model.glb> <OutputName> [options]

      --blocks N      target block count (default 80000)
      --height N      exact height in blocks, instead of a budget
      --solid         fill the interior (default: surface shell only)
      --palette A,B   restrict to palette groups, e.g. Stone,Wool
                      (Solid Wool Clay Neon Pastel Wood Stone Natural Ore)
      --simplify N    cap the build to N distinct block types (0 = off)
      --single NAME   ignore colour, build it all from one block type
      --up y|z        force the up axis (default: auto-detect)

Writes builds/solid/<OutputName>.json and builds/hollow/<OutputName>.json.

Only a full-height block is ever emitted, with identity rotation, and every
block goes through one placer keyed on the cell - so the file cannot contain
overlapping blocks. Textures need Pillow for JPEG; PNG works without it.
"""
import collections
import json
import os
import sys

import numpy as np

import glb
import islands_palette
from hollow_build import outer_skin

CELL = 3            # studs per block
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def arg(flag, default=None, cast=str):
    if flag in sys.argv:
        return cast(sys.argv[sys.argv.index(flag) + 1])
    return default


# ── geometry ────────────────────────────────────────────────────────────────
def pick_up_axis(size, forced=None):
    """glTF says Y is up, but plenty of exports are Z-up and land on their side.

    A model standing up is usually taller than it is deep. If Z is much the
    largest axis while Y is small, it was almost certainly authored Z-up.
    """
    if forced in ("y", "z"):
        return forced, "forced"
    x, y, z = size
    if z > y * 1.6 and z > x * 1.1:
        return "z", "auto (Z is much the tallest axis)"
    return "y", "auto (glTF default)"


def to_world(positions, up):
    """Reorient so Y is up, matching how a build file is laid out."""
    if up == "z":
        # Z-up -> Y-up: y = z, z = -y
        return np.stack([positions[:, 0], positions[:, 2], -positions[:, 1]], axis=1)
    return positions


def sample_triangles(pos, uv, col, tris, spacing):
    """Points covering every triangle, at most `spacing` apart.

    Barycentric sampling rather than a scanline rasteriser: it handles skinny
    and near-degenerate triangles without special cases, and it vectorises.
    Triangles are grouped by how many samples they need so each group is one
    numpy pass instead of a Python loop over every triangle.
    """
    a, b, c = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
    longest = np.maximum.reduce([
        np.linalg.norm(b - a, axis=1),
        np.linalg.norm(c - a, axis=1),
        np.linalg.norm(c - b, axis=1),
    ])
    steps = np.clip(np.ceil(longest / spacing).astype(np.int64) + 1, 2, 512)

    pts, uvs, cols = [], [], []
    for n in np.unique(steps):
        sel = steps == n
        idx = tris[sel]
        # barycentric lattice: i + j <= n
        i, j = np.meshgrid(np.arange(n + 1), np.arange(n + 1), indexing="ij")
        keep = (i + j) <= n
        wi = (i[keep] / n).astype(np.float32)
        wj = (j[keep] / n).astype(np.float32)
        wk = (1.0 - wi - wj).astype(np.float32)

        p0, p1, p2 = pos[idx[:, 0]], pos[idx[:, 1]], pos[idx[:, 2]]
        pts.append((p0[:, None, :] * wk[None, :, None]
                    + p1[:, None, :] * wi[None, :, None]
                    + p2[:, None, :] * wj[None, :, None]).reshape(-1, 3))
        if uv is not None:
            u0, u1, u2 = uv[idx[:, 0]], uv[idx[:, 1]], uv[idx[:, 2]]
            uvs.append((u0[:, None, :] * wk[None, :, None]
                        + u1[:, None, :] * wi[None, :, None]
                        + u2[:, None, :] * wj[None, :, None]).reshape(-1, 2))
        if col is not None:
            c0, c1, c2 = col[idx[:, 0]], col[idx[:, 1]], col[idx[:, 2]]
            cols.append((c0[:, None, :] * wk[None, :, None]
                         + c1[:, None, :] * wi[None, :, None]
                         + c2[:, None, :] * wj[None, :, None]).reshape(-1, 4))

    return (np.concatenate(pts) if pts else np.zeros((0, 3), np.float32),
            np.concatenate(uvs) if uvs else None,
            np.concatenate(cols) if cols else None)


def primitive_colours(prim, uvs, cols, count):
    """Colour per sample: texture if there is one, else the flat material
    colour, modulated by any vertex colours."""
    base = np.ones((count, 3), dtype=np.float64)
    mat = prim.material
    if mat is not None:
        tex = mat.texture
        if tex is not None and tex.usable and uvs is not None:
            base = tex.sample(uvs[:, 0], uvs[:, 1]).astype(np.float64) / 255.0
        else:
            base = np.tile(np.array(mat.base_color[:3], dtype=np.float64), (count, 1))
        if tex is not None and tex.usable:
            base *= np.array(mat.base_color[:3], dtype=np.float64)
    if cols is not None:
        base *= cols[:, :3].astype(np.float64)
    return np.clip(base * 255.0, 0, 255)


def voxelise(model, up, cells_long, want_colour=True):
    """Surface-voxelise at a grid `cells_long` cells along the longest axis.

    Returns {(x, y, z): (r, g, b)} - the mean colour of the surface in each
    cell.
    """
    lo = np.array([np.inf] * 3)
    hi = np.array([-np.inf] * 3)
    for p in model.primitives:
        w = to_world(p.positions.astype(np.float64), up)
        lo = np.minimum(lo, w.min(axis=0))
        hi = np.maximum(hi, w.max(axis=0))
    size = hi - lo
    scale = cells_long / max(size.max(), 1e-9)
    spacing = 0.5 / scale          # world units per half cell

    sums = collections.defaultdict(lambda: np.zeros(3))
    hits = collections.Counter()
    seen = set()

    for prim in model.primitives:
        world = to_world(prim.positions.astype(np.float64), up)
        pts, uvs, cols = sample_triangles(
            world, prim.uvs, prim.colors, prim.indices, spacing)
        if len(pts) == 0:
            continue
        grid = np.floor((pts - lo) * scale).astype(np.int64)
        np.clip(grid, 0, None, out=grid)

        if not want_colour:
            # sizing only cares how many cells get hit, so skip the texture
            # sampling and the averaging entirely - this runs several times
            # over while searching for the right grid
            seen.update(map(tuple, np.unique(grid, axis=0).tolist()))
            continue

        rgb = primitive_colours(prim, uvs, cols, len(pts))

        # Collapse to one row per cell before touching Python. A big model
        # produces tens of millions of samples, and looping over those - or
        # even over every cell - is the difference between seconds and minutes.
        keys = (grid[:, 0].astype(np.int64) << 42) \
            ^ (grid[:, 1].astype(np.int64) << 21) ^ grid[:, 2].astype(np.int64)
        order = np.argsort(keys, kind="stable")
        keys_s, grid_s, rgb_s = keys[order], grid[order], rgb[order]
        starts = np.flatnonzero(np.r_[True, keys_s[1:] != keys_s[:-1]])
        totals = np.add.reduceat(rgb_s, starts, axis=0)
        counts = np.diff(np.r_[starts, len(keys_s)])
        cells = grid_s[starts]

        for cell, total, n in zip(map(tuple, cells.tolist()), totals, counts):
            sums[cell] += total
            hits[cell] += int(n)

    if not want_colour:
        return {c: (0, 0, 0) for c in seen}
    return {c: tuple((sums[c] / hits[c]).round().astype(int)) for c in hits}


def fill_interior(surface):
    """Flood empty space inwards from outside the bounding box; whatever the
    air never reaches is interior, and gets the colour of the cell above it.

    Outside-in, like hollow_build.py, rather than an "are all six neighbours
    filled" test - that one only finds solid fill.
    """
    xs = [c[0] for c in surface]
    ys = [c[1] for c in surface]
    zs = [c[2] for c in surface]
    lo = (min(xs) - 1, min(ys) - 1, min(zs) - 1)
    hi = (max(xs) + 1, max(ys) + 1, max(zs) + 1)

    outside = {lo}
    stack = [lo]
    dirs = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
    while stack:
        x, y, z = stack.pop()
        for dx, dy, dz in dirs:
            n = (x + dx, y + dy, z + dz)
            if not (lo[0] <= n[0] <= hi[0] and lo[1] <= n[1] <= hi[1]
                    and lo[2] <= n[2] <= hi[2]):
                continue
            if n in outside or n in surface:
                continue
            outside.add(n)
            stack.append(n)

    out = dict(surface)
    for x in range(lo[0], hi[0] + 1):
        for y in range(lo[1], hi[1] + 1):
            for z in range(lo[2], hi[2] + 1):
                c = (x, y, z)
                if c in surface or c in outside:
                    continue
                # borrow a colour from the nearest surface cell above
                col = (128, 128, 128)
                for up in range(1, 64):
                    hit = surface.get((x, y + up, z))
                    if hit:
                        col = hit
                        break
                out[c] = col
    return out


def size_for_budget(model, up, target, solid, tries=4):
    """Find the grid resolution that lands nearest the block budget.

    A surface grows with the square of the resolution (a solid volume with the
    cube), so rather than bisecting blindly, measure once and extrapolate from
    that law, then refine. Four passes instead of nine or ten, which matters
    because each pass re-samples every triangle in the model.
    """
    power = 3.0 if solid else 2.0

    def measure(g):
        cells = voxelise(model, up, g, want_colour=False)
        n = len(fill_interior(cells)) if solid else len(cells)
        print(f"  grid {g:4d} -> {n:,} blocks")
        return n

    grid = 48
    n = measure(grid)
    best = (grid, n)
    for _ in range(tries - 1):
        if n <= 0:
            grid *= 2
        else:
            # n ~ k * grid**power  =>  grid_next = grid * (target/n)**(1/power)
            grid = int(round(grid * (target / n) ** (1.0 / power)))
        grid = max(8, min(1024, grid))
        if grid == best[0]:
            break
        n = measure(grid)
        if abs(n - target) < abs(best[1] - target):
            best = (grid, n)
    return best[0]


# ── writing ─────────────────────────────────────────────────────────────────
def to_blocks(cells, matcher, single):
    """One full block per cell, identity rotation, never flagged upperBlock.

    Keyed on the cell, so two blocks cannot land in the same place - the same
    guarantee generate_palace.py makes.
    """
    placed = {}
    for cell, rgb in cells.items():
        name = single or matcher.block(int(rgb[0]), int(rgb[1]), int(rgb[2]))
        placed[cell] = name
    blocks = []
    for (x, y, z), name in placed.items():
        blocks.append({
            "blockType": name,
            "upperBlock": False,
            "cframe": [x * CELL, y * CELL, z * CELL, 1, 0, 0, 0, 1, 0],
            "parts": [],
        })
    return blocks


def anchor(blocks):
    """Re-anchor to the build's own corner, so the file drops in anywhere."""
    mnx = min(b["cframe"][0] for b in blocks)
    mny = min(b["cframe"][1] for b in blocks)
    mnz = min(b["cframe"][2] for b in blocks)
    for b in blocks:
        c = b["cframe"]
        c[0] -= mnx
        c[1] -= mny
        c[2] -= mnz
    return blocks


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return

    path, name = sys.argv[1], sys.argv[2]
    target = arg("--blocks", 80000, int)
    height = arg("--height", None, int)
    solid = "--solid" in sys.argv
    simplify = arg("--simplify", 0, int)
    single = arg("--single")
    groups = arg("--palette")
    up_flag = arg("--up")

    print(f"reading {path}")
    model = glb.load(path)
    for note in model.notes:
        print("note:", note)
    if model.skipped_modes:
        kinds = ", ".join(f"mode {m} x{n}" for m, n in model.skipped_modes.items())
        print(f"note: skipped non-triangle primitives ({kinds})")
    print(f"{len(model.primitives)} primitives, {model.triangle_count:,} triangles")

    lo, hi = model.bounds()
    up, why = pick_up_axis(hi - lo, up_flag)
    print(f"up axis: {up.upper()} - {why}")

    if height:
        world = to_world(np.array([lo, hi]), up)
        size = np.abs(world[1] - world[0])
        cells_long = max(8, int(round(height * size.max() / max(size[1], 1e-9))))
        print(f"sizing for {height} blocks tall -> grid {cells_long}")
    else:
        print(f"sizing for ~{target:,} blocks:")
        cells_long = size_for_budget(model, up, target, solid)
        print(f"chose grid {cells_long}")

    cells = voxelise(model, up, cells_long)
    print(f"{len(cells):,} surface cells")
    if solid:
        cells = fill_interior(cells)
        print(f"{len(cells):,} cells after filling the interior")

    if single:
        matcher = None
        print(f"single block: {single}")
    else:
        pal = islands_palette.build(groups.split(",") if groups else None)
        if simplify:
            counts = collections.Counter(tuple(int(v) for v in c) for c in cells.values())
            pal = islands_palette.choose_limited(pal, counts, simplify)
            print(f"simplified to {len(pal)} block types")
        else:
            print(f"palette: {len(pal)} blocks"
                  + (f" ({groups})" if groups else ""))
        matcher = islands_palette.Matcher(pal)

    blocks = anchor(to_blocks(cells, matcher, single))

    solid_dir = os.path.join(ROOT, "builds", "solid")
    hollow_dir = os.path.join(ROOT, "builds", "hollow")
    os.makedirs(solid_dir, exist_ok=True)
    os.makedirs(hollow_dir, exist_ok=True)

    out = os.path.join(solid_dir, name + ".json")
    with open(out, "w") as f:
        json.dump({"blocks": blocks}, f, separators=(",", ":"))
    print(f"\nwrote {out}  ({len(blocks):,} blocks)")

    skin = outer_skin(blocks)
    hout = os.path.join(hollow_dir, name + ".json")
    with open(hout, "w") as f:
        json.dump({"blocks": skin}, f, separators=(",", ":"))
    print(f"wrote {hout}  ({len(skin):,} blocks)")

    xs = [b["cframe"][0] // CELL for b in blocks]
    ys = [b["cframe"][1] // CELL for b in blocks]
    zs = [b["cframe"][2] // CELL for b in blocks]
    print(f"size {max(xs) + 1} x {max(ys) + 1} x {max(zs) + 1} blocks")
    used = collections.Counter(b["blockType"] for b in blocks)
    print(f"{len(used)} block types, top:")
    for k, n in used.most_common(15):
        print(f"   {k:24} {n:,}")


if __name__ == "__main__":
    main()
