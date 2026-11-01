extends Node3D

const NpcScript = preload("res://scripts/npc.gd")
const Shade = preload("res://scripts/circus_shade.gd")

const HOME := Vector3(430.0, 0.0, 36.0)

var _tent_spawn := Vector3.ZERO
var _gate_tent := Vector3.ZERO
var _gate_back := Vector3.ZERO
var _inside := false
var _cool := 0.0
var _map: Node3D
var _portal_label: Label3D
var _ready_gate := false
var _plan_text := ""
var _plan_ready := false
var _expect := "invent"
var _revise_text := ""
var _revise_ready := false
var _revise_deadline := 0.0
var _plan: Dictionary = {}
var _title := "An Adventure"
var _built := false
var _stage := 0
var _clock := 0.0
var _wait_until := 0.0
var _span_from := 0.0
var _plan_deadline := 0.0
var _sketch_until := 0.0
var _prize: Node3D
var _home_open := false
var _job_giver := ""
var _job_goal := "the prize"
var _returns: Array[Vector3] = []
var _portals: Array[Node3D] = []
var _waiting := false
var _rest := 0.0
var _choice_ready := false
var _choice_use := false
var _choice_why := ""
var _choice_deadline := 0.0
var _seed := ""
var _voices: Node
var _voice_wait := false
var _voice_ready := false
var _voice_gen := 0
var _voice_busy := false
var _voice_pool_tried := false
var _voice_http: HTTPRequest
var _voice_jobs: Array = []
var _voice_picks: Array = []
var _voice_pool: Array = []
var _voice_used: Dictionary = {}


func hosting() -> bool:
	return _inside


func open_show(tent_spawn: Vector3) -> void:
	add_to_group("adventure_world")
	_tent_spawn = tent_spawn
	_gate_tent = tent_spawn + Vector3(6.4, 0.0, 0.4)
	_gate_back = HOME + Vector3(0.0, 0.45, 16.0)
	if not LocalAI.invented.is_connected(_on_invented):
		LocalAI.invented.connect(_on_invented)
	if not LocalAI.decided.is_connected(_on_decided):
		LocalAI.decided.connect(_on_decided)
	_stage = 1
	_clock = 0.0
	_wait_until = 0.0


func _process(delta: float) -> void:
	if _waiting:
		_rest -= delta
		if _rest <= 0.0 and _stage == 0 and not _inside:
			if LocalAI.design_busy():
				_rest = 1.5
			else:
				_waiting = false
				_begin_next()
	if _stage > 0 and _stage < 10:
		_clock += delta
		_paint_work()
		_run_stage()
	if not _ready_gate:
		return
	_cool = maxf(_cool - delta, 0.0)
	if _cool > 0.0:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	if player == null:
		return
	if not _inside and player.global_position.distance_to(_gate_tent) < 1.7:
		_enter(player)
	elif _inside and _home_open and _near_return(player.global_position):
		_leave(player)


func _on_decided(text: String) -> void:
	if _waiting or _stage == 0 or _expect != "choose" or _choice_ready:
		return
	var picked := _read_choice(text)
	if picked == "":
		if not LocalAI.design_busy():
			print("ADVENTURE choice retry")
			LocalAI.choose_idea()
		return
	_choice_use = picked == "use"
	_choice_why = _read_why(text)
	_choice_ready = true
	print("ADVENTURE choice ", picked)


func _on_invented(plan_text: String) -> void:
	if _waiting or _stage == 0 or _expect == "choose":
		return
	if _expect == "revise":
		var low := plan_text.to_lower()
		if low.contains("title:") and not low.contains("map:"):
			return
		if _revise_ready:
			return
		if _revision_ok(plan_text):
			_revise_text = plan_text
			_revise_ready = true
			print("ADVENTURE revise ok")
		elif not LocalAI.design_busy():
			print("ADVENTURE revise retry")
			LocalAI.revise_adventure(_brief())
		return
	if _plan_ready or _built:
		return
	if _base_ok(plan_text):
		_plan_text = plan_text
		_plan_ready = true
		print("ADVENTURE plan ok")
	elif not LocalAI.design_busy():
		print("ADVENTURE plan retry")
		LocalAI.invent_adventure(_seed if _seed != "" else LocalAI.invent_hint())


func _run_stage() -> void:
	if _clock < _wait_until:
		return
	match _stage:
		1:
			print("ADVENTURE think")
			if LocalAI.has_idea():
				_expect = "choose"
				_choice_ready = false
				_caine_say("Hold on. You gave me an idea. I am deciding whether I want yours, or mine.")
				LocalAI.choose_idea()
				TentUI.show_work("Deciding whose idea to use")
				_choice_deadline = _clock + 18.0
			else:
				_expect = "invent"
				_seed = LocalAI.invent_hint()
				_caine_say("Hold still! I am thinking up an adventure, and I will not rush it.")
				LocalAI.invent_adventure(_seed)
				TentUI.show_work("Thinking up an adventure")
			_stage = 2
			_hold(8.0)
		2:
			if _expect == "choose":
				if not _choice_ready:
					if _clock >= _choice_deadline and not LocalAI.design_busy():
						_choice_deadline = _clock + 12.0
						LocalAI.choose_idea()
					return
				_announce_choice()
				_expect = "invent"
				_seed = _invent_line()
				LocalAI.invent_adventure(_seed)
				TentUI.show_work("Thinking up an adventure")
				_stage = 3
				_plan_deadline = _clock + 18.0
				_sketch_until = _clock + 10.0
				_span_from = _clock
				_wait_until = _sketch_until
				return
			_stage = 3
			_plan_deadline = _clock + 18.0
			_sketch_until = _clock + 10.0
			_span_from = _clock
			_wait_until = _sketch_until
		3:
			if _clock < _sketch_until:
				return
			if not _plan_ready:
				if _clock >= _plan_deadline and not LocalAI.design_busy():
					_plan_deadline = _clock + 12.0
					LocalAI.invent_adventure(_seed if _seed != "" else LocalAI.invent_hint())
				return
			var plan := _parse(_plan_text)
			_plan = plan
			_title = str(plan.get("title", "An Adventure"))
			_expect = "revise"
			_revise_deadline = _clock + 24.0
			LocalAI.revise_adventure(_brief())
			_caine_say("I have it. %s. You are coming in, whether you are ready or not." % _title)
			_stage = 4
			_hold(7.0)
		4:
			if not _apply(_plan, _plan_text != ""):
				_expect = "invent"
				_plan_ready = false
				_built = false
				_stage = 3
				_sketch_until = _clock
				_plan_deadline = _clock + 12.0
				if not LocalAI.design_busy():
					LocalAI.invent_adventure(_seed if _seed != "" else LocalAI.invent_hint())
				return
			_stage = 5
			_hold(6.5)
		5:
			if not _voice_wait:
				_voice_wait = true
				_voice_ready = false
				_caine_say("Okay, I made the characters. I am searching Fish Audio for their voices.")
				_begin_voice_search()
			return
		6:
			if not _revise_ready:
				if _clock >= _revise_deadline and not LocalAI.design_busy():
					_revise_deadline = _clock + 12.0
					LocalAI.revise_adventure(_brief())
				return
			_apply_revision()
			_refine_guests()
			_stage = 7
			_hold(7.0)
		7:
			_caine_say("What should I improve for the adventure map?")
			_stage = 8
			_hold(9.0)
		8:
			_improve_map()
			_caine_say("There. Better eyes, better bodies, and a better map. This is the adventure!")
			TentUI.set_work(1.0, "The adventure is ready")
			_force_in()
			_stage = 9
			_hold(2.0)
			print("ADVENTURE showtime")
		9:
			TentUI.hide_work()
			_stage = 10


