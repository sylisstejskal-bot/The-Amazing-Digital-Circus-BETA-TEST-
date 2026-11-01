import json
import struct
from pathlib import Path

root = Path(r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\characters")
names = ["jax.glb", "queenie.glb", "ragatha.glb", "shrimp.glb", "mannequin.glb", "fish.glb", "orbsman.glb", "gloink.glb"]


def load(path):
    data = path.read_bytes()
    off = 12
    doc = blob = None
    while off + 8 <= len(data):
        size, kind = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off : off + size]
        off += size
        if kind == 0x4E4F534A:
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
    step = max(1, accessor["count"] // 30)
    for index in range(0, accessor["count"], step):
        raw = struct.unpack_from("<" + fmt * comps, blob, start + index * stride)
        if ctype == 5126:
            rgb = raw[:3]
        else:
            scale = 255 if ctype == 5121 else 65535
            rgb = tuple(channel / scale for channel in raw[:3])
        key = tuple(round(value, 2) for value in rgb)
        seen[key] = seen.get(key, 0) + 1
    return sorted(seen.items(), key=lambda pair: pair[1], reverse=True)[:3]


for name in names:
    doc, blob = load(root / name)
    labels = {}
    for node in doc["nodes"]:
        if "mesh" in node:
            labels.setdefault(node["mesh"], node.get("name", ""))
    print("\n==", name, "images", len(doc.get("images", [])))
    for index, mesh in enumerate(doc["meshes"]):
        label = labels.get(index, "")
        bits = []
        for primitive in mesh["primitives"]:
            mat = doc["materials"][primitive["material"]]
            pbr = mat.get("pbrMetallicRoughness", {})
            factor = tuple(round(value, 2) for value in pbr.get("baseColorFactor", [1, 1, 1, 1])[:3])
            tex = "tex" if "baseColorTexture" in pbr else "flat"
            color = primitive["attributes"].get("COLOR_0")
            colors = "no-color" if color is None else top(doc, blob, color)
            bits.append(f"{tex} {factor} {colors}")
        print(f"  {label}: " + " | ".join(bits))
