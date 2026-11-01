extends Node3D

const NpcScript = preload("res://scripts/npc.gd")
const PlayerScript = preload("res://scripts/player.gd")
const Shade = preload("res://scripts/circus_shade.gd")

const LOUNGE := Vector3(77.9, 0.0, 4.2)

var _player: CharacterBody3D
var _caine: Node3D
var _spawn := Vector3(LOUNGE.x, 0.6, LOUNGE.z + 6.0)
var _chatter_wait := 4.5
var _chatter_step := 0
var _chatter_pair: Array = []
var _chatter_last := ""


func _ready() -> void:
	Game.reset()
	Music.celebrate = false
	if not LocalAI.overheard.is_connected(_on_overheard):
		LocalAI.overheard.connect(_on_overheard)
	if not Game.adventure_completed.is_connected(_burst_confetti):
		Game.adventure_completed.connect(_burst_confetti)
	TentUI.show_gameplay(false)
	TentUI.show_loading("Opening the tent...")
	await get_tree().process_frame
	_build_environment()
	var packed := load("res://Circus Lobby V10.glb") as PackedScene
	if packed == null:
		TentUI.set_loading(1.0, "The tent model did not load.")
		return
	var lobby := packed.instantiate()
	lobby.name = "CircusTent"
	add_child(lobby)
	Shade.apply_to_tree(lobby)
	TentUI.set_loading(0.2, "Raising the tent poles...")
	await _build_collision(lobby)
	_spawn = _plant_cast()
	_place_exit()
	_mark_suggestion(lobby)
	_player = _make_player(_spawn)
	add_child(_player)
	_player.remember_spawn(_spawn)
	print("PLAYER_AT ", _player.global_position)
	TentUI.hide_loading()
	TentUI.show_gameplay(true)
	print("TENT_READY spawn=", _spawn)
	var show := preload("res://scripts/adventure_world.gd").new()
	show.name = "AdventureShow"
	add_child(show)
	show.open_show(_spawn)
	var cellar := preload("res://scripts/cellar.gd").new()
	cellar.name = "Cellar"
	add_child(cellar)
	cellar.build(self)
	if _wants_shot():
		await _capture_shot()
		return
	await get_tree().create_timer(1.15).timeout
	if _caine and is_instance_valid(_caine):
		_caine.talk()


func _process(delta: float) -> void:
	if not TentUI.gameplay_on or TentUI.paused or _chatter_step != 0:
		return
	_chatter_wait -= delta
	if _chatter_wait > 0.0:
		return
	if LocalAI.is_busy():
		_chatter_wait = 1.2
		return
	_begin_chatter()


func _begin_chatter() -> void:
	var pair := _pick_chatter_pair()
	if pair.is_empty():
		_chatter_wait = 5.0
		return
	_chatter_pair = pair
	_chatter_step = 1
	var speaker: Node3D = pair[0]
	var listener: Node3D = pair[1]
	_chatter_last = "%s|%s" % [speaker.get("char_name"), listener.get("char_name")]
	LocalAI.ask_ambient(str(speaker.get("char_name")), "%s is beside you. Greet them as yourself." % str(listener.get("char_name")))


func _on_overheard(character: String, text: String) -> void:
	var speaker := _npc_named(character)
	var partner: Node3D = null
	if _chatter_pair.size() == 2:
		var first: Node3D = _chatter_pair[0]
		var second: Node3D = _chatter_pair[1]
		if character == str(first.get("char_name")):
			partner = second
		elif character == str(second.get("char_name")):
			partner = first
	if speaker != null and speaker.has_method("show_line"):
		speaker.show_line(text, partner)
	if _chatter_step == 1 and _chatter_pair.size() == 2 and character == str(_chatter_pair[0].get("char_name")):
		_chatter_step = 2
		var heard: Node3D = _chatter_pair[1]
		LocalAI.ask_ambient(str(heard.get("char_name")), "%s just told you: \"%s\" Answer them as yourself." % [character, text])
		return
	if _chatter_step == 2 and _chatter_pair.size() == 2 and character == str(_chatter_pair[1].get("char_name")):
		_chatter_step = 0
		_chatter_pair = []
		_chatter_wait = randf_range(14.0, 22.0)


