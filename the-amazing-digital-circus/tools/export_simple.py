"""Export the Color paint and base-color images without baking shaders.

Baking turned some heads solid black because their paint is the Color
layer, not the principled base color.
"""
import bpy
import os
import sys
import traceback


def _args():
    tail = sys.argv[sys.argv.index("--") + 1 :]
    return tail[0], tail[1]


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
    arms = [obj for obj in bpy.context.view_layer.objects if obj.type == "ARMATURE" and "metarig" not in obj.name.lower()]
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


def _image(mat):
    best = None
    best_score = -1
    for node in mat.node_tree.nodes:
        if node.type != "TEX_IMAGE" or not getattr(node, "image", None):
            continue
        image = node.image
        low = image.name.lower()
        if any(word in low for word in ("normal", "rough", "metal", "height", "displace")):
            continue
        score = 5 if any(word in low for word in ("basecolor", "base_color", "albedo", "diffuse")) else 1
        if score > best_score and image.size[0] > 0:
            best = image
            best_score = score
    return best


def _prepare():
    for mat in list(bpy.data.materials):
        if not mat.use_nodes or mat.node_tree is None:
            continue
        image = _image(mat)
        layers = [node.layer_name for node in mat.node_tree.nodes if node.type == "VERTEX_COLOR"]
        layer = "Color" if "Color" in layers else ""
        tree = mat.node_tree
        tree.nodes.clear()
        output = tree.nodes.new("ShaderNodeOutputMaterial")
        bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Roughness"].default_value = 0.55
        if image is not None and layer:
            tex = tree.nodes.new("ShaderNodeTexImage")
            tex.image = image
            color = tree.nodes.new("ShaderNodeVertexColor")
            color.layer_name = layer
            mix = tree.nodes.new("ShaderNodeMixRGB")
            mix.blend_type = "MULTIPLY"
            mix.inputs["Fac"].default_value = 1.0
            tree.links.new(tex.outputs["Color"], mix.inputs["Color1"])
            tree.links.new(color.outputs["Color"], mix.inputs["Color2"])
            tree.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
            kind = "image*color"
        elif image is not None:
            tex = tree.nodes.new("ShaderNodeTexImage")
            tex.image = image
            tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            kind = "image"
        elif layer:
            color = tree.nodes.new("ShaderNodeVertexColor")
            color.layer_name = layer
            tree.links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
            kind = "color"
        else:
            bsdf.inputs["Base Color"].default_value = (0.82, 0.78, 0.74, 1.0)
            kind = "flat"
        tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
        mat.use_backface_culling = False
        print("MAT", mat.name, kind)


def main():
    src, dst = _args()
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=src)
    chosen = _select()
    for obj in bpy.context.view_layer.objects:
        try:
            obj.select_set(obj in chosen)
        except RuntimeError:
            pass
    _prepare()
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


try:
    main()
except Exception:
    traceback.print_exc()
    sys.exit(1)
