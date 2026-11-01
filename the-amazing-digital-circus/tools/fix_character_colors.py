"""Point each mesh's COLOR_0 at the painted color layer.

Godot only shades COLOR_0. Several circus models stored the real paint in
COLOR_1 and up, so those parts rendered white.
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "characters"


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


def samples(document, blob, accessor_index):
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    component_type = accessor["componentType"]
    fmt = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}[component_type]
    size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride", size * components)
    count = accessor["count"]
    step = max(1, count // 32)
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
    sats = []
    reds = []
    greens = []
    blues = []
    for red, green, blue in colors:
        bright = (red + green + blue) / 3.0
        sat = max(red, green, blue) - min(red, green, blue)
        if bright > 0.97 or bright < 0.025:
            sat *= 0.05
        sats.append(sat)
        reds.append(red)
        greens.append(green)
        blues.append(blue)

    def spread(values):
        mean = sum(values) / len(values)
        return sum((value - mean) ** 2 for value in values) / len(values)

    return sum(sats) / len(sats) + (spread(reds) + spread(greens) + spread(blues)) ** 0.5


def save(path: Path, document, blob) -> None:
    payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
    while len(payload) % 4:
        payload += b" "
    header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(payload) + 8 + len(blob))
    out = bytearray()
    out += header
    out += struct.pack("<I4s", len(payload), b"JSON")
    out += payload
    out += struct.pack("<I4s", len(blob), b"BIN\x00")
    out += blob
    path.write_bytes(out)


def fix(path: Path) -> int:
    document, blob = load(path)
    changed = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            attributes = primitive.setdefault("attributes", {})
            best_score = -1.0
            best_accessor = None
            for name, accessor_index in list(attributes.items()):
                if not name.startswith("COLOR_"):
                    continue
                layer_score = score(samples(document, blob, accessor_index))
                if layer_score > best_score:
                    best_score = layer_score
                    best_accessor = accessor_index
            if best_accessor is None or best_score < 0.08:
                continue
            if attributes.get("COLOR_0") == best_accessor:
                continue
            attributes["COLOR_0"] = best_accessor
            changed += 1
    if changed:
        save(path, document, blob)
    return changed


def main() -> None:
    for path in sorted(ROOT.glob("*.glb")):
        changed = fix(path)
        print(("PAINT" if changed else "KEEP "), path.name, changed)


if __name__ == "__main__":
    main()