func _pick_chatter_pair() -> Array:
	var people: Array[Node3D] = []
	var busy := TentUI.speaker_name if TentUI.dialogue_open else ""
	for node in get_tree().get_nodes_in_group("circus_npc"):
		var npc := node as Node3D
		if npc == null:
			continue
		var who := str(npc.get("char_name"))
		if who == "" or who == "Exit" or who == "Pomni" or who == busy:
			continue
		if bool(npc.get_meta("lost_one", false)) or Abstraction.is_gone(who):
			continue
		if bool(npc.get_meta("adventure_guest", false)):
			var shows := get_tree().get_nodes_in_group("adventure_world")
			if shows.is_empty() or not bool(shows[0].call("hosting")):
				continue
		people.append(npc)
	var choices: Array = []
	for i in people.size():
		for j in range(i + 1, people.size()):
			var dist := people[i].global_position.distance_to(people[j].global_position)
			if dist < 0.45 or dist > 7.0:
				continue
			var key := "%s|%s" % [people[i].get("char_name"), people[j].get("char_name")]
			var swapped := "%s|%s" % [people[j].get("char_name"), people[i].get("char_name")]
			if (key == _chatter_last or swapped == _chatter_last) and choices.size() > 0:
				continue
			choices.append([people[i], people[j]])
	if choices.is_empty():
		return []
	return choices[randi() % choices.size()]


func _npc_named(who: String) -> Node3D:
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) == who:
			return node as Node3D
	return null


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.12, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.93)
	env.ambient_light_energy = 0.62
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(1.0, 0.9, 0.94)
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.glow_enabled = false
	var world := WorldEnvironment.new()
	world.environment = env
	world.add_to_group("circus_sky")
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.add_to_group("circus_sun")
	sun.rotation_degrees = Vector3(-58, 32, 0)
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 0.72
	sun.shadow_enabled = false
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(LOUNGE.x, 7.5, LOUNGE.z + 4.0)
	fill.light_color = Color(1.0, 0.86, 0.75)
	fill.light_energy = 0.35
	fill.omni_range = 28.0
	fill.shadow_enabled = false
	add_child(fill)

	var confetti := CPUParticles3D.new()
	confetti.position = Vector3(LOUNGE.x, 8.0, LOUNGE.z + 2.0)
	confetti.amount = 36
	confetti.lifetime = 7.0
	confetti.preprocess = 4.0
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(8, 1, 8)
	confetti.direction = Vector3(0, -1, 0)
	confetti.spread = 28.0
	confetti.gravity = Vector3(0, -0.6, 0)
	confetti.initial_velocity_min = 0.4
	confetti.initial_velocity_max = 1.1
	confetti.scale_amount_min = 0.05
	confetti.scale_amount_max = 0.12
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("#ff3b3b"), Color("#ffd23a"), Color("#4ad2ff"), Color("#ff4fa3")])
	ramp.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	confetti.color_ramp = ramp
	add_child(confetti)


