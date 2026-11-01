extends Node3D

const NpcScript = preload("res://scripts/npc.gd")
const CELLAR := Vector3(-420.0, 0.0, 20.0)

var _uses: Array[Dictionary] = []
var _bulbs: Array[OmniLight3D] = []
var _dead_bulb: OmniLight3D
var _secret_wall: MeshInstance3D
var _secret_body: StaticBody3D
var _hatch := Vector3.ZERO
var _inside := false
var _dark_saved := false
var _amb_energy := 0.62
var _amb_color := Color(1, 0.96, 0.93)
var _bg := Color(0.45, 0.12, 0.28)
var _fog := 0.0012
var _fog_color := Color(1, 0.9, 0.94)
var _sun_energy := 0.72
var _brick_open := false
var _pen: Array[Vector3] = []
var _pen_used := 0
var _caine_home := Vector3.ZERO
var _drop_t := -1.0
var _drop_from := Vector3.ZERO
var _drop_hole := Vector3.ZERO
var _drop_land := Vector3.ZERO
var _hole: Node3D
var _mouth: Node3D
var _shot: Camera3D


func _ready() -> void:
	add_to_group("cellar_root")
	if not Abstraction.someone_abstracted.is_connected(_on_abstracted):
		Abstraction.someone_abstracted.connect(_on_abstracted)
	if not Abstraction.someone_restored.is_connected(_on_restored):
		Abstraction.someone_restored.connect(_on_restored)


func build(host: Node) -> void:
	_build_cellar()
	_build_hatch(host)
	_build_clues(host)
	print("CELLAR_READY hatch=", _hatch)


func interact_prompt(at: Vector3) -> String:
	var item := _nearest_use(at)
	var id := ""
	if not item.is_empty():
		id = str(item.get("id", ""))
	if id == "" and Abstraction.holding_spool and _inside:
		if Abstraction.is_gone("Pomni"):
			return "E    Turn the centering spool on yourself"
		var victim := _nearest_gone(at, 2.6)
		if victim != "":
			return "E    Use the centering spool on %s" % victim
	if id == "spool" and Abstraction.holding_spool and _inside:
		var victim := _nearest_gone(at, 3.0)
		if victim != "":
			return "E    Use the centering spool on %s" % victim
		if Abstraction.is_gone("Pomni"):
			return "E    Turn the centering spool on yourself"
	if item.is_empty():
		return ""
	return _prompt_for(id)


func try_use(player: Node3D) -> bool:
	if player == null:
		return false
	var item := _nearest_use(player.global_position)
	if not item.is_empty():
		var id := str(item.get("id", ""))
		if id == "spool" and Abstraction.holding_spool and _inside:
			var victim := _nearest_gone(player.global_position, 3.0)
			if victim == "" and Abstraction.is_gone("Pomni"):
				victim = "Pomni"
			if victim != "":
				_restore_who(victim)
				return true
		_activate(id, player)
		return true
	if Abstraction.holding_spool and _inside:
		var victim := _nearest_gone(player.global_position, 2.6)
		if victim == "" and Abstraction.is_gone("Pomni"):
			victim = "Pomni"
		if victim != "":
			_restore_who(victim)
			return true
	return false


func _process(delta: float) -> void:
	_flicker(delta)
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	if player == null:
		return
	if not Abstraction.cellar_known and player.global_position.distance_to(_hatch) < 3.2:
		Abstraction.mark_known()
		TentUI.toast("A hatch is set into the floor. The lock has been used.")
	if _drop_t >= 0.0:
		_tick_drop(delta, player)


