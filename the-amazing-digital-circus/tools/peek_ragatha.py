import bpy

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\Sylis\Desktop\player models\ragatha_UPDATE5_RELEASE.blend")
for obj in bpy.data.objects:
    if obj.type != "MESH" or obj.name.startswith("WGT"):
        continue
    low = obj.name.lower()
    if not any(word in low for word in ("dress", "hair", "head", "arm", "leg", "bow")):
        continue
    print(obj.name)
    for attr in obj.data.color_attributes:
        if any(word in attr.name.lower() for word in ("metal", "rough")):
            continue
        seen = {}
        step = max(1, len(attr.data) // 16)
        for index in range(0, len(attr.data), step):
            key = tuple(round(channel, 2) for channel in attr.data[index].color[:3])
            seen[key] = seen.get(key, 0) + 1
        top = sorted(seen.items(), key=lambda pair: pair[1], reverse=True)[:3]
        print(" ", attr.name, top)
