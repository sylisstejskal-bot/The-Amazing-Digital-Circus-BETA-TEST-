extends Node3D

const Loader = preload("res://scripts/model_loader.gd")
const Shade = preload("res://scripts/circus_shade.gd")

var char_name := "Friend"
var accent := Color.WHITE
var hover := 0.0
var bob_amp := 0.04
var phase := 0.0
var base_y := 0.0
var home := Vector3.ZERO
var home_ready := false
var celebrating := false
var face_player := true
var model_id := ""
var target_height := 1.7
var stays_in_circus := false
var joins_adventure := false
var follow_slot := 0.0
var following := false
var _roam_center := Vector3.ZERO
var _roam_set := false
var _goal := Vector3.ZERO
var _goal_left := 0.0
var _model: Node3D
var _preview := ""
var _speech: Node3D
var _speech_label: Label3D
var _speech_fill: MeshInstance3D
var _speech_edge: MeshInstance3D
var _speech_time := 0.0
var _speech_partner: Node3D
var _slip_wait := 8.0
var _touch_wait := 0.0
var _follow_lock := false
var _follow_yes := false
var _follow_line := ""
var _snap_left := 0.0
var _snap_flash: MeshInstance3D
var _caine_voice: Node
var _bubble_voice: Node
var _gangle_voice: Node
var _zooble_voice: Node
var _kinger_voice: Node
var _ragatha_voice: Node
var _jax_voice: Node
var _guest_voice: Node
var _guest_lines: Array[String] = []


func setup(id: String, display: String, p_accent: Color, p_hover: float, p_bob: float, height: float, stay: bool, party: bool, slot: float) -> void:
	model_id = id
	char_name = display
	accent = p_accent
	hover = p_hover
	bob_amp = p_bob
	target_height = height
	stays_in_circus = stay
	joins_adventure = party
	follow_slot = slot
	phase = randf() * TAU
	name = display
	_goal_left = randf_range(0.3, 2.2)


func _ready() -> void:
	if model_id == "made":
		_model = _made_body()
		add_child(_model)
	else:
		_model = Loader.build(model_id, target_height)
		add_child(_model)
		Loader.fit(_model, target_height)
	_add_label(target_height + 0.28)
	_add_speech(target_height + 1.15)
	add_to_group("circus_npc")
	if not Game.adventure_completed.is_connected(_celebrate):
		Game.adventure_completed.connect(_celebrate)
	if not Abstraction.someone_abstracted.is_connected(_on_abstracted):
		Abstraction.someone_abstracted.connect(_on_abstracted)
	if not Abstraction.someone_restored.is_connected(_on_restored):
		Abstraction.someone_restored.connect(_on_restored)
	if not Abstraction.crossed.is_connected(_on_crossed):
		Abstraction.crossed.connect(_on_crossed)
	_slip_wait = randf_range(6.0, 14.0)


func plant(at: Vector3) -> void:
	global_position = at + Vector3(0, hover, 0)
	base_y = global_position.y
	home = global_position
	home_ready = true
	if not _roam_set:
		_roam_center = home


func show_line(text: String, partner: Node3D = null) -> void:
	var clean := LocalAI.censor(text.replace("\n", " ").strip_edges())
	if clean == "":
		return
	if char_name == "Caine":
		_caine_say(clean)
	elif char_name == "Bubble":
		_bubble_say(clean)
	elif char_name == "Gangle":
		_gangle_say(clean)
	elif char_name == "Zooble":
		_zooble_say(clean)
	elif char_name == "Kinger":
		_kinger_say(clean)
	elif char_name == "Ragatha":
		_ragatha_say(clean)
	elif char_name == "Jax":
		_jax_say(clean)
	elif bool(get_meta("adventure_guest", false)):
		_guest_say(clean)
	if _speech_label == null:
		return
	if clean.length() > 140:
		clean = clean.substr(0, 137).strip_edges() + "..."
	var lines := _wrap_speech(clean)
	_speech_partner = partner
	_speech_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speech_label.width = 0
	_speech_label.text = "\n".join(lines)
	var font := _speech_label.font
	if font == null:
		font = ThemeDB.fallback_font
	var widest := 0.0
	for line in lines:
		var measured := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _speech_label.font_size).x
		widest = maxf(widest, measured * _speech_label.pixel_size)
	var line_height := font.get_height(_speech_label.font_size) * _speech_label.pixel_size
	line_height += _speech_label.line_spacing * _speech_label.pixel_size
	var width := widest + 0.34
	var height := line_height * float(lines.size()) + 0.22
	(_speech_fill.mesh as QuadMesh).size = Vector2(width, height)
	(_speech_edge.mesh as QuadMesh).size = Vector2(width + 0.08, height + 0.08)
	_speech.visible = true
	_speech_time = 6.5


