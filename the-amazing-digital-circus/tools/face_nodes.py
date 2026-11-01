import json
import struct
from pathlib import Path

ROOT = Path(r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\characters")


def load(path):
    data = path.read_bytes()
    off = 12
    doc = None
    while off + 8 <= len(data):
        size, kind = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off : off + size]
        off += size
        if kind == 0x4E4F534A:
            doc = json.loads(chunk)
    return doc


def show(filename):
    doc = load(ROOT / filename)
    print("FILE", filename)
    for node in doc["nodes"]:
        if "mesh" not in node:
            continue
        name = node.get("name", "")
        low = name.lower()
        if not any(word in low for word in ("mask", "eye", "face", "head", "pupil")):
            continue
        print(" ", name, "t", [round(v, 3) for v in node.get("translation", [0, 0, 0])])


for filename in ("gangle.glb", "pomni.glb", "kinger.glb", "jax.glb", "ragatha.glb"):
    show(filename)