func _hold(seconds: float) -> void:
	_span_from = _clock
	_wait_until = _clock + seconds


func _paint_work() -> void:
	var caption := "Thinking up an adventure"
	var start := 0.04
	var finish := 0.18
	match _stage:
		2:
			caption = "Deciding whose idea to use" if _expect == "choose" else "Thinking up an adventure"
			start = 0.04
			finish = 0.2
		3:
			caption = "Sketching the idea"
			start = 0.2
			finish = 0.36
		4:
			caption = "Opening the adventure"
			start = 0.36
			finish = 0.5
		5:
			caption = "Looking at the characters"
			start = 0.5
			finish = 0.62
		6:
			caption = "Improving the eyes, heads, and bodies"
			start = 0.62
			finish = 0.78
		7:
			caption = "Checking the new characters"
			start = 0.78
			finish = 0.86
		8:
			caption = "Improving the adventure map"
			start = 0.86
			finish = 0.97
		9:
			caption = "The adventure is ready"
			start = 1.0
			finish = 1.0
	var span := maxf(_wait_until - _span_from, 0.001)
	var along := clampf((_clock - _span_from) / span, 0.0, 1.0)
	if _stage == 2 and _expect == "choose" and not _choice_ready and _clock >= _wait_until:
		along = 1.0
		caption = "Still deciding. Your idea, or mine?"
	elif _stage == 3 and not _plan_ready and _clock >= _sketch_until:
		along = 1.0
		caption = "Still thinking. I will not rush this."
	elif _stage == 5 and _voice_wait:
		along = 1.0
		caption = "Waiting for their voices" if _voice_ready else "Searching Fish Audio for voices"
	elif _stage == 6 and not _revise_ready:
		along = 1.0
		caption = "Still improving the characters and the map."
	TentUI.set_work(lerpf(start, finish, along), caption)


func _caine_say(line: String) -> void:
	print("ADVENTURE line ", line)
	TentUI.toast(line, 8.0)
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) == "Caine" and node.has_method("show_line"):
			node.show_line(line)
			return


func _force_in() -> void:
	if _portal_label == null:
		_raise_portal(_gate_tent, _title, Color("#ff4fa3"))
	else:
		_portal_label.text = _title
	_ready_gate = true
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	if player == null or _inside:
		return
	if TentUI.dialogue_open:
		TentUI.close_dialogue()
	_release_cellar()
	_enter(player)
	print("ADVENTURE forced")


func _apply(plan: Dictionary, from_ai: bool) -> bool:
	var people: Array = plan.get("people", [])
	var colors: Array = plan.get("colors", [])
	if people.is_empty() or colors.size() < 3:
		_built = false
		_plan_ready = false
		_expect = "invent"
		return false
	_forget_guest_voices()
	LocalAI.clear_guests()
	_built = true
	if _map != null and is_instance_valid(_map):
		_map.free()
		_map = null
	_map = Node3D.new()
	_map.name = "GeneratedAdventure"
	add_child(_map)
	_build_map(_map, plan)
	var title := str(plan.get("title", "An Adventure"))
	_title = title
	if _portal_label:
		_portal_label.text = title
	print("ADVENTURE ", "ai" if from_ai else "ready", " ", title)
	return true


func _enter(player: Node3D) -> void:
	_inside = true
	_cool = 1.6
	Game.start_adventure()
	var land := HOME + Vector3(0.0, 0.7, 12.0)
	_move_player(player, land)
	_move_party(land)
	_announce_job()


func _leave(player: Node3D) -> void:
	_inside = false
	_ready_gate = false
	_home_open = false
	_cool = 1.6
	var back := _tent_spawn + Vector3(3.2, 0.1, 0.2)
	_move_player(player, back)
	_move_party(back)
	_finish_cycle()


func _begin_next() -> void:
	if _stage != 0 or _inside or _waiting:
		return
	_caine_say("I have prepared another adventure! Gather round. I am going to make a new one, and I will not rush it.")
	_clock = 0.0
	_span_from = 0.0
	_wait_until = 4.0
	_stage = 1
	TentUI.show_work("Another adventure is coming")
	print("ADVENTURE next")


func _finish_cycle() -> void:
	if _waiting:
		return
	TentUI.hide_work()
	_stage = 0
	_clock = 0.0
	_wait_until = 0.0
	LocalAI.note_adventure("The adventure was %s. Everyone brought back %s." % [_title, _job_goal])
	_caine_say("And we're back in the tent! Wander, talk, look around. I'll decide when the next adventure is ready.")
	_cast_react()
	_clear_show()
	_waiting = true
	_rest = randf_range(48.0, 96.0)
	print("ADVENTURE rest ", snappedf(_rest, 0.1))


