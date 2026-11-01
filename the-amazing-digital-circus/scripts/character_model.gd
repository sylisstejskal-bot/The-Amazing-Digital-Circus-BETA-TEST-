extends Node3D

var _skeleton: Skeleton3D
var _upper_l := -1
var _upper_r := -1
var _fore_l := -1
var _fore_r := -1
var _thigh_l := -1
var _thigh_r := -1
var _shin_l := -1
var _shin_r := -1
var _chest := -1
var _head := -1
var _state := "idle"
var _phase := 0.0
var _base_scale := Vector3.ONE
var _has_limbs := false
var _bind_rotation := {}
var _claw_src := -1
var _claw_dst := -1
var _strain := 0.0
var _glitch := 0.0


func prepare() -> void:
	_base_scale = scale
	_phase = randf() * TAU
	if bool(get_meta("no_pose", false)):
		return
	_skeleton = _largest_skeleton(self)
	if _skeleton == null:
		return
	_upper_l = _find_bone("upper_arm.L")
	_upper_r = _find_bone("upper_arm.R")
	# Chess pieces only have hand bones, and those rest out in a T.
	if _upper_l < 0:
		_upper_l = _find_bone("hand.L")
		_drop_hand(_upper_l, -1.0)
	if _upper_r < 0:
		_upper_r = _find_bone("hand.R")
		_drop_hand(_upper_r, 1.0)
	_fore_l = _find_bone("forearm.L")
	_fore_r = _find_bone("forearm.R")
	_thigh_l = _find_bone("thigh.L")
	_thigh_r = _find_bone("thigh.R")
	_shin_l = _find_bone("shin.L")
	_shin_r = _find_bone("shin.R")
	_chest = _find_chest()
	_head = _find_bone("head")
	if _head < 0:
		_head = _skeleton.find_bone("head")
	_has_limbs = _upper_l >= 0 or _thigh_l >= 0
	_claw_src = _skeleton.find_bone("DEF-hand.L")
	_claw_dst = _skeleton.find_bone("ORG-hand.L")
	if _skeleton.find_bone("DEF-clawTop.001") < 0:
		_claw_src = -1
		_claw_dst = -1
	_remember_bind()


func set_locomotion(state: String) -> void:
	_state = state


func set_moving(moving: bool) -> void:
	set_locomotion("walk" if moving else "idle")


func set_strain(amount: float) -> void:
	_strain = clampf(amount, 0.0, 1.0)


func glitch_burst() -> void:
	_glitch = 1.0


func _shown_strain() -> float:
	return maxf(_strain, _glitch)


func _process(delta: float) -> void:
	if _glitch > 0.0:
		_glitch = maxf(_glitch - delta * 1.15, 0.0)
	_phase += delta * _tempo()
	if bool(get_meta("no_pose", false)):
		_apply_strain_motion()
		return
	if _skeleton != null and _has_limbs:
		_apply_body()
	else:
		_apply_blob()
	_apply_strain_motion()


func _tempo() -> float:
	var base := 1.7
	match _state:
		"walk":
			base = 8.2
		"run":
			base = 12.4
		"jump":
			base = 0.0
	return base * (1.0 + _shown_strain() * 1.6)


func _apply_body() -> void:
	var amp := 0.05
	var arm_out := 0.08
	var lean := 0.0
	match _state:
		"walk":
			amp = 0.52
			arm_out = 0.1
			lean = 0.08
		"run":
			amp = 0.78
			arm_out = 0.06
			lean = 0.2
		"jump":
			amp = 0.0
			arm_out = 0.12
			lean = -0.12
	var breathe := sin(_phase * 0.45) * 0.045
	if _chest >= 0:
		var axis := _local_axis(_chest, Vector3.RIGHT)
		_set_rest_delta(_chest, Quaternion(axis, lean + breathe))
	if _head >= 0:
		var axis := _local_axis(_head, Vector3.RIGHT)
		var nod := sin(_phase * 0.45) * 0.04
		if _shown_strain() > 0.2:
			nod += sin(_phase * 11.0) * _shown_strain() * 0.22
		_set_rest_delta(_head, Quaternion(axis, nod))
	_pose_arm(_upper_l, _fore_l, amp, arm_out, true, _claw_src >= 0)
	_pose_arm(_upper_r, _fore_r, amp, arm_out, false, false)
	_pose_leg(_thigh_l, _shin_l, amp, true)
	_pose_leg(_thigh_r, _shin_r, amp, false)
	_glue_claw()


func _apply_strain_motion() -> void:
	var shown := _shown_strain()
	if shown > 0.05:
		rotation.z = sin(_phase * 17.0) * shown * 0.14
		if _glitch > 0.2:
			rotation.x = sin(_phase * 41.0) * _glitch * 0.1
			visible = randf() > _glitch * 0.62
		else:
			rotation.x = 0.0
			visible = randf() > shown * 0.045
	else:
		rotation.z = 0.0
		rotation.x = 0.0
		visible = true


