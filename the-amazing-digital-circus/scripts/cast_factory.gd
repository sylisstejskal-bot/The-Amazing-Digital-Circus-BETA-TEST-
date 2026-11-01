extends RefCounted

const RED := Color("#e23d3d")
const BLUE := Color("#3340c9")
const YELLOW := Color("#ffd23a")
const PURPLE := Color("#a44dff")
const PURPLE_DARK := Color("#6d2ec4")
const SKIN := Color("#fff4ea")
const BLACK := Color("#1c1c1c")
const WHITE := Color("#fffdf8")
const TEETH := Color("#fffaf2")
const MOUTH := Color("#7a1530")
const RAG_DRESS := Color("#3f9fe6")
const RAG_HAIR := Color("#d4334a")
const KING := Color("#6b3bb8")
const GOLD := Color("#f0c14a")


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	match id:
		"pomni":
			_pomni(root)
		"caine":
			_caine(root)
		"jax":
			_jax(root)
		"ragatha":
			_ragatha(root)
		"gangle":
			_gangle(root)
		"zooble":
			_zooble(root)
		"kinger":
			_kinger(root)
		"bubble":
			_bubble(root)
		"exit":
			_exit(root)
		"crate":
			_crate(root)
		"abstracted":
			_abstracted(root)
		_:
			_mesh(root, "sphere", Vector3(0, 0.4, 0), Vector3(0.3, 0.3, 0.3), YELLOW)
	return root


static func _pomni(n: Node3D) -> void:
	_mesh(n, "capsule", Vector3(-0.1, 0.42, 0), Vector3(0.09, 0.62, 0), RED)
	_mesh(n, "capsule", Vector3(0.1, 0.42, 0), Vector3(0.09, 0.62, 0), BLUE)
	_mesh(n, "box", Vector3(-0.11, 0.92, 0), Vector3(0.22, 0.38, 0.26), RED)
	_mesh(n, "box", Vector3(0.11, 0.92, 0), Vector3(0.22, 0.38, 0.26), BLUE)
	_mesh(n, "cyl", Vector3(0, 1.16, 0), Vector3(0.2, 0.08, 0.2), WHITE)
	_mesh(n, "sphere", Vector3(0, 1.4, 0), Vector3(0.2, 0, 0), SKIN)
	_eye(n, Vector3(-0.07, 1.46, -0.14), RED)
	_eye(n, Vector3(0.07, 1.46, -0.14), BLUE)
	_mesh(n, "box", Vector3(0, 1.32, -0.16), Vector3(0.08, 0.025, 0.02), BLACK)
	var hat_l := _mesh(n, "cone", Vector3(-0.12, 1.78, 0), Vector3(0.13, 0.42, 0), RED)
	hat_l.rotation.z = 0.7
	hat_l.rotation.x = 0.2
	var hat_r := _mesh(n, "cone", Vector3(0.12, 1.78, 0), Vector3(0.13, 0.42, 0), BLUE)
	hat_r.rotation.z = -0.7
	hat_r.rotation.x = 0.2
	_mesh(n, "sphere", Vector3(-0.28, 1.92, 0.05), Vector3(0.07, 0, 0), YELLOW)
	_mesh(n, "sphere", Vector3(0.28, 1.92, 0.05), Vector3(0.07, 0, 0), YELLOW)
	_mesh(n, "capsule", Vector3(-0.28, 0.95, 0), Vector3(0.06, 0.36, 0), RED)
	_mesh(n, "capsule", Vector3(0.28, 0.95, 0), Vector3(0.06, 0.36, 0), BLUE)


