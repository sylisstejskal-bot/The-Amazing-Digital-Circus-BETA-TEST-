"""Scan a compressed Blender file for image and color-attribute names."""
import sys
from pathlib import Path

import zstandard


def strings_in(data: bytes, minimum: int = 4):
    found = []
    current = bytearray()
    for byte in data:
        if 32 <= byte < 127:
            current.append(byte)
        else:
            if len(current) >= minimum:
                found.append(current.decode("ascii"))
            current.clear()
    if len(current) >= minimum:
        found.append(current.decode("ascii"))
    return found


def scan(path: Path):
    raw = path.read_bytes()
    if raw[:4] == b"\x28\xb5\x2f\xfd":
        reader = zstandard.ZstdDecompressor().stream_reader(raw)
        parts = []
        while True:
            chunk = reader.read(1 << 20)
            if not chunk:
                break
            parts.append(chunk)
        data = b"".join(parts)
    else:
        data = raw
    print("FILE", path.name, "compressed", len(raw), "plain", len(data), "head", data[:12])
    pointer = 8 if data[7:8] == b"-" else 4
    offset = 12
    images = []
    interesting = []
    while offset + 16 < len(data):
        code = data[offset : offset + 4]
        if code == b"ENDB":
            break
        size = int.from_bytes(data[offset + 4 : offset + 8], "little")
        block_size = 16 + pointer
        payload = data[offset + block_size : offset + block_size + size]
        if code == b"IM\x00\x00":
            names = [item for item in strings_in(payload[:400], 3) if not item.startswith("bpy")]
            images.append(names[:8])
        offset += block_size + size
        if offset > len(data):
            break
    print("IMAGES", len(images))
    for names in images:
        print(" ", names)
    print("JPEG", data.count(b"\xff\xd8\xff"), "PNG", data.count(b"\x89PNG"))
    names = []
    start = 0
    while True:
        found = data.find(b".", start)
        if found < 0 or len(names) > 80:
            break
        window = data[max(0, found - 40) : found + 8]
        text = "".join(chr(b) if 32 <= b < 127 else " " for b in window).strip()
        low = text.lower()
        if any(ext in low for ext in (".png", ".jpg", ".jpeg", ".exr", ".tga")) and text not in names:
            names.append(text)
        start = found + 1
    print("FILENAMES")
    for text in names:
        print(" ", text)
    # Color attribute names live in mesh customdata. A name search is enough.
    needles = (b"Color", b"face", b"Face", b"Base", b"albedo", b"Diffuse", b".png", b".jpg")
    hits = []
    for needle in needles:
        start = 0
        count = 0
        while count < 6:
            found = data.find(needle, start)
            if found < 0:
                break
            window = data[max(0, found - 24) : found + 48]
            text = "".join(chr(b) if 32 <= b < 127 else "." for b in window)
            hits.append(text)
            start = found + len(needle)
            count += 1
    print("HITS")
    for hit in hits:
        print(" ", hit)


if __name__ == "__main__":
    scan(Path(sys.argv[1]))
