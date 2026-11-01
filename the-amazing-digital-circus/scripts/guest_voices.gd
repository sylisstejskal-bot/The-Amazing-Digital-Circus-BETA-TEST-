extends Node

const CaineVoice = preload("res://scripts/caine_voice.gd")

var _http: HTTPRequest
var _mint: Array = []
var _live: Array[String] = []
var _gone: Array[String] = []
var _gen := 0
var _busy := false
var _step := ""
var _current: Dictionary = {}
var _audio := PackedByteArray()
var _clip_text := ""
var _signature := ""
var _audio_type := "audio/wav"
var _audio_name := "voice.wav"
var _told_credit := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 90.0
	_http.request_completed.connect(_on_http)
	add_child(_http)


func mint(npc: Node, who: String, about: String) -> void:
	var name := who.strip_edges()
	if name == "":
		return
	_mint.append({"gen": _gen, "npc": npc, "name": name, "about": about})
	_pump()


func discard() -> void:
	_gen += 1
	_mint.clear()
	for voice_id in _live:
		_gone.append(voice_id)
	_live.clear()
	_pump()


func _pump() -> void:
	if _busy or _http == null:
		return
	if not _gone.is_empty():
		var voice_id: String = _gone.pop_front()
		_step = "delete"
		_busy = true
		var err := _http.request(
			"https://api.fish.audio/model/" + voice_id.uri_encode(),
			_headers(),
			HTTPClient.METHOD_DELETE
		)
		if err != OK:
			print("GUEST VOICE delete failed ", err)
			_busy = false
			_pump()
		return
	if _mint.is_empty():
		return
	_current = _mint.pop_front()
	if int(_current.get("gen", -1)) != _gen:
		_pump()
		return
	var who := str(_current.get("name", "Guest"))
	var about := str(_current.get("about", ""))
	var instruction := "A character in a cartoon circus adventure named %s. %s" % [who, about]
	if instruction.length() > 700:
		instruction = instruction.substr(0, 700)
	var preview := "Hello. I am %s." % who
	if preview.length() > 140:
		preview = "Hello."
	var payload := {
		"instruction": instruction,
		"reference_text": preview,
		"language": "en",
		"n": 1,
		"speed": 1.0,
		"num_step": 16,
	}
	_step = "design"
	_busy = true
	var err := _http.request(
		"https://api.fish.audio/v1/voice-design",
		_headers("application/json", "voice-design-1"),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		print("GUEST VOICE design failed ", err)
		_busy = false
		_pump()
	else:
		print("GUEST VOICE designing ", who)


func _headers(content := "", model := "") -> PackedStringArray:
	var headers := PackedStringArray(["Authorization: Bearer " + str(CaineVoice.account_key("caine"))])
	if content != "":
		headers.append("Content-Type: " + content)
	if model != "":
		headers.append("model: " + model)
	return headers


func _on_http(result: int, code: int, _headers_back: PackedStringArray, body: PackedByteArray) -> void:
	var step := _step
	_step = ""
	if step == "delete":
		print("GUEST VOICE deleted ", code)
		_busy = false
		_pump()
		return
	if int(_current.get("gen", -1)) != _gen:
		_busy = false
		if step == "create":
			_drop_created(body)
		_pump()
		return
	if result != HTTPRequest.RESULT_SUCCESS or (code != 200 and code != 201):
		_fail(code, body)
		_busy = false
		_pump()
		return
	if step == "design":
		if not _take_design(body):
			_busy = false
			_pump()
			return
		call_deferred("_send_create")
		return
	if step == "create":
		_keep_created(body)
		_busy = false
		_pump()


func _fail(code: int, body: PackedByteArray) -> void:
	var note := body.slice(0, 180).get_string_from_utf8()
	print("GUEST VOICE ", code, " ", note)
	if code == 402 and not _told_credit:
		_told_credit = true
		TentUI.toast("Caine could not open new voices. The Fish account needs API credit.", 8.0)


func _take_design(body: PackedByteArray) -> bool:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		print("GUEST VOICE bad design")
		return false
	var data: Dictionary = parsed
	var candidates: Array = data.get("candidates", [])
	if candidates.is_empty() or typeof(candidates[0]) != TYPE_DICTIONARY:
		print("GUEST VOICE no candidate")
		return false
	var cand: Dictionary = candidates[0]
	var encoded := str(cand.get("audio_base64", ""))
	if encoded == "":
		print("GUEST VOICE empty audio")
		return false
	_audio = Marshalls.base64_to_raw(encoded)
	_clip_text = str(cand.get("text", ""))
	if _clip_text == "":
		_clip_text = "Hello. I am %s." % str(_current.get("name", "Guest"))
	_signature = str(cand.get("signature", cand.get("voice_design_signature", "")))
	if _audio.size() >= 4 and _audio.slice(0, 4).get_string_from_ascii() == "RIFF":
		_audio_type = "audio/wav"
		_audio_name = "voice.wav"
	else:
		_audio_type = "application/octet-stream"
		_audio_name = "voice.bin"
	return _audio.size() > 44


func _send_create() -> void:
	if int(_current.get("gen", -1)) != _gen:
		_busy = false
		_pump()
		return
	var who := str(_current.get("name", "Guest"))
	var boundary := "CircusGuestBoundary"
	var fields := {
		"type": "tts",
		"title": "Circus " + who.substr(0, 32),
		"train_mode": "fast",
		"visibility": "private",
		"texts": _clip_text,
		"enhance_audio_quality": "false",
		"generate_sample": "false",
	}
	if _signature != "":
		fields["voice_design_signatures"] = _signature
	var raw := PackedByteArray()
	for field_name in fields.keys():
		raw.append_array(_part(boundary, str(field_name), str(fields[field_name])))
	raw.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	raw.append_array(("Content-Disposition: form-data; name=\"voices\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % [_audio_name, _audio_type]).to_utf8_buffer())
	raw.append_array(_audio)
	raw.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	_step = "create"
	var err := _http.request_raw(
		"https://api.fish.audio/model",
		_headers("multipart/form-data; boundary=" + boundary),
		HTTPClient.METHOD_POST,
		raw
	)
	if err != OK:
		print("GUEST VOICE create failed ", err)
		_busy = false
		_step = ""
		_pump()


func _part(boundary: String, field_name: String, value: String) -> PackedByteArray:
	var chunk := "--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, field_name, value]
	return chunk.to_utf8_buffer()


func _keep_created(body: PackedByteArray) -> void:
	var voice_id := _model_id(body)
	if voice_id == "":
		print("GUEST VOICE missing id")
		return
	if int(_current.get("gen", -1)) != _gen:
		_gone.append(voice_id)
		return
	var npc = _current.get("npc")
	if npc == null or not is_instance_valid(npc):
		_gone.append(voice_id)
		return
	_live.append(voice_id)
	if npc.has_method("grant_fish_voice"):
		npc.call("grant_fish_voice", voice_id)
	print("GUEST VOICE ready ", str(_current.get("name", "")), " ", voice_id)


func _drop_created(body: PackedByteArray) -> void:
	var voice_id := _model_id(body)
	if voice_id != "":
		_gone.append(voice_id)


func _model_id(body: PackedByteArray) -> String:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var data: Dictionary = parsed
	return str(data.get("_id", data.get("id", "")))