func _build_cellar() -> void:
	_box(Vector3(0, 0.2, 0), Vector3(32, 0.4, 28), Color(0.07, 0.06, 0.08), true)
	_box(Vector3(0, 3.35, 0), Vector3(32, 0.28, 28), Color(0.04, 0.04, 0.05), true)
	_box(Vector3(0, 1.7, -14), Vector3(32, 3.1, 0.45), Color(0.09, 0.07, 0.1), true)
	_box(Vector3(0, 1.7, 14), Vector3(32, 3.1, 0.45), Color(0.09, 0.07, 0.1), true)
	_box(Vector3(16, 1.7, 0), Vector3(0.45, 3.1, 28), Color(0.09, 0.07, 0.1), true)
	_box(Vector3(-16, 1.7, 0), Vector3(0.45, 3.1, 28), Color(0.09, 0.07, 0.1), true)
	_box(Vector3(-9, 1.7, -1), Vector3(12, 3.1, 0.4), Color(0.11, 0.08, 0.1), true)
	_box(Vector3(8, 1.7, -1), Vector3(14, 3.1, 0.4), Color(0.11, 0.08, 0.1), true)
	_box(Vector3(-2, 1.7, 6), Vector3(0.4, 3.1, 10), Color(0.1, 0.07, 0.09), true)
	_secret_wall = _box(Vector3(-8.2, 1.7, -8), Vector3(0.4, 3.1, 7.5), Color(0.12, 0.08, 0.09), false)
	_secret_body = _body(_at(Vector3(-8.2, 1.7, -8)), Vector3(0.4, 3.1, 7.5))
	_plaque(_at(Vector3(-6, 1.7, -13.2)), "SCRATCH\nstopped answering\nto their name")
	_plaque(_at(Vector3(0, 1.7, -13.2)), "PENNY\nleft a ribbon\nand nothing else")
	_plaque(_at(Vector3(6, 1.7, -13.2)), "DOODLE\nthe walls kept\nthe last drawing")
	_plaque(_at(Vector3(10, 1.5, 4)), "III  III  III\nthree, and then\nthe hatch")
	_use("journal", Vector3(9.2, 0.7, 7.5))
	_box(Vector3(9.2, 0.45, 7.5), Vector3(1.1, 0.5, 0.8), Color(0.18, 0.1, 0.08), false)
	_use("brick", Vector3(-8.2, 1.1, -3.6))
	_box(Vector3(-8.2, 1.05, -3.6), Vector3(0.28, 0.16, 0.22), Color(0.28, 0.16, 0.14), false)
	_use("spool", Vector3(-12.4, 0.7, -10.5))
	_spool_mesh(Vector3(-12.4, 0.55, -10.5))
	_use("climb", Vector3(0, 0.6, 11.2))
	for spot in [Vector3(-6, 2.4, 8), Vector3(4, 2.4, 2), Vector3(-2, 2.4, -6), Vector3(8, 2.4, -8)]:
		_bulbs.append(_bulb(_at(spot), 0.9))
	_dead_bulb = _bulb(_at(Vector3(-12, 2.3, -10)), 0.0)
	_pen = [_at(Vector3(-5, 0.45, -8)), _at(Vector3(5, 0.45, -7)), _at(Vector3(1, 0.45, 3))]
	_lost("Scratch", Color("#c9b7a2"), _pen[0])
	_lost("Penny", Color("#e7a3b8"), _pen[1])
	_lost("Doodle", Color("#d7c56a"), _pen[2])


func _build_hatch(host: Node) -> void:
	var x := 77.9 - 18.0
	var z := 4.2 - 9.0
	var floor_y := 0.3
	if host.has_method("_floor_y"):
		floor_y = float(host.call("_floor_y", x, z, 0.3))
	_hatch = Vector3(x, floor_y + 0.06, z)
	var plate := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.85
	mesh.bottom_radius = 0.85
	mesh.height = 0.08
	plate.mesh = mesh
	plate.position = _hatch
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.1, 0.11)
	mat.roughness = 0.84
	plate.material_override = mat
	add_child(plate)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.62
	ring.mesh = torus
	ring.position = _hatch + Vector3(0, 0.05, 0)
	ring.rotation.x = PI * 0.5
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.35, 0.12, 0.14)
	ring.material_override = ring_mat
	add_child(ring)
	_plaque(_hatch + Vector3(0, 0.9, 0), "KEEP THIS SHUT")
	_uses.append({"id": "hatch", "at": _hatch + Vector3(0, 0.4, 0)})