func _wrap_speech(text: String) -> PackedStringArray:
	var words: PackedStringArray = text.split(" ", false)
	var lines: PackedStringArray = []
	var current := ""
	for word in words:
		var piece := word
		while piece.length() > 22:
			if current != "":
				lines.append(current)
				current = ""
			lines.append(piece.substr(0, 22))
			piece = piece.substr(22)
		if piece == "":
			continue
		if current == "":
			current = piece
		elif current.length() + 1 + piece.length() > 22:
			lines.append(current)
			current = piece
		else:
			current += " " + piece
	if current != "":
		lines.append(current)
	if lines.is_empty():
		lines.append("...")
	if lines.size() > 4:
		var trimmed: PackedStringArray = []
		trimmed.append(lines[0])
		trimmed.append(lines[1])
		trimmed.append(lines[2])
		var tail := lines[3]
		if tail.length() > 19:
			tail = tail.substr(0, 19).rstrip(" ")
		trimmed.append(tail + "...")
		return trimmed
	return lines


func talk() -> void:
	if TentUI.is_dialogue_open() or char_name == "Exit" or char_name == "Pomni":
		return
	if _is_lost_form():
		Music.sting_glitch()
		return
	Music.blip_talk()
	TentUI.open_chat(char_name, accent)


func _celebrate() -> void:
	celebrating = true
	bob_amp = maxf(bob_amp, 0.08)


func _add_label(height: float) -> void:
	var label := Label3D.new()
	label.text = char_name
	label.font_size = 64
	label.pixel_size = 0.0032
	label.position = Vector3(0, height, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.outline_size = 18
	label.outline_modulate = Color(0, 0, 0, 1)
	label.modulate = Color(1, 0.98, 0.94)
	add_child(label)


func _add_speech(height: float) -> void:
	_speech = Node3D.new()
	_speech.name = "Speech"
	_speech.position = Vector3(0, height, 0)
	_speech.visible = false
	_speech_edge = _speech_card(accent)
	_speech_edge.position.z = -0.012
	_speech.add_child(_speech_edge)
	_speech_fill = _speech_card(Color(1.0, 0.98, 0.94))
	_speech.add_child(_speech_fill)
	_speech_label = Label3D.new()
	_speech_label.position.z = 0.02
	_speech_label.font_size = 36
	_speech_label.pixel_size = 0.0032
	_speech_label.width = 0
	_speech_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speech_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_speech_label.double_sided = false
	_speech_label.modulate = Color(0.16, 0.07, 0.1)
	_speech_label.outline_size = 0
	_speech_label.render_priority = 2
	_speech.add_child(_speech_label)
	add_child(_speech)


func _speech_card(color: Color) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.2, 0.42)
	card.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	card.material_override = mat
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return card


func _tick_speech(delta: float) -> void:
	if _speech_time <= 0.0:
		return
	_speech_time -= delta
	if _speech_time <= 0.0:
		_speech.visible = false
		_speech_partner = null


func _aim_speech() -> void:
	if _speech == null or not _speech.visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var toward := cam.global_position - _speech.global_position
	if toward.length_squared() < 0.001:
		return
	_speech.global_basis = Basis.looking_at(toward, Vector3.UP, true)


func _caine_say(line: String) -> void:
	if _caine_voice == null or not is_instance_valid(_caine_voice):
		_caine_voice = preload("res://scripts/caine_voice.gd").new()
		_caine_voice.name = "CaineVoice"
		add_child(_caine_voice)
	_caine_voice.call("say", line)


func _bubble_say(line: String) -> void:
	if _bubble_voice == null or not is_instance_valid(_bubble_voice):
		_bubble_voice = preload("res://scripts/bubble_voice.gd").new()
		_bubble_voice.name = "BubbleVoice"
		add_child(_bubble_voice)
	_bubble_voice.call("say", line)


func _gangle_say(line: String) -> void:
	if _gangle_voice == null or not is_instance_valid(_gangle_voice):
		_gangle_voice = preload("res://scripts/gangle_voice.gd").new()
		_gangle_voice.name = "GangleVoice"
		add_child(_gangle_voice)
	_gangle_voice.call("say", line)


func _zooble_say(line: String) -> void:
	if _zooble_voice == null or not is_instance_valid(_zooble_voice):
		_zooble_voice = preload("res://scripts/zooble_voice.gd").new()
		_zooble_voice.name = "ZoobleVoice"
		add_child(_zooble_voice)
	_zooble_voice.call("say", line)


func _kinger_say(line: String) -> void:
	if _kinger_voice == null or not is_instance_valid(_kinger_voice):
		_kinger_voice = preload("res://scripts/kinger_voice.gd").new()
		_kinger_voice.name = "KingerVoice"
		add_child(_kinger_voice)
	_kinger_voice.call("say", line)


func _ragatha_say(line: String) -> void:
	if _ragatha_voice == null or not is_instance_valid(_ragatha_voice):
		_ragatha_voice = preload("res://scripts/ragatha_voice.gd").new()
		_ragatha_voice.name = "RagathaVoice"
		add_child(_ragatha_voice)
	_ragatha_voice.call("say", line)


func _jax_say(line: String) -> void:
	if _jax_voice == null or not is_instance_valid(_jax_voice):
		_jax_voice = preload("res://scripts/jax_voice.gd").new()
		_jax_voice.name = "JaxVoice"
		add_child(_jax_voice)
	_jax_voice.call("say", line)


