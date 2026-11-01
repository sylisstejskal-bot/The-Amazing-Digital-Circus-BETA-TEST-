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


def sample(doc, blob, accessor_index, limit=4):
    accessor = doc["accessors"][accessor_index]
    view = doc["bufferViews"][accessor["bufferView"]]
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    ctype = accessor["componentType"]
    fmt = {5121: "B", 5123: "H", 5126: "f"}[ctype]
    size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride", size * comps)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    seen = {}
    step = max(1, accessor["count"] // 80)
    for i in range(0, accessor["count"], step):
        raw = struct.unpack_from("<" + fmt * comps, blob, start + i * stride)
        if ctype == 5126:
            rgb = raw[:3]
        else:
            scale = 255 if ctype == 5121 else 65535
            rgb = tuple(ch / scale for ch in raw[:3])
        key = tuple(round(v, 2) for v in rgb)
        seen[key] = seen.get(key, 0) + 1
    top = sorted(seen.items(), key=lambda pair: pair[1], reverse=True)[:limit]
    return top


names = ["jax.glb", "caine.glb", "pomni.glb", "gangle.glb", "ragatha.glb", "kinger.glb", "zooble.glb"]
for name in names:
    path = root / name
    doc, blob = load(path)
    labels = {}
    for node in doc["nodes"]:
        if "mesh" in node:
            labels.setdefault(node["mesh"], node.get("name", ""))
    print("\n==", name, "images", len(doc.get("images", [])), "bytes", path.stat().st_size)
    for index, mesh in enumerate(doc["meshes"]):
        label = labels.get(index, "")
        low = label.lower()
        if not any(word in low for word in ("head", "eye", "pupil", "face", "mask", "teeth", "mouth", "body")):
            continue
        prim = mesh["primitives"][0]
        mat = doc["materials"][prim["material"]]
        pbr = mat.get("pbrMetallicRoughness", {})
        factor = tuple(round(v, 2) for v in pbr.get("baseColorFactor", [1, 1, 1, 1])[:3])
        tex = "tex" if "baseColorTexture" in pbr else "notex"
        color = prim["attributes"].get("COLOR_0")
        colors = "no-color" if color is None else sample(doc, blob, color)
        print(f"  {label:22} {tex:6} factor{factor} {colors}")
