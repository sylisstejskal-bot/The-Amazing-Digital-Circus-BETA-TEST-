"""Export each mesh with the paint that actually has color.

Shader bakes turned heads and eyes black. The color is in a vertex layer
(often named Attribute, not Color) or in a real albedo image. This keeps
whichever of those two is the paint, and turns Jax's red skin purple.
"""
import bpy
import os
import sys
import traceback

ROOT = r"C:\Users\Sylis\Desktop\player models"
OUT = r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\characters"
JOBS = [
    ("jax_UPDATE6_RELEASE.blend", "jax.glb"),
    ("caine_UPDATE5_RELEASE.blend", "caine.glb"),
    ("gangle_UPDATE5_RELEASE.blend", "gangle.glb"),
    ("kinger_UPDATE5_RELEASE.blend", "kinger.glb"),
    ("zooble_UPDATE6_RELEASE.blend", "zooble.glb"),
    ("ragatha_UPDATE5_RELEASE.blend", "ragatha.glb"),
]
SKIP = ("metal", "rough", "ao", "sheen", "bump", "alpha", "mask", "void", "normal", "height", "evil")


def _is_body(obj) -> bool:
    if obj.type != "MESH":
        return False
    if obj.name.startswith("WGT") or "WGT-" in obj.name:
        return False
    if obj.hide_render or obj.hide_get():
        return False
    return True


def _select():
    for obj in bpy.context.view_layer.objects:
        try:
            obj.select_set(False)
        except RuntimeError:
            pass
    chosen = []
    arms = [
        obj
        for obj in bpy.context.view_layer.objects
        if obj.type == "ARMATURE" and "metarig" not in obj.name.lower()
    ]
    for arm in arms:
        arm.select_set(True)
        chosen.append(arm)
    for obj in bpy.context.view_layer.objects:
        if not _is_body(obj):
            continue
        skinned = any(mod.type == "ARMATURE" for mod in obj.modifiers)
        if skinned or obj.parent in arms or not arms:
            obj.select_set(True)
            chosen.append(obj)
    if chosen:
        bpy.context.view_layer.objects.active = chosen[0]
    return chosen


