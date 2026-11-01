extends CanvasLayer

var dialogue_open := false
var paused := false
var gameplay_on := false
var speaker_name := ""

var _root: Control
var _loading: Control
var _loading_label: Label
var _loading_fill: ColorRect
var _orb_label: Label
var _prompt: Label
var _hint: Label
var _compass: Control
var _arrow: Label
var _distance: Label
var _banner: Label
var _toast: Label
var _toast_tween: Tween
var _work: Control
var _work_title: Label
var _work_status: Label
var _work_fill: ColorRect
var _censoring_entry := false
var _panel: PanelContainer
var _speaker: Label
var _body: Label
var _choices: VBoxContainer
var _entry: LineEdit
var _pause: Control
var _talk: Button
var _cast_scroll: ScrollContainer
var _cast: HBoxContainer
var _tree: Dictionary = {}
var _veil: ColorRect
var _voice_form := false
var _voice_panel: Control
var _voice_rows: VBoxContainer
var _voice_done: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	Game.progress_changed.connect(_on_progress)
	Game.adventure_completed.connect(_on_complete)
	LocalAI.reply.connect(_on_ai_reply)
	_on_progress()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _voice_form:
			get_viewport().set_input_as_handled()
			return
		if dialogue_open:
			close_dialogue()
		elif gameplay_on:
			toggle_pause()
		get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	if gameplay_on and not paused:
		_update_compass()


func is_dialogue_open() -> bool:
	return dialogue_open


func blocks_look() -> bool:
	return dialogue_open or paused or not gameplay_on or _voice_form


func show_loading(text: String) -> void:
	_loading.visible = true
	_loading_label.text = text
	_set_progress(0.08)


func set_loading(fraction: float, text: String) -> void:
	_loading.visible = true
	_loading_label.text = text
	_set_progress(fraction)


func hide_loading() -> void:
	_loading.visible = false


func show_gameplay(on: bool) -> void:
	gameplay_on = on
	_orb_label.visible = false
	_compass.visible = false
	_hint.visible = on
	_talk.visible = on
	_prompt.visible = false
	if on:
		_fade_hint()
	else:
		_banner.visible = false
		_toast.visible = false


func set_strain_overlay(amount: float) -> void:
	if _veil == null:
		return
	var alpha := 0.0
	if amount > 0.28:
		alpha = (amount - 0.28) * 0.62
	_veil.color = Color(0.2, 0.0, 0.02, clampf(alpha, 0.0, 0.55))


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = gameplay_on and text != "" and not dialogue_open


func open_chat(speaker: String, accent: Color) -> void:
	if paused:
		return
	var already := dialogue_open
	dialogue_open = true
	_panel.visible = true
	_clear_choices()
	_entry.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_cast()
	_show_speaker(speaker, accent, already)
	_entry.grab_focus()


func _show_speaker(speaker: String, accent: Color, already_open: bool = true) -> void:
	var waiting := already_open and speaker == speaker_name and _body.text == "..."
	speaker_name = speaker
	_speaker.text = speaker.to_upper()
	_speaker.add_theme_color_override("font_color", accent)
	_mark_cast()
	if waiting:
		return
	var previous := LocalAI.last_reply(speaker)
	if previous != "":
		_body.text = previous
		return
	_body.text = "..."
	LocalAI.ask(speaker, "")


func _switch_chat(speaker: String, accent: Color) -> void:
	if paused:
		return
	if not dialogue_open:
		Music.blip_talk()
		open_chat(speaker, accent)
		return
	if speaker == speaker_name:
		_entry.grab_focus()
		return
	Music.blip_talk()
	_entry.text = ""
	_show_speaker(speaker, accent)
	_entry.grab_focus()