static func _caine(n: Node3D) -> void:
	_mesh(n, "capsule", Vector3(-0.12, 0.55, 0), Vector3(0.09, 0.9, 0), BLACK)
	_mesh(n, "capsule", Vector3(0.12, 0.55, 0), Vector3(0.09, 0.9, 0), BLACK)
	_mesh(n, "box", Vector3(0, 1.25, 0), Vector3(0.62, 0.7, 0.34), RED)
	_mesh(n, "box", Vector3(0, 1.28, -0.12), Vector3(0.28, 0.36, 0.08), WHITE)
	_mesh(n, "box", Vector3(0, 1.42, -0.16), Vector3(0.16, 0.1, 0.06), BLACK)
	_mesh(n, "box", Vector3(0, 1.95, 0), Vector3(0.78, 0.42, 0.4), TEETH)
	_mesh(n, "box", Vector3(0, 1.9, -0.16), Vector3(0.58, 0.16, 0.08), MOUTH)
	_eye(n, Vector3(-0.16, 2.05, -0.18), Color("#2f6bff"))
	_eye(n, Vector3(0.16, 2.05, -0.18), Color("#3dcf6a"))
	_mesh(n, "cyl", Vector3(0, 2.28, 0), Vector3(0.34, 0.06, 0.34), BLACK)
	_mesh(n, "cyl", Vector3(0, 2.52, 0), Vector3(0.2, 0.42, 0.2), BLACK)
	_mesh(n, "cyl", Vector3(0, 2.36, 0), Vector3(0.205, 0.08, 0.205), RED)
	var cane := _mesh(n, "cyl", Vector3(0.48, 1.05, -0.05), Vector3(0.035, 1.5, 0.035), BLACK)
	cane.rotation.z = 0.25
	_mesh(n, "sphere", Vector3(0.66, 1.78, -0.05), Vector3(0.07, 0, 0), GOLD)
	_mesh(n, "sphere", Vector3(-0.42, 1.15, 0), Vector3(0.09, 0, 0), WHITE)
	_mesh(n, "sphere", Vector3(0.42, 1.15, 0), Vector3(0.09, 0, 0), WHITE)


static func _jax(n: Node3D) -> void:
	_mesh(n, "capsule", Vector3(0, 0.95, 0), Vector3(0.28, 1.35, 0), PURPLE)
	_mesh(n, "sphere", Vector3(0, 0.85, -0.12), Vector3(0.18, 0, 0), Color("#d7a6ff"))
	_mesh(n, "sphere", Vector3(0, 1.72, 0), Vector3(0.3, 0, 0), PURPLE)
	var ear_l := _mesh(n, "box", Vector3(-0.14, 2.25, 0), Vector3(0.1, 0.7, 0.05), PURPLE_DARK)
	ear_l.rotation.z = 0.15
	var ear_r := _mesh(n, "box", Vector3(0.14, 2.25, 0), Vector3(0.1, 0.7, 0.05), PURPLE_DARK)
	ear_r.rotation.z = -0.15
	_mesh(n, "box", Vector3(-0.14, 2.22, -0.02), Vector3(0.05, 0.5, 0.02), Color("#ff8ad4"))
	_mesh(n, "box", Vector3(0.14, 2.22, -0.02), Vector3(0.05, 0.5, 0.02), Color("#ff8ad4"))
	_eye(n, Vector3(-0.1, 1.78, -0.22), YELLOW)
	_eye(n, Vector3(0.1, 1.78, -0.22), YELLOW)
	_mesh(n, "box", Vector3(0, 1.58, -0.24), Vector3(0.22, 0.06, 0.04), BLACK)
	_mesh(n, "capsule", Vector3(-0.38, 1.05, 0), Vector3(0.07, 0.7, 0), PURPLE)
	_mesh(n, "capsule", Vector3(0.38, 1.05, 0), Vector3(0.07, 0.7, 0), PURPLE)


static func _ragatha(n: Node3D) -> void:
	_mesh(n, "cone", Vector3(0, 0.55, 0), Vector3(0.46, 0.95, 0), RAG_DRESS)
	_mesh(n, "box", Vector3(0.22, 0.4, -0.28), Vector3(0.16, 0.16, 0.02), Color("#f28a3a"))
	_mesh(n, "box", Vector3(0, 1.15, 0), Vector3(0.36, 0.32, 0.24), RAG_DRESS)
	_mesh(n, "sphere", Vector3(0, 1.5, 0), Vector3(0.2, 0, 0), SKIN)
	_mesh(n, "sphere", Vector3(0, 1.68, 0.02), Vector3(0.22, 0, 0), RAG_HAIR)
	_mesh(n, "sphere", Vector3(-0.12, 1.6, -0.08), Vector3(0.12, 0, 0), RAG_HAIR)
	_mesh(n, "sphere", Vector3(0.14, 1.58, -0.06), Vector3(0.13, 0, 0), RAG_HAIR)
	_mesh(n, "cyl", Vector3(-0.07, 1.52, -0.16), Vector3(0.06, 0.03, 0.06), BLUE)
	_eye(n, Vector3(0.08, 1.52, -0.15), Color("#3a2a22"))
	_mesh(n, "box", Vector3(0, 1.4, -0.17), Vector3(0.1, 0.02, 0.02), RAG_HAIR)
	_mesh(n, "sphere", Vector3(0, 1.78, -0.02), Vector3(0.08, 0, 0), BLUE)


