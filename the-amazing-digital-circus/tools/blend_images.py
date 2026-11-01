"""Read packed image names out of a Blender 4.x file using its own DNA."""
import struct
import sys
from pathlib import Path

import zstandard


def decompress(path: Path) -> bytes:
    raw = path.read_bytes()
    if raw[:4] != b"\x28\xb5\x2f\xfd":
        return raw
    reader = zstandard.ZstdDecompressor().stream_reader(raw)
    parts = []
    while True:
        chunk = reader.read(1 << 20)
        if not chunk:
            break
        parts.append(chunk)
    return b"".join(parts)


def cstr(data: bytes, offset: int) -> str:
    end = data.find(b"\x00", offset)
    return data[offset:end].decode("utf-8", "replace")


def parse_sdna(data: bytes):
    marker = data.find(b"DNA1")
    start = data.find(b"SDNA", marker if marker >= 0 else 0)
    if start < 0:
        raise SystemExit("no SDNA")
    offset = start + 4
    assert data[offset : offset + 4] == b"NAME"
    offset += 4
    name_count = int.from_bytes(data[offset : offset + 4], "little")
    offset += 4
    names = []
    for _ in range(name_count):
        names.append(cstr(data, offset))
        offset += len(names[-1].encode("utf-8")) + 1

    def align(cursor):
        relative = cursor - start
        return start + ((relative + 3) & ~3)

    offset = align(offset)
    if data[offset : offset + 4] != b"TYPE":
        window = data[offset : offset + 32]
        raise SystemExit(f"TYPE missing at {offset}: {window!r} names={name_count}")
    offset += 4
    type_count = int.from_bytes(data[offset : offset + 4], "little")
    offset += 4
    types = []
    for _ in range(type_count):
        types.append(cstr(data, offset))
        offset += len(types[-1].encode("utf-8")) + 1
    offset = align(offset)
    assert data[offset : offset + 4] == b"TLEN"
    offset += 4
    lengths = [int.from_bytes(data[offset + i * 2 : offset + i * 2 + 2], "little") for i in range(type_count)]
    offset += type_count * 2
    offset = align(offset)
    assert data[offset : offset + 4] == b"STRC"
    offset += 4
    struct_count = int.from_bytes(data[offset : offset + 4], "little")
    offset += 4
    structs = []
    for _ in range(struct_count):
        type_index = int.from_bytes(data[offset : offset + 2], "little")
        field_count = int.from_bytes(data[offset + 2 : offset + 4], "little")
        offset += 4
        fields = []
        for _field in range(field_count):
            field_type = int.from_bytes(data[offset : offset + 2], "little")
            field_name = int.from_bytes(data[offset + 2 : offset + 4], "little")
            offset += 4
            fields.append((field_type, field_name))
        structs.append((type_index, fields))
    return names, types, lengths, structs


def field_size(names, lengths, type_index, name, pointer_size):
    raw = names[name]
    if "*" in raw.split("[", 1)[0]:
        size = pointer_size
    else:
        size = lengths[type_index]
    while "[" in raw:
        left = raw.rfind("[")
        right = raw.rfind("]")
        size *= int(raw[left + 1 : right])
        raw = raw[:left]
    return size


def struct_fields(names, types, lengths, structs, type_name, pointer_size):
    type_index = types.index(type_name)
    for index, fields in structs:
        if index != type_index:
            continue
        cursor = 0
        layout = []
        for field_type, field_name in fields:
            size = field_size(names, lengths, field_type, field_name, pointer_size)
            if "*" in names[field_name]:
                size_for_align = pointer_size
            else:
                size_for_align = min(size, 8)
            if size_for_align >= 2:
                cursor = (cursor + size_for_align - 1) & ~(size_for_align - 1)
            layout.append((names[field_name], types[field_type], cursor, size))
            cursor += size
        expected = lengths[type_index]
        if cursor != expected and (cursor + 7) & ~7 != expected and (cursor + 3) & ~3 != expected:
            print("SIZE", type_name, "walked", cursor, "dna", expected)
        return layout
    raise SystemExit("missing " + type_name)


def blocks(data, pointer_size):
    offset = 12
    header = 16 + pointer_size
    found = []
    while offset + header <= len(data):
        code = data[offset : offset + 4]
        if code == b"ENDB":
            break
        size = int.from_bytes(data[offset + 4 : offset + 8], "little")
        address = int.from_bytes(data[offset + 8 : offset + 8 + pointer_size], "little")
        sdna = int.from_bytes(data[offset + 8 + pointer_size : offset + 12 + pointer_size], "little")
        count = int.from_bytes(data[offset + 12 + pointer_size : offset + 16 + pointer_size], "little")
        payload = offset + header
        found.append((code, address, sdna, count, payload, size))
        offset = payload + size
    return found