func _build_clues(host: Node) -> void:
	var floor_y := 0.45
	if host.has_method("_floor_y"):
		floor_y = float(host.call("_floor_y", 77.9 - 16.5, 4.2 - 7.4, 0.45))
	var note_at := Vector3(77.9 - 16.5, floor_y + 1.15, 4.2 - 7.4)
	_board(note_at, "The spare key is under\nthe yellow cushion.\nHe never looks down.")
	_uses.append({"id": "hatch_note", "at": note_at})
	var exit_y := 0.45
	if host.has_method("_floor_y"):
		exit_y = float(host.call("_floor_y", 77.9 + 2.5, 4.2 + 11.2, 0.45))
	var exit_at := Vector3(77.9 + 2.5, exit_y + 1.25, 4.2 + 11.2)
	_board(exit_at, "Three went under the floor.\nScratch. Penny. Doodle.")
	_uses.append({"id": "exit_note", "at": exit_at})
	var cush_y := 0.35
	if host.has_method("_floor_y"):
		cush_y = float(host.call("_floor_y", 77.9 + 11.0, 4.2 - 5.5, 0.35))
	var cush := Vector3(77.9 + 11.0, cush_y + 0.16, 4.2 - 5.5)
	_box(cush - CELLAR, Vector3(1.25, 0.32, 1.05), Color("#ffd23a"), false)
	_uses.append({"id": "cushion", "at": cush + Vector3(0, 0.3, 0)})


func _activate(id: String, player: Node3D) -> void:
	match id:
		"hatch_note":
			_read("A scrap is tacked by the hatch. The spare key is under the yellow cushion. He never looks down.", "Ragatha")
		"exit_note":
			_read("Scratch, Penny, and Doodle went under the floor. The door still knows their names.", "Kinger")
		"cushion":
			if Abstraction.cellar_known and not _has_key():
				_grant_key()
			elif _has_key():
				TentUI.toast("The cushion's seam is empty.")
			else:
				TentUI.toast("A yellow cushion. The seam has been picked at.")
				Abstraction.mark_known()
		"hatch":
			_use_hatch(player)
		"journal":
			_read("A journal in the dark: Scratch stopped answering to their name. Caine called the flickering a lighting cue.", "Zooble")
		"brick":
			if _brick_open:
				TentUI.toast("The brick stays out. The gap smells like dust and rain that never fell.")
			else:
				_brick_open = true
				if _secret_wall:
					_secret_wall.visible = false
				if _secret_body:
					_secret_body.collision_layer = 0
				if _dead_bulb:
					_dead_bulb.light_energy = 1.1
				TentUI.toast("The brick gives. A side room opens, and one bulb remembers the name Scratch.")
				Abstraction.remember("A loose brick in the cellar opens onto Scratch's name.")
				_gossip("Jax", "Secret passage. Love that for us. I'm still not going first.")
		"spool":
			if Abstraction.take_spool():
				TentUI.toast("You take the centering spool. The note beside it says it answers one person, one time, and only down here.")
				Abstraction.strain("Pomni", 8.0)
			elif Abstraction.spool_spent:
				TentUI.toast("The stand is empty. The spool already answered.")
			else:
				TentUI.toast("You already hold the centering spool.")
		"climb":
			_leave(player)


func _use_hatch(player: Node3D) -> void:
	Abstraction.mark_known()
	if not _has_key() and not _unlocked():
		TentUI.toast("The hatch does not move. A small key would turn in the lock.")
		_gossip("Caine", "Set dressing! Very spooky, very fake. Let's look at anything else!")
		return
	if not _unlocked():
		Abstraction.remember("The cellar hatch is unlocked.")
		TentUI.toast("The key turns. Cold air comes up through the hatch.")
		Music.sting_glitch()
		_pull_all_inside()
	_enter(player)


func _enter(player: Node3D) -> void:
	_inside = true
	_place_player(player, _at(Vector3(0, 0.85, 11.2)))
	_set_dark(true)
	Music.in_cellar = true
	Abstraction.enter_cellar(true)
	TentUI.toast("The cellar swallows the circus light.")


func release() -> void:
	if not _inside:
		return
	_inside = false
	_set_dark(false)
	Music.in_cellar = false
	Abstraction.enter_cellar(false)


