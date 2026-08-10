"""Read a .glb into world-space triangles, UVs and base colours.

A GLB is a 12-byte header followed by chunks: one JSON chunk describing the
scene, one binary chunk holding the vertex data and the texture images. That is
little enough structure to read with struct and json, the way anvil.py reads
region files, so this stays dependency-free apart from numpy.

Only what a voxeliser needs is read - positions, texture coordinates, vertex
colours, indices, and each material's base colour and base colour texture.
Normals, tangents, animation, skinning, cameras and lights are ignored.

    from glb import load
    model = load("thing.glb")
    for prim in model.primitives:
        prim.positions   # (n, 3) float32, world space
        prim.uvs         # (n, 2) float32 or None
        prim.colors      # (n, 4) float32 0-1 or None
        prim.indices     # (m, 3) int32
        prim.material    # Material or None
"""
import json
import pathlib
import struct

import numpy as np

MAGIC = 0x46546C67          # 'glTF'
CHUNK_JSON = 0x4E4F534A     # 'JSON'
CHUNK_BIN = 0x004E4942      # 'BIN\0'

# accessor componentType -> numpy dtype
COMPONENT = {
    5120: np.int8, 5121: np.uint8, 5122: np.int16,
    5123: np.uint16, 5125: np.uint32, 5126: np.float32,
}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
         "MAT2": 4, "MAT3": 9, "MAT4": 16}

# Extensions that change how the mesh data itself is encoded. Anything here
# means the vertex arrays cannot be read the plain way, and a silently empty
# model is far worse than a clear stop.
BLOCKING_EXTENSIONS = {
    "KHR_draco_mesh_compression":
        "mesh is Draco-compressed; re-export without Draco compression",
    "EXT_meshopt_compression":
        "mesh is meshopt-compressed; re-export without it",
}


class GLBError(Exception):
    pass


class Material:
    def __init__(self, name, base_color, texture):
        self.name = name
        self.base_color = base_color      # (r, g, b, a) floats 0-1
        self.texture = texture            # Texture or None

    def __repr__(self):
        return f"<Material {self.name!r} texture={self.texture is not None}>"


class Texture:
    """A decoded base colour image, or a stub when it could not be decoded."""

    def __init__(self, pixels, width, height, name=""):
        self.pixels = pixels              # (h, w, 3) uint8, or None
        self.width = width
        self.height = height
        self.name = name

    @property
    def usable(self):
        return self.pixels is not None

    def sample(self, u, v):
        """Nearest-neighbour lookup, UVs wrapped. Arrays in, (n, 3) out."""
        u = np.asarray(u, dtype=np.float64)
        v = np.asarray(v, dtype=np.float64)
        x = np.mod(u, 1.0) * (self.width - 1)
        # glTF UV origin is top-left, image row 0 is the top, so v maps straight
        y = np.mod(v, 1.0) * (self.height - 1)
        return self.pixels[np.rint(y).astype(np.int32),
                           np.rint(x).astype(np.int32)]


class Primitive:
    def __init__(self, positions, uvs, colors, indices, material):
        self.positions = positions
        self.uvs = uvs
        self.colors = colors
        self.indices = indices
        self.material = material

    @property
    def triangle_count(self):
        return len(self.indices)


class Model:
    def __init__(self, primitives, skipped_modes, notes):
        self.primitives = primitives
        self.skipped_modes = skipped_modes
        self.notes = notes

    @property
    def triangle_count(self):
        return sum(p.triangle_count for p in self.primitives)

    def bounds(self):
        lo = np.array([np.inf] * 3)
        hi = np.array([-np.inf] * 3)
        for p in self.primitives:
            lo = np.minimum(lo, p.positions.min(axis=0))
            hi = np.maximum(hi, p.positions.max(axis=0))
        return lo, hi


# ── image decoding ──────────────────────────────────────────────────────────
def _decode_with_pillow(data):
    try:
        from PIL import Image
    except ImportError:
        return None
    import io
    try:
        img = Image.open(io.BytesIO(data)).convert("RGB")
        return np.asarray(img, dtype=np.uint8)
    except Exception:
        return None