func _clear_show() -> void:
	_voice_wait = false
	_voice_ready = false
	_stop_voice_search()
	TentUI.close_guest_voices()
	_forget_guest_voices()
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null
	_sweep_guests()
	LocalAI.clear_guests()
	for portal in _portals:
		if is_instance_valid(portal):
			portal.queue_free()
	_portals.clear()
	_portal_label = null
	_returns.clear()
	if _prize != null and is_instance_valid(_prize):
		_prize.queue_free()
	_prize = null
	_home_open = false
	_ready_gate = false
	_built = false
	_plan_ready = false
	_plan_text = ""
	_revise_ready = false
	_revise_text = ""
	_expect = "invent"
	_plan = {}
	_choice_ready = false
	_choice_use = false
	_choice_why = ""
	_seed = ""


func _announce_choice() -> void:
	if _choice_use:
		var yours := "I thought it over. Your idea wins. I am going to try it."
		if _choice_why != "":
			yours = "I thought it over. Your idea wins. %s" % _choice_why
		_caine_say(yours)
		print("ADVENTURE choice yours")
		return
	var mine := "I thought it over. I want my own idea instead."
	if _choice_why != "":
		mine = "I thought it over. I want mine. %s" % _choice_why
	_caine_say(mine)
	print("ADVENTURE choice mine")


func _invent_line() -> String:
	var hint := LocalAI.invent_hint()
	var idea := ""
	if _choice_use:
		idea = "Build Pomni's idea as this adventure: %s Keep one character who asks Pomni to bring one thing back. The place, the people, and the goal should fit that idea." % LocalAI.idea_text()
	LocalAI.clear_idea()
	if idea == "":
		return hint
	if hint == "":
		return idea
	return idea + " " + hint


func _read_choice(text: String) -> String:
	var low := text.to_lower()
	var use := low.contains("choice: use") or low.contains("choice:use")
	var mine := low.contains("choice: mine") or low.contains("choice:mine") or low.contains("choice: my")
	if use and not mine:
		return "use"
	if mine and not use:
		return "mine"
	return ""


func _read_why(text: String) -> String:
	var why := ""
	for raw in text.split("\n"):
		var line := str(raw).strip_edges()
		if line.to_lower().begins_with("why:"):
			why = line.substr(4).strip_edges()
			break
	why = LocalAI.censor(why)
	if why.length() > 110:
		why = why.substr(0, 110).strip_edges()
	if why.to_lower().contains("choice"):
		return ""
	return why


func _sweep_guests() -> void:
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if bool(node.get_meta("adventure_guest", false)):
			node.queue_free()


func halt_for_player() -> void:
	TentUI.hide_work()
	if TentUI.dialogue_open:
		TentUI.close_dialogue()
	_stage = 0
	_waiting = false
	_rest = 0.0
	_clock = 0.0
	_wait_until = 0.0
	_expect = "invent"
	_choice_ready = false
	_ready_gate = false
	_home_open = false
	print("ADVENTURE halted")


func dismiss_adventure() -> void:
	var was_inside := _inside
	_inside = false
	if was_inside:
		_move_party(_tent_spawn + Vector3(3.2, 0.1, 0.2))
	_clear_show()


func resume_after_player() -> void:
	if Abstraction.is_gone("Pomni") or _stage != 0 or _inside or _waiting:
		return
	_waiting = true
	_rest = randf_range(48.0, 96.0)
	print("ADVENTURE rest ", snappedf(_rest, 0.1))


func _release_cellar() -> void:
	var cellar := get_tree().get_first_node_in_group("cellar_root")
	if cellar != null and cellar.has_method("release"):
		cellar.call("release")


func _cast_react() -> void:
	var again := LocalAI.adventure_count() > 1
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if bool(node.get_meta("adventure_guest", false)) or bool(node.get_meta("lost_one", false)):
			continue
		var who := str(node.get("char_name"))
		if Abstraction.is_gone(who):
			continue
		var line := _return_line(who, again)
		if line != "" and node.has_method("show_line"):
			node.show_line(line)


func _return_line(who: String, again: bool) -> String:
	match who:
		"Jax":
			return "He is really going to keep sending us out. Hilarious." if again else "Well. That happened. Don't clap."
		"Ragatha":
			return "Another one, when he's ready. I'll stay with everyone until then." if again else "We're back. I'm glad everyone made it."
		"Gangle":
			return "I can do another one. I just need a quiet minute first." if again else "I kept my mask. That's something."
		"Zooble":
			return "Of course there's going to be another one." if again else "If he sends us out again, I'm taking a minute first."
		"Kinger":
			return "We left, and then we came back. I think the pillows stayed." if again else "The tent! I knew the pillows would still be here."
		"Bubble":
			return "Pop! Home again. Caine is already thinking." if again else "Pop! Home!"
		_:
			return ""


func _move_player(player: Node3D, at: Vector3) -> void:
	player.global_position = at
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	if player.has_method("remember_spawn"):
		player.remember_spawn(at)


func _move_party(at: Vector3) -> void:
	var slot := 0
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if bool(node.get_meta("adventure_guest", false)):
			continue
		if not bool(node.get("joins_adventure")) or bool(node.get("stays_in_circus")):
			continue
		if bool(node.get_meta("lost_one", false)) or Abstraction.is_gone(str(node.get("char_name"))):
			continue
		var npc := node as Node3D
		if npc == null:
			continue
		var land := at + Vector3(-1.8 + float(slot) * 1.15, 0.0, 2.0)
		npc.global_position = land
		if _inside and npc.has_method("set_roam_center"):
			npc.set_roam_center(land)
		elif npc.has_method("clear_roam_center"):
			npc.clear_roam_center()
		slot += 1