func _build_collision(root: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	_gather_meshes(root, meshes)
	var used := 0
	var index := 0
	var total := maxi(meshes.size(), 1)
	for mi in meshes:
		index += 1
		if _should_collide(mi):
			if mi.mesh.get_surface_count() > 0:
				mi.create_trimesh_collision()
				used += 1
		if index % 30 == 0:
			TentUI.set_loading(0.2 + 0.7 * float(index) / float(total), "Stitching the floor... %d%%" % int(100.0 * float(index) / float(total)))
			await get_tree().process_frame
	_add_ground()
	print("COLLISION_BODIES ", used, " of ", meshes.size())
	TentUI.set_loading(0.95, "Calling the cast...")
	await get_tree().process_frame


func _should_collide(mi: MeshInstance3D) -> bool:
	if mi.mesh == null:
		return false
	var n := mi.name.to_lower()
	if "light" in n or "leaf" in n or "photo" in n:
		return false
	for word in ["floor", "wall", "stair", "couch", "stage", "ceiling", "rug", "castle", "tent", "trim", "pole", "therapy", "tower", "bench", "curtain", "suggestion"]:
		if word in n:
			return true
	var size := mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()
	var wide := maxf(size.x, size.z)
	# Skip the giant scaled floor sheet; a simple ground stands in for it.
	if wide > 80.0 or size.y > 80.0:
		return false
	if wide > 8.0 and size.y > 0.08:
		return true
	if size.y > 4.0 and wide > 0.8:
		return true
	return false


func _gather_meshes(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_gather_meshes(child, into)


func _plant_cast() -> Vector3:
	var spots := [
		{"id": "caine", "name": "Caine", "color": Color("#ff4b5c"), "at": Vector3(0, 0, 2.2), "hover": 0.85, "bob": 0.08, "height": 2.15, "stay": true, "party": false, "slot": 0.0},
		{"id": "ragatha", "name": "Ragatha", "color": Color("#3f9fe6"), "at": Vector3(-3.8, 0, 3.6), "hover": 0.0, "bob": 0.02, "height": 1.65, "stay": false, "party": true, "slot": -1.6},
		{"id": "jax", "name": "Jax", "color": Color("#c06bff"), "at": Vector3(3.8, 0, 3.6), "hover": 0.0, "bob": 0.02, "height": 2.05, "stay": false, "party": true, "slot": 1.6},
		{"id": "gangle", "name": "Gangle", "color": Color("#ff5a4a"), "at": Vector3(-6.2, 0, 1.5), "hover": 0.0, "bob": 0.03, "height": 1.6, "stay": false, "party": true, "slot": -2.7},
		{"id": "zooble", "name": "Zooble", "color": Color("#ff4fa3"), "at": Vector3(6.2, 0, 1.5), "hover": 0.0, "bob": 0.02, "height": 1.55, "stay": false, "party": true, "slot": 2.7},
		{"id": "kinger", "name": "Kinger", "color": Color("#f0c14a"), "at": Vector3(-2.0, 0, 0.4), "hover": 0.0, "bob": 0.02, "height": 1.95, "stay": false, "party": true, "slot": 0.0},
	]
	var floor_y := _floor_y(LOUNGE.x, LOUNGE.z + 6.0, 0.45)
	var spawn := Vector3(LOUNGE.x, floor_y, LOUNGE.z + 6.0)
	for spot in spots:
		var offset: Vector3 = spot.at
		var y := _floor_y(LOUNGE.x + offset.x, LOUNGE.z + offset.z, floor_y)
		var npc := _make_npc(str(spot.id), str(spot.name), spot.color, float(spot.hover), float(spot.bob), float(spot.height), bool(spot.stay), bool(spot.party), float(spot.slot))
		add_child(npc)
		npc.plant(Vector3(LOUNGE.x + offset.x, y, LOUNGE.z + offset.z))
		if str(spot.id) == "caine":
			_caine = npc
			_attach_bubble(npc)
			var light := OmniLight3D.new()
			light.light_color = Color(1, 0.82, 0.7)
			light.light_energy = 0.45
			light.omni_range = 11.0
			light.position = Vector3(0, 2.4, 0)
			light.shadow_enabled = false
			npc.add_child(light)
	_plant_residents(floor_y)
	return spawn


func _plant_residents(floor_y: float) -> void:
	var people: Array[Dictionary] = [
		{"id": "kaufmo", "name": "Kaufmo", "color": Color("#ffd23a"), "height": 1.7},
		{"id": "queenie", "name": "Queenie", "color": Color("#f0c14a"), "height": 1.55},
		{"id": "gummigoo", "name": "Gummigoo", "color": Color("#7dcea0"), "height": 2.05},
		{"id": "martha", "name": "Martha", "color": Color("#d7b48a"), "height": 1.6},
		{"id": "ribbit", "name": "Ribbit", "color": Color("#3dff8a"), "height": 1.45},
		{"id": "orbsman", "name": "Orbsman", "color": Color("#4ad2ff"), "height": 1.7},
		{"id": "fudge", "name": "Fudge", "color": Color("#8a4b2a"), "height": 1.2},
		{"id": "moon", "name": "Moon", "color": Color("#d7e4ff"), "height": 1.35},
		{"id": "sun", "name": "Sun", "color": Color("#ffd23a"), "height": 1.35},
		{"id": "fish", "name": "Fish", "color": Color("#4ad2ff"), "height": 0.7},
		{"id": "shrimp", "name": "Shrimp", "color": Color("#ff8a7a"), "height": 0.7},
		{"id": "gloink", "name": "Gloink", "color": Color("#c06bff"), "height": 0.55},
		{"id": "gloinkqueen", "name": "Gloink Queen", "color": Color("#c06bff"), "height": 2.1},
		{"id": "mannequin", "name": "Mannequin", "color": Color("#f4efe8"), "height": 1.7},
		{"id": "ghostly", "name": "Ghostly", "color": Color("#d7f4ff"), "height": 1.7},
		{"id": "loolilalu", "name": "Loolilalu", "color": Color("#ffb3d9"), "height": 1.15},
		{"id": "baron", "name": "Baron", "color": Color("#6b3bb8"), "height": 2.1},
		{"id": "max", "name": "Max", "color": Color("#ff8a2a"), "height": 1.8},
		{"id": "chad", "name": "Chad", "color": Color("#3f9fe6"), "height": 1.9},
	]
	var placed := 0
	for person in people:
		var id := str(person.id)
		if not FileAccess.file_exists("res://characters/%s.glb" % id):
			continue
		var side := -1.0 if placed % 2 == 0 else 1.0
		var row := int(placed / 2.0)
		var offset := Vector3(side * (10.5 + float(row / 7) * 3.2), 0.0, -2.0 + float(row % 7) * 2.15)
		var y := _floor_y(LOUNGE.x + offset.x, LOUNGE.z + offset.z, floor_y)
		var npc := _make_npc(id, str(person.name), person.color, 0.0, 0.015, float(person.height), true, false, 0.0)
		add_child(npc)
		npc.plant(Vector3(LOUNGE.x + offset.x, y, LOUNGE.z + offset.z))
		placed += 1
	print("RESIDENTS ", placed)


func _attach_bubble(caine: Node3D) -> void:
	var bubble := _make_npc("bubble", "Bubble", Color("#d7f4ff"), 0.0, 0.0, 0.5, true, false, 0.0)
	caine.add_child(bubble)
	bubble.face_player = true
	bubble.home_ready = false


func _place_exit() -> void:
	var y := _floor_y(LOUNGE.x, LOUNGE.z + 11.5, _spawn.y)
	var door := _make_npc("exit", "Exit", Color("#ffd23a"), 0.0, 0.0, 2.3, true, false, 0.0)
	add_child(door)
	door.plant(Vector3(LOUNGE.x, y, LOUNGE.z + 11.5))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.5, 0.32)
	shape.shape = box
	shape.position.y = 1.25
	body.add_child(shape)
	door.add_child(body)


func _mark_suggestion(root: Node) -> void:
	var box := _find_exact(root, "Suggestion Box")
	if box == null or not box is Node3D:
		return
	var where: Vector3 = (box as Node3D).global_position
	var talk := _make_npc("crate", "Suggestion Box", Color("#ffd23a"), 0.0, 0.02, 1.1, true, false, 0.0)
	add_child(talk)
	talk.plant(where + Vector3(0, 0.0, 1.6))


func _make_player(at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Pomni"
	body.set_script(PlayerScript)
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.55
	shape_node.shape = capsule
	shape_node.position.y = 0.78
	body.add_child(shape_node)
	body.collision_layer = 2
	body.collision_mask = 1
	body.remember_spawn(at)
	return body


func _make_npc(id: String, display: String, accent: Color, hover: float, bob: float, height: float, stay: bool, party: bool, slot: float) -> Node3D:
	var npc := Node3D.new()
	npc.set_script(NpcScript)
	npc.setup(id, display, accent, hover, bob, height, stay, party, slot)
	return npc


func _floor_y(x: float, z: float, fallback: float) -> float:
	var hit := _ray(x, z, 40.0, -4.0)
	if hit.is_empty() or hit.normal.y < 0.5:
		return fallback
	if hit.position.y > 20.0 or hit.position.y < -2.0:
		return fallback
	return hit.position.y


func _ray(x: float, z: float, from_y: float, to_y: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, to_y, z))
	query.collision_mask = 1
	return space.intersect_ray(query)


func _find_exact(root: Node, wanted: String) -> Node:
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name == wanted:
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func _wants_shot() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--shot":
			return true
	for arg in OS.get_cmdline_args():
		if arg == "--shot":
			return true
	return false


func _add_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(420.0, 0.5, 320.0)
	shape_node.shape = box
	shape_node.position = Vector3(40.0, 0.01, 20.0)
	body.add_child(shape_node)
	add_child(body)


func _capture_shot() -> void:
	await get_tree().create_timer(0.6).timeout
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://shot_lounge.png")
	var err := ERR_CANT_CREATE
	var size := Vector2i.ZERO
	if image != null:
		size = image.get_size()
		err = image.save_png(path)
	var status := FileAccess.open("res://shot_status.txt", FileAccess.WRITE)
	if status:
		status.store_string("err=%s size=%s path=%s player=%s\n" % [err, size, path, _player.global_position])
		status.close()
	print("SHOT ", err, " ", path, " ", size)
	get_tree().quit()


func _burst_confetti() -> void:
	for offset in [Vector3(0, 2, 2), Vector3(-3, 2, 4), Vector3(3, 2, 4)]:
		var burst := CPUParticles3D.new()
		burst.position = Vector3(LOUNGE.x, 0, LOUNGE.z) + offset
		burst.amount = 80
		burst.lifetime = 2.4
		burst.one_shot = true
		burst.explosiveness = 0.92
		burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		burst.emission_sphere_radius = 0.6
		burst.direction = Vector3.UP
		burst.spread = 70.0
		burst.initial_velocity_min = 5.0
		burst.initial_velocity_max = 11.0
		burst.gravity = Vector3(0, -7, 0)
		burst.scale_amount_min = 0.06
		burst.scale_amount_max = 0.16
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color.RED, Color.YELLOW, Color.CYAN, Color.MAGENTA])
		ramp.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
		burst.color_ramp = ramp
		add_child(burst)
		burst.emitting = true


func _ready_complete_hook() -> void:
	pass