def read_ptr(data, offset, pointer_size):
    return int.from_bytes(data[offset : offset + pointer_size], "little")


def main(path: Path):
    data = decompress(path)
    pointer_size = 8 if data[7:8] == b"-" else 4
    names, types, lengths, structs = parse_sdna(data)
    image_fields = struct_fields(names, types, lengths, structs, "Image", pointer_size)
    packed_fields = struct_fields(names, types, lengths, structs, "PackedFile", pointer_size)
    print("Image fields:")
    for field in image_fields[:18]:
        print(" ", field)
    print("PackedFile:")
    for field in packed_fields:
        print(" ", field)
    id_fields = struct_fields(names, types, lengths, structs, "ID", pointer_size)
    id_name = next(field for field in id_fields if field[0].startswith("name["))
    file_name = next(field for field in image_fields if field[0].startswith("name["))
    name_offset = id_name[2]
    packed_offset = next(field[2] for field in image_fields if "packedfile" in field[0])
    data_offset = next(field[2] for field in packed_fields if field[0].startswith("*data") or field[0] == "*data")
    size_offset = next(field[2] for field in packed_fields if field[0] == "size")
    by_address = {}
    file_blocks = blocks(data, pointer_size)
    for block in file_blocks:
        by_address[block[1]] = block
    for type_name in ("Material", "bNode", "bNodeTree", "NodeShaderVertexColor", "CustomDataLayer", "CustomData", "Mesh", "Attribute"):
        try:
            layout = struct_fields(names, types, lengths, structs, type_name, pointer_size)
        except SystemExit:
            print(type_name, "MISSING")
            continue
        print(type_name)
        for field in layout:
            low = field[0].lower()
            show_all = type_name in ("Attribute", "AttributeArray", "AttributeSingle", "AttributeStorage", "CustomData", "CustomDataLayer")
            if show_all or any(word in low for word in ("name", "node", "type", "id", "tree", "next", "storage")):
                print(" ", field)
    for type_name in ("AttributeStorage", "AttributeArray", "AttributeSingle"):
        try:
            layout = struct_fields(names, types, lengths, structs, type_name, pointer_size)
        except SystemExit:
            continue
        print(type_name)
        for field in layout:
            print(" ", field)
    print("ATTR NAMES")
    for type_name in types:
        if "ttribute" in type_name:
            print(" ", type_name)
    print("VERTEX TYPES")
    for type_name in types:
        if "Vertex" in type_name or "TexImage" in type_name or "VertexColor" in type_name:
            print(" ", type_name)
    print("IMAGES")
    for code, _address, _sdna, count, payload, size in file_blocks:
        if code != b"IM\x00\x00":
            continue
        stride = size // max(count, 1)
        for index in range(count):
            base = payload + index * stride
            if index == 0 and code == b"IM\x00\x00":
                chunk = data[base : base + min(stride, 2500)]
                texts = []
                current = bytearray()
                for byte in chunk:
                    if 32 <= byte < 127:
                        current.append(byte)
                    else:
                        if len(current) >= 4:
                            texts.append(current.decode("ascii"))
                        current.clear()
                found = chunk.find(b"IM")
                print("  name at", found, "stride", stride)
            image_name = cstr(data, base + name_offset)
            file_path = cstr(data, base + file_name[2])
            packed_ptr = read_ptr(data, base + packed_offset, pointer_size)
            packed = by_address.get(packed_ptr)
            byte_count = 0
            kind = ""
            if packed:
                packed_at = packed[4]
                byte_count = int.from_bytes(data[packed_at + size_offset : packed_at + size_offset + 4], "little")
                data_ptr = read_ptr(data, packed_at + data_offset, pointer_size)
                blob = by_address.get(data_ptr)
                if blob:
                    raw = data[blob[4] : blob[4] + min(blob[5], 8)]
                    kind = raw[:4].hex()
            print(f"  {image_name} file={file_path[-70:]} packed={byte_count} magic={kind}")
            low = (image_name + file_path).lower()
            if byte_count > 2000 and any(word in low for word in ("base", "albedo", "diffuse")) and "normal" not in low and "rough" not in low and "metal" not in low and "height" not in low:
                data_ptr = read_ptr(data, by_address[packed_ptr][4] + data_offset, pointer_size)
                blob = by_address[data_ptr]
                raw = data[blob[4] : blob[4] + byte_count]
                ext = "png" if raw[:4] == b"\x89PNG" else "jpg"
                dest = Path(r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\tools\_blend_imgs")
                dest.mkdir(exist_ok=True)
                safe = "".join(ch if ch.isalnum() else "_" for ch in image_name[:40])
                out = dest / f"{safe}.{ext}"
                if not out.exists() or out.stat().st_size != len(raw):
                    out.write_bytes(raw)
                    print("  saved", out.name, len(raw))
    struct_type = {}
    for index, (type_index, _fields) in enumerate(structs):
        struct_type[index] = types[type_index]
    image_at = {}
    for code, address, _sdna, count, payload, size in file_blocks:
        if code != b"IM\x00\x00":
            continue
        stride = size // max(count, 1)
        for index in range(count):
            image_at[address + index * stride] = cstr(data, payload + index * stride + name_offset)
    print("MATERIALS")
    for code, _address, sdna, count, payload, size in file_blocks:
        if struct_type.get(sdna) != "Material":
            continue
        stride = size // max(count, 1)
        for index in range(count):
            base = payload + index * stride
            material_name = cstr(data, base + name_offset)
            tree_ptr = read_ptr(data, base + 296, pointer_size)
            tree = by_address.get(tree_ptr)
            if not tree:
                print(" ", material_name, "no tree")
                continue
            first = read_ptr(data, tree[4] + 336, pointer_size)
            seen = 0
            images_used = []
            while first and seen < 80:
                node = by_address.get(first)
                if not node:
                    break
                node_base = node[4]
                idname = cstr(data, node_base + 120)
                image_ptr = read_ptr(data, node_base + 216, pointer_size)
                image_name = image_at.get(image_ptr, "")
                if "TexImage" in idname or image_name:
                    images_used.append(image_name or cstr(data, node_base + 48))
                elif "VertexColor" in idname:
                    storage_ptr = read_ptr(data, node_base + 224, pointer_size)
                    storage = by_address.get(storage_ptr)
                    layer = cstr(data, storage[4]) if storage else "?"
                    images_used.append("vcol:" + layer)
                first = read_ptr(data, node_base, pointer_size)
                seen += 1
            if images_used:
                print(" ", material_name, " | ".join(images_used))
    print("MESH BLOCKS", sum(1 for block in file_blocks if struct_type.get(block[2]) == "Mesh"))
    print("MESH ATTRS")
    for code, _address, sdna, count, payload, size in file_blocks:
        if struct_type.get(sdna) != "Mesh":
            continue
        stride = size // max(count, 1)
        for index in range(count):
            base = payload + index * stride
            mesh_name = cstr(data, base + name_offset)
            if mesh_name.startswith("MEWGT") or "WGT" in mesh_name:
                continue
            storage = base + 280
            attr_ptr = read_ptr(data, storage, pointer_size)
            attr_count = int.from_bytes(data[storage + 8 : storage + 12], "little")
            if attr_count <= 0 or attr_count > 64:
                if "head" in mesh_name.lower() or "pomni" in mesh_name.lower():
                    print(" ", mesh_name, "attr_count", attr_count, "ptr", hex(attr_ptr))
                continue
            attr_block = by_address.get(attr_ptr)
            if not attr_block:
                continue
            print(" ", mesh_name, "attrs", attr_count)
            for attr_index in range(attr_count):
                attr = attr_block[4] + attr_index * 24
                name_ptr = read_ptr(data, attr, pointer_size)
                name_block = by_address.get(name_ptr)
                attr_name = cstr(data, name_block[4]) if name_block else "?"
                data_type = int.from_bytes(data[attr + 8 : attr + 10], "little")
                domain = data[attr + 10]
                storage_type = data[attr + 11]
                data_ptr = read_ptr(data, attr + 16, pointer_size)
                holder = by_address.get(data_ptr)
                array_size = 0
                sample = ""
                if holder and storage_type == 0:
                    array_size = int.from_bytes(data[holder[4] + 16 : holder[4] + 24], "little")
                    raw_ptr = read_ptr(data, holder[4], pointer_size)
                    raw_block = by_address.get(raw_ptr)
                    if raw_block and raw_block[5] >= 16:
                        floats = struct.unpack_from("<ffff", data, raw_block[4])
                        sample = " ".join(f"{v:.2f}" for v in floats)
                elif holder and storage_type == 1:
                    raw_ptr = read_ptr(data, holder[4], pointer_size)
                    raw_block = by_address.get(raw_ptr)
                    if raw_block and raw_block[5] >= 16:
                        floats = struct.unpack_from("<ffff", data, raw_block[4])
                        sample = "single " + " ".join(f"{v:.2f}" for v in floats)
                if attr_name.lower() in ("color", "face", "col") or "face" in attr_name.lower() or "color" in attr_name.lower():
                    print(f"    {attr_name} type={data_type} domain={domain} store={storage_type} size={array_size} {sample}")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