def _sample(attr):
    data = attr.data
    count = len(data)
    if count == 0:
        return []
    step = max(1, count // 36)
    colors = []
    for index in range(0, count, step):
        pixel = data[index].color
        colors.append((pixel[0], pixel[1], pixel[2]))
    return colors


def _sat_luma(colors):
    if not colors:
        return 0.0, 0.0
    sat = 0.0
    luma = 0.0
    for red, green, blue in colors:
        sat += max(red, green, blue) - min(red, green, blue)
        luma += (red + green + blue) / 3.0
    return sat / len(colors), luma / len(colors)


def _useful(name) -> bool:
    low = name.lower()
    return not any(word in low for word in SKIP)


def _image_sat(image):
    width, height = image.size
    if width < 2 or height < 2:
        return 0.0
    pixels = image.pixels
    step = max(1, (width * height) // 60)
    total = 0.0
    count = 0
    index = 0
    last = width * height
    while index < last and count < 60:
        offset = index * 4
        red, green, blue = pixels[offset], pixels[offset + 1], pixels[offset + 2]
        total += max(red, green, blue) - min(red, green, blue)
        count += 1
        index += step
    if count == 0:
        return 0.0
    return total / count


def _color_image(mat):
    if mat is None or not mat.use_nodes or mat.node_tree is None:
        return None
    best = None
    best_sat = 0.12
    for node in mat.node_tree.nodes:
        if node.type != "TEX_IMAGE" or not getattr(node, "image", None):
            continue
        image = node.image
        low = image.name.lower()
        if any(word in low for word in ("normal", "rough", "metal", "height", "displace", "ao", "orm", "evil")):
            continue
        if image.size[0] < 16:
            continue
        sat = _image_sat(image)
        if sat > best_sat:
            best = image
            best_sat = sat
    return best


def _purple(attr):
    for item in attr.data:
        red, green, blue, alpha = item.color
        if red > 0.55 and green < 0.55 and blue < 0.45 and (red - green) > 0.25:
            item.color = (0.58, 0.16, 0.88, alpha)


def _rebuild(mat, layer, image, fallback):
    tree = mat.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.55
    if image is not None:
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    elif layer:
        color = tree.nodes.new("ShaderNodeVertexColor")
        color.layer_name = layer
        tree.links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*fallback, 1.0)
    tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    mat.use_backface_culling = False


def _fallback(name):
    low = name.lower()
    if any(word in low for word in ("pupil", "brow", "lash", "face")):
        return (0.02, 0.02, 0.03)
    if any(word in low for word in ("eye", "teeth", "tooth")):
        return (0.95, 0.95, 0.95)
    return (0.82, 0.78, 0.74)


def _layers(mesh):
    found = []
    for attr in mesh.color_attributes:
        if not _useful(attr.name):
            continue
        sat, luma = _sat_luma(_sample(attr))
        found.append((attr.name, sat, luma))
    return found


def _choose(obj, jax, layers):
    low = obj.name.lower()
    if jax and ("head" in low or "ear" in low):
        for name, _sat, _luma in layers:
            if name == "thomas":
                return name, "thomas"
    if "teeth" in low or "tooth" in low:
        light = [item for item in layers if item[2] > 0.55 and item[1] < 0.2]
        if light:
            light.sort(key=lambda item: item[2], reverse=True)
            return light[0][0], "teeth"
    if "hand" in low:
        for name, _sat, luma in layers:
            if name.lower() == "glove" and luma > 0.7:
                return name, "glove"
    for name, sat, _luma in layers:
        if name == "Attribute" and sat >= 0.08:
            return name, "paint"
    painted = [item for item in layers if item[1] >= 0.08]
    if painted:
        painted.sort(key=lambda item: item[1], reverse=True)
        return painted[0][0], "paint"
    if layers:
        name, _sat, luma = sorted(layers, key=lambda item: item[2])[0]
        return name, "ink" if luma < 0.2 else "paint"
    return "", "flat"


def _paint(obj, jax):
    mesh = obj.data
    layers = _layers(mesh)
    low = obj.name.lower()
    for slot in obj.material_slots:
        src = slot.material
        if src is None:
            continue
        mat = src.copy()
        slot.material = mat
        if mat.node_tree is None:
            mat.use_nodes = True
        chosen, kind = _choose(obj, jax, layers)
        image = None
        if kind == "flat" or (chosen and kind != "thomas"):
            gray = False
            if chosen:
                for name, sat, luma in layers:
                    if name == chosen:
                        gray = sat < 0.08 and 0.2 < luma < 0.85
                        break
            if kind == "flat" or gray:
                image = _color_image(mat)
                if image is not None:
                    chosen = ""
                    kind = "image"
        if jax and chosen:
            attr = mesh.color_attributes.get(chosen)
            if attr is not None:
                _purple(attr)
        if chosen:
            mesh.color_attributes.active_color = mesh.color_attributes[chosen]
        if "hand" in low and kind == "flat":
            _rebuild(mat, "", None, (0.95, 0.95, 0.95))
            print("USE", obj.name, "glove-white", "-", "-")
            continue
        _rebuild(mat, chosen, image, _fallback(obj.name))
        print("USE", obj.name, kind, chosen or "-", image.name if image else "-")


def _export(src, dst):
    bpy.ops.wm.open_mainfile(filepath=src)
    jax = "jax" in os.path.basename(src).lower()
    chosen = _select()
    for obj in chosen:
        if obj.type == "MESH":
            _paint(obj, jax)
    for obj in bpy.context.view_layer.objects:
        try:
            obj.select_set(obj in chosen)
        except RuntimeError:
            pass
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=dst,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="JPEG",
        export_jpeg_quality=74,
        export_vertex_color="MATERIAL",
    )
    print("WROTE", dst, os.path.getsize(dst))


def main():
    for filename, out_name in JOBS:
        src = os.path.join(ROOT, filename)
        dst = os.path.join(OUT, out_name)
        print("JOB", filename)
        _export(src, dst)


try:
    main()
except Exception:
    traceback.print_exc()
    sys.exit(1)
