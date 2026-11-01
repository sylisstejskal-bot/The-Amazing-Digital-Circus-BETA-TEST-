import bpy
import os

ROOT = r"C:\Users\Sylis\Desktop\player models"
FILES = [
    "caine_UPDATE5_RELEASE.blend",
    "gangle_UPDATE5_RELEASE.blend",
    "kinger_UPDATE5_RELEASE.blend",
    "ragatha_UPDATE5_RELEASE.blend",
    "zooble_UPDATE6_RELEASE.blend",
]
KEYS = ("head", "eye", "pupil", "face", "mask", "teeth", "mouth", "body", "ear", "hand")


def hist(attr):
    seen = {}
    step = max(1, len(attr.data) // 40)
    for index in range(0, len(attr.data), step):
        key = tuple(round(channel, 2) for channel in attr.data[index].color[:3])
        seen[key] = seen.get(key, 0) + 1
    return sorted(seen.items(), key=lambda pair: pair[1], reverse=True)[:4]


for filename in FILES:
    path = os.path.join(ROOT, filename)
    if not os.path.exists(path):
        print("MISSING", path)
        continue
    bpy.ops.wm.open_mainfile(filepath=path)
    print("\nFILE", filename)
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        low = obj.name.lower()
        if obj.name.startswith("WGT"):
            continue
        if not any(word in low for word in KEYS):
            continue
        attrs = list(obj.data.color_attributes)
        if not attrs:
            print(obj.name, "NO ATTR")
            continue
        print(obj.name, "attrs", [attr.name for attr in attrs])
        for attr in attrs:
            if attr.name.lower() in ("metal", "rough", "roughness"):
                continue
            print(" ", attr.name, hist(attr))