func grant_fish_login(api_key: String, voice_id: String) -> void:
	set_meta("fish_key", api_key.strip_edges())
	set_meta("fish_voice", voice_id.strip_edges())
	if str(get_meta("fish_key", "")) == "":
		_guest_lines.clear()
		return
	_ensure_guest_voice()
	for line in _guest_lines:
		_guest_voice.call("say", line)
	_guest_lines.clear()


func _guest_say(line: String) -> void:
	if not has_meta("fish_key"):
		_guest_lines.append(line)
		if _guest_lines.size() > 3:
			_guest_lines.pop_front()
		return
	if str(get_meta("fish_key", "")) == "":
		return
	_ensure_guest_voice()
	_guest_voice.call("say", line)


func _ensure_guest_voice() -> void:
	if _guest_voice == null or not is_instance_valid(_guest_voice):
		_guest_voice = preload("res://scripts/caine_voice.gd").new()
		_guest_voice.name = "GuestVoice"
		add_child(_guest_voice)
	_guest_voice.set("skip_default_voice", true)
	_guest_voice.set("key_override", str(get_meta("fish_key", "")))
	_guest_voice.set("voice_override", str(get_meta("fish_voice", "")))
	_guest_voice.set("who_override", char_name)


func snap_fingers() -> void:
	_snap_left = 0.62
	if _snap_flash == null:
		_snap_flash = MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.09
		ball.height = 0.18
		_snap_flash.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.94, 0.55)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.82, 0.28)
		mat.emission_energy_multiplier = 6.0
		_snap_flash.material_override = mat
		_snap_flash.position = Vector3(0.46, 1.22, 0.28)
		add_child(_snap_flash)
	_snap_flash.visible = true
	_snap_flash.scale = Vector3.ONE


func settle(at: Vector3) -> void:
	global_position = at
	base_y = at.y
	home = at
	home_ready = true
	_roam_center = at
	_roam_set = true
	_goal = at
	_goal_left = 0.4


func _process(delta: float) -> void:
	if _snap_left > 0.0:
		_snap_left = maxf(_snap_left - delta, 0.0)
		if _snap_flash != null:
			var popped := 1.0 - _snap_left / 0.62
			_snap_flash.scale = Vector3.ONE * (0.25 + sin(popped * PI) * 2.4)
			_snap_flash.visible = _snap_left > 0.04
	_tick_speech(delta)
	if _is_lost_form():
		_lost_motion(delta)
		_aim_speech()
		return
	_feel_player_form(delta)
	_apply_pressure(delta)
	if char_name == "Bubble":
		var spin := Time.get_ticks_msec() / 1000.0 + phase
		position = Vector3(sin(spin) * 1.15, target_height * 4.2, cos(spin) * 1.15)
		_face_player()
		_set_locomotion("idle" if _preview == "" else _preview)
		_aim_speech()
		return
	if not home_ready:
		_aim_speech()
		return
	if _is_pinned():
		var bob := sin(Time.get_ticks_msec() / 1000.0 * 2.1 + phase) * bob_amp
		global_position = Vector3(home.x, base_y + bob, home.z)
		_face_player()
		_set_locomotion("idle")
		if _preview != "":
			_set_locomotion(_preview)
		_aim_speech()
		return
	if _wants_to_stand():
		_face_player()
		_set_locomotion("idle")
		_aim_speech()
		return
	if following:
		_follow(delta)
	else:
		_wander(delta)
	if _preview != "":
		_set_locomotion(_preview)
	_aim_speech()


func set_following(on: bool) -> void:
	if _is_pinned() or _is_lost_form():
		return
	if on and Abstraction.band(char_name) == "critical":
		show_line(Abstraction.warning(char_name, "critical"))
		return
	following = on
	if not on:
		_goal_left = 0.0
		_follow_lock = false


func decide_follow() -> void:
	if _is_lost_form():
		return
	var yes := false
	var line := _refuse_line()
	if _is_pinned():
		yes = false
	elif Abstraction.band(char_name) == "critical":
		yes = false
		var warning := Abstraction.warning(char_name, "critical")
		if warning != "":
			line = warning
	else:
		yes = randf() < _follow_chance()
		line = _agree_line() if yes else _refuse_line()
	if not _is_pinned() and not _is_lost_form():
		set_following(yes)
	_follow_yes = yes
	_follow_line = line
	_follow_lock = true
	show_line(line)
	print("FOLLOW ", char_name, " ", "yes" if yes else "no")


func follow_agreed() -> bool:
	return _follow_yes


func keep_follow_line(ai_text: String) -> String:
	if not _follow_lock:
		return ai_text
	_follow_lock = false
	var low := ai_text.to_lower()
	var says_no := _has_words(low, ["no", "nope", "nah", "won't", "wont", "will not", "not going", "staying", "stay here", "not following", "refuse", "rather not"])
	var says_yes := _has_words(low, ["yes", "yeah", "yep", "sure", "okay", "alright", "all right", "i'll come", "ill come", "i will come", "i'll follow", "ill follow", "right behind", "lead the way", "coming"])
	if _follow_yes and says_yes and not says_no:
		return ai_text
	if not _follow_yes and says_no and not says_yes:
		return ai_text
	return _follow_line


