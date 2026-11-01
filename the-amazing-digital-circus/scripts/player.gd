extends CharacterBody3D

const WALK := 8.5
const SPRINT := 16.0
const JUMP := 8.0
const GRAVITY := 24.0
const LOOK_SENS := 0.0024

var elevation := 0.5
var cam_dist := 6.4
var _spawn := Vector3.ZERO
var _visual: Node3D
var _camera: Camera3D
var _bob := 0.0
var _preview := ""
var _knock := 0.0
var _knock_dir := Vector3.ZERO
var _ride: Node3D
var _glitch := 0.0
var _held := false


func setup_visual() -> void:
	var loader = preload("res://scripts/model_loader.gd")
	_visual = loader.build("pomni", 1.5)
	add_child(_visual)
	loader.fit(_visual, 1.5)


func remember_spawn(at: Vector3) -> void:
	_spawn = at
	if is_inside_tree():
		global_position = at
	else:
		position = at
	velocity = Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	if _visual == null:
		setup_visual()
	if not Abstraction.someone_abstracted.is_connected(_on_abstracted):
		Abstraction.someone_abstracted.connect(_on_abstracted)
	if not Abstraction.someone_restored.is_connected(_on_restored):
		Abstraction.someone_restored.connect(_on_restored)
	if not Abstraction.crossed.is_connected(_on_crossed):
		Abstraction.crossed.connect(_on_crossed)
	_camera = Camera3D.new()
	_camera.fov = 68.0
	_camera.current = true
	add_child(_camera)
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED


func hold_still(on: bool) -> void:
	_held = on
	velocity = Vector3.ZERO


func use_own_camera() -> void:
	if _camera != null:
		_camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if _held or TentUI.blocks_look():
		return
	if event is InputEventMouseMotion:
		if get_viewport().gui_get_hovered_control() != null:
			return
		rotate_y(-event.relative.x * LOOK_SENS)
		elevation = clampf(elevation + event.relative.y * LOOK_SENS, -0.15, 1.15)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.45, 2.2, 8.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.45, 2.2, 8.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			var cellar := get_tree().get_first_node_in_group("cellar_root")
			if cellar != null and cellar.has_method("try_use") and bool(cellar.call("try_use", self)):
				return
			var show := get_tree().get_first_node_in_group("adventure_world")
			if show != null and show.has_method("try_job") and bool(show.call("try_job", self)):
				return
			var npc := _nearest_npc()
			if npc:
				npc.talk()


func mount(body: Node3D) -> void:
	_ride = body
	velocity = Vector3.ZERO


func dismount(at: Vector3) -> void:
	_ride = null
	global_position = at
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _held:
		velocity = Vector3.ZERO
		TentUI.set_prompt("")
		return
	if _ride != null and is_instance_valid(_ride):
		var seat := _ride.global_position + Vector3(0, 1.25, 0) + _ride.global_transform.basis * Vector3(0.15, 0.0, 0.35)
		global_position = seat
		velocity = Vector3.ZERO
		rotation.y = _ride.rotation.y
		_update_camera()
		_update_prompt()
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var locked := TentUI.blocks_look()
	var wish := Vector3.ZERO
	if not locked:
		var input := Vector3(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			0.0,
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		)
		if Input.is_physical_key_pressed(KEY_LEFT):
			input.x -= 1.0
		if Input.is_physical_key_pressed(KEY_RIGHT):
			input.x += 1.0
		if Input.is_physical_key_pressed(KEY_UP):
			input.z -= 1.0
		if Input.is_physical_key_pressed(KEY_DOWN):
			input.z += 1.0
		if input.length() > 1.0:
			input = input.normalized()
		wish = Basis(Vector3.UP, rotation.y) * input
		var sway := _mind_pressure()
		if sway > 0.45:
			wish = wish.rotated(Vector3.UP, sin(Time.get_ticks_msec() / 220.0) * sway * 0.45)
		if sway > 0.85:
			wish *= 0.62
		if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
			velocity.y = JUMP
	var speed := SPRINT if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	if _knock > 0.2:
		wish = _knock_dir
		speed = _knock
		_knock = move_toward(_knock, 0.0, 14.0 * delta)
	velocity.x = move_toward(velocity.x, wish.x * speed, 70.0 * delta)
	velocity.z = move_toward(velocity.z, wish.z * speed, 70.0 * delta)
	move_and_slide()
	if _glitch > 0.0:
		_glitch = maxf(_glitch - delta * 1.15, 0.0)
	_bob_visual(delta, wish.length() > 0.1 and is_on_floor())
	_update_camera()
	_update_prompt()
	_rescue_if_fallen()
	TentUI.set_strain_overlay(maxf(_mind_pressure(), _glitch))


