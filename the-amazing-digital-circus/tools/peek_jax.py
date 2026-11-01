import bpy

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\Sylis\Desktop\player models\jax_UPDATE6_RELEASE.blend")
for name in ("jax_head", "jax_body", "jax_eyeR", "jax_pupils"):
    obj = bpy.data.objects.get(name)
    if obj is None:
        print("MISSING", name)
        continue
    attrs = [attr.name for attr in obj.data.color_attributes]
    print(name, "slots", [slot.material.name if slot.material else None for slot in obj.material_slots], "attrs", attrs)
    for layer_name in ("Color", "thomas"):
        color = obj.data.color_attributes.get(layer_name)
        if color is None:
            continue
        seen = {}
        for item in color.data:
            key = tuple(round(channel, 2) for channel in item.color[:3])
            seen[key] = seen.get(key, 0) + 1
        top = sorted(seen.items(), key=lambda pair: pair[1], reverse=True)[:5]
        print(" ", layer_name, top)
