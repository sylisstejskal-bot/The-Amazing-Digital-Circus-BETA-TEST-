import bpy

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\Sylis\Desktop\player models\jax_UPDATE6_RELEASE.blend")
for name in ("jax_teeth", "jax_hands", "jax_handball", "jax_body"):
    obj = bpy.data.objects.get(name)
    if obj is None:
        print("MISSING", name)
        continue
    print(name, [attr.name for attr in obj.data.color_attributes])
    for attr in obj.data.color_attributes:
        if any(word in attr.name.lower() for word in ("metal", "rough")):
            continue
        seen = {}
        step = max(1, len(attr.data) // 20)
        for index in range(0, len(attr.data), step):
            key = tuple(round(channel, 2) for channel in attr.data[index].color[:3])
            seen[key] = seen.get(key, 0) + 1
        print(" ", attr.name, sorted(seen.items(), key=lambda pair: pair[1], reverse=True)[:4])
