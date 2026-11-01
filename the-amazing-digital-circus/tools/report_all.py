import json
import struct
from pathlib import Path

root = Path(r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\characters")


def load(path):
    data = path.read_bytes()
    off = 12
    doc = blob = None
    while off + 8 <= len(data):
        n, t = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off : off + n]
        off += n
        if t == 0x4E4F534A:
            doc = json.loads(chunk)
        else:
            blob = chunk
    return doc, blob


def top(doc, blob, accessor_index):
    accessor = doc["accessors"][accessor_index]
    view = doc["bufferViews"][accessor["bufferView"]]
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    ctype = accessor["componentType"]
    fmt = {5121: "B", 5123: "H", 5126: "f"}[ctype]
    size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride", size * comps)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    seen = {}
    step = max(1, accessor["count"] // 40)
    for i in range(0, accessor["count"], step):
        raw = struct.unpack_from("<" + fmt * comps, blob, start + i * stride)
        if ctype == 5126:
            rgb = raw[:3]
        else:
            scale = 255 if ctype == 5121 else 65535
            rgb = tuple(ch / scale for ch in raw[:3])
        key = tuple(round(v, 2) for v in rgb)
        seen[key] = seen.get(key, 0) + 1
    return sorted(seen.items(), key=lambda pair: pair[1], reverse=True)[:4]


for name in ("caine.glb", "jax.glb", "kinger.glb", "ragatha.glb"):
    doc, blob = load(root / name)
    labels = {}
    for node in doc["nodes"]:
        if "mesh" in node:
            labels.setdefault(node["mesh"], node.get("name", ""))
    print("\n", name)
    if doc.get("images"):
        print(" images", [image.get("name") for image in doc["images"]])
    for index, mesh in enumerate(doc["meshes"]):
        label = labels.get(index, "")
        prims = []
        for prim in mesh["primitives"]:
            mat = doc["materials"][prim["material"]]
            pbr = mat.get("pbrMetallicRoughness", {})
            factor = tuple(round(v, 2) for v in pbr.get("baseColorFactor", [1, 1, 1, 1])[:3])
            tex = "tex" if "baseColorTexture" in pbr else "notex"
            color = prim["attributes"].get("COLOR_0")
            colors = "no-color" if color is None else top(doc, blob, color)
            prims.append(f"{tex} {factor} {colors}")
        print(f"  {label}: " + " | ".join(prims))