def _decode_png(data):
    """Minimal PNG reader: 8-bit, non-interlaced, colour types 0/2/3/4/6.

    The same ground IAB.lua's Lua decoder covers. It exists so PNG textures
    still work without Pillow installed; JPEG needs Pillow.
    """
    import zlib

    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    pos = 8
    idat = bytearray()
    width = height = depth = ctype = None
    palette = None
    while pos + 8 <= len(data):
        (length,) = struct.unpack_from(">I", data, pos)
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or interlace:
                return None
        elif kind == b"PLTE":
            palette = np.frombuffer(body, dtype=np.uint8).reshape(-1, 3)
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break

    if width is None:
        return None
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(ctype)
    if channels is None:
        return None

    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    out = np.zeros((height, stride), dtype=np.uint8)
    prev = np.zeros(stride, dtype=np.uint8)
    at = 0
    for y in range(height):
        f = raw[at]
        line = np.frombuffer(raw, dtype=np.uint8, count=stride, offset=at + 1).copy()
        at += 1 + stride
        if f == 1:      # Sub
            for i in range(channels, stride):
                line[i] = (int(line[i]) + int(line[i - channels])) & 0xFF
        elif f == 2:    # Up
            line = (line.astype(np.int32) + prev.astype(np.int32)).astype(np.uint8)
        elif f == 3:    # Average
            for i in range(stride):
                left = int(line[i - channels]) if i >= channels else 0
                line[i] = (int(line[i]) + ((left + int(prev[i])) >> 1)) & 0xFF
        elif f == 4:    # Paeth
            for i in range(stride):
                a = int(line[i - channels]) if i >= channels else 0
                b = int(prev[i])
                c = int(prev[i - channels]) if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (int(line[i]) + pred) & 0xFF
        out[y] = line
        prev = line

    img = out.reshape(height, width, channels)
    if ctype == 3 and palette is not None:
        return palette[img[:, :, 0]]
    if ctype in (0, 4):
        return np.repeat(img[:, :, :1], 3, axis=2)
    return img[:, :, :3]


def _decode_image(data, name, notes):
    px = _decode_with_pillow(data)
    if px is None and data[:8] == b"\x89PNG\r\n\x1a\n":
        px = _decode_png(data)
    if px is None:
        kind = "JPEG" if data[:2] == b"\xff\xd8" else "image"
        notes.append(f"could not decode {kind} texture {name!r} - "
                     f"falling back to its flat material colour "
                     f"(pip install Pillow to sample it)")
        return None
    h, w = px.shape[:2]
    return Texture(px, w, h, name)


# ── glTF plumbing ───────────────────────────────────────────────────────────
def _node_matrix(node):
    if "matrix" in node:
        # glTF matrices are column-major; transpose to row-major for numpy
        return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
    m = np.eye(4)
    if "scale" in node:
        m = np.diag([*node["scale"], 1.0]) @ m
    if "rotation" in node:
        x, y, z, w = node["rotation"]
        r = np.array([
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0],
            [0, 0, 0, 1],
        ])
        m = r @ m
    if "translation" in node:
        t = np.eye(4)
        t[:3, 3] = node["translation"]
        m = t @ m
    return m


class _Reader:
    def __init__(self, gltf, blob):
        self.g = gltf
        self.blob = blob
        self._tex_cache = {}
        self._mat_cache = {}
        self.notes = []

    def view_bytes(self, index):
        bv = self.g["bufferViews"][index]
        if bv.get("buffer", 0) != 0:
            raise GLBError("external buffers are not supported; use a .glb")
        off = bv.get("byteOffset", 0)
        return self.blob[off:off + bv["byteLength"]], bv.get("byteStride")

    def accessor(self, index):
        acc = self.g["accessors"][index]
        if "sparse" in acc:
            raise GLBError("sparse accessors are not supported")
        n = acc["count"]
        comps = COUNT[acc["type"]]
        dtype = COMPONENT[acc["componentType"]]
        if "bufferView" not in acc:
            return np.zeros((n, comps), dtype=dtype)

        raw, stride = self.view_bytes(acc["bufferView"])
        off = acc.get("byteOffset", 0)
        item = np.dtype(dtype).itemsize * comps
        if stride and stride != item:
            # interleaved: step over the other attributes
            out = np.empty((n, comps), dtype=dtype)
            for i in range(n):
                start = off + i * stride
                out[i] = np.frombuffer(raw, dtype=dtype, count=comps,
                                       offset=start)
            data = out
        else:
            data = np.frombuffer(raw, dtype=dtype, count=n * comps,
                                 offset=off).reshape(n, comps)

        if acc.get("normalized") and dtype != np.float32:
            info = np.iinfo(dtype)
            data = data.astype(np.float32)
            data = data / info.max if info.min == 0 else np.maximum(data / info.max, -1.0)
        return data

    def texture(self, index):
        if index in self._tex_cache:
            return self._tex_cache[index]
        tex = self.g["textures"][index]
        src = tex.get("source")
        out = None
        if src is not None:
            img = self.g["images"][src]
            name = img.get("name") or f"image{src}"
            data = None
            if "bufferView" in img:
                data = self.view_bytes(img["bufferView"])[0]
            elif "uri" in img and img["uri"].startswith("data:"):
                import base64
                data = base64.b64decode(img["uri"].split(",", 1)[1])
            elif "uri" in img:
                self.notes.append(f"texture {name!r} is an external file "
                                  f"({img['uri']}); GLB should embed it")
            if data:
                out = _decode_image(bytes(data), name, self.notes)
        self._tex_cache[index] = out
        return out

    def material(self, index):
        if index is None:
            return None
        if index in self._mat_cache:
            return self._mat_cache[index]
        m = self.g["materials"][index]
        pbr = m.get("pbrMetallicRoughness", {})
        base = tuple(pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0]))
        tex = None
        if "baseColorTexture" in pbr:
            tex = self.texture(pbr["baseColorTexture"]["index"])
        out = Material(m.get("name", f"material{index}"), base, tex)
        self._mat_cache[index] = out
        return out


