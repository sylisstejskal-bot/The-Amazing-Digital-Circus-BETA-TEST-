extends RefCounted

const OPAQUE := preload("res://shaders/circus_toon.gdshader")
const BLEND := preload("res://shaders/circus_toon_blend.gdshader")


static func apply_to_tree(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			_apply_mesh(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)


static func _apply_mesh(mesh_node: MeshInstance3D) -> void:
	if mesh_node.mesh == null:
		return
	if mesh_node.material_override is BaseMaterial3D:
		mesh_node.material_override = _from(mesh_node.material_override, mesh_node.name)
		return
	for surface in mesh_node.mesh.get_surface_count():
		var source := mesh_node.get_surface_override_material(surface)
		if source == null:
			source = mesh_node.mesh.surface_get_material(surface)
		if source is ShaderMaterial:
			continue
		mesh_node.set_surface_override_material(surface, _from(source, mesh_node.name))


static func _from(source: Material, mesh_name: String) -> ShaderMaterial:
	var albedo := Color.WHITE
	var tex: Texture2D = null
	var glow := 0.0
	var blend := false
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		albedo = base.albedo_color
		tex = base.albedo_texture
		blend = base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		if base.emission_enabled:
			glow = maxf(base.emission_energy_multiplier * 0.35, 0.2)
			if base.emission.r + base.emission.g + base.emission.b > 0.15:
				albedo = base.emission
	# The baked head map breaks into blotches. The eyes, lashes, and
	# pupils are their own meshes, so the head itself stays a clean skin color.
	var flat_skin := "pomni_head" in mesh_name.to_lower()
	if flat_skin:
		albedo = Color(0.97, 0.95, 0.93)
		tex = null
	var mat := ShaderMaterial.new()
	mat.shader = BLEND if blend else OPAQUE
	mat.set_shader_parameter("albedo_color", albedo)
	if tex != null:
		mat.set_shader_parameter("albedo_texture", tex)
	mat.set_shader_parameter("glow", glow)
	if flat_skin:
		mat.set_shader_parameter("vertex_color_amount", 0.0)
	return mat
