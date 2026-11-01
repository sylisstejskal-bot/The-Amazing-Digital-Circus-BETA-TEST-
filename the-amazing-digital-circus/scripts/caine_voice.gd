extends Node

const KEY_FILE := "res://fish_keys.cfg"
const URL := "https://api.fish.audio/v1/tts"

var _http: HTTPRequest
var _queue: Array[String] = []
var _busy := false
var _voice: AudioStreamPlayer
var voice_override := ""
var who_override := ""
var key_override := ""
var skip_default_voice := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 40.0
	_http.request_completed.connect(_on_audio)
	add_child(_http)


func say(line: String) -> void:
	var clean := line.replace("\n", " ").strip_edges()
	if clean == "":
		return
	if clean.length() > 280:
		clean = clean.substr(0, 277).strip_edges() + "..."
	_queue.append(clean)
	if _queue.size() > 3:
		_queue.pop_front()
	_pump()


func _pump() -> void:
	if _busy or _queue.is_empty() or _http == null:
		return
	_busy = true
	var line: String = _queue.pop_front()
	var payload := {
		"text": line,
		"format": "wav",
		"sample_rate": 44100,
		"latency": "balanced",
	}
	var reference := _voice_id()
	if reference != "":
		payload["reference_id"] = reference
	var headers := PackedStringArray([
		"Authorization: Bearer " + _api_key(),
		"Content-Type: application/json",
		"model: s2.1-pro-free",
	])
	var err := _http.request(URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		print(_who(), " TTS request failed ", err)
		_busy = false
		_pump()
	else:
		print(_who(), " TTS speak")


func _on_audio(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		var note := body.slice(0, 160).get_string_from_utf8()
		print(_who(), " TTS ", code, " ", note)
		_busy = false
		_pump()
		return
	var clip := _wav(body)
	if clip == null:
		print(_who(), " TTS bad audio")
		_busy = false
		_pump()
		return
	_play(clip)


func _play(clip: AudioStreamWAV) -> void:
	if _voice != null and is_instance_valid(_voice):
		_voice.stop()
		_voice.queue_free()
	_voice = AudioStreamPlayer.new()
	_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	_voice.stream = clip
	_voice.volume_db = 0.0
	_voice.finished.connect(_on_played)
	add_child(_voice)
	_voice.play()
	print(_who(), " TTS playing")


func _api_key() -> String:
	if key_override != "":
		return key_override
	return account_key("caine")


func _voice_id() -> String:
	if voice_override != "":
		return voice_override
	if skip_default_voice:
		return ""
	return account_voice("caine")


static func account_key(section: String) -> String:
	return _account_value(section, "key")


static func account_voice(section: String) -> String:
	return _account_value(section, "voice")


static func _account_value(section: String, field: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(KEY_FILE) != OK:
		return ""
	return str(cfg.get_value(section, field, "")).strip_edges()


func _who() -> String:
	if who_override != "":
		return who_override
	return "CAINE"


func _on_played() -> void:
	_busy = false
	_pump()


func _wav(raw: PackedByteArray) -> AudioStreamWAV:
	if raw.size() < 44 or raw.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var channels := 1
	var rate := 44100
	var bits := 16
	var pcm := PackedByteArray()
	var i := 12
	while i + 8 <= raw.size():
		var id := raw.slice(i, i + 4).get_string_from_ascii()
		var size := raw.decode_u32(i + 4)
		var start := i + 8
		if id == "fmt " and start + 16 <= raw.size():
			channels = raw.decode_u16(start + 2)
			rate = raw.decode_u32(start + 4)
			bits = raw.decode_u16(start + 14)
		elif id == "data":
			var end := mini(start + size, raw.size())
			pcm = raw.slice(start, end)
			break
		var step := size
		if step % 2 != 0:
			step += 1
		i = start + step
	if pcm.is_empty() or bits != 16:
		return null
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = rate
	clip.stereo = channels >= 2
	clip.data = pcm
	return clip
