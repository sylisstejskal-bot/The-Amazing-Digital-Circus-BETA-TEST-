import bpy

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\Sylis\Desktop\player models\jax_UPDATE6_RELEASE.blend")
obj = bpy.data.objects["jax_head"]
mat = obj.material_slots[0].material
print("ACTIVE OUTPUTS")
for node in mat.node_tree.nodes:
    if node.type == "OUTPUT_MATERIAL":
        print(" ", node.name, "active", node.is_active_output, "linked", node.inputs["Surface"].is_linked)

bsdf = None
for node in mat.node_tree.nodes:
    if node.type == "BSDF_PRINCIPLED" and node.inputs["Base Color"].is_linked:
        bsdf = node
        break
print("BSDF", bsdf.name if bsdf else None)
out = mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
mat.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
for node in mat.node_tree.nodes:
    if node.type == "OUTPUT_MATERIAL":
        node.is_active_output = node == out

for item in bpy.context.view_layer.objects:
    try:
        item.select_set(item == obj)
    except RuntimeError:
        pass
bpy.context.view_layer.objects.active = obj
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 1
scene.cycles.device = "CPU"
image = bpy.data.images.new("jax_head_direct", 256, 256, alpha=False)
node = mat.node_tree.nodes.new("ShaderNodeTexImage")
node.image = image
node.select = True
mat.node_tree.nodes.active = node
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
path = r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\tools\jax_head_direct.png"
image.filepath_raw = path
image.file_format = "PNG"
image.save()
print("SAVED", path)