func _send_chat(text: String) -> void:
	var line := LocalAI.censor(text.strip_edges())
	if line == "" or speaker_name == "":
		return
	_entry.text = ""
	_body.text = line
	_apply_orders(speaker_name, line)
	if speaker_name == "Caine" and _is_idea(line):
		LocalAI.offer_idea(line)
	Abstraction.notice_speech(speaker_name, line)
	if speaker_name == "Caine" and _help_request(line) and Abstraction.help_pomni():
		var saved := "Hold still. I can pull you back. You are Pomni."
		_show_world_line("Caine", saved)
		if dialogue_open:
			_body.text = saved
		toast("Caine pulls you back. You are yourself again.")
		return
	if _follow_request(line) and not _stop_request(line):
		LocalAI.ask_decided(speaker_name, line, _speaker_agreed(speaker_name))
	else:
		LocalAI.ask(speaker_name, line)


func _apply_orders(speaker: String, line: String) -> void:
	var low := line.to_lower()
	var stop := _stop_request(line)
	var go := _follow_request(line)
	if not stop and not go:
		return
	var everyone := _has_phrase(low, ["everyone", "everybody", "all of you", "you all", "you guys", "the group"])
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if bool(node.get_meta("lost_one", false)) or Abstraction.is_gone(str(node.get("char_name"))):
			continue
		var who := str(node.get("char_name"))
		if not everyone and who != speaker:
			continue
		if stop and node.has_method("set_following"):
			node.set_following(false)
		elif go and node.has_method("decide_follow"):
			node.decide_follow()


func _help_request(line: String) -> bool:
	return _has_phrase(line.to_lower(), ["help", "turn me back", "change me back", "fix me", "bring me back", "put me back", "make me normal", "stop glitching", "stop the glitch", "save me", "undo this"])


func _follow_request(line: String) -> bool:
	return _has_phrase(line.to_lower(), ["follow me", "follow us", "come with me", "come with us", "walk with me", "tag along", "come along", "stay with me"])


func _stop_request(line: String) -> bool:
	return _has_phrase(line.to_lower(), ["stop following", "don't follow", "dont follow", "do not follow", "stay here", "wait here", "stay put", "hang back", "leave me alone", "go back"])


func _speaker_agreed(speaker: String) -> bool:
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) != speaker:
			continue
		if node.has_method("follow_agreed"):
			return bool(node.call("follow_agreed"))
	return false


func _is_idea(line: String) -> bool:
	var low := line.to_lower()
	if _has_phrase(low, ["stop following", "don't follow", "dont follow", "do not follow", "stay here", "wait here", "stay put", "hang back", "leave me alone", "go back"]):
		return false
	if _has_phrase(low, ["follow me", "follow us", "come with me", "come with us", "walk with me", "tag along", "come along", "stay with me"]):
		return false
	if _has_phrase(low, ["how are you", "who are you", "what are you", "where are you", "what's your name", "whats your name"]):
		return false
	if _has_phrase(low, ["idea", "adventure", "what if", "how about", "what about", "let's", "lets ", "let us", "make a", "make an", "make us", "i want", "i'd like", "id like", "can we", "could we", "you should", "please make", "take us", "send us", "imagine", "quest"]):
		return true
	return low.length() >= 40


func _has_phrase(text: String, phrases: Array) -> bool:
	for phrase in phrases:
		if text.contains(str(phrase)):
			return true
	return false


func _censor_entry(value: String) -> void:
	if _censoring_entry:
		return
	var clean := LocalAI.censor_typing(value)
	if clean == value:
		return
	_censoring_entry = true
	var caret := _entry.caret_column
	_entry.text = clean
	_entry.caret_column = mini(caret, clean.length())
	_censoring_entry = false


func _on_ai_reply(character: String, text: String) -> void:
	var spoken := text
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) != character:
			continue
		if node.has_method("keep_follow_line"):
			spoken = str(node.call("keep_follow_line", text))
		break
	if character == "Caine":
		Game.start_adventure()
	_show_world_line(character, spoken)
	if dialogue_open and character == speaker_name:
		_body.text = spoken


func _show_world_line(character: String, text: String) -> void:
	for node in get_tree().get_nodes_in_group("circus_npc"):
		if str(node.get("char_name")) != character:
			continue
		if node.has_method("show_line"):
			node.show_line(text)
		return


func open_dialogue(speaker: String, accent: Color, tree: Dictionary) -> void:
	if paused:
		return
	_tree = tree
	speaker_name = speaker
	dialogue_open = true
	_panel.visible = true
	_speaker.text = speaker.to_upper()
	_speaker.add_theme_color_override("font_color", accent)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_node("start")