func _build_map(root: Node3D, plan: Dictionary) -> void:
	var colors: Array = plan.get("colors", [])
	var floor_color: Color = colors[0]
	var wall_color: Color = colors[1]
	var prop_color: Color = colors[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(plan.get("title", "circus")))
	_solid(root, HOME + Vector3(0, 0.2, 0), Vector3(52, 0.4, 52), floor_color.darkened(0.08), true)
	for gx in range(-3, 4):
		for gz in range(-3, 4):
			var tile: Color = floor_color if (gx + gz) % 2 == 0 else floor_color.lightened(0.18)
			_solid(root, HOME + Vector3(gx * 6.2, 0.42, gz * 6.2), Vector3(6.0, 0.06, 6.0), tile, false)
	_wall_ring(root, wall_color)
	var sign := _caption(root, HOME + Vector3(0, 4.2, 10.0), str(plan.get("title", "Adventure")))
	sign.font_size = 96
	for i in 10:
		var kind := rng.randi() % 5
		var at := HOME + Vector3(rng.randf_range(-16.0, 16.0), 0.45, rng.randf_range(-14.0, 10.0))
		if at.distance_to(_gate_back) < 4.0:
			at.z -= 6.0
		if absf(at.x - HOME.x) < 4.5 and at.z < HOME.z + 4.0:
			continue
		_prop(root, kind, at, prop_color, wall_color, rng)
	_prepare_job(plan)
	var people: Array = plan.get("people", [])
	var shapes := ["round", "tall", "box", "blob"]
	for index in people.size():
		var person: Dictionary = people[index]
		var who := str(person.get("name", "Friend"))
		var about := str(person.get("about", ""))
		var stand := HOME + Vector3(-6.0 + float(index) * 6.0, 0.45, 4.0)
		if who == _job_giver:
			stand = HOME + Vector3(-4.2, 0.45, 9.0)
			about += " You need Pomni to bring back %s. The way home stays shut until they have it." % _job_goal
		_make_guest(root, stand, who, person.get("color", prop_color), about, shapes[index % shapes.size()], 1.45 + float(index) * 0.12)
	var lamp := OmniLight3D.new()
	lamp.position = HOME + Vector3(0, 8, 0)
	lamp.light_color = floor_color.lightened(0.4)
	lamp.light_energy = 1.1
	lamp.omni_range = 40.0
	lamp.shadow_enabled = false
	root.add_child(lamp)
	_build_errand(root, floor_color, wall_color, prop_color)


func _prepare_job(plan: Dictionary) -> void:
	var job: Dictionary = plan.get("job", {})
	_job_giver = str(job.get("giver", "Friend"))
	_job_goal = str(job.get("stolen", "the prize"))
	_home_open = false
	_returns.clear()


func _build_errand(root: Node3D, floor_color: Color, _wall_color: Color, prop_color: Color) -> void:
	var spot := HOME + Vector3(0.0, 1.15, -14.0)
	_prize = _make_prize(spot, prop_color)
	root.add_child(_prize)
	_caption(root, spot + Vector3(0.0, 2.1, 0.0), _job_goal.to_upper())
	_solid(root, spot + Vector3(0.0, 0.35, 0.0), Vector3(1.4, 0.7, 1.4), floor_color.lightened(0.08), true)


func _make_prize(at: Vector3, color: Color) -> Node3D:
	var prize := Node3D.new()
	prize.position = at
	prize.name = "StolenPrize"
	_decor(prize, "sphere", Vector3.ZERO, 0.42, color.lightened(0.2))
	_caption(prize, Vector3(0, 0.9, 0), _job_goal.to_upper())
	return prize


func _announce_job() -> void:
	var line := "%s needs you to bring back %s. It is further in. The way back to the circus opens when you have it." % [_job_giver, _job_goal]
	TentUI.toast(line, 8.0)
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) == _job_giver and node.has_method("show_line"):
			node.show_line(line)
			return


func job_prompt(at: Vector3) -> String:
	if not _inside or not _built or _home_open:
		return ""
	if _prize != null and is_instance_valid(_prize) and at.distance_to(_prize.global_position) < 3.4:
		return "E    Take %s" % _job_goal
	return ""


func try_job(player: Node3D) -> bool:
	if player == null or not _inside or not _built or _home_open:
		return false
	if _prize != null and is_instance_valid(_prize) and player.global_position.distance_to(_prize.global_position) < 3.4:
		_grab_prize(player)
		return true
	return false


func _grab_prize(player: Node3D) -> void:
	if _home_open:
		return
	var colors: Array = _plan.get("colors", [])
	var portal_color: Color = colors[2] if colors.size() > 2 else Color("#ff4fa3")
	if _prize != null and is_instance_valid(_prize):
		_prize.queue_free()
	_prize = null
	_home_open = true
	var ahead := player.global_position - player.global_transform.basis.z * 3.5
	ahead.y = HOME.y + 0.45
	_open_return(ahead, portal_color)
	_open_return(HOME + Vector3(0.0, 0.45, 16.0), portal_color)
	TentUI.toast("You have %s. The way back to the circus is open." % _job_goal)
	print("ADVENTURE home open")


func _open_return(at: Vector3, color: Color) -> void:
	for spot in _returns:
		if spot.distance_to(at) < 2.0:
			return
	_returns.append(at)
	_raise_portal(at, "BACK TO THE CIRCUS", color)


func _near_return(at: Vector3) -> bool:
	for spot in _returns:
		if at.distance_to(spot) < 2.2:
			return true
	return false


func _make_guest(root: Node3D, at: Vector3, who: String, color: Color, about: String, shape: String, height: float) -> void:
	LocalAI.register_guest(who, about)
	var npc := Node3D.new()
	npc.set_script(NpcScript)
	npc.setup("made", who, color, 0.0, 0.02, height, true, false, 0.0)
	npc.set_meta("made_shape", shape)
	npc.set_meta("adventure_guest", true)
	root.add_child(npc)
	npc.plant(at)


func _begin_voice_search() -> void:
	_stop_voice_search()
	_voice_gen += 1
	_voice_busy = false
	_voice_ready = false
	_voice_pool_tried = false
	_voice_jobs.clear()
	_voice_picks.clear()
	_voice_pool.clear()
	_voice_used.clear()
	_voice_http = HTTPRequest.new()
	_voice_http.timeout = 20.0
	_voice_http.set_meta("gen", _voice_gen)
	_voice_http.request_completed.connect(_on_voice_http)
	add_child(_voice_http)
	var people: Array = _plan.get("people", [])
	for person in people:
		if typeof(person) != TYPE_DICTIONARY:
			continue
		var who := str(person.get("name", "")).strip_edges()
		if who == "":
			continue
		_voice_jobs.append({
			"name": who,
			"words": _voice_words(str(person.get("about", "")) + " " + who),
			"step": 0,
		})
	_pump_voice_search()


