"""Pull embedded JPEG/PNG images out of a compressed Blender file."""
import sys
from pathlib import Path

import zstandard

OUT = Path(r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\tools\_blend_imgs")
OUT.mkdir(exist_ok=True)


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


def extract(path: Path):
    data = decompress(path)
    stem = path.stem.split("_")[0].lower()
    saved = 0
    for magic, ender, ext in ((b"\xff\xd8\xff", b"\xff\xd9", "jpg"), (b"\x89PNG\r\n\x1a\n", b"IEND", "png")):
        start = 0
        while True:
            found = data.find(magic, start)
            if found < 0:
                break
            if ext == "jpg":
                stop = data.find(ender, found + 3)
                if stop < 0:
                    break
                blob = data[found : stop + 2]
            else:
                stop = data.find(ender, found + 8)
                if stop < 0:
                    break
                blob = data[found : stop + 8]
            if len(blob) > 800:
                dest = OUT / f"{stem}_{saved}.{ext}"
                dest.write_bytes(blob)
                print("WROTE", dest.name, len(blob))
                saved += 1
            start = found + 3
            if saved > 30:
                return
    print("DONE", path.name, "images", saved)


if __name__ == "__main__":
    extract(Path(sys.argv[1]))