func close_dialogue() -> void:
	dialogue_open = false
	_panel.visible = false
	_clear_choices()
	if _entry:
		_entry.release_focus()
		_entry.text = ""
	if paused or not gameplay_on:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED


func toggle_pause() -> void:
	if dialogue_open:
		close_dialogue()
	paused = not paused
	get_tree().paused = paused
	_pause.visible = paused
	_talk.visible = gameplay_on and not paused
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif gameplay_on:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED


func show_work(status: String) -> void:
	_work.visible = true
	_work_status.text = status
	set_work(0.02, status)


func set_work(amount: float, status: String) -> void:
	if _work == null:
		return
	_work.visible = true
	_work_status.text = status
	var fill := clampf(amount, 0.0, 1.0)
	_work_fill.anchor_right = fill
	_work_fill.offset_right = 0.0


func hide_work() -> void:
	if _work == null:
		return
	_work.visible = false


func toast(text: String, hold: float = 2.2) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void:
		_toast.visible = false
	)


func _on_progress() -> void:
	_orb_label.text = "WACKY ORBS   %d / %d" % [Game.orbs_found, Game.ORB_GOAL]


func _on_complete() -> void:
	Music.celebrate = true
	_banner.text = "CURTAIN CALL"
	_banner.visible = true
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(4.5)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		_banner.visible = false
	)


func _show_node(id: String) -> void:
	if id == "" or not _tree.has(id):
		close_dialogue()
		return
	var node: Dictionary = _tree[id]
	_body.text = str(node.get("text", ""))
	_clear_choices()
	var choices: Array = node.get("choices", [])
	for choice in choices:
		var button := Button.new()
		button.text = str(choice.get("label", "..."))
		button.custom_minimum_size = Vector2(0, 38)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_button(button)
		var goto_id := str(choice.get("goto", ""))
		button.pressed.connect(_show_node.bind(goto_id))
		_choices.add_child(button)
	if choices.is_empty():
		var leave := Button.new()
		leave.text = "Close"
		_style_button(leave)
		leave.pressed.connect(close_dialogue)
		_choices.add_child(leave)


func _update_compass() -> void:
	_arrow.visible = false
	_distance.text = ""