func _stop_voice_search() -> void:
	_voice_gen += 1
	_voice_busy = false
	_voice_jobs.clear()
	if _voice_http != null and is_instance_valid(_voice_http):
		if _voice_http.request_completed.is_connected(_on_voice_http):
			_voice_http.request_completed.disconnect(_on_voice_http)
		_voice_http.cancel_request()
		_voice_http.queue_free()
	_voice_http = null


func _pump_voice_search() -> void:
	if _voice_busy:
		return
	if _voice_jobs.is_empty():
		if not _voice_ready and _stage == 5 and _voice_wait:
			_voice_ready = true
			print("VOICE SEARCH done ", _voice_picks.size())
			TentUI.ask_guest_voices(_voice_picks, _on_voices_done)
		return
	var job: Dictionary = _voice_jobs[0]
	var words: PackedStringArray = job.get("words", PackedStringArray())
	var step := int(job.get("step", 0))
	if step < words.size():
		_request_voices(words[step], false)
	elif not _voice_pool_tried:
		_voice_pool_tried = true
		_request_voices("", true)
	else:
		_finish_voice_job(_pick_voice(_voice_pool))


func _request_voices(title: String, popular: bool) -> void:
	if _voice_http == null:
		return
	var sort := "task_count" if popular else "score"
	var url := "https://api.fish.audio/model?language=en&page_size=12&sort_by=%s" % sort
	if title != "":
		url += "&title=" + title.uri_encode()
	var headers := PackedStringArray([
		"Authorization: Bearer " + str(preload("res://scripts/caine_voice.gd").account_key("caine")),
	])
	_voice_busy = true
	_voice_http.set_meta("popular", popular)
	var err := _voice_http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("VOICE SEARCH request failed ", err)
		_voice_busy = false
		_finish_voice_job({})


func _on_voice_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _voice_http == null or int(_voice_http.get_meta("gen", -1)) != _voice_gen:
		return
	_voice_busy = false
	var popular := bool(_voice_http.get_meta("popular", false))
	var items: Array = []
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY:
			var data: Dictionary = parsed
			var found = data.get("items", [])
			if typeof(found) == TYPE_ARRAY:
				items = found
	else:
		print("VOICE SEARCH ", code)
	if popular:
		_voice_pool = items
		_finish_voice_job(_pick_voice(_voice_pool))
		return
	var pick := _pick_voice(items)
	if not pick.is_empty():
		_finish_voice_job(pick)
		return
	if not _voice_jobs.is_empty():
		var job: Dictionary = _voice_jobs[0]
		job["step"] = int(job.get("step", 0)) + 1
	_pump_voice_search()


func _finish_voice_job(pick: Dictionary) -> void:
	if _voice_jobs.is_empty():
		_pump_voice_search()
		return
	var job: Dictionary = _voice_jobs.pop_front()
	var voice_id := str(pick.get("id", ""))
	var voice_title := str(pick.get("title", "")).strip_edges()
	if voice_id != "":
		_voice_used[voice_id] = true
	if voice_title == "":
		voice_title = "No voice found"
	_voice_picks.append({
		"name": str(job.get("name", "")),
		"voice": voice_id,
		"title": voice_title,
	})
	print("VOICE SEARCH ", job.get("name", ""), " ", voice_title)
	_pump_voice_search()


func _pick_voice(items: Array) -> Dictionary:
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = item
		if str(data.get("type", "tts")) != "tts":
			continue
		if str(data.get("state", "")) == "failed":
			continue
		var voice_id := str(data.get("_id", ""))
		if voice_id == "" or _voice_used.has(voice_id):
			continue
		return {"id": voice_id, "title": str(data.get("title", "Voice"))}
	return {}


func _voice_words(about: String) -> PackedStringArray:
	var liked := {
		"young": true, "old": true, "deep": true, "soft": true, "warm": true, "cold": true,
		"cute": true, "silly": true, "serious": true, "robot": true, "child": true,
		"woman": true, "man": true, "girl": true, "boy": true, "queen": true, "king": true,
		"pirate": true, "wizard": true, "narrator": true, "british": true, "gentle": true,
		"gruff": true, "bright": true, "dark": true, "tiny": true, "giant": true,
		"knight": true, "witch": true, "fairy": true, "monster": true, "hero": true,
		"villain": true, "singer": true, "chef": true, "baker": true, "captain": true,
		"princess": true, "prince": true, "cowboy": true, "grandma": true, "grandpa": true,
	}
	var skip := {
		"the": true, "and": true, "with": true, "who": true, "their": true, "they": true,
		"from": true, "that": true, "this": true, "for": true, "you": true, "are": true,
		"was": true, "has": true, "her": true, "his": true, "she": true, "him": true,
		"into": true, "your": true, "about": true, "very": true, "just": true, "like": true,
	}
	var traits: PackedStringArray = []
	var other: PackedStringArray = []
	for bit in about.to_lower().split(" ", false):
		var clean := ""
		var lowered := bit.to_lower()
		for i in lowered.length():
			var letter := lowered.substr(i, 1)
			if letter >= "a" and letter <= "z":
				clean += letter
		if clean.length() < 3 or skip.has(clean):
			continue
		if liked.has(clean) and not traits.has(clean):
			traits.append(clean)
		elif not other.has(clean):
			other.append(clean)
	var words: PackedStringArray = []
	for word in traits:
		if words.size() >= 3:
			break
		words.append(word)
	for word in other:
		if words.size() >= 3:
			break
		words.append(word)
	if words.is_empty():
		words.append("narrator")
	return words


func _guest_names() -> Array:
	var names: Array = []
	var people: Array = _plan.get("people", [])
	for person in people:
		if typeof(person) != TYPE_DICTIONARY:
			continue
		var who := str(person.get("name", "")).strip_edges()
		if who != "":
			names.append(who)
	return names


