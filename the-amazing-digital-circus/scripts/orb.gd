extends Node3D

var tint := Color.WHITE
var collected := false
var _spin := Node3D.new()


func setup(color: Color) -> void:
	tint = color
	name = "WackyOrb"
	add_to_group("wacky_orb")
	_spin.name = "Spin"
	add_child(_spin)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	ball.mesh = sphere
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.2
	mat.roughness = 0.25
	ball.material_override = mat
	_spin.add_child(ball)
	preload("res://scripts/circus_shade.gd").apply_to_tree(ball)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.16
	cyl.height = 14.0
	beam.mesh = cyl
	beam.position.y = 7.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.22)
	beam_mat.emission_enabled = true
	beam_mat.emission = color
	beam_mat.emission_energy_multiplier = 1.4
	beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	beam.material_override = beam_mat
	add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.4
	light.omni_range = 8.0
	light.shadow_enabled = false
	add_child(light)


func _process(delta: float) -> void:
	if collected:
		return
	_spin.rotate_y(delta * 1.6)
	var pulse := 0.9 + sin(Time.get_ticks_msec() / 170.0) * 0.1
	_spin.scale = Vector3.ONE * pulse


func collect() -> void:
	if collected:
		return
	collected = true
	remove_from_group("wacky_orb")
	Game.collect()
	Music.blip_collect()
	queue_free()