func _build() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Trebuchet MS", "Verdana", "Segoe UI"])
	font.font_weight = 700
	var theme := Theme.new()
	theme.default_font = font

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(0, 0, 0, 0)
	_root.add_child(_veil)

	_loading = _full_rect(Color(0.08, 0.02, 0.08, 0.82))
	_loading.visible = false
	_loading.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_label = _label("Opening the tent...", 36, Color("#ffe14a"))
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.offset_top = -40
	_loading.add_child(_loading_label)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.18)
	track.anchor_left = 0.5
	track.anchor_right = 0.5
	track.anchor_top = 0.5
	track.anchor_bottom = 0.5
	track.offset_left = -220
	track.offset_right = 220
	track.offset_top = 48
	track.offset_bottom = 64
	_loading.add_child(track)
	_loading_fill = ColorRect.new()
	_loading_fill.color = Color("#ff4b5c")
	_loading_fill.anchor_left = 0.0
	_loading_fill.anchor_top = 0.0
	_loading_fill.anchor_bottom = 1.0
	_loading_fill.offset_right = 40
	track.add_child(_loading_fill)
	_root.add_child(_loading)

	_orb_label = _label("WACKY ORBS   0 / 8", 28, Color("#ffe14a"))
	_orb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_orb_label.anchor_left = 0.5
	_orb_label.anchor_right = 0.5
	_orb_label.anchor_top = 0.0
	_orb_label.offset_left = -220
	_orb_label.offset_right = 220
	_orb_label.offset_top = 18
	_orb_label.offset_bottom = 58
	_orb_label.visible = false
	_root.add_child(_orb_label)

	_work = Control.new()
	_work.anchor_left = 0.5
	_work.anchor_right = 0.5
	_work.anchor_top = 0.0
	_work.offset_left = -250
	_work.offset_right = 250
	_work.offset_top = 62
	_work.offset_bottom = 132
	_work.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_work.visible = false
	_work_title = _label("CAINE IS WORKING", 18, Color("#ffe14a"))
	_work_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_work_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_work_title.offset_bottom = 24
	_work.add_child(_work_title)
	var work_track := ColorRect.new()
	work_track.color = Color(1, 1, 1, 0.16)
	work_track.anchor_left = 0.0
	work_track.anchor_right = 1.0
	work_track.offset_top = 28
	work_track.offset_bottom = 46
	work_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_work.add_child(work_track)
	_work_fill = ColorRect.new()
	_work_fill.color = Color("#ff4b5c")
	_work_fill.anchor_left = 0.0
	_work_fill.anchor_top = 0.0
	_work_fill.anchor_bottom = 1.0
	_work_fill.anchor_right = 0.02
	_work_fill.offset_right = 0.0
	_work_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	work_track.add_child(_work_fill)
	_work_status = _label("Thinking up an adventure", 15, Color.WHITE)
	_work_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_work_status.anchor_left = 0.0
	_work_status.anchor_right = 1.0
	_work_status.offset_top = 50
	_work_status.offset_bottom = 70
	_work.add_child(_work_status)
	_root.add_child(_work)

	_talk = Button.new()
	_talk.text = "Talk to Caine"
	_talk.anchor_left = 0.0
	_talk.anchor_top = 0.0
	_talk.offset_left = 18
	_talk.offset_top = 16
	_talk.offset_right = 214
	_talk.offset_bottom = 64
	_talk.visible = false
	_style_button(_talk)
	_talk.add_theme_font_size_override("font_size", 18)
	_talk.pressed.connect(func() -> void:
		Music.blip_talk()
		open_chat("Caine", Color("#ff4b5c"))
	)
	_root.add_child(_talk)

	_compass = Control.new()
	_compass.anchor_left = 1.0
	_compass.anchor_right = 1.0
	_compass.anchor_top = 0.0
	_compass.offset_left = -130
	_compass.offset_right = -20
	_compass.offset_top = 16
	_compass.offset_bottom = 110
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.visible = false
	_arrow = _label(">", 32, Color.WHITE)
	_arrow.text = ">"
	_arrow.custom_minimum_size = Vector2(36, 36)
	_arrow.pivot_offset = Vector2(18, 18)
	_arrow.position = Vector2(22, 8)
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass.add_child(_arrow)
	_distance = _label("", 18, Color.WHITE)
	_distance.position = Vector2(-10, 48)
	_distance.custom_minimum_size = Vector2(100, 24)
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass.add_child(_distance)
	_root.add_child(_compass)

	_hint = _label("WASD move    Mouse look    Talk to Caine    Switch chats inside    Esc close", 16, Color(1, 1, 1, 0.92))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -520
	_hint.offset_right = 520
	_hint.offset_top = -36
	_hint.offset_bottom = -12
	_hint.visible = false
	_root.add_child(_hint)

	_prompt = _label("", 26, Color("#ffe14a"))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -280
	_prompt.offset_right = 280
	_prompt.offset_top = -78
	_prompt.offset_bottom = -40
	_prompt.visible = false
	_root.add_child(_prompt)

	_banner = _label("CURTAIN CALL", 64, Color("#ffe14a"))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)

	_toast = _label("", 22, Color.WHITE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.0
	_toast.offset_left = -460
	_toast.offset_right = 460
	_toast.offset_top = 150
	_toast.offset_bottom = 250
	_toast.visible = false
	_root.add_child(_toast)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -470
	_panel.offset_right = 470
	_panel.offset_top = -380
	_panel.offset_bottom = -88
	_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.03, 0.1, 0.94)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel_style.border_color = Color("#ff4b5c")
	panel_style.set_border_width_all(3)
	_panel.add_theme_stylebox_override("panel", panel_style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_speaker = _label("", 22, Color("#ffe14a"))
	box.add_child(_speaker)
	_cast_scroll = ScrollContainer.new()
	_cast_scroll.custom_minimum_size = Vector2(880, 46)
	_cast_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_cast_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cast = HBoxContainer.new()
	_cast.add_theme_constant_override("separation", 6)
	_cast_scroll.add_child(_cast)
	box.add_child(_cast_scroll)
	_body = _label("", 18, Color.WHITE)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(860, 0)
	box.add_child(_body)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	box.add_child(_choices)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_entry = LineEdit.new()
	_entry.placeholder_text = "Say something..."
	_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry.custom_minimum_size = Vector2(0, 40)
	_entry.text_submitted.connect(_send_chat)
	_entry.text_changed.connect(_censor_entry)
	row.add_child(_entry)
	var send := Button.new()
	send.text = "Say it"
	send.custom_minimum_size = Vector2(110, 40)
	_style_button(send)
	send.pressed.connect(func() -> void:
		_send_chat(_entry.text)
	)
	row.add_child(send)
	box.add_child(row)
	_root.add_child(_panel)

	_pause = _full_rect(Color(0.05, 0.01, 0.08, 0.72))
	_pause.visible = false
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	var pause_box := VBoxContainer.new()
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_box.add_theme_constant_override("separation", 14)
	_pause.add_child(pause_box)
	var paused_label := _label("PAUSED", 64, Color("#ffe14a"))
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(paused_label)
	var resume := Button.new()
	resume.text = "Back to the tent"
	resume.custom_minimum_size = Vector2(280, 48)
	_style_button(resume)
	resume.pressed.connect(toggle_pause)
	pause_box.add_child(resume)
	var leave := Button.new()
	leave.text = "Leave the tent"
	leave.custom_minimum_size = Vector2(280, 48)
	_style_button(leave)
	leave.pressed.connect(_leave)
	pause_box.add_child(leave)
	_root.add_child(_pause)


func _leave() -> void:
	paused = false
	get_tree().paused = false
	dialogue_open = false
	gameplay_on = false
	_pause.visible = false
	_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _fade_hint() -> void:
	_hint.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(10.0)
	tween.tween_property(_hint, "modulate:a", 0.0, 1.2)


func _set_progress(fraction: float) -> void:
	var width := 440.0 * clampf(fraction, 0.02, 1.0)
	_loading_fill.offset_right = width
	_loading_fill.anchor_right = 0.0


func _clear_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()


func _refresh_cast() -> void:
	var old := _cast.get_children()
	for child in old:
		_cast.remove_child(child)
		child.free()
	for person in _chat_people():
		var button := Button.new()
		var who := str(person["name"])
		var accent: Color = person["color"]
		button.text = who
		button.custom_minimum_size = Vector2(0, 34)
		button.set_meta("who", who)
		_style_button(button)
		button.add_theme_color_override("font_color", accent.lightened(0.4))
		button.pressed.connect(_switch_chat.bind(who, accent))
		_cast.add_child(button)
	_mark_cast()


func _mark_cast() -> void:
	for child in _cast.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := str(button.get_meta("who", "")) == speaker_name
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("#ffe14a") if selected else Color(0.45, 0.08, 0.16)
		normal.set_corner_radius_all(10)
		normal.content_margin_left = 12
		normal.content_margin_right = 12
		normal.content_margin_top = 4
		normal.content_margin_bottom = 4
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", normal)
		button.add_theme_stylebox_override("pressed", normal)
		if selected:
			button.add_theme_color_override("font_color", Color(0.16, 0.04, 0.07))


func _chat_people() -> Array[Dictionary]:
	var found := {
		"Caine": Color("#ff4b5c"),
	}
	for node in get_tree().get_nodes_in_group("circus_npc"):
		var who := str(node.get("char_name"))
		if who == "":
			who = str(node.name)
		if who == "Pomni" or who == "Exit":
			continue
		if bool(node.get_meta("lost_one", false)) or Abstraction.is_gone(who):
			continue
		var accent: Color = Color.WHITE
		var raw = node.get("accent")
		if raw is Color:
			accent = raw
		found[who] = accent
	var ordered: Array[Dictionary] = []
	for name in ["Caine", "Jax", "Ragatha", "Gangle", "Zooble", "Kinger", "Bubble"]:
		if found.has(name):
			ordered.append({"name": name, "color": found[name]})
			found.erase(name)
	var rest: Array = found.keys()
	rest.sort()
	for name in rest:
		ordered.append({"name": name, "color": found[name]})
	return ordered


func ask_guest_voices(picks: Array, done: Callable) -> void:
	close_guest_voices()
	_voice_done = done
	_voice_form = true
	_voice_panel = Control.new()
	_voice_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_voice_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_voice_panel.add_child(dim)
	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -360
	card.offset_right = 360
	card.offset_top = -280
	card.offset_bottom = 280
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.03, 0.06)
	box.border_color = Color("#ffe14a")
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", box)
	_voice_panel.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var title := _label("Use these voices", 28, Color("#ffe14a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var note := _label("Caine searched Fish Audio and picked these voices. Paste an API key for each character.", 16, Color(1, 0.94, 0.9))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_voice_rows = VBoxContainer.new()
	_voice_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voice_rows.add_theme_constant_override("separation", 12)
	scroll.add_child(_voice_rows)
	for entry in picks:
		var who := ""
		var voice := ""
		var voice_title := ""
		if typeof(entry) == TYPE_DICTIONARY:
			var data: Dictionary = entry
			who = str(data.get("name", ""))
			voice = str(data.get("voice", ""))
			voice_title = str(data.get("title", ""))
		else:
			who = str(entry)
		if who == "":
			continue
		_voice_rows.add_child(_voice_row(who, voice, voice_title))
	var finish := Button.new()
	finish.text = "Done"
	finish.custom_minimum_size = Vector2(0, 46)
	_style_button(finish)
	finish.add_theme_color_override("font_color", Color(0.16, 0.04, 0.07))
	var done_style := StyleBoxFlat.new()
	done_style.bg_color = Color("#ffe14a")
	done_style.set_corner_radius_all(10)
	finish.add_theme_stylebox_override("normal", done_style)
	finish.add_theme_stylebox_override("hover", done_style)
	finish.add_theme_stylebox_override("pressed", done_style)
	finish.pressed.connect(_finish_guest_voices)
	column.add_child(finish)


func close_guest_voices() -> void:
	_voice_form = false
	if _voice_panel != null and is_instance_valid(_voice_panel):
		_voice_panel.queue_free()
	_voice_panel = null
	_voice_rows = null


func _voice_row(who: String, voice_id: String, voice_title: String) -> Control:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	var name_label := _label(who, 18, Color("#ff8ea0"))
	row.add_child(name_label)
	var shown := voice_title if voice_title != "" else "No voice found"
	var picked := _label("Use this voice: %s" % shown, 16, Color("#ffe14a"))
	picked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(picked)
	var key_box := LineEdit.new()
	key_box.placeholder_text = "API key"
	key_box.custom_minimum_size = Vector2(640, 36)
	key_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_box.set_meta("field", "key")
	row.add_child(key_box)
	var voice_box := LineEdit.new()
	voice_box.placeholder_text = "Voice model"
	voice_box.text = voice_id
	voice_box.custom_minimum_size = Vector2(640, 36)
	voice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voice_box.set_meta("field", "voice")
	row.add_child(voice_box)
	row.set_meta("who", who)
	return row


func _finish_guest_voices() -> void:
	var rows: Array = []
	if _voice_rows != null:
		for child in _voice_rows.get_children():
			var who := str(child.get_meta("who", ""))
			var key := ""
			var voice := ""
			for box in child.get_children():
				if box is LineEdit:
					var field := str(box.get_meta("field", ""))
					if field == "key":
						key = box.text.strip_edges()
					elif field == "voice":
						voice = box.text.strip_edges()
			rows.append({"name": who, "key": key, "voice": voice})
	var done := _voice_done
	close_guest_voices()
	if done.is_valid():
		done.call(rows)


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.45, 0.08, 0.16)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	hover.bg_color = Color(0.7, 0.16, 0.24)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.3, 0.05, 0.1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color("#ffe14a"))


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _full_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect
