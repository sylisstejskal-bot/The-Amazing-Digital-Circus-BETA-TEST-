"""Export characters with baked face paint and their real color maps.

Face details live in shader graphs, not in a single color layer. Baking the
surface color keeps the eyes, mouth, and texture maps in the game.
"""
import bpy
import os
import sys
import traceback

COMPLEX = {"TEX_NOISE", "VALTORGB", "TEX_VORONOI", "TEX_GRADIENT", "HUE_SAT", "CURVE_RGB", "TEX_IMAGE"}


def _args():
    tail = sys.argv[sys.argv.index("--") + 1 :]
    if len(tail) < 2:
        raise SystemExit("need src and dst")
    return tail[0], tail[1]


def _is_body(obj) -> bool:
    if obj.type != "MESH":
        return False
    name = obj.name
    if name.startswith("WGT") or "WGT-" in name:
        return False
    if obj.hide_render or obj.hide_get():
        return False
    return True


def _select_characters():
    for obj in bpy.context.view_layer.objects:
        try:
            obj.select_set(False)
        except RuntimeError:
            pass
    chosen = []
    armatures = [
        obj
        for obj in bpy.context.view_layer.objects
        if obj.type == "ARMATURE" and "metarig" not in obj.name.lower()
    ]
    for arm in armatures:
        arm.select_set(True)
        chosen.append(arm)
    for obj in bpy.context.view_layer.objects:
        if not _is_body(obj):
            continue
        uses_armature = any(mod.type == "ARMATURE" for mod in obj.modifiers)
        if uses_armature or obj.parent in armatures or not armatures:
            obj.select_set(True)
            chosen.append(obj)
    if not chosen:
        for obj in bpy.context.view_layer.objects:
            if _is_body(obj):
                obj.select_set(True)
                chosen.append(obj)
    if chosen:
        bpy.context.view_layer.objects.active = chosen[0]
    return chosen


def _only(obj):
    for item in bpy.context.view_layer.objects:
        try:
            item.select_set(item == obj)
        except RuntimeError:
            pass
    bpy.context.view_layer.objects.active = obj


def _is_complex(mat) -> bool:
    if mat is None or not mat.use_nodes or mat.node_tree is None:
        return False
    return any(node.type in COMPLEX for node in mat.node_tree.nodes)


def _use_image(mat, image):
    tree = mat.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tex = tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    bsdf.inputs["Roughness"].default_value = 0.55
    tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    mat.use_backface_culling = False


def _use_vertex(mat, layer_name):
    tree = mat.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    color = tree.nodes.new("ShaderNodeVertexColor")
    color.layer_name = layer_name
    bsdf.inputs["Roughness"].default_value = 0.55
    tree.links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    mat.use_backface_culling = False


def _flat(mat, color):
    if mat.node_tree is None:
        mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.55
    tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])


def _bake(obj):
    if not obj.data.uv_layers:
        return
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.device = "CPU"
    scene.render.bake.margin = 6
    _only(obj)
    for slot in obj.material_slots:
        mat = slot.material
        if not _is_complex(mat):
            continue
        mat = mat.copy()
        slot.material = mat
        image = bpy.data.images.new(f"{obj.name}_{mat.name}_bake", 512, 512, alpha=False)
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        for other in mat.node_tree.nodes:
            other.select = False
        node.select = True
        mat.node_tree.nodes.active = node
        try:
            bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
        except RuntimeError as exc:
            print("BAKE_FAIL", obj.name, mat.name, exc)
            continue
        _use_image(mat, image)
        print("BAKED", obj.name, mat.name)


def _simple_colors(obj):
    low = obj.name.lower()
    feature = any(word in low for word in ("brow", "lash", "pupil"))
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None or _is_complex(mat):
            continue
        attrs = obj.data.color_attributes
        layer = "Color" if "Color" in attrs else ""
        if feature and layer:
            data = attrs[layer].data
            if len(data) == 0:
                continue
            pixel = data[0].color
            if pixel[0] > 0.8 and pixel[1] > 0.8 and pixel[2] > 0.8:
                _flat(mat, (0.02, 0.02, 0.03, 1.0))
                print("INK", obj.name)
                continue
        if layer:
            _use_vertex(mat, layer)
        elif feature:
            _flat(mat, (0.02, 0.02, 0.03, 1.0))
            print("INK", obj.name)


def main():
    src, dst = _args()
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=src)
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        for node in list(mat.node_tree.nodes):
            image = getattr(node, "image", None)
            if node.type == "TEX_IMAGE" and image is not None:
                low = image.name.lower()
                if any(word in low for word in ("normal", "rough", "metal", "height", "displace", "ao", "orm")):
                    mat.node_tree.nodes.remove(node)
    for image in list(bpy.data.images):
        if image.users == 0:
            bpy.data.images.remove(image)
    chosen = _select_characters()
    print("SELECTED", [obj.name for obj in chosen])
    for obj in chosen:
        if obj.type != "MESH":
            continue
        _bake(obj)
        _simple_colors(obj)
    for obj in bpy.context.view_layer.objects:
        try:
            obj.select_set(obj in chosen)
        except RuntimeError:
            pass
    if chosen:
        bpy.context.view_layer.objects.active = chosen[0]
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