static func _gangle(n: Node3D) -> void:
	for i in 7:
		var y := 0.15 + float(i) * 0.18
		var x := sin(float(i) * 0.7) * 0.12
		var piece := _mesh(n, "box", Vector3(x, y, 0), Vector3(0.14, 0.16, 0.05), RED)
		piece.rotation.z = sin(float(i)) * 0.3
	_mesh(n, "box", Vector3(-0.28, 1.15, 0), Vector3(0.28, 0.06, 0.04), RED)
	_mesh(n, "box", Vector3(0.28, 1.15, 0), Vector3(0.28, 0.06, 0.04), RED)
	var mask := _mesh(n, "sphere", Vector3(0, 1.55, 0), Vector3(0.26, 0, 0), WHITE)
	mask.scale = Vector3(1.15, 1.0, 0.45)
	_mesh(n, "sphere", Vector3(-0.07, 1.6, -0.1), Vector3(0.045, 0, 0), BLACK)
	_mesh(n, "sphere", Vector3(0.07, 1.6, -0.1), Vector3(0.045, 0, 0), BLACK)
	var smile := _mesh(n, "box", Vector3(0, 1.46, -0.11), Vector3(0.14, 0.035, 0.02), RED)
	smile.rotation.z = 0.0


static func _zooble(n: Node3D) -> void:
	_mesh(n, "box", Vector3(0, 0.35, 0), Vector3(0.46, 0.4, 0.4), Color("#ff4f9a"))
	_mesh(n, "cyl", Vector3(0.05, 0.85, 0), Vector3(0.22, 0.5, 0.16), YELLOW)
	_mesh(n, "box", Vector3(-0.28, 0.95, 0), Vector3(0.16, 0.42, 0.16), Color("#7dff4a"))
	_mesh(n, "sphere", Vector3(0.32, 1.15, 0), Vector3(0.16, 0, 0), Color("#4ad2ff"))
	_mesh(n, "cone", Vector3(0, 1.4, 0), Vector3(0.2, 0.4, 0), Color("#ff7a3c"))
	_eye(n, Vector3(0.02, 1.15, -0.18), WHITE)
	_mesh(n, "cyl", Vector3(0.2, 1.7, 0), Vector3(0.04, 0.35, 0.04), BLACK)
	_mesh(n, "sphere", Vector3(0.2, 1.92, 0), Vector3(0.08, 0, 0), YELLOW)


static func _kinger(n: Node3D) -> void:
	_mesh(n, "cone", Vector3(0, 0.7, 0), Vector3(0.55, 1.25, 0), KING)
	_mesh(n, "box", Vector3(0, 1.55, 0), Vector3(0.46, 0.5, 0.4), WHITE)
	_mesh(n, "box", Vector3(0, 1.95, 0), Vector3(0.5, 0.12, 0.42), GOLD)
	_mesh(n, "box", Vector3(-0.16, 2.12, 0), Vector3(0.08, 0.22, 0.08), GOLD)
	_mesh(n, "box", Vector3(0, 2.16, 0), Vector3(0.08, 0.28, 0.08), GOLD)
	_mesh(n, "box", Vector3(0.16, 2.12, 0), Vector3(0.08, 0.22, 0.08), GOLD)
	_eye(n, Vector3(-0.1, 1.62, -0.2), BLACK)
	_eye(n, Vector3(0.1, 1.62, -0.2), BLACK)
	_mesh(n, "sphere", Vector3(0, 1.38, -0.16), Vector3(0.1, 0, 0), WHITE)
	_mesh(n, "sphere", Vector3(-0.46, 0.85, 0), Vector3(0.14, 0, 0), WHITE)
	_mesh(n, "sphere", Vector3(0.46, 0.85, 0), Vector3(0.14, 0, 0), WHITE)


