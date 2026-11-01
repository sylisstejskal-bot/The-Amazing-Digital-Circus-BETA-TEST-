extends RefCounted

const ModelScript = preload("res://scripts/character_model.gd")
const Factory = preload("res://scripts/cast_factory.gd")
const Shade = preload("res://scripts/circus_shade.gd")


static func build(id: String, target_height: float) -> Node3D:
	var path := "res://characters/%s.glb" % id
	if id == "abstracted":
		path = "res://characters/abstracted.fbx"
	var node: Node3D = null
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed:
			var inst := packed.instantiate()
			if inst is Node3D:
				node = inst
	if node == null:
		if id == "abstracted":
			print("ABSTRACTED MODEL MISSING")
		node = Factory.build(id)
	if id == "abstracted":
		node.set_meta("no_pose", true)
	Shade.apply_to_tree(node)
	if id == "abstracted":
		_blacken_skin(node)
	_bring_faces_forward(node)
	node.name = "Visual"
	node.set_script(ModelScript)
	return node


static func _blacken_skin(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var low := mesh_node.name.to_lower()
		if "eye" not in low and "pupil" not in low:
			_paint_black(mesh_node)
	for child in node.get_children():
		_blacken_skin(child)


static func _paint_black(mesh_node: MeshInstance3D) -> void:
	if mesh_node.mesh == null:
		return
	for surface in mesh_node.mesh.get_surface_count():
		var mat := mesh_node.get_surface_override_material(surface)
		if mat is ShaderMaterial:
			var shader_mat := mat as ShaderMaterial
			shader_mat.set_shader_parameter("albedo_color", Color(0, 0, 0, 1))
			shader_mat.set_shader_parameter("vertex_color_amount", 0.0)


static func _bring_faces_forward(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_name := node.name.to_lower()
		if mesh_name.begins_with("gangle_eye") or mesh_name == "gangle_face":
			node.position.z += 0.035
		if mesh_name == "pomni_eyelashes":
			node.visible = false
		if mesh_name in ["ragatha_pupil", "ragatha_eye", "ragatha_eyering", "ragatha_button", "ragatha_nose", "ragatha_mouth", "ragatha_eyelash.001"]:
			node.position.z += 0.05
		if mesh_name == "fish_eyes":
			node.position.z += 0.06
		if mesh_name == "fish_eyelidtop" or mesh_name == "fish_eyelidsbot":
			node.position.z -= 0.03
	for child in node.get_children():
		_bring_faces_forward(child)


static func fit(node: Node3D, target_height: float) -> void:
	if target_height <= 0.0:
		return
	# Blender front view faces +Y, which lands facing the camera in Godot.
	node.rotation.y = PI
	var box := _bounds(node)
	if box.size.y <= 0.001:
		return
	var factor := target_height / box.size.y
	node.scale = Vector3.ONE * factor
	box = _bounds(node)
	node.position.y -= box.position.y
	if node.has_method("prepare"):
		node.prepare()


static func _bounds(root: Node3D) -> AABB:
	var merged := AABB()
	var started := false
	var meshes: Array[MeshInstance3D] = []
	_collect(root, meshes)
	for mesh_node in meshes:
		if mesh_node.mesh == null:
			continue
		var local := mesh_node.mesh.get_aabb()
		var to_root := root.global_transform.affine_inverse() * mesh_node.global_transform
		for i in 8:
			var point: Vector3 = to_root * _corner(local, i)
			if not started:
				merged = AABB(point, Vector3.ZERO)
				started = true
			else:
				merged = merged.expand(point)
	return merged


static func _collect(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect(child, into)


static func _corner(box: AABB, index: int) -> Vector3:
	var p := box.position
	var s := box.size
	return Vector3(
		p.x + s.x * float((index & 1) != 0),
		p.y + s.y * float((index & 2) != 0),
		p.z + s.z * float((index & 4) != 0)
	)