func _on_voices_done(rows: Array) -> void:
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = row
		var who := str(data.get("name", ""))
		var key := str(data.get("key", ""))
		var voice := str(data.get("voice", ""))
		for node in get_tree().get_nodes_in_group("circus_npc"):
			if not bool(node.get_meta("adventure_guest", false)):
				continue
			if str(node.get("char_name")) != who:
				continue
			if node.has_method("grant_fish_login"):
				node.call("grant_fish_login", key, voice)
			break
	_voice_wait = false
	_caine_say("How can I improve the eyes, the head, and the body?")
	_stage = 6
	_hold(9.0)


func _forget_guest_voices() -> void:
	if _voices != null and _voices.has_method("discard"):
		_voices.call("discard")


func _wall_ring(root: Node3D, color: Color) -> void:
	_solid(root, HOME + Vector3(-13.5, 2.2, -22), Vector3(18.0, 4.0, 0.8), color, true)
	_solid(root, HOME + Vector3(13.5, 2.2, -22), Vector3(18.0, 4.0, 0.8), color, true)
	_solid(root, HOME + Vector3(-22, 2.2, 0), Vector3(0.8, 4.0, 40), color, true)
	_solid(root, HOME + Vector3(22, 2.2, 0), Vector3(0.8, 4.0, 40), color, true)
	_solid(root, HOME + Vector3(-14, 2.2, 22), Vector3(16, 4.0, 0.8), color, true)
	_solid(root, HOME + Vector3(14, 2.2, 22), Vector3(16, 4.0, 0.8), color, true)


func _prop(root: Node3D, kind: int, at: Vector3, color: Color, trim: Color, rng: RandomNumberGenerator) -> void:
	match kind:
		0:
			_solid(root, at + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 2.2), color, true)
			_decor(root, "sphere", at + Vector3(0, 1.3, 0), 0.55, trim)
		1:
			_solid(root, at + Vector3(0, 0.7, 0), Vector3(3.4, 0.35, 3.4), trim, true)
			_decor(root, "cone", at + Vector3(0, 1.5, 0), 0.7, color)
		2:
			_decor(root, "cylinder", at + Vector3(0, 1.3, 0), 0.35, color)
			_decor(root, "sphere", at + Vector3(0, 2.5, 0), 0.55, trim)
		3:
			_solid(root, at + Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 1.4), color, true)
			_solid(root, at + Vector3(0.4, 1.05, 0), Vector3(1.0, 0.7, 1.0), trim, true)
		_:
			_decor(root, "torus", at + Vector3(0, 1.6, 0), 0.9, color)


func _raise_portal(at: Vector3, caption: String, color: Color, root: Node3D = null) -> void:
	var host: Node3D = self if root == null else root
	var frame := Node3D.new()
	frame.position = at
	host.add_child(frame)
	if host == self:
		_portals.append(frame)
	_solid(frame, Vector3(-1.3, 1.5, 0), Vector3(0.28, 3.0, 0.28), color, false)
	_solid(frame, Vector3(1.3, 1.5, 0), Vector3(0.28, 3.0, 0.28), color, false)
	_solid(frame, Vector3(0, 3.05, 0), Vector3(2.9, 0.28, 0.28), color.lightened(0.15), false)
	var veil := MeshInstance3D.new()
	var sheet := QuadMesh.new()
	sheet.size = Vector2(2.2, 2.6)
	veil.mesh = sheet
	veil.position = Vector3(0, 1.55, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.38)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil.material_override = mat
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.add_child(veil)
	var label := _caption(frame, Vector3(0, 3.55, 0), caption)
	if root == null:
		_portal_label = label


func _caption(parent: Node3D, at: Vector3, text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 56
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0, 1)
	label.modulate = Color(1, 0.97, 0.9)
	parent.add_child(label)
	return label


func _solid(parent: Node3D, at: Vector3, size: Vector3, color: Color, collide: bool) -> void:
	var body := StaticBody3D.new() if collide else Node3D.new()
	body.position = at
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_node.material_override = mat
	body.add_child(mesh_node)
	if collide:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
	parent.add_child(body)
	Shade.apply_to_tree(mesh_node)


func _decor(parent: Node3D, kind: String, at: Vector3, scale: float, color: Color) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.position = at
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "cone":
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = scale
		cone.height = scale * 1.8
		mesh_node.mesh = cone
	elif kind == "cylinder":
		var cyl := CylinderMesh.new()
		cyl.top_radius = scale
		cyl.bottom_radius = scale
		cyl.height = scale * 4.0
		mesh_node.mesh = cyl
	elif kind == "torus":
		var ring := TorusMesh.new()
		ring.inner_radius = scale * 0.55
		ring.outer_radius = scale
		mesh_node.mesh = ring
		mesh_node.rotation.x = PI * 0.5
	else:
		var sphere := SphereMesh.new()
		sphere.radius = scale
		sphere.height = scale * 2.0
		mesh_node.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_node.material_override = mat
	parent.add_child(mesh_node)
	Shade.apply_to_tree(mesh_node)


func _refine_guests() -> void:
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if not bool(node.get_meta("adventure_guest", false)):
			continue
		if node.has_method("refine_body"):
			node.refine_body()
	print("ADVENTURE refined characters")


func _apply_revision() -> void:
	var notes := _parse_revision(_revise_text)
	var looks: Dictionary = notes.get("looks", {})
	var features: Array = notes.get("features", [])
	_plan["features"] = features
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if not bool(node.get_meta("adventure_guest", false)):
			continue
		var key := str(node.get("char_name")).to_lower()
		if not looks.has(key):
			continue
		var look: Dictionary = looks[key]
		node.set_meta("made_head", str(look.get("head", "round")))
		node.set_meta("made_eyes", str(look.get("eyes", "big")))
		node.set_meta("made_extra", str(look.get("extra", "none")))
	print("ADVENTURE notes ", features.size(), " features")


func _improve_map() -> void:
	if _map == null or not is_instance_valid(_map):
		return
	var colors: Array = _plan.get("colors", [])
	if colors.size() < 3:
		return
	var floor_color: Color = colors[0]
	var wall_color: Color = colors[1]
	var prop_color: Color = colors[2]
	var trim: Color = prop_color.lightened(0.22)
	var features: Array = _plan.get("features", [])
	for feature in features:
		_add_feature(str(feature), floor_color, wall_color, prop_color, trim)
	print("ADVENTURE improved map ", features)


