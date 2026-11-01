"""Save packed images and the name stored just before each one."""
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


def nearby_name(data: bytes, index: int) -> str:
    window = data[max(0, index - 180) : index]
    text = "".join(chr(b) if 32 <= b < 127 else "\n" for b in window)
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    for line in reversed(lines):
        low = line.lower()
        if any(ext in low for ext in (".png", ".jpg", ".jpeg", ".exr")):
            return line[-80:]
    return lines[-1][-80:] if lines else ""


def extract(path: Path):
    data = decompress(path)
    stem = path.stem.split("_")[0].lower()
    saved = 0
    cursor = 0
    while cursor < len(data):
        jpg = data.find(b"\xff\xd8\xff", cursor)
        png = data.find(b"\x89PNG\r\n\x1a\n", cursor)
        if jpg < 0 and png < 0:
            break
        if png < 0 or (jpg >= 0 and jpg < png):
            found = jpg
            stop = data.find(b"\xff\xd9", found + 3)
            ext = "jpg"
            end = 2
        else:
            found = png
            stop = data.find(b"IEND", found + 8)
            ext = "png"
            end = 8
        if stop < 0:
            break
        blob = data[found : stop + end]
        name = nearby_name(data, found)
        keep = any(word in name.lower() for word in ("base", "albedo", "diffuse", "color", "face"))
        print(f"{'KEEP' if keep else 'skip'} {len(blob):8d} {name}")
        if keep and 2000 < len(blob) < 12_000_000:
            dest = OUT / f"{stem}_{saved}.{ext}"
            dest.write_bytes(blob)
            print("  wrote", dest.name)
            saved += 1
        cursor = found + 3
        if saved > 12:
            break
    print("DONE", path.name, saved)


if __name__ == "__main__":
    extract(Path(sys.argv[1]))