func _pose_arm(upper: int, fore: int, amp: float, arm_out: float, left_side: bool, keep_twist: bool) -> void:
	if upper < 0:
		return
	var rest := _skeleton.get_bone_global_rest(upper)
	var outward := Vector3(rest.basis.y.x, 0.0, rest.basis.y.z)
	if outward.length() < 0.15:
		outward = Vector3(-1.0 if left_side else 1.0, 0.0, 0.0)
	else:
		outward = outward.normalized()
	var sway := sin(_phase + (0.0 if left_side else PI))
	var aim := Vector3.DOWN
	var elbow := -0.18
	var swing := 0.0
	if _state == "idle":
		var drift := sway * 0.12
		aim = Vector3.DOWN + outward * (0.16 + sin(_phase * 0.45) * 0.03) + Vector3(0.0, 0.0, drift)
		elbow = -0.22 + sway * 0.08
	elif _state == "jump":
		aim = outward * 0.12 + Vector3(0.0, 0.35, -0.45)
		elbow = -0.55
	elif keep_twist:
		# Swing around the arm's own bend axis so the claw does not roll open.
		aim = Vector3.DOWN + outward * arm_out
		swing = sway * amp
		elbow = -0.16 + maxf(-swing, 0.0) * 0.2
	else:
		swing = sway * amp
		aim = Vector3.DOWN + outward * arm_out + Vector3(0.0, 0.0, swing * 0.75)
		elbow = -0.2 + maxf(-swing, 0.0) * 0.35
	var posed := _hang_rotation(upper, aim)
	if keep_twist and (_state == "walk" or _state == "run"):
		posed = posed * Quaternion(Vector3.RIGHT, swing * 0.72)
	_skeleton.set_bone_pose_rotation(upper, posed)
	if fore >= 0:
		_set_rest_delta(fore, Quaternion(Vector3.RIGHT, elbow))


func _glue_claw() -> void:
	if _claw_src < 0 or _claw_dst < 0 or _skeleton == null:
		return
	var src_pose := _skeleton.get_bone_global_pose(_claw_src)
	var parent := _skeleton.get_bone_parent(_claw_dst)
	var parent_xform := Transform3D.IDENTITY
	if parent >= 0:
		parent_xform = _skeleton.get_bone_global_pose(parent)
	var local := parent_xform.affine_inverse() * src_pose
	_skeleton.set_bone_pose_position(_claw_dst, local.origin)
	_skeleton.set_bone_pose_rotation(_claw_dst, local.basis.get_rotation_quaternion())


func _pose_leg(thigh: int, shin: int, amp: float, left_side: bool) -> void:
	if thigh < 0:
		return
	# Thighs already point down in the rest pose. Swing around the bone's
	# own X axis so the standing rotation stays put.
	var pitch := sin(_phase + (0.0 if left_side else PI)) * amp
	if _state == "jump":
		pitch = -0.9
	_set_rest_delta(thigh, Quaternion(Vector3.RIGHT, pitch))
	if shin >= 0:
		var bend := 0.16
		if _state == "walk" or _state == "run":
			bend = 0.1 + maxf(-pitch, 0.0) * 1.05
		elif _state == "jump":
			bend = 1.2
		_set_rest_delta(shin, Quaternion(Vector3.RIGHT, bend))


func _drop_hand(bone: int, side: float) -> void:
	if bone < 0 or _skeleton == null:
		return
	var origin: Vector3 = _skeleton.get_bone_global_rest(bone).origin
	var target := Vector3(side * 0.22, origin.y * 0.55, origin.z * 0.2)
	var parent := _skeleton.get_bone_parent(bone)
	var local := target
	if parent >= 0:
		local = _skeleton.get_bone_global_rest(parent).affine_inverse() * target
	_skeleton.set_bone_pose_position(bone, local)


func _remember_bind() -> void:
	if _skeleton == null:
		return
	# Rebuilding a quaternion from the rest basis flips bones whose rest is a
	# 180 degree turn. Zooble's thighs are that case, so keep the imported pose.
	for bone in [_upper_l, _upper_r, _fore_l, _fore_r, _thigh_l, _thigh_r, _shin_l, _shin_r, _chest, _head]:
		if bone >= 0:
			_bind_rotation[bone] = _skeleton.get_bone_pose_rotation(bone)


func _set_rest_delta(bone: int, delta: Quaternion) -> void:
	_skeleton.set_bone_pose_rotation(bone, _bind_rotation.get(bone, Quaternion.IDENTITY) * delta)


func _hang_rotation(bone: int, direction: Vector3) -> Quaternion:
	var rest := _skeleton.get_bone_global_rest(bone)
	var rest_q: Quaternion = _bind_rotation.get(bone, Quaternion.IDENTITY)
	var local_target := rest.basis.inverse() * direction.normalized()
	if local_target.length() < 0.001:
		return rest_q
	# Keep the imported rest, then turn the bone so it hangs toward direction.
	return rest_q * Quaternion(Vector3.UP, local_target.normalized())


func _local_axis(bone: int, world_axis: Vector3) -> Vector3:
	var rest := _skeleton.get_bone_global_rest(bone)
	var local := rest.basis.inverse() * world_axis
	if local.length() < 0.001:
		return Vector3.RIGHT
	return local.normalized()


func _apply_blob() -> void:
	var pulse := sin(_phase) * 0.045
	var tall := 1.0
	match _state:
		"jump":
			tall = 1.18
			pulse = 0.0
		"run":
			pulse *= 1.8
		"walk":
			pulse *= 1.3
	var squash := 1.0 + pulse
	scale = Vector3(_base_scale.x / squash, _base_scale.y * tall * squash, _base_scale.z / squash)


func _find_bone(suffix: String) -> int:
	if _skeleton == null:
		return -1
	for prefix in ["DEF-", "", "ORG-"]:
		var idx := _skeleton.find_bone(prefix + suffix)
		if idx >= 0:
			return idx
	return -1


func _find_chest() -> int:
	for name in ["DEF-spine.003", "DEF-spine.002", "DEF-spine", "spine.002", "spine"]:
		var idx := _skeleton.find_bone(name)
		if idx >= 0:
			return idx
	return -1


func _largest_skeleton(node: Node) -> Skeleton3D:
	var best: Skeleton3D = null
	var best_count := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Skeleton3D:
			var bones := (current as Skeleton3D).get_bone_count()
			if bones > best_count:
				best = current
				best_count = bones
		for child in current.get_children():
			stack.append(child)
	return best
