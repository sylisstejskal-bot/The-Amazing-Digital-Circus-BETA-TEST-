"""Correct character colors that came out as the wrong hue.

Some parts were using a flat id color (red teeth, red rabbit skin) and some
materials were still multiplied by the exporter's beige placeholder.
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "characters"
BEIGE = (0.82, 0.78, 0.74)
PURPLE = (0.64, 0.28, 0.9)


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
            blob = bytearray(chunk)
    return document, blob


def save(path: Path, document, blob: bytearray) -> None:
    document["buffers"][0]["byteLength"] = len(blob)
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


def mesh_labels(document):
    labels = {}
    for node in document["nodes"]:
        if "mesh" in node:
            labels.setdefault(node["mesh"], node.get("name", ""))
    return labels


def accessor_layout(document, accessor_index):
    accessor = document["accessors"][accessor_index]
    view = document["bufferViews"][accessor["bufferView"]]
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    component_type = accessor["componentType"]
    fmt = {5121: "B", 5123: "H", 5126: "f"}[component_type]
    size = struct.calcsize("<" + fmt)
    stride = view.get("byteStride", size * components)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return accessor, start, stride, components, component_type, fmt


def read_rgb(blob, offset, component_type, fmt, components):
    raw = struct.unpack_from("<" + fmt * components, blob, offset)
    if component_type == 5126:
        return raw[:3]
    scale = 255.0 if component_type == 5121 else 65535.0
    return tuple(channel / scale for channel in raw[:3])


def write_rgb(blob, offset, component_type, fmt, components, rgb):
    if component_type == 5126:
        struct.pack_into("<fff", blob, offset, *rgb)
        return
    scale = 255 if component_type == 5121 else 65535
    packed = [max(0, min(scale, int(round(channel * scale)))) for channel in rgb]
    current = list(struct.unpack_from("<" + fmt * components, blob, offset))
    current[:3] = packed
    struct.pack_into("<" + fmt * components, blob, offset, *current)


def each_vertex(document, blob, accessor_index):
    accessor, start, stride, components, component_type, fmt = accessor_layout(document, accessor_index)
    for index in range(accessor["count"]):
        offset = start + index * stride
        yield offset, read_rgb(blob, offset, component_type, fmt, components), component_type, fmt, components


def is_red(rgb):
    red, green, blue = rgb
    return red > 0.75 and red > green * 1.7 and red > blue * 1.7 and green < 0.55


def is_yellow(rgb):
    red, green, blue = rgb
    return red > 0.75 and green > 0.35 and blue < 0.35


def to_purple(rgb):
    light = (rgb[0] + rgb[1] + rgb[2]) / 3.0
    return (
        min(1.0, 0.42 + 0.28 * light),
        min(1.0, 0.16 + 0.14 * light),
        min(1.0, 0.72 + 0.22 * light),
    )


def recolor(document, blob, accessor_index, predicate, paint):
    changed = 0
    for offset, rgb, component_type, fmt, components in each_vertex(document, blob, accessor_index):
        if not predicate(rgb):
            continue
        new_rgb = paint(rgb) if callable(paint) else paint
        write_rgb(blob, offset, component_type, fmt, components, new_rgb)
        changed += 1
    return changed


def mostly_red(document, blob, accessor_index):
    reds = 0
    total = 0
    for _offset, rgb, *_rest in each_vertex(document, blob, accessor_index):
        total += 1
        if is_red(rgb):
            reds += 1
        if total > 80 and reds / total < 0.5:
            return False
    return total > 0 and reds / total > 0.85


def whitest_color_accessor(document, blob, attributes, skip):
    best = None
    best_score = -1.0
    for name, accessor_index in attributes.items():
        if not name.startswith("COLOR_") or accessor_index == skip:
            continue
        total = 0.0
        count = 0
        reds = 0
        for _offset, rgb, *_rest in each_vertex(document, blob, accessor_index):
            total += sum(rgb) / 3.0
            if is_red(rgb):
                reds += 1
            count += 1
            if count > 400:
                break
        if count == 0 or reds / count > 0.5:
            continue
        score = total / count
        if score > best_score:
            best_score = score
            best = accessor_index
    return best


def fix_beige(document):
    changed = 0
    for material in document.get("materials", []):
        factor = material.get("pbrMetallicRoughness", {}).get("baseColorFactor")
        if not factor:
            continue
        if all(abs(factor[channel] - BEIGE[channel]) < 0.02 for channel in range(3)):
            material.setdefault("pbrMetallicRoughness", {})["baseColorFactor"] = [1.0, 1.0, 1.0, 1.0]
            changed += 1
    return changed


def fix_caine(document, blob):
    labels = mesh_labels(document)
    changed = 0
    for index, mesh in enumerate(document["meshes"]):
        if "teeth" not in labels.get(index, "").lower():
            continue
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            color = attributes.get("COLOR_0")
            if color is None or not mostly_red(document, blob, color):
                continue
            better = whitest_color_accessor(document, blob, attributes, color)
            if better is None:
                continue
            attributes["COLOR_0"] = better
            changed += 1
    return changed


def fix_jax(document, blob):
    labels = mesh_labels(document)
    changed = 0
    for index, mesh in enumerate(document["meshes"]):
        label = labels.get(index, "")
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            color = attributes.get("COLOR_0")
            if color is None:
                continue
            if label in ("jax_head", "jax_ears", "jax_body"):
                changed += recolor(document, blob, color, is_red, to_purple)
            elif label in ("jax_hands", "jax_handball"):
                changed += recolor(document, blob, color, lambda rgb: is_red(rgb) or is_yellow(rgb), to_purple)
            elif label == "jax_teeth":
                better = whitest_color_accessor(document, blob, attributes, color)
                if better is not None and better != color:
                    attributes["COLOR_0"] = better
                    changed += 1
    return changed


def fix_kinger_hands(document, blob):
    labels = mesh_labels(document)
    changed = 0
    for index, mesh in enumerate(document["meshes"]):
        if labels.get(index, "") not in ("kinger_hands", "kinger_gloveballs", "QUEENIE_hands", "QUEENIE_gloveballs"):
            continue
        for primitive in mesh["primitives"]:
            color = primitive["attributes"].get("COLOR_0")
            if color is None:
                continue
            changed += recolor(
                document,
                blob,
                color,
                lambda rgb: max(rgb) < 0.28,
                (0.95, 0.93, 0.88),
            )
    return changed


def retint_flat(document, blob, names, predicate, color):
    labels = mesh_labels(document)
    changed = 0
    for index, mesh in enumerate(document["meshes"]):
        if labels.get(index, "") not in names:
            continue
        for primitive in mesh["primitives"]:
            accessor = primitive["attributes"].get("COLOR_0")
            if accessor is None:
                continue
            changed += recolor(document, blob, accessor, predicate, color)
    return changed


def paint_orbsman(document, blob):
    labels = mesh_labels(document)
    body_index = None
    for index, _mesh in enumerate(document["meshes"]):
        if labels.get(index, "") == "orbsman_body":
            body_index = index
            break
    if body_index is None:
        return 0
    primitive = document["meshes"][body_index]["primitives"][0]
    position = primitive["attributes"]["POSITION"]
    accessor, start, stride, _components, _ctype, _fmt = accessor_layout(document, position)
    points = []
    for index in range(accessor["count"]):
        points.append(struct.unpack_from("<fff", blob, start + index * stride))
    centers = []
    for point in points[:: max(1, len(points) // 900)]:
        if all(sum((point[axis] - center[axis]) ** 2 for axis in range(3)) > 0.08 for center in centers):
            centers.append(point)
    palette = [
        (0.93, 0.24, 0.28),
        (0.25, 0.48, 0.95),
        (0.98, 0.78, 0.18),
        (0.28, 0.78, 0.38),
        (0.86, 0.34, 0.74),
        (0.98, 0.5, 0.16),
    ]
    colors = bytearray()
    for point in points:
        best = 0
        best_dist = 1e9
        for index, center in enumerate(centers):
            dist = sum((point[axis] - center[axis]) ** 2 for axis in range(3))
            if dist < best_dist:
                best_dist = dist
                best = index
        colors += struct.pack("<fff", *palette[best % len(palette)])
    view_index = len(document["bufferViews"])
    document["bufferViews"].append({
        "buffer": 0,
        "byteOffset": len(blob),
        "byteLength": len(colors),
    })
    blob += colors
    accessor_index = len(document["accessors"])
    document["accessors"].append({
        "bufferView": view_index,
        "componentType": 5126,
        "count": len(points),
        "type": "VEC3",
    })
    primitive["attributes"]["COLOR_0"] = accessor_index
    for material in document["materials"]:
        pbr = material.setdefault("pbrMetallicRoughness", {})
        name = material.get("name", "")
        if "pupil" in name:
            pbr["baseColorFactor"] = [0.06, 0.05, 0.1, 1.0]
        else:
            pbr["baseColorFactor"] = [1.0, 1.0, 1.0, 1.0]
    return len(points)


def main():
    jobs = {
        "caine.glb": lambda document, blob: fix_caine(document, blob),
        "jax.glb": lambda document, blob: fix_jax(document, blob),
        "kinger.glb": lambda document, blob: fix_kinger_hands(document, blob),
        "queenie.glb": lambda document, blob: fix_kinger_hands(document, blob)
        + retint_flat(
            document, blob, {"QUEENIE_body"}, lambda rgb: max(rgb) < 0.4 and rgb[0] >= rgb[2], (0.46, 0.16, 0.62)
        )
        + retint_flat(
            document, blob, {"QUEENIE_head"}, lambda rgb: max(rgb) < 0.4 and rgb[0] >= rgb[2], (0.87, 0.58, 0.24)
        ),
        "martha.glb": lambda document, blob: (
            retint_flat(document, blob, {"martha_hairbot", "martha_hairtop"}, lambda _rgb: True, (0.45, 0.24, 0.16))
            + retint_flat(document, blob, {"martha_head", "martha_hands"}, lambda _rgb: True, (0.94, 0.78, 0.66))
            + retint_flat(document, blob, {"martha_eyebrows"}, lambda _rgb: True, (0.18, 0.1, 0.08))
            + retint_flat(
                document,
                blob,
                {"martha_body", "martha_dress", "martha_hat", "martha_collar", "martha_bowbody", "martha_bowbody2", "martha_bowhat", "martha_bowwaist"},
                lambda _rgb: True,
                (0.82, 0.62, 0.68),
            )
        ),
        "ghostly.glb": lambda document, blob: retint_flat(
            document, blob, {"ghostly_body"}, lambda rgb: rgb[1] > 0.6 and rgb[0] < 0.2, (0.74, 0.9, 0.9)
        ),
        "fudge.glb": lambda document, blob: retint_flat(
            document, blob, {"FUDGE_body", "FUDGE_river"}, lambda rgb: max(rgb) < 0.25, (0.52, 0.28, 0.14)
        ),
        "orbsman.glb": lambda document, blob: paint_orbsman(document, blob),
    }
    for name, fixer in jobs.items():
        path = ROOT / name
        document, blob = load(path)
        beige = fix_beige(document)
        changed = fixer(document, blob)
        save(path, document, blob)
        print(name, "parts", changed, "beige", beige)


if __name__ == "__main__":
    main()