func _follow_chance() -> float:
	var chance := 0.55
	match char_name:
		"Ragatha":
			chance = 0.84
		"Gangle":
			chance = 0.62
		"Kinger":
			chance = 0.5
		"Jax":
			chance = 0.36
		"Zooble":
			chance = 0.3
		"Kaufmo":
			chance = 0.42
	var mood := Abstraction.band(char_name)
	if mood == "uneasy":
		chance -= 0.12
	elif mood == "fraying":
		chance -= 0.28
	return clampf(chance, 0.08, 0.92)


func _agree_line() -> String:
	match char_name:
		"Ragatha":
			return "Okay. I'll come with you."
		"Jax":
			return "Ugh, fine. This better be funny."
		"Gangle":
			return "Oh. Um. I'll try to keep up."
		"Zooble":
			return "Don't make it weird. I'm coming."
		"Kinger":
			return "I'll come. I think the pillows can wait."
		_:
			return "Alright. I'll follow you."


func _refuse_line() -> String:
	match char_name:
		"Ragatha":
			return "I want to help, but I'm staying here this time."
		"Jax":
			return "Nope. You don't get to tell me where to walk."
		"Gangle":
			return "I don't think I can. Sorry."
		"Zooble":
			return "No. I'm not following you around."
		"Kinger":
			return "I'll stay with the light. You go on."
		"Caine":
			return "I stay in the tent. That's the job."
		"Bubble":
			return "I'll stay with Caine."
		_:
			return "I'll stay here."


func _has_words(low: String, words: Array) -> bool:
	var padded := " " + low + " "
	for word in words:
		var piece := " " + str(word)
		if padded.contains(piece + " ") or padded.contains(piece + ".") or padded.contains(piece + ",") or padded.contains(piece + "!") or padded.contains(piece + "?"):
			return true
	return false


func set_roam_center(at: Vector3) -> void:
	_roam_center = at
	_roam_set = true
	base_y = at.y


func clear_roam_center() -> void:
	_roam_set = false
	_roam_center = home
	base_y = home.y


func _is_pinned() -> bool:
	return char_name == "Caine" or char_name == "Bubble" or char_name == "Exit" or char_name == "Suggestion Box"


func _is_lost_form() -> bool:
	return bool(get_meta("lost_one", false)) or Abstraction.is_gone(char_name)


func _apply_pressure(delta: float) -> void:
	if not Abstraction.tracks(char_name):
		return
	var amount := Abstraction.pressure(char_name)
	if _model and _model.has_method("set_strain"):
		_model.set_strain(amount)
	var mood := Abstraction.band(char_name)
	if mood == "critical":
		following = false
	if mood != "fraying" and mood != "critical":
		return
	_slip_wait -= delta
	if _slip_wait > 0.0 or _wants_to_stand():
		return
	var line := Abstraction.mutter(char_name)
	if line != "":
		show_line(line)
	_slip_wait = randf_range(12.0, 20.0)


func _lost_motion(delta: float) -> void:
	if _model and _model.has_method("set_strain"):
		_model.set_strain(1.0)
	_goal_left -= delta
	if _goal_left <= 0.0:
		var origin := _roam_origin()
		var angle := randf() * TAU
		var dist := randf_range(1.4, 6.5)
		var spot := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_goal = _clamp_roam(spot, origin, 8.5)
		_goal_left = randf_range(0.45, 1.8)
	_step_toward(_goal, delta, 0.65)
	if randf() < 0.5:
		_set_locomotion("run")
	_touch_wait = maxf(_touch_wait - delta, 0.0)
	var hit_player := false
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var person := players[0] as Node3D
		if person != null:
			var dist := global_position.distance_to(person.global_position)
			if dist < 5.5 and not Abstraction.is_gone("Pomni"):
				Abstraction.aura_tick("Pomni", delta)
			if dist < 1.7:
				hit_player = true
	var struck := hit_player
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if node == self:
			continue
		if bool(node.get_meta("lost_one", false)) or Abstraction.is_gone(str(node.get("char_name"))):
			continue
		var other := node as Node3D
		if other == null:
			continue
		var gap := global_position.distance_to(other.global_position)
		var who := str(node.get("char_name"))
		if gap < 5.5 and Abstraction.tracks(who):
			Abstraction.aura_tick(who, delta)
		if gap < 1.7:
			struck = true
	if not struck or _touch_wait > 0.0:
		return
	_touch_wait = 2.6
	if not Abstraction.spread_touch(char_name):
		return
	Music.sting_glitch()
	if hit_player and not players.is_empty():
		var person := players[0] as Node3D
		if person != null:
			var away := person.global_position - global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.FORWARD
			if person.has_method("shove"):
				person.shove(away.normalized())
			if person.has_method("glitch_burst"):
				person.glitch_burst()
			TentUI.toast(Abstraction.touch_reaction("Pomni", char_name))
	_echo_glitch(char_name)