static func _bubble(n: Node3D) -> void:
	var body := _mesh(n, "sphere", Vector3.ZERO, Vector3(0.28, 0, 0), Color("#f4fbff"))
	var mat := body.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.9, 1.0)
	mat.emission_energy_multiplier = 0.4
	_eye(n, Vector3(-0.08, 0.06, -0.22), BLACK)
	_eye(n, Vector3(0.08, 0.06, -0.22), BLACK)
	_mesh(n, "box", Vector3(0, -0.08, -0.24), Vector3(0.1, 0.03, 0.02), Color("#ff7aa2"))


static func _exit(n: Node3D) -> void:
	_mesh(n, "box", Vector3(0, 1.25, 0), Vector3(1.5, 2.5, 0.18), RED)
	_mesh(n, "box", Vector3(0, 1.25, -0.08), Vector3(0.85, 1.7, 0.08), Color("#2a120c"))
	_mesh(n, "box", Vector3(0, 2.35, 0.02), Vector3(0.7, 0.22, 0.2), YELLOW)
	_mesh(n, "sphere", Vector3(0.22, 1.2, -0.16), Vector3(0.06, 0, 0), GOLD)


static func _abstracted(n: Node3D) -> void:
	_mesh(n, "sphere", Vector3(0, 1.15, 0), Vector3(0.7, 0.15, 0.7), Color(0.08, 0.02, 0.04))
	_mesh(n, "sphere", Vector3(0, 0.7, 0), Vector3(0.55, 0.2, 0.5), Color(0.02, 0.02, 0.03))
	_mesh(n, "box", Vector3(-0.28, 1.35, -0.2), Vector3(0.16, 0.1, 0.08), Color(0.85, 0.1, 0.15))
	_mesh(n, "box", Vector3(0.22, 1.28, -0.16), Vector3(0.1, 0.18, 0.08), Color(0.9, 0.85, 0.7))
	_mesh(n, "capsule", Vector3(-0.35, 0.45, 0.1), Vector3(0.08, 0.5, 0.08), Color(0.05, 0.02, 0.04))
	_mesh(n, "capsule", Vector3(0.32, 0.4, -0.05), Vector3(0.08, 0.55, 0.08), Color(0.05, 0.02, 0.04))
	var spike := _mesh(n, "cone", Vector3(0.1, 1.7, 0.05), Vector3(0.08, 0.45, 0.08), Color(0.12, 0.02, 0.05))
	spike.rotation.z = 0.4


static func _crate(n: Node3D) -> void:
	_mesh(n, "box", Vector3(0, 0.45, 0), Vector3(0.9, 0.7, 0.7), GOLD)
	_mesh(n, "box", Vector3(0, 0.86, -0.05), Vector3(0.55, 0.1, 0.08), RED)
	_mesh(n, "box", Vector3(0, 0.45, -0.36), Vector3(0.4, 0.12, 0.02), RED)


static func _eye(n: Node3D, pos: Vector3, color: Color) -> void:
	var eye := _mesh(n, "sphere", pos, Vector3(0.055, 0, 0), color)
	var mat := eye.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.55
	_mesh(n, "sphere", pos + Vector3(0, 0, -0.03), Vector3(0.025, 0, 0), BLACK)


static func _mesh(n: Node3D, kind: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	match kind:
		"box":
			var box := BoxMesh.new()
			box.size = size
			mesh = box
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = size.x
			sphere.height = size.x * 2.0
			sphere.radial_segments = 16
			sphere.rings = 8
			mesh = sphere
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = size.x
			capsule.height = size.y
			mesh = capsule
		"cyl":
			var cyl := CylinderMesh.new()
			cyl.top_radius = size.x
			cyl.bottom_radius = size.z if size.z > 0.0 else size.x
			cyl.height = size.y
			mesh = cyl
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.01
			cone.bottom_radius = size.x
			cone.height = size.y
			mesh = cone
		_:
			mesh = BoxMesh.new()
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = mat
	n.add_child(mi)
	return mi