func _leave(player: Node3D) -> void:
	_inside = false
	_place_player(player, _hatch + Vector3(0, 0.55, 1.5))
	_set_dark(false)
	Music.in_cellar = false
	Abstraction.enter_cellar(false)
	TentUI.toast("You climb back into the tent. The hatch stays open.")


func _read(text: String, worried: String) -> void:
	Abstraction.mark_known()
	Abstraction.remember(text)
	Abstraction.strain("Pomni", 6.0)
	TentUI.toast(text)
	_gossip(worried, "")


func _gossip(prefer: String, forced: String) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	if player == null:
		return
	for node in get_tree().get_nodes_in_group("circus_npc"):
		var npc := node as Node3D
		if npc == null or bool(node.get_meta("lost_one", false)):
			continue
		var who := str(node.get("char_name"))
		if Abstraction.is_gone(who):
			continue
		if player.global_position.distance_to(npc.global_position) > 12.0:
			continue
		var line := forced if forced != "" and who == prefer else _clue_line(who)
		if line != "" and node.has_method("show_line"):
			node.show_line(line)
		if Abstraction.tracks(who):
			Abstraction.strain(who, 4.0)


func _clue_line(who: String) -> String:
	match who:
		"Ragatha":
			return "Please leave it shut. Some doors are closed for a reason."
		"Jax":
			return "A forbidden basement. What could go wrong. Ha. Ha."
		"Kinger":
			return "No. I have already been down there in my head. Don't open it."
		"Gangle":
			return "I don't want to know who Scratch was."
		"Zooble":
			return "If Caine hid it, it's because he doesn't want to look at it."
		"Caine":
			return "That's a prop! A spooky prop! We are looking at something cheerful now!"
		"Bubble":
			return "I don't pop down there."
		_:
			return ""


func _grant_key() -> void:
	Abstraction.remember("The cellar key was hidden under the yellow cushion.")
	Abstraction.strain("Pomni", 5.0)
	set_meta("has_key", true)
	TentUI.toast("Tucked in the cushion seam: a small iron key.")
	_gossip("Jax", "You found a key in the furniture. I'm choosing to respect that.")


func _has_key() -> bool:
	return bool(get_meta("has_key", false))


func _unlocked() -> bool:
	return bool(get_meta("unlocked", false)) or Abstraction.memories.has("The cellar hatch is unlocked.")


func _restore_who(who: String) -> void:
	if Abstraction.restore(who):
		TentUI.toast("The spool turns once. %s comes back, and remembers all of it." % who)
	else:
		TentUI.toast("The spool stays cold.")


func _on_abstracted(who: String) -> void:
	if who == "Pomni":
		if _drop_t < 0.0:
			_begin_fetch()
		return
	if not _unlocked():
		return
	_pull_inside(who)


func _on_restored(who: String) -> void:
	if who == "Pomni":
		var show := get_tree().get_first_node_in_group("adventure_world")
		if show != null and show.has_method("resume_after_player"):
			show.call("resume_after_player")
		return
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) != who:
			continue
		var npc := node as Node3D
		if npc == null or not _point_inside(npc.global_position):
			return
		if npc.has_method("settle"):
			npc.settle(_hatch + Vector3(1.4, 0.45, 1.6))
		return


func _pull_all_inside() -> void:
	set_meta("unlocked", true)
	for who in Abstraction.MAIN:
		if Abstraction.is_gone(who) and who != "Pomni":
			_pull_inside(who)


func _begin_fetch() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	if player == null:
		return
	var show := get_tree().get_first_node_in_group("adventure_world")
	if show != null and show.has_method("halt_for_player"):
		show.call("halt_for_player")
	if _inside:
		release()
	if player.has_method("dismount"):
		player.call("dismount", player.global_position)
	if player.has_method("hold_still"):
		player.call("hold_still", true)
	_drop_from = player.global_position
	var caine := _caine()
	if caine != null:
		_caine_home = caine.global_position
		caine.call_deferred("snap_fingers")
		caine.call_deferred("show_line", "Into the cellar you go.")
	else:
		_caine_home = _drop_from
	_drop_hole = Vector3(_caine_home.x, 0.34, _caine_home.z + 1.55)
	_drop_land = _at(Vector3(0.0, 0.85, 1.2))
	_open_hole()
	_ensure_shot()
	_drop_t = 0.0
	Music.play_cellar_drop()
	Abstraction.mark_known()
	Abstraction.remember("Caine snapped his fingers, opened the floor, and dropped Pomni into the cellar.")
	set_meta("unlocked", true)