func _add_feature(feature: String, floor_color: Color, wall_color: Color, prop_color: Color, trim: Color) -> void:
	match feature:
		"path":
			for step in range(-2, 3):
				_solid(_map, HOME + Vector3(0, 0.5, float(step) * 4.2), Vector3(2.4, 0.08, 3.4), trim, false)
		"fountain":
			var fountain := HOME + Vector3(0, 0.45, -8)
			_solid(_map, fountain, Vector3(3.2, 0.45, 3.2), wall_color, true)
			_decor(_map, "cylinder", fountain + Vector3(0, 0.55, 0), 0.35, trim)
			_decor(_map, "sphere", fountain + Vector3(0, 1.7, 0), 0.42, prop_color)
		"lamps":
			for side_index in 2:
				var side := -1.0 if side_index == 0 else 1.0
				var lamp_at := HOME + Vector3(side * 8.0, 0.45, 4.0)
				_decor(_map, "cylinder", lamp_at + Vector3(0, 1.1, 0), 0.12, wall_color)
				_decor(_map, "sphere", lamp_at + Vector3(0, 2.5, 0), 0.38, trim)
				var glow := OmniLight3D.new()
				glow.position = lamp_at + Vector3(0, 2.5, 0)
				glow.light_color = trim
				glow.light_energy = 0.8
				glow.omni_range = 8.0
				glow.shadow_enabled = false
				_map.add_child(glow)
		"trees":
			var trees: Array[Vector3] = [Vector3(-12, 0.45, -4), Vector3(12, 0.45, -2), Vector3(-11, 0.45, 11), Vector3(11, 0.45, 9)]
			for spot in trees:
				var tree := HOME + spot
				_decor(_map, "cylinder", tree + Vector3(0, 0.7, 0), 0.16, wall_color.darkened(0.3))
				_decor(_map, "sphere", tree + Vector3(0, 1.8, 0), 0.7, prop_color)
				_decor(_map, "sphere", tree + Vector3(0.3, 2.15, 0.2), 0.4, floor_color)
		"platforms":
			_solid(_map, HOME + Vector3(-9, 0.85, -12), Vector3(3.2, 0.4, 3.2), floor_color.lightened(0.1), true)
			_solid(_map, HOME + Vector3(9, 1.05, -12), Vector3(2.6, 0.7, 2.6), wall_color, true)
		"arch":
			_solid(_map, HOME + Vector3(-2.2, 1.6, -14), Vector3(0.4, 2.4, 0.4), trim, true)
			_solid(_map, HOME + Vector3(2.2, 1.6, -14), Vector3(0.4, 2.4, 0.4), trim, true)
			_solid(_map, HOME + Vector3(0, 2.9, -14), Vector3(5.0, 0.4, 0.4), prop_color, true)
		"towers":
			_solid(_map, HOME + Vector3(-16, 2.4, -16), Vector3(1.6, 4.4, 1.6), wall_color, true)
			_decor(_map, "cone", HOME + Vector3(-16, 4.8, -16), 0.9, trim)
			_solid(_map, HOME + Vector3(16, 2.4, -16), Vector3(1.6, 4.4, 1.6), wall_color, true)
			_decor(_map, "cone", HOME + Vector3(16, 4.8, -16), 0.9, trim)
		"bridge":
			_solid(_map, HOME + Vector3(0, 0.85, -4), Vector3(8.0, 0.28, 2.2), trim, true)
			_solid(_map, HOME + Vector3(-3.6, 1.35, -4), Vector3(0.28, 0.8, 2.2), wall_color, false)
			_solid(_map, HOME + Vector3(3.6, 1.35, -4), Vector3(0.28, 0.8, 2.2), wall_color, false)
		"pool":
			_solid(_map, HOME + Vector3(-11, 0.52, -7), Vector3(4.2, 0.16, 4.2), floor_color.lightened(0.35), true)
			_decor(_map, "sphere", HOME + Vector3(-11, 0.75, -7), 0.28, trim)
		"stage":
			_solid(_map, HOME + Vector3(0, 0.7, -16), Vector3(8.0, 0.5, 4.0), prop_color, true)
			_solid(_map, HOME + Vector3(0, 2.2, -18), Vector3(8.0, 2.4, 0.4), wall_color, true)
		"rings":
			_decor(_map, "torus", HOME + Vector3(-6, 1.5, -10), 0.8, prop_color)
			_decor(_map, "torus", HOME + Vector3(6, 2.0, -6), 0.6, trim)
			_decor(_map, "torus", HOME + Vector3(0, 2.4, 2), 0.7, wall_color)


func _brief() -> String:
	var lines := "Adventure: %s\n" % _title
	var people: Array = _plan.get("people", [])
	for index in people.size():
		var person: Dictionary = people[index]
		var who := str(person.get("name", "Friend"))
		var about := str(person.get("about", "friendly"))
		lines += "NPC: %s | %s\n" % [who, about]
	return lines


func _base_ok(text: String) -> bool:
	var low := text.to_lower()
	if not low.contains("title:") or not low.contains("npc:"):
		return false
	var plan := _parse(text)
	var people: Array = plan.get("people", [])
	return str(plan.get("title", "")) != "" and people.size() > 0


func _revision_ok(text: String) -> bool:
	var notes := _parse_revision(text)
	var features: Array = notes.get("features", [])
	return not features.is_empty()


func _parse_revision(text: String) -> Dictionary:
	var looks := {}
	var features: Array[String] = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		var low := line.to_lower()
		if low.begins_with("char:"):
			var bits := line.substr(5).split("|")
			var who := _clean_name(bits[0] if bits.size() > 0 else "")
			if who == "":
				continue
			var head := _word_choice(bits[1] if bits.size() > 1 else "", ["round", "box", "tall", "wide"], "round")
			var eyes := _word_choice(bits[2] if bits.size() > 2 else "", ["big", "small", "sleepy", "star"], "big")
			var extra := _word_choice(bits[3] if bits.size() > 3 else "", ["hat", "horns", "bow", "antenna", "none"], "none")
			looks[who.to_lower()] = {"head": head, "eyes": eyes, "extra": extra}
		elif low.begins_with("map:"):
			for word in line.substr(4).split(","):
				var feature := _feature_word(word.strip_edges().to_lower())
				if feature != "" and not features.has(feature):
					features.append(feature)
	return {"looks": looks, "features": features}