func suffer_glitch(source: String, speak: bool) -> void:
	if _is_lost_form() or char_name == "Exit" or char_name == "Suggestion Box":
		return
	if _model != null and _model.has_method("glitch_burst"):
		_model.glitch_burst()
	if speak:
		var line := Abstraction.touch_reaction(char_name, source)
		if line != "":
			show_line(line)


func _feel_player_form(delta: float) -> void:
	if not Abstraction.is_gone("Pomni") or char_name == "Exit" or char_name == "Suggestion Box":
		return
	_touch_wait = maxf(_touch_wait - delta, 0.0)
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var person := players[0] as Node3D
	if person == null:
		return
	var dist := global_position.distance_to(person.global_position)
	if dist < 5.5 and Abstraction.tracks(char_name):
		Abstraction.aura_tick(char_name, delta)
	if dist > 1.7 or _touch_wait > 0.0:
		return
	_touch_wait = 2.6
	if not Abstraction.spread_touch("Pomni"):
		return
	Music.sting_glitch()
	if person.has_method("glitch_burst"):
		person.glitch_burst()
	suffer_glitch("Pomni", true)
	_echo_glitch("Pomni")
	TentUI.toast(Abstraction.touch_reaction(char_name, "Pomni"))


func _echo_glitch(source: String) -> void:
	var heard := false
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if node == self or not node.has_method("suffer_glitch"):
			continue
		var other := node as Node3D
		if other == null:
			continue
		var near := global_position.distance_to(other.global_position) < 18.0
		if near:
			heard = true
		node.suffer_glitch(source, near or Abstraction.tracks(str(node.get("char_name"))))
	if not heard:
		var stand_in := "Ragatha"
		for who in ["Ragatha", "Jax", "Gangle", "Zooble", "Kinger"]:
			if not Abstraction.is_gone(who) and who != source:
				stand_in = who
				break
		TentUI.toast(Abstraction.touch_reaction(stand_in, source))


func _on_crossed(who: String, mood: String) -> void:
	if who != char_name or bool(get_meta("lost_one", false)):
		return
	var line := Abstraction.warning(char_name, mood)
	if line != "":
		show_line(line)


func _on_abstracted(who: String) -> void:
	if bool(get_meta("lost_one", false)):
		return
	if who == char_name:
		_take_abstracted_form()
		if TentUI.dialogue_open and TentUI.speaker_name == char_name:
			TentUI.close_dialogue()
		return
	if Abstraction.is_gone(char_name):
		return
	var line := Abstraction.reaction(char_name, who)
	if line != "":
		show_line(line)


func _on_restored(who: String) -> void:
	if who != char_name or bool(get_meta("lost_one", false)):
		return
	_restore_form()


func _take_abstracted_form() -> void:
	following = false
	face_player = false
	if _model != null and is_instance_valid(_model):
		_model.free()
	_model = Loader.build("abstracted", target_height)
	add_child(_model)
	Loader.fit(_model, target_height)


func _restore_form() -> void:
	face_player = true
	following = false
	if _model != null and is_instance_valid(_model):
		_model.free()
	if model_id == "made":
		_model = _made_body()
		add_child(_model)
	else:
		_model = Loader.build(model_id, target_height)
		add_child(_model)
		Loader.fit(_model, target_height)
	show_line("I came back. I remember the dark. Don't ask me to describe it.")


func _wants_to_stand() -> bool:
	return TentUI.dialogue_open and TentUI.speaker_name == char_name


func _roam_origin() -> Vector3:
	if _roam_set:
		return _roam_center
	return home


func _wander(delta: float) -> void:
	_goal_left -= delta
	if _goal_left <= 0.0:
		_choose_goal()
	var arrived := _step_toward(_goal, delta, 0.85)
	if arrived:
		var bob := sin(Time.get_ticks_msec() / 1000.0 * 2.1 + phase) * bob_amp
		global_position.y = base_y + bob
		_face_player()
		_set_locomotion("idle")


func _choose_goal() -> void:
	var origin := _roam_origin()
	var pal := _nearest_pal(8.0)
	if pal != null and randf() < 0.55:
		var beside := pal.global_position + Vector3(randf_range(-1.4, 1.4), 0.0, randf_range(-1.4, 1.4))
		_goal = _clamp_roam(beside, origin, 12.0)
		_goal_left = randf_range(4.0, 7.0)
		return
	var angle := randf() * TAU
	var dist := randf_range(2.2, 8.5)
	var spot := origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	_goal = _clamp_roam(spot, origin, 12.0)
	_goal_left = randf_range(3.0, 6.5)


func _clamp_roam(spot: Vector3, origin: Vector3, reach: float) -> Vector3:
	var flat := spot - origin
	flat.y = 0.0
	if flat.length() > reach:
		flat = flat.normalized() * reach
	return Vector3(origin.x + flat.x, base_y, origin.z + flat.z)


func _nearest_pal(reach: float) -> Node3D:
	var best: Node3D = null
	var best_dist := reach
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if node == self:
			continue
		var who := str(node.get("char_name"))
		if who == "Exit" or who == "Bubble" or who == "Caine":
			continue
		if bool(node.get_meta("lost_one", false)) or Abstraction.is_gone(who):
			continue
		if bool(node.get("following")):
			continue
		var npc := node as Node3D
		if npc == null:
			continue
		var dist := global_position.distance_to(npc.global_position)
		if dist < best_dist:
			best_dist = dist
			best = npc
	return best