func _tick_drop(delta: float, player: Node3D) -> void:
	_drop_t += delta
	var t := _drop_t
	var hover := _drop_hole + Vector3(0.0, 1.75, 0.0)
	var body := player as CharacterBody3D
	if body:
		body.velocity = Vector3.ZERO
	if t < 0.7:
		_set_hole_open(0.04)
		_aim(_caine_home + Vector3(2.3, 1.9, 2.5), _caine_home + Vector3(0.2, 1.25, 0.2))
	elif t < 2.45:
		var along := _smooth((t - 0.7) / 1.75)
		player.global_position = _drop_from.lerp(hover, along)
		player.rotation.x = 0.0
		_set_hole_open(0.04)
		_aim_travel(player, hover)
	elif t < 3.25:
		player.global_position = hover
		player.rotation.x = 0.0
		_set_hole_open(lerpf(0.05, 1.0, (t - 2.45) / 0.8))
		_aim(_drop_hole + Vector3(3.2, 1.45, 3.0), hover)
	elif t < 4.15:
		var sink := _smooth((t - 3.25) / 0.9)
		player.global_position = hover.lerp(_drop_hole + Vector3(0.0, 0.15, 0.0), sink)
		player.rotation.x = sink * 0.35
		_set_hole_open(1.0)
		_aim(_drop_hole + Vector3(2.6, 1.7, 2.4), player.global_position)
	elif t < 4.55:
		var through := (t - 4.15) / 0.4
		player.global_position = (_drop_hole + Vector3(0.0, 0.15, 0.0)).lerp(_drop_hole + Vector3(0.0, -2.1, 0.0), through)
		player.rotation.x = 0.35 + through * 0.8
		_set_hole_open(1.0)
		_aim(_drop_hole + Vector3(1.8, 2.4, 1.6), player.global_position)
	elif t < 7.21:
		var fall := (t - 4.55) / 2.66
		var top := _drop_land + Vector3(0.0, 4.6, 0.0)
		player.global_position = top.lerp(_drop_land, fall * fall)
		player.rotation.x = sin(fall * 8.0) * 0.45
		player.rotation.y += delta * 1.4
		_set_hole_open(1.0)
		_show_mouth()
		if not _inside:
			_inside = true
			_set_dark(true)
			Music.in_cellar = true
			Abstraction.enter_cellar(true)
		_aim(_drop_land + Vector3(4.3, 1.7, 3.5), player.global_position + Vector3(0.0, 0.45, 0.0))
	else:
		_finish_drop(player)


func _finish_drop(player: Node3D) -> void:
	_drop_t = -1.0
	player.rotation.x = 0.0
	_place_player(player, _drop_land)
	_inside = true
	_set_dark(true)
	Music.in_cellar = true
	Abstraction.enter_cellar(true)
	if player.has_method("hold_still"):
		player.call("hold_still", false)
	if player.has_method("use_own_camera"):
		player.call("use_own_camera")
	if player.has_method("remember_spawn"):
		player.remember_spawn(_drop_land)
	if _shot != null:
		_shot.current = false
	if _hole != null and is_instance_valid(_hole):
		_hole.queue_free()
	_hole = null
	if _mouth != null and is_instance_valid(_mouth):
		_mouth.queue_free()
	_mouth = null
	var show := get_tree().get_first_node_in_group("adventure_world")
	if show != null and show.has_method("dismiss_adventure"):
		show.call("dismiss_adventure")
	TentUI.toast("The floor opened. Caine put you in the cellar.")