func _parse(text: String) -> Dictionary:
	var title := ""
	var colors: Array[Color] = []
	var people: Array = []
	var job_giver := ""
	var job_stolen := ""
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		var low := line.to_lower()
		if low.begins_with("title:"):
			title = _short(line.substr(6).strip_edges(), 42)
		elif low.begins_with("colors:"):
			for word in line.substr(7).split(","):
				var found := _color_word(word.strip_edges().to_lower())
				if found != Color.BLACK:
					colors.append(found)
		elif low.begins_with("npc:"):
			var rest := line.substr(4).strip_edges()
			var bits := rest.split("|")
			var who := _clean_name(bits[0] if bits.size() > 0 else "")
			var about := _short(bits[1].strip_edges() if bits.size() > 1 else "friendly and curious", 140)
			if who != "":
				people.append({"name": who, "about": about})
		elif low.begins_with("job:"):
			var bits := line.substr(4).split("|")
			job_giver = _clean_name(bits[0] if bits.size() > 0 else "")
			job_stolen = _thing_name(bits[1] if bits.size() > 1 else "")
	if title == "" or people.is_empty():
		return {"title": "", "colors": colors, "people": []}
	var painted: Array[Color] = _fill_colors(title, colors)
	var used := {}
	var kept: Array = []
	for index in people.size():
		var person: Dictionary = people[index]
		var who: String = str(person.get("name", ""))
		if used.has(who.to_lower()):
			continue
		used[who.to_lower()] = true
		person["color"] = painted[kept.size() % painted.size()]
		kept.append(person)
		if kept.size() == 3:
			break
	var job := _finish_job(title, kept, job_giver, job_stolen)
	return {"title": title, "colors": painted, "people": kept, "job": job}


func _finish_job(title: String, people: Array, giver: String, stolen: String) -> Dictionary:
	var names: Array[String] = []
	for index in people.size():
		var person: Dictionary = people[index]
		names.append(str(person.get("name", "")))
	if giver == "" or not names.has(giver):
		giver = names[0] if not names.is_empty() else "Friend"
	if stolen == "":
		stolen = _thing_from_title(title)
	return {"giver": giver, "stolen": stolen}


func _thing_name(raw: String) -> String:
	var clean := _short(raw.strip_edges().trim_prefix("the ").trim_prefix("The "), 32)
	if clean == "":
		return ""
	return "the " + clean


func _thing_from_title(title: String) -> String:
	var skip := ["the", "a", "an", "of", "and", "adventure"]
	var kept: Array[String] = []
	for word in title.split(" ", false):
		if skip.has(word.to_lower()):
			continue
		kept.append(word)
	if kept.is_empty():
		return "the prize"
	var tail := kept[kept.size() - 1]
	if kept.size() > 1:
		tail = kept[kept.size() - 2] + " " + tail
	return "the " + tail.to_lower()


func _fill_colors(title: String, colors: Array[Color]) -> Array[Color]:
	var painted: Array[Color] = []
	for color in colors:
		painted.append(color)
	var extra := 0
	while painted.size() < 3:
		var hue := float(absi(hash(title + str(extra))) % 360) / 360.0
		painted.append(Color.from_hsv(hue, 0.72, 0.95))
		extra += 1
	return painted


func _word_choice(text: String, allowed: Array, fallback: String) -> String:
	var low := text.to_lower()
	for word in allowed:
		if low.contains(str(word)):
			return str(word)
	return fallback


func _feature_word(word: String) -> String:
	if word.contains("bridge"):
		return "bridge"
	if word.contains("tower") or word.contains("spire") or word.contains("castle"):
		return "towers"
	if word.contains("pool") or word.contains("pond") or word.contains("lake") or word.contains("water"):
		return "pool"
	if word.contains("arch"):
		return "arch"
	if word.contains("path") or word.contains("road"):
		return "path"
	if word.contains("lamp") or word.contains("light") or word.contains("lantern"):
		return "lamps"
	if word.contains("tree") or word.contains("forest") or word.contains("plant"):
		return "trees"
	if word.contains("stage"):
		return "stage"
	if word.contains("fountain"):
		return "fountain"
	if word.contains("platform") or word.contains("stair") or word.contains("step"):
		return "platforms"
	if word.contains("ring"):
		return "rings"
	return ""


func _color_word(word: String) -> Color:
	match word:
		"red":
			return Color(0.9, 0.16, 0.2)
		"blue":
			return Color(0.2, 0.38, 0.92)
		"yellow":
			return Color(0.98, 0.8, 0.16)
		"green":
			return Color(0.16, 0.74, 0.3)
		"pink":
			return Color(0.95, 0.36, 0.62)
		"purple":
			return Color(0.55, 0.24, 0.86)
		"orange":
			return Color(0.95, 0.46, 0.12)
		"gold":
			return Color(0.95, 0.72, 0.22)
		"cyan":
			return Color(0.22, 0.82, 0.95)
		_:
			return Color.BLACK


func _clean_name(raw: String) -> String:
	var out := ""
	for index in raw.length():
		var letter := raw.substr(index, 1)
		var code := letter.unicode_at(0)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or letter == " ":
			out += letter
	out = out.strip_edges()
	if out.length() > 16:
		out = out.substr(0, 16).strip_edges()
	var blocked := ["pomni", "jax", "ragatha", "gangle", "zooble", "kinger", "caine", "bubble", "exit", "queenie", "kaufmo", "gummigoo", "martha", "ribbit", "orbsman", "fudge", "moon", "sun", "fish", "shrimp", "gloink", "mannequin", "ghostly", "loolilalu", "baron", "max", "chad"]
	if out == "" or blocked.has(out.to_lower()):
		return ""
	return out


func _short(text: String, limit: int) -> String:
	var clean := text.strip_edges()
	if clean.length() > limit:
		clean = clean.substr(0, limit).strip_edges()
	return clean
