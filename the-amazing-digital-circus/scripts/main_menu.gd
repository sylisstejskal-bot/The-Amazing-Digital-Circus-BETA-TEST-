extends Control

var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.reset()
	Music.celebrate = false
	TentUI.hide_loading()
	TentUI.show_gameplay(false)
	TentUI.close_dialogue()
	_build()
	if _wants_shot():
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = 0.15
		timer.timeout.connect(_enter)
		add_child(timer)
		timer.start()
	elif _wants_menu_shot():
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = 0.4
		timer.timeout.connect(_capture_menu)
		add_child(timer)
		timer.start()


func _wants_shot() -> bool:
	return _has_arg("--shot")


func _wants_menu_shot() -> bool:
	return _has_arg("--menu-shot")


func _has_arg(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == flag:
			return true
	for arg in OS.get_cmdline_args():
		if arg == flag:
			return true
	return false


func _capture_menu() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path("res://shot_menu.png"))
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_enter()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float stripe = step(0.5, fract(uv.y * 10.0));
	vec3 a = vec3(0.62, 0.07, 0.13);
	vec3 b = vec3(0.07, 0.07, 0.28);
	vec3 col = mix(a, b, stripe);
	vec2 cell = floor(uv * vec2(18.0, 7.0));
	float check = mod(cell.x + cell.y, 2.0);
	if (uv.y > 0.82) {
		col = mix(vec3(0.96, 0.91, 0.82), vec3(0.78, 0.12, 0.18), check);
	}
	float vignette = smoothstep(0.95, 0.25, length(uv - vec2(0.5, 0.42)));
	col *= mix(0.72, 1.0, vignette);
	COLOR = vec4(col, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	backdrop.material = material
	add_child(backdrop)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Trebuchet MS", "Verdana", "Segoe UI"])
	font.font_weight = 700

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = -40
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = "THE AMAZING\nDIGITAL CIRCUS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color("#ffe14a"))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.02, 0.05))
	title.add_theme_constant_override("outline_size", 18)
	column.add_child(title)

	var sub := Label.new()
	sub.text = "You wake up in the tent. Caine already has an adventure."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color.WHITE)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	sub.add_theme_constant_override("outline_size", 8)
	column.add_child(sub)

	var button := Button.new()
	button.text = "Enter the Tent"
	button.custom_minimum_size = Vector2(320, 64)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 28)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#e23d3d")
	normal.set_corner_radius_all(16)
	var hover := normal.duplicate()
	hover.bg_color = Color("#ff5a4a")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color("#ffe14a"))
	button.pressed.connect(_enter)
	column.add_child(button)

	var help := Label.new()
	help.text = "WASD to walk   ·   Talk to Caine opens the chat   ·   Switch to anyone inside it"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(1, 0.95, 0.9, 0.92))
	column.add_child(help)


func _enter() -> void:
	if _busy:
		return
	_busy = true
	TentUI.show_loading("Opening the tent...")
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