func preview_pose(state: String) -> void:
	_preview = state
	if _visual and _visual.has_method("set_locomotion"):
		_visual.set_locomotion(state)


func _bob_visual(_delta: float, moving: bool) -> void:
	if _visual and _visual.has_method("set_locomotion"):
		var state := "idle"
		if _preview != "":
			state = _preview
		elif not is_on_floor():
			state = "jump"
		elif moving and Input.is_physical_key_pressed(KEY_SHIFT):
			state = "run"
		elif moving:
			state = "walk"
		_visual.set_locomotion(state)
	if not Game.adventure_started and global_position.distance_to(_spawn) > 14.0:
		Game.start_adventure()


func _update_camera() -> void:
	if _camera == null:
		return
	var head := global_position + Vector3(0, 1.35, 0)
	var back := Basis(Vector3.UP, rotation.y) * Vector3(0, 0, 1)
	var desired := head + back * (cos(elevation) * cam_dist) + Vector3.UP * (sin(elevation) * cam_dist * 0.85)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(head, desired)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_camera.global_position = desired
	else:
		_camera.global_position = hit.position + hit.normal * 0.2
	_camera.look_at(head, Vector3.UP)
	var sway := _mind_pressure()
	_camera.h_offset = sin(Time.get_ticks_msec() / 70.0) * sway * 0.08
	_camera.v_offset = sin(Time.get_ticks_msec() / 90.0) * sway * 0.05


func _nearest_npc() -> Node:
	var best: Node = null
	var best_dist := 3.3
	for node in get_tree().get_nodes_in_group("circus_npc"):
		var npc := node as Node3D
		if npc == null:
			continue
		if str(node.get("char_name")) == "Exit":
			continue
		if bool(node.get_meta("lost_one", false)) or Abstraction.is_gone(str(node.get("char_name"))):
			continue
		var dist := global_position.distance_to(npc.global_position)
		if dist < best_dist:
			best_dist = dist
			best = npc
	return best


func glitch_burst() -> void:
	_glitch = 1.0
	if _visual != null and _visual.has_method("glitch_burst"):
		_visual.glitch_burst()


func shove(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = -global_transform.basis.z
	_knock_dir = flat.normalized()
	_knock = 7.5
	velocity.y = 3.2


func _mind_pressure() -> float:
	return Abstraction.pressure("Pomni")


func _on_crossed(who: String, mood: String) -> void:
	if who != "Pomni":
		return
	var line := Abstraction.warning("Pomni", mood)
	if line != "":
		TentUI.toast(line)


func _on_abstracted(who: String) -> void:
	if who == "Pomni":
		_take_form("abstracted")
		TentUI.toast("Your name slips. The tent keeps the thing you became.")
		return
	TentUI.toast(Abstraction.reaction("Pomni", who))


func _on_restored(who: String) -> void:
	if who != "Pomni":
		return
	_take_form("pomni")
	TentUI.toast("You are Pomni again. You remember the dark.")


func _take_form(id: String) -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	var loader = preload("res://scripts/model_loader.gd")
	_visual = loader.build(id, 1.5)
	add_child(_visual)
	loader.fit(_visual, 1.5)


func _update_prompt() -> void:
	if TentUI.blocks_look():
		TentUI.set_prompt("")
		return
	var cellar := get_tree().get_first_node_in_group("cellar_root")
	if cellar != null and cellar.has_method("interact_prompt"):
		var cellar_line := str(cellar.call("interact_prompt", global_position))
		if cellar_line != "":
			TentUI.set_prompt(cellar_line)
			return
	var show := get_tree().get_first_node_in_group("adventure_world")
	if show != null and show.has_method("job_prompt"):
		var job_line := str(show.call("job_prompt", global_position))
		if job_line != "":
			TentUI.set_prompt(job_line)
			return
	var npc := _nearest_npc()
	if npc:
		TentUI.set_prompt("E   Talk to %s" % npc.char_name)
	else:
		TentUI.set_prompt("")


func _rescue_if_fallen() -> void:
	if global_position.y > -8.0 and global_position.y < 160.0:
		return
	global_position = _spawn + Vector3(0, 0.2, 0)
	velocity = Vector3.ZERO
	TentUI.toast("Caine set you back on the floor.")