func _open_hole() -> void:
	if _hole != null and is_instance_valid(_hole):
		_hole.queue_free()
	_hole = Node3D.new()
	_hole.position = _drop_hole
	add_child(_hole)
	var pit := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 0.62
	cyl.height = 0.55
	pit.mesh = cyl
	pit.position.y = -0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.01, 0.008, 0.012)
	mat.emission_enabled = true
	mat.emission = Color(0.03, 0.0, 0.04)
	mat.emission_energy_multiplier = 0.4
	pit.material_override = mat
	_hole.add_child(pit)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.16
	rim.mesh = torus
	rim.rotation.x = PI * 0.5
	rim.position.y = 0.05
	var ring := StandardMaterial3D.new()
	ring.albedo_color = Color(0.22, 0.03, 0.05)
	ring.emission_enabled = true
	ring.emission = Color(0.75, 0.08, 0.1)
	ring.emission_energy_multiplier = 1.6
	rim.material_override = ring
	_hole.add_child(rim)
	_set_hole_open(0.04)


func _show_mouth() -> void:
	if _mouth != null:
		return
	_mouth = Node3D.new()
	_mouth.position = _drop_land + Vector3(0.0, 2.55, 0.0)
	add_child(_mouth)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 1.05
	rim.mesh = torus
	rim.rotation.x = PI * 0.5
	var ring := StandardMaterial3D.new()
	ring.albedo_color = Color(0.02, 0.01, 0.02)
	ring.emission_enabled = true
	ring.emission = Color(0.45, 0.04, 0.06)
	ring.emission_energy_multiplier = 1.2
	rim.material_override = ring
	_mouth.add_child(rim)


func _set_hole_open(amount: float) -> void:
	if _hole == null or not is_instance_valid(_hole):
		return
	var wide := clampf(amount, 0.02, 1.0)
	_hole.scale = Vector3(wide, 1.0, wide)


func _ensure_shot() -> void:
	if _shot == null:
		_shot = Camera3D.new()
		_shot.fov = 62.0
		add_child(_shot)
	_shot.current = true


func _aim(from: Vector3, at: Vector3) -> void:
	if _shot == null:
		return
	_shot.global_position = from
	if from.distance_to(at) > 0.2:
		_shot.look_at(at, Vector3.UP)


func _aim_travel(player: Node3D, hover: Vector3) -> void:
	var dir := hover - _drop_from
	dir.y = 0.0
	if dir.length() < 0.25:
		dir = Vector3(0.0, 0.0, 1.0)
	else:
		dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	_aim(player.global_position - dir * 4.4 + Vector3(0.0, 2.15, 0.0) + side * 1.5, player.global_position + Vector3(0.0, 0.7, 0.0))


func _smooth(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _caine() -> Node3D:
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) == "Caine":
			return node as Node3D
	return null


func _pull_inside(who: String) -> void:
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) != who or bool(node.get_meta("lost_one", false)):
			continue
		var npc := node as Node3D
		if npc == null:
			continue
		var spot: Vector3 = _pen[_pen_used % _pen.size()]
		_pen_used += 1
		if npc.has_method("settle"):
			npc.settle(spot)
		else:
			npc.global_position = spot
		Music.play_cellar_drop()
		return


func _nearest_gone(at: Vector3, reach: float) -> String:
	var best := ""
	var best_dist := reach
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if bool(node.get_meta("lost_one", false)):
			continue
		var who := str(node.get("char_name"))
		if not Abstraction.is_gone(who):
			continue
		var npc := node as Node3D
		if npc == null:
			continue
		var dist := at.distance_to(npc.global_position)
		if dist < best_dist:
			best_dist = dist
			best = who
	return best


func _nearest_use(at: Vector3) -> Dictionary:
	var best := {}
	var best_dist := 2.35
	for index in _uses.size():
		var item: Dictionary = _uses[index]
		var pos: Vector3 = item.get("at", Vector3.ZERO)
		var dist := at.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best = item
	return best


func _prompt_for(id: String) -> String:
	match id:
		"hatch":
			if _unlocked() or _has_key():
				return "E    Open the cellar hatch"
			return "E    Try the locked hatch"
		"hatch_note", "exit_note":
			return "E    Read the note"
		"cushion":
			return "E    Look under the cushion"
		"journal":
			return "E    Read the journal"
		"brick":
			return "E    Pull the loose brick"
		"spool":
			if Abstraction.spool_spent:
				return ""
			return "E    Take the centering spool"
		"climb":
			if _inside:
				return "E    Climb back to the tent"
			return ""
		_:
			return ""