def load(path):
    """Read a .glb and return a Model whose positions are in world space."""
    data = pathlib.Path(path).read_bytes()
    if len(data) < 12:
        raise GLBError("file is too small to be a GLB")
    magic, version, _ = struct.unpack_from("<III", data, 0)
    if magic != MAGIC:
        hint = ("this looks like a .gltf (JSON); export or convert it to .glb"
                if data.lstrip()[:1] == b"{" else "not a GLB file")
        raise GLBError(hint)
    if version != 2:
        raise GLBError(f"GLB version {version}, only version 2 is supported")

    gltf = None
    blob = b""
    pos = 12
    while pos + 8 <= len(data):
        length, kind = struct.unpack_from("<II", data, pos)
        body = data[pos + 8:pos + 8 + length]
        pos += 8 + length + (-length % 4)
        if kind == CHUNK_JSON:
            # the spec pads this chunk with spaces; tolerate nulls too
            gltf = json.loads(body.decode("utf-8").rstrip(" \t\r\n\0"))
        elif kind == CHUNK_BIN:
            blob = body
    if gltf is None:
        raise GLBError("no JSON chunk in the GLB")

    for ext in gltf.get("extensionsRequired", []):
        if ext in BLOCKING_EXTENSIONS:
            raise GLBError(BLOCKING_EXTENSIONS[ext])

    r = _Reader(gltf, blob)
    prims = []
    skipped_modes = {}

    def walk(node_index, parent):
        node = gltf["nodes"][node_index]
        world = parent @ _node_matrix(node)
        if "mesh" in node:
            for prim in gltf["meshes"][node["mesh"]].get("primitives", []):
                if "extensions" in prim:
                    for ext in prim["extensions"]:
                        if ext in BLOCKING_EXTENSIONS:
                            raise GLBError(BLOCKING_EXTENSIONS[ext])
                mode = prim.get("mode", 4)
                if mode != 4:
                    skipped_modes[mode] = skipped_modes.get(mode, 0) + 1
                    continue
                attrs = prim.get("attributes", {})
                if "POSITION" not in attrs:
                    continue

                pos_local = r.accessor(attrs["POSITION"]).astype(np.float64)
                homo = np.concatenate(
                    [pos_local, np.ones((len(pos_local), 1))], axis=1)
                positions = (homo @ world.T)[:, :3].astype(np.float32)

                uvs = None
                if "TEXCOORD_0" in attrs:
                    uvs = r.accessor(attrs["TEXCOORD_0"]).astype(np.float32)
                colors = None
                if "COLOR_0" in attrs:
                    c = r.accessor(attrs["COLOR_0"]).astype(np.float32)
                    if c.shape[1] == 3:
                        c = np.concatenate([c, np.ones((len(c), 1), np.float32)], 1)
                    colors = c

                if "indices" in prim:
                    idx = r.accessor(prim["indices"]).reshape(-1)
                else:
                    idx = np.arange(len(positions))
                usable = (len(idx) // 3) * 3
                tris = idx[:usable].reshape(-1, 3).astype(np.int32)
                if len(tris) == 0:
                    continue

                prims.append(Primitive(positions, uvs, colors, tris,
                                       r.material(prim.get("material"))))
        for child in node.get("children", []):
            walk(child, world)

    scene = gltf.get("scene", 0)
    roots = gltf.get("scenes", [{}])[scene].get("nodes")
    if roots is None:
        roots = range(len(gltf.get("nodes", [])))
    for n in roots:
        walk(n, np.eye(4))

    if not prims:
        raise GLBError("no triangle geometry found in the file")
    return Model(prims, skipped_modes, r.notes)


if __name__ == "__main__":
    import sys
    m = load(sys.argv[1])
    lo, hi = m.bounds()
    print(f"{len(m.primitives)} primitives, {m.triangle_count:,} triangles")
    print(f"bounds  min {lo.round(3)}  max {hi.round(3)}  size {(hi - lo).round(3)}")
    textured = sum(1 for p in m.primitives
                   if p.material and p.material.texture and p.material.texture.usable)
    print(f"{textured} primitives with a usable base colour texture")
    for n in m.notes:
        print("note:", n)
