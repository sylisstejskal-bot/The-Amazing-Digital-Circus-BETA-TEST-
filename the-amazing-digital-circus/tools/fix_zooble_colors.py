"""Point Zooble's glTF COLOR_0 at the painted color layer.

Godot only shades COLOR_0. The export left that layer white and stored the
real part colors in COLOR_1 / COLOR_2, so Zooble rendered white.
"""
import json
import struct
from pathlib import Path

PATH = Path(__file__).resolve().parents[1] / "characters" / "zooble.glb"


def load(path: Path):
    data = path.read_bytes()
    offset = 12
    document = None
    blob = None
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


def samples(document, blob, accessor_index, step_target=24):
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    component_type = accessor["componentType"]
    fmt = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}[component_type]
    size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride", size * components)
    count = accessor["count"]
    step = max(1, count // step_target)
    colors = []
    for index in range(0, count, step):
        raw = struct.unpack_from("<" + fmt * components, blob, start + index * stride)
        if component_type == 5126:
            rgb = raw[:3]
        elif component_type in (5121, 5123):
            scale = 255.0 if component_type == 5121 else 65535.0
            rgb = tuple(channel / scale for channel in raw[:3])
        else:
            continue
        colors.append(rgb)
    return colors


def score(colors):
    if not colors:
        return -1.0
    total = 0.0
    for red, green, blue in colors:
        spread = max(red, green, blue) - min(red, green, blue)
        brightness = (red + green + blue) / 3.0
        # White and black layers are masks, not the outfit.
        if brightness > 0.97 or brightness < 0.02:
            spread *= 0.05
        total += spread
    return total / len(colors)


def main():
    document, blob = load(PATH)
    changed = 0
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            attributes = primitive.setdefault("attributes", {})
            best_name = ""
            best_score = -1.0
            best_accessor = None
            for name, accessor_index in list(attributes.items()):
                if not name.startswith("COLOR_"):
                    continue
                layer_score = score(samples(document, blob, accessor_index))
                if layer_score > best_score:
                    best_score = layer_score
                    best_name = name
                    best_accessor = accessor_index
            if best_accessor is None or best_score < 0.04:
                print("SKIP", mesh.get("name"), "best", best_name, round(best_score, 3))
                continue
            current = attributes.get("COLOR_0")
            if current == best_accessor:
                print("KEEP", mesh.get("name"), best_name, round(best_score, 3))
                continue
            attributes["COLOR_0"] = best_accessor
            changed += 1
            print("PAINT", mesh.get("name"), best_name, "score", round(best_score, 3))
    payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
    while len(payload) % 4:
        payload += b" "
    header = struct.pack("<III", 12 + 8 + len(payload) + 8 + len(blob), 2, 0x46546C67)
    # glTF header is magic, version, length. Pack order above is wrong; write it explicitly.
    header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(payload) + 8 + len(blob))
    out = bytearray()
    out += header
    out += struct.pack("<I4s", len(payload), b"JSON")
    out += payload
    out += struct.pack("<I4s", len(blob), b"BIN\x00")
    out += blob
    PATH.write_bytes(out)
    print("WROTE", PATH, "changed", changed, "bytes", len(out))


if __name__ == "__main__":
    main()
