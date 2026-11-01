import bpy
import os
import sys
import traceback


def _args():
    argv = sys.argv
    if "--" not in argv:
        raise SystemExit("missing -- src dst")
    tail = argv[argv.index("--") + 1 :]
    if len(tail) < 2:
        raise SystemExit("need src and dst")
    return tail[0], tail[1]


def _is_body(obj) -> bool:
    if obj.type != "MESH":
        return False
    name = obj.name
    if name.startswith("WGT") or name.startswith("WGTS") or "WGT-" in name:
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
    armatures = [obj for obj in bpy.context.view_layer.objects if obj.type == "ARMATURE" and "metarig" not in obj.name.lower()]
    for arm in armatures:
        arm.select_set(True)
        chosen.append(arm)
    for obj in bpy.context.view_layer.objects:
        if not _is_body(obj):
            continue
        uses_armature = False
        for mod in obj.modifiers:
            if mod.type == "ARMATURE":
                uses_armature = True
                break
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


def _albedo_image(mat):
    if not mat.use_nodes or mat.node_tree is None:
        return None
    best = None
    best_score = -1
    for node in mat.node_tree.nodes:
        if node.type != "TEX_IMAGE" or not getattr(node, "image", None):
            continue
        image = node.image
        if image.size[0] <= 0:
            continue
        low = image.name.lower()
        if any(word in low for word in ("normal", "rough", "metal", "height", "displace", "ao", "orm")):
            continue
        if not any(word in low for word in ("base", "albedo", "diffuse")):
            continue
        score = 3
        if score > best_score:
            best = image
            best_score = score
    return best


def _painted_layer(mat):
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.data is None:
            continue
        if not any(slot.material == mat for slot in obj.material_slots):
            continue
        attrs = obj.data.color_attributes
        if "Color" not in attrs or len(attrs["Color"].data) == 0:
            continue
        data = attrs["Color"].data
        step = max(1, len(data) // 48)
        total = [0.0, 0.0, 0.0]
        spread = 0.0
        first = None
        count = 0
        for index in range(0, len(data), step):
            color = data[index].color
            if first is None:
                first = color
            spread += abs(color[0] - first[0]) + abs(color[1] - first[1]) + abs(color[2] - first[2])
            total[0] += color[0]
            total[1] += color[1]
            total[2] += color[2]
            count += 1
        if count == 0:
            continue
        avg = [channel / count for channel in total]
        # Flat id colors are not the painted outfit. Real outfits vary across the mesh.
        if spread / count < 0.12:
            continue
        if max(avg) > 0.04 and min(avg) < 0.98:
            return "Color"
    return ""


def _shrink_image(image, limit):
    if image is None or image.size[0] <= limit or image.size[1] <= limit:
        return
    try:
        width = max(1, min(limit, image.size[0]))
        height = max(1, min(limit, image.size[1]))
        if image.size[0] >= image.size[1]:
            height = max(1, int(image.size[1] * (width / float(image.size[0]))))
        else:
            width = max(1, int(image.size[0] * (height / float(image.size[1]))))
        image.scale(width, height)
        print("SCALED", image.name, width, height)
    except Exception as exc:
        print("SCALE_SKIP", image.name, exc)


def _simplify_materials():
    for mat in list(bpy.data.materials):
        if not mat.use_nodes or mat.node_tree is None:
            continue
        image = _albedo_image(mat)
        layer = "" if image is not None else _painted_layer(mat)
        tree = mat.node_tree
        tree.nodes.clear()
        output = tree.nodes.new("ShaderNodeOutputMaterial")
        bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.48
        if image is not None:
            _shrink_image(image, 512)
            tex = tree.nodes.new("ShaderNodeTexImage")
            tex.image = image
            tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            kind = "image"
        elif layer:
            color_node = tree.nodes.new("ShaderNodeVertexColor")
            color_node.layer_name = layer
            tree.links.new(color_node.outputs["Color"], bsdf.inputs["Base Color"])
            kind = "vertex"
        else:
            low = mat.name.lower()
            if "bubble" in low and "eye" in low:
                color = (0.08, 0.08, 0.1, 1.0)
            elif "bubble" in low and "teeth" in low:
                color = (0.96, 0.96, 0.98, 1.0)
            elif "bubble" in low:
                color = (0.75, 0.93, 1.0, 1.0)
            else:
                color = (0.82, 0.78, 0.74, 1.0)
            bsdf.inputs["Base Color"].default_value = color
            kind = "flat"
        tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
        mat.use_backface_culling = False
        print("MAT_SIMPLE", mat.name, kind)


def _bounds():
    low = [1e9, 1e9, 1e9]
    high = [-1e9, -1e9, -1e9]
    count = 0
    for obj in bpy.context.selected_objects:
        if obj.type != "MESH":
            continue
        count += 1
        for corner in obj.bound_box:
            world = obj.matrix_world @ __import__("mathutils").Vector(corner)
            for i in range(3):
                low[i] = min(low[i], world[i])
                high[i] = max(high[i], world[i])
    if count == 0:
        return None
    size = [high[i] - low[i] for i in range(3)]
    return low, high, size, count


def main():
    src, dst = _args()
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=src)
    bodies = [obj.name for obj in bpy.data.objects if obj.type == "MESH" and not obj.name.startswith("WGT")]
    arms = [obj.name for obj in bpy.data.objects if obj.type == "ARMATURE"]
    print("OPENED", os.path.basename(src), "armatures", arms, "body_meshes", bodies)
    chosen = _select_characters()
    print("SELECTED", [obj.name for obj in chosen])
    meshes = [obj for obj in chosen if obj.type == "MESH"]
    for obj in list(bpy.context.view_layer.objects):
        obj.select_set(obj in chosen)
    if meshes:
        bpy.context.view_layer.objects.active = meshes[0]

    _simplify_materials()
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.data is None:
            continue
        attrs = obj.data.color_attributes
        if "Color" in attrs:
            attrs.active_color = attrs["Color"]
    info = _bounds()
    if info:
        low, high, size, count = info
        print("BBOX_MIN", ["%.3f" % v for v in low])
        print("BBOX_MAX", ["%.3f" % v for v in high])
        print("BBOX_SIZE", ["%.3f" % v for v in size], "meshes", count)
        print("HEIGHT", "%.3f" % size[2])
    else:
        print("BBOX_EMPTY")

    kwargs = dict(
        filepath=dst,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
    )
    try:
        bpy.ops.export_scene.gltf(
            **kwargs,
            export_image_format="JPEG",
            export_jpeg_quality=68,
            export_vertex_color="MATERIAL",
        )
    except TypeError:
        print("EXTRA_ARGS_UNAVAILABLE")
        bpy.ops.export_scene.gltf(**kwargs)
    print("WROTE", dst, os.path.getsize(dst))


try:
    main()
except Exception:
    traceback.print_exc()
    sys.exit(1)
