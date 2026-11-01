"""Put black features back on brows, lashes, and pupils.

The color pass had pointed those meshes at a white mask layer, so the
face details disappeared. The dark layer is still stored beside it.
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "characters"
WORDS = ("brow", "lash", "pupil", "eyelid")


def load(path: Path):
    data = path.read_bytes()
    offset = 12
    document = blob = None
    while offset < len(data):
        length, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset : offset + length]
        offset += length
        if chunk_type == 0x4E4F534A:
            document = json.loads(chunk)
        else:
            blob = chunk
    return document, blob


def save(path: Path, document, blob: bytearray) -> None:
    document["buffers"][0]["byteLength"] = len(blob)
    payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
    while len(payload) % 4:
        payload += b" "
    header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(payload) + 8 + len(blob))
    out = bytearray(header)
    out += struct.pack("<I4s", len(payload), b"JSON")
    out += payload
    out += struct.pack("<I4s", len(blob), b"BIN\x00")
    out += blob
    path.write_bytes(out)


def mean_luma(document, blob, accessor_index):
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    component_type = accessor["componentType"]
    fmt = {5121: "B", 5123: "H", 5126: "f"}[component_type]
    size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride", size * components)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    step = max(1, accessor["count"] // 200)
    total = 0.0
    count = 0
    for index in range(0, accessor["count"], step):
        raw = struct.unpack_from("<" + fmt * components, blob, start + index * stride)
        if component_type == 5126:
            rgb = raw[:3]
        else:
            scale = 255.0 if component_type == 5121 else 65535.0
            rgb = tuple(channel / scale for channel in raw[:3])
        total += rgb[0] * 0.3 + rgb[1] * 0.59 + rgb[2] * 0.11
        count += 1
    return total / max(count, 1)


def labels(document):
    found = {}
    for node in document["nodes"]:
        if "mesh" in node:
            found.setdefault(node["mesh"], node.get("name", ""))
    return found


def restore(path: Path) -> int:
    document, blob = load(path)
    names = labels(document)
    changed = 0
    for index, mesh in enumerate(document["meshes"]):
        label = names.get(index, "").lower()
        if not any(word in label for word in WORDS):
            continue
        if "eyeball" in label:
            continue
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            colors = [key for key in attributes if key.startswith("COLOR_")]
            if "COLOR_0" not in colors or len(colors) < 2:
                continue
            ranked = sorted(colors, key=lambda key: mean_luma(document, blob, attributes[key]))
            darkest = ranked[0]
            current = mean_luma(document, blob, attributes["COLOR_0"])
            dark = mean_luma(document, blob, attributes[darkest])
            if current > 0.45 and dark < current - 0.25:
                attributes["COLOR_0"] = attributes[darkest]
                changed += 1
                print(f"  {names.get(index, '')} {current:.2f} -> {dark:.2f}")
    if changed:
        save(path, document, blob)
    return changed


def main():
    total = 0
    for path in sorted(ROOT.glob("*.glb")):
        changed = restore(path)
        if changed:
            print(path.name, changed)
            total += changed
    print("features", total)


if __name__ == "__main__":
    main()