func _place_player(player: Node3D, at: Vector3) -> void:
	player.global_position = at
	var body := player as CharacterBody3D
	if body:
		body.velocity = Vector3.ZERO


func _set_dark(on: bool) -> void:
	var world := get_tree().get_first_node_in_group("circus_sky") as WorldEnvironment
	var sun := get_tree().get_first_node_in_group("circus_sun") as DirectionalLight3D
	if world == null or world.environment == null:
		return
	var env := world.environment
	if not _dark_saved:
		_amb_energy = env.ambient_light_energy
		_amb_color = env.ambient_light_color
		_bg = env.background_color
		_fog = env.fog_density
		_fog_color = env.fog_light_color
		if sun:
			_sun_energy = sun.light_energy
		_dark_saved = true
	if on:
		env.ambient_light_energy = 0.035
		env.ambient_light_color = Color(0.16, 0.17, 0.22)
		env.background_color = Color(0.01, 0.012, 0.016)
		env.fog_enabled = true
		env.fog_density = 0.075
		env.fog_light_color = Color(0.02, 0.02, 0.03)
		if sun:
			sun.light_energy = 0.0
	else:
		env.ambient_light_energy = _amb_energy
		env.ambient_light_color = _amb_color
		env.background_color = _bg
		env.fog_density = _fog
		env.fog_light_color = _fog_color
		if sun:
			sun.light_energy = _sun_energy


func _flicker(_delta: float) -> void:
	if not _inside:
		for bulb in _bulbs:
			if bulb:
				bulb.light_energy = 0.15
		return
	var t := Time.get_ticks_msec() / 1000.0
	for index in _bulbs.size():
		var bulb := _bulbs[index]
		if bulb == null:
			continue
		var wave := 0.45 + sin(t * (3.0 + float(index)) + float(index)) * 0.35
		if fposmod(t + float(index) * 0.37, 2.6) > 2.35:
			wave = 0.02
		bulb.light_energy = wave


func _lost(display: String, accent: Color, at: Vector3) -> void:
	var npc := Node3D.new()
	npc.set_script(NpcScript)
	npc.setup("abstracted", display, accent, 0.0, 0.0, 1.8, true, false, 0.0)
	npc.set_meta("lost_one", true)
	add_child(npc)
	npc.plant(at)


func _point_inside(at: Vector3) -> bool:
	var flat := at - CELLAR
	return absf(flat.x) < 18.0 and absf(flat.z) < 16.0 and at.y < 6.0


func _at(offset: Vector3) -> Vector3:
	return CELLAR + offset


func _use(id: String, offset: Vector3) -> void:
	_uses.append({"id": id, "at": _at(offset)})


func _box(offset: Vector3, size: Vector3, color: Color, collide: bool) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = _at(offset)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mesh_node.material_override = mat
	add_child(mesh_node)
	if collide:
		_body(_at(offset), size)
	return mesh_node


func _body(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)
	return body


func _bulb(at: Vector3, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(0.92, 0.78, 0.55)
	light.light_energy = energy
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)
	var glow := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	glow.mesh = mesh
	glow.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.65, 0.35)
	mat.emission_energy_multiplier = 0.6
	glow.material_override = mat
	add_child(glow)
	return light


func _spool_mesh(offset: Vector3) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.16
	mesh.height = 0.28
	mesh_node.mesh = mesh
	mesh_node.position = _at(offset)
	mesh_node.rotation.z = PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.08, 0.12)
	mesh_node.material_override = mat
	add_child(mesh_node)


func _plaque(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.004
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.modulate = Color(0.86, 0.8, 0.72)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 1)
	add_child(label)


func _board(at: Vector3, text: String) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 0.5, 0.04)
	mesh_node.mesh = mesh
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.32, 0.2)
	mesh_node.material_override = mat
	add_child(mesh_node)
	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.pixel_size = 0.003
	label.position = at + Vector3(0, 0, 0.04)
	label.modulate = Color(0.95, 0.9, 0.82)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 1)
	add_child(label)