func _step_toward(dest: Vector3, delta: float, arrive: float) -> bool:
	var flat := Vector3(dest.x - global_position.x, 0.0, dest.z - global_position.z)
	global_position.y = base_y
	if flat.length() <= arrive:
		return true
	var running := flat.length() > 6.5
	var speed := 6.2 if running else 3.15
	var step := minf(flat.length(), speed * delta)
	global_position += flat.normalized() * step
	global_position.y = base_y
	look_at(global_position + flat.normalized(), Vector3.UP)
	_set_locomotion("run" if running else "walk")
	return false


func _follow(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var person := players[0] as Node3D
	var back := person.global_transform.basis.z
	var right := person.global_transform.basis.x
	var dest := person.global_position + back * 2.5 + right * follow_slot
	dest.y = person.global_position.y
	if stays_in_circus:
		var leash := _roam_origin()
		var away := dest - leash
		away.y = 0.0
		if away.length() > 18.0:
			dest = leash + away.normalized() * 18.0
			dest.y = base_y
	var flat := dest - global_position
	flat.y = 0.0
	if _player_is_airborne():
		global_position.y = dest.y
		_face_player()
		_set_locomotion("jump")
		return
	if flat.length() > 1.2:
		var running := flat.length() > 3.4
		var step := minf(flat.length(), (14.5 if running else 7.2) * delta)
		global_position += flat.normalized() * step
		global_position.y = dest.y
		look_at(global_position + flat.normalized(), Vector3.UP)
		_set_locomotion("run" if running else "walk")
	else:
		global_position.y = dest.y
		_face_player()
		_set_locomotion("idle")


func preview_pose(state: String) -> void:
	_preview = state
	_set_locomotion(state)


func _player_is_airborne() -> bool:
	if not joins_adventure or not Game.adventure_started:
		return false
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty() or not (players[0] is CharacterBody3D):
		return false
	return not (players[0] as CharacterBody3D).is_on_floor()


func _set_locomotion(state: String) -> void:
	if _model and _model.has_method("set_locomotion"):
		_model.set_locomotion(state)


func refine_body() -> void:
	if model_id != "made":
		return
	set_meta("made_detail", 1)
	if _model != null and is_instance_valid(_model):
		_model.free()
	_model = _made_body()
	add_child(_model)
	move_child(_model, 0)


func _made_body() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	if int(get_meta("made_detail", 0)) >= 1:
		_build_refined(root)
		root.scale = Vector3.ONE * clampf(target_height / 1.9, 0.72, 1.25)
	else:
		_build_draft(root)
	Shade.apply_to_tree(root)
	return root


func _build_draft(root: Node3D) -> void:
	var shape := str(get_meta("made_shape", "round"))
	var ink := Color(0.12, 0.08, 0.1)
	match shape:
		"tall":
			_part(root, "capsule", Vector3(0, 0.78, 0), Vector3(0.34, 1.25, 0.34), accent)
			_part(root, "sphere", Vector3(0, 1.62, 0), Vector3(0.36, 0.36, 0.36), accent.lightened(0.2))
		"box":
			_part(root, "box", Vector3(0, 0.55, 0), Vector3(0.7, 0.85, 0.45), accent)
			_part(root, "box", Vector3(0, 1.22, 0), Vector3(0.48, 0.42, 0.4), accent.lightened(0.15))
		"blob":
			_part(root, "sphere", Vector3(0, 0.48, 0), Vector3(0.85, 0.6, 0.7), accent)
			_part(root, "sphere", Vector3(0, 1.05, 0), Vector3(0.5, 0.42, 0.46), accent.lightened(0.12))
		_:
			_part(root, "sphere", Vector3(0, 0.55, 0), Vector3(0.72, 0.72, 0.72), accent)
			_part(root, "sphere", Vector3(0, 1.15, 0), Vector3(0.48, 0.48, 0.48), accent.lightened(0.18))
	var head := Vector3(0, 1.2, -0.2)
	if shape == "tall":
		head = Vector3(0, 1.66, -0.16)
	elif shape == "box":
		head = Vector3(0, 1.26, -0.2)
	elif shape == "blob":
		head = Vector3(0, 1.08, -0.2)
	_part(root, "sphere", head + Vector3(-0.1, 0.02, 0), Vector3(0.08, 0.08, 0.08), Color.WHITE)
	_part(root, "sphere", head + Vector3(0.1, 0.02, 0), Vector3(0.08, 0.08, 0.08), Color.WHITE)
	_part(root, "sphere", head + Vector3(-0.1, 0.02, -0.04), Vector3(0.04, 0.04, 0.04), ink)
	_part(root, "sphere", head + Vector3(0.1, 0.02, -0.04), Vector3(0.04, 0.04, 0.04), ink)


func _build_refined(root: Node3D) -> void:
	var shape := str(get_meta("made_shape", "round"))
	var ink := Color(0.1, 0.06, 0.08)
	var cloth := accent.darkened(0.25)
	var skin := accent.lightened(0.14)
	var wide := 1.0
	var tall := 1.0
	var boxy := false
	match shape:
		"tall":
			wide = 0.78
			tall = 1.12
		"box":
			wide = 1.1
			tall = 0.94
			boxy = true
		"blob":
			wide = 1.26
			tall = 0.84
		_:
			wide = 1.0
			tall = 1.0
	var limb := "box" if boxy else "capsule"
	var torso := "box" if boxy else "capsule"
	if shape == "blob" or shape == "round":
		torso = "sphere"
	_part(root, "box", Vector3(-0.14 * wide, 0.05, 0.04), Vector3(0.22 * wide, 0.1, 0.34), cloth)
	_part(root, "box", Vector3(0.14 * wide, 0.05, 0.04), Vector3(0.22 * wide, 0.1, 0.34), cloth)
	_part(root, limb, Vector3(-0.13 * wide, 0.4 * tall, 0), Vector3(0.16 * wide, 0.56 * tall, 0.16 * wide), cloth)
	_part(root, limb, Vector3(0.13 * wide, 0.4 * tall, 0), Vector3(0.16 * wide, 0.56 * tall, 0.16 * wide), cloth)
	_part(root, torso, Vector3(0, 0.74 * tall, 0), Vector3(0.48 * wide, 0.3 * tall, 0.32), cloth)
	_part(root, torso, Vector3(0, 1.08 * tall, 0), Vector3(0.52 * wide, 0.5 * tall, 0.36), skin)
	_part(root, "box", Vector3(0, 0.86 * tall, 0.02), Vector3(0.54 * wide, 0.08, 0.38), cloth)
	_part(root, limb, Vector3(-0.4 * wide, 0.98 * tall, 0), Vector3(0.13, 0.48 * tall, 0.13), skin)
	_part(root, limb, Vector3(0.4 * wide, 0.98 * tall, 0), Vector3(0.13, 0.48 * tall, 0.13), skin)
	_part(root, "sphere", Vector3(-0.4 * wide, 0.7 * tall, 0.02), Vector3(0.16, 0.16, 0.16), skin.lightened(0.08))
	_part(root, "sphere", Vector3(0.4 * wide, 0.7 * tall, 0.02), Vector3(0.16, 0.16, 0.16), skin.lightened(0.08))
	_part(root, "cylinder", Vector3(0, 1.36 * tall, 0), Vector3(0.14 * wide, 0.18, 0.14 * wide), skin)
	var head_y := 1.62 * tall
	var head_r := 0.3 * wide
	var head_style := str(get_meta("made_head", "box" if boxy else "round"))
	var head_size := Vector3(head_r * 2.0, head_r * 2.05, head_r * 1.9)
	if head_style == "tall":
		head_size.y *= 1.35
	elif head_style == "wide":
		head_size.x *= 1.35
		head_size.z *= 1.2
	var head_kind := "box" if head_style == "box" else "sphere"
	_part(root, head_kind, Vector3(0, head_y, 0), head_size, skin)
	_part(root, "sphere", Vector3(0, head_y + head_r * 0.78, 0.02), Vector3(head_r * 1.55, head_r * 0.72, head_r * 1.35), cloth)
	if shape == "tall":
		_part(root, "sphere", Vector3(-head_r, head_y + head_r * 0.15, 0), Vector3(0.14, 0.2, 0.1), skin)
		_part(root, "sphere", Vector3(head_r, head_y + head_r * 0.15, 0), Vector3(0.14, 0.2, 0.1), skin)
	elif shape == "blob":
		_part(root, "sphere", Vector3(-head_r * 0.85, head_y - head_r * 0.1, 0), Vector3(0.16, 0.16, 0.12), skin)
		_part(root, "sphere", Vector3(head_r * 0.85, head_y - head_r * 0.1, 0), Vector3(0.16, 0.16, 0.12), skin)
	var eye_y := head_y + head_r * 0.08
	var eye_z := -head_r * 0.86
	var eye_style := str(get_meta("made_eyes", "big"))
	var eye_r := head_r * 0.38
	if eye_style == "small":
		eye_r *= 0.62
	elif eye_style == "big":
		eye_r *= 1.28
	_eye(root, Vector3(-head_r * 0.36, eye_y, eye_z), eye_r, eye_style)
	_eye(root, Vector3(head_r * 0.36, eye_y, eye_z), eye_r, eye_style)
	_add_extra(root, Vector3(0, head_y, 0), head_r, cloth, skin)
	_part(root, "box", Vector3(-head_r * 0.36, eye_y + head_r * 0.34, eye_z - 0.02), Vector3(head_r * 0.58, 0.04, 0.04), ink)
	_part(root, "box", Vector3(head_r * 0.36, eye_y + head_r * 0.34, eye_z - 0.02), Vector3(head_r * 0.58, 0.04, 0.04), ink)
	_part(root, "box", Vector3(0, head_y - head_r * 0.42, eye_z - 0.02), Vector3(head_r * 0.72, 0.05, 0.045), ink)
	_part(root, "sphere", Vector3(-head_r * 0.55, head_y - head_r * 0.12, eye_z + 0.04), Vector3(0.07, 0.05, 0.04), accent.lightened(0.35))
	_part(root, "sphere", Vector3(head_r * 0.55, head_y - head_r * 0.12, eye_z + 0.04), Vector3(0.07, 0.05, 0.04), accent.lightened(0.35))


func _eye(root: Node3D, at: Vector3, radius: float, style: String) -> void:
	var iris := Color(0.95, 0.82, 0.2) if style == "star" else Color(0.15, 0.34, 0.82)
	var white_h := radius * 1.15 if style == "sleepy" else radius * 2.3
	_part(root, "sphere", at, Vector3(radius * 2.3, white_h, radius * 1.15), Color.WHITE)
	if style == "star":
		_part(root, "box", at + Vector3(0, 0, -radius * 0.7), Vector3(radius * 1.5, radius * 0.16, radius * 0.2), iris)
		_part(root, "box", at + Vector3(0, 0, -radius * 0.75), Vector3(radius * 0.16, radius * 1.5, radius * 0.2), iris)
		return
	_part(root, "sphere", at + Vector3(0, 0, -radius * 0.42), Vector3(radius * 1.35, radius * 1.35, radius * 0.5), iris)
	_part(root, "sphere", at + Vector3(0, 0, -radius * 0.68), Vector3(radius * 0.62, radius * 0.62, radius * 0.28), Color(0.08, 0.05, 0.08))
	_part(root, "sphere", at + Vector3(radius * 0.28, radius * 0.32, -radius * 0.82), Vector3(radius * 0.34, radius * 0.34, radius * 0.16), Color.WHITE)
	if style == "sleepy":
		_part(root, "box", at + Vector3(0, radius * 0.35, -radius * 0.2), Vector3(radius * 2.4, radius * 0.7, radius * 0.4), accent)


func _add_extra(root: Node3D, head: Vector3, head_r: float, cloth: Color, skin: Color) -> void:
	var extra := str(get_meta("made_extra", "none"))
	if extra == "hat":
		_part(root, "cylinder", head + Vector3(0, head_r * 0.95, 0), Vector3(head_r * 1.3, 0.12, head_r * 1.3), cloth)
		_part(root, "cylinder", head + Vector3(0, head_r * 1.25, 0), Vector3(head_r * 0.7, 0.38, head_r * 0.7), cloth.darkened(0.15))
	elif extra == "horns":
		_part(root, "cone", head + Vector3(-head_r * 0.55, head_r * 0.85, 0), Vector3(0.08, 0.36, 0.08), skin.darkened(0.2))
		_part(root, "cone", head + Vector3(head_r * 0.55, head_r * 0.85, 0), Vector3(0.08, 0.36, 0.08), skin.darkened(0.2))
	elif extra == "bow":
		_part(root, "sphere", head + Vector3(-head_r * 0.45, head_r * 0.7, -head_r * 0.2), Vector3(0.18, 0.14, 0.1), cloth)
		_part(root, "sphere", head + Vector3(head_r * 0.45, head_r * 0.7, -head_r * 0.2), Vector3(0.18, 0.14, 0.1), cloth)
		_part(root, "sphere", head + Vector3(0, head_r * 0.7, -head_r * 0.28), Vector3(0.1, 0.1, 0.1), cloth.darkened(0.2))
	elif extra == "antenna":
		_part(root, "cylinder", head + Vector3(0, head_r * 1.15, 0), Vector3(0.05, 0.42, 0.05), skin.darkened(0.15))
		_part(root, "sphere", head + Vector3(0, head_r * 1.45, 0), Vector3(0.16, 0.16, 0.16), cloth)


func _part(root: Node3D, kind: String, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.position = at
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "box":
		var box := BoxMesh.new()
		box.size = size
		mesh_node.mesh = box
	elif kind == "capsule":
		var capsule := CapsuleMesh.new()
		capsule.radius = size.x * 0.5
		capsule.height = maxf(size.y, size.x + 0.05)
		mesh_node.mesh = capsule
	elif kind == "cone":
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = size.x
		cone.height = size.y
		mesh_node.mesh = cone
	elif kind == "cylinder":
		var cyl := CylinderMesh.new()
		cyl.top_radius = size.x * 0.5
		cyl.bottom_radius = size.x * 0.5
		cyl.height = maxf(size.y, 0.08)
		mesh_node.mesh = cyl
	else:
		var sphere := SphereMesh.new()
		sphere.radius = size.x * 0.5
		sphere.height = size.x
		mesh_node.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_node.material_override = mat
	root.add_child(mesh_node)


func _face_player() -> void:
	if _speech_time > 0.0 and _speech_partner != null and is_instance_valid(_speech_partner):
		var toward := _speech_partner.global_position - global_position
		toward.y = 0.0
		if toward.length() > 0.35:
			look_at(global_position + toward.normalized(), Vector3.UP)
		return
	if not face_player:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var person := players[0] as Node3D
	var flat := person.global_position - global_position
	flat.y = 0.0
	if flat.length() < 0.45 or flat.length() > 18.0:
		return
	look_at(global_position + flat.normalized(), Vector3.UP)
