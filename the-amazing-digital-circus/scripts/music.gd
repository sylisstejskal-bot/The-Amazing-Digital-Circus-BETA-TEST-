extends AudioStreamPlayer

const RATE := 22050.0

var _pb: AudioStreamGeneratorPlayback
var _t := 0.0
var _bpm := 108.0
var celebrate := false
var in_cellar := false
var _cellar_voice: AudioStreamPlayer
var _cellar_stream: AudioStreamWAV

# Original lounge tune. A bright major waltz-feel in 4/4, written for this tent.
var _lead := [64, 67, 72, 67, 69, 72, 76, 72, 71, 74, 77, 74, 72, 69, 67, 64]
var _lead_party := [72, 76, 79, 76, 74, 77, 81, 77, 76, 79, 84, 79, 77, 74, 72, 69]
var _bass := [48, 55, 48, 43]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	stream = gen
	volume_db = -18.0
	play()
	var playback = get_stream_playback()
	if playback is AudioStreamGeneratorPlayback:
		_pb = playback


func _process(_dt: float) -> void:
	if _pb == null:
		return
	if in_cellar:
		volume_db = -12.0
	elif TentUI and TentUI.is_dialogue_open():
		volume_db = -24.0
	elif celebrate:
		volume_db = -14.0
	else:
		volume_db = -18.0
	var frames := _pb.get_frames_available()
	var step := 1.0 / RATE
	var lead: Array = _lead_party if celebrate else _lead
	for _i in frames:
		var beat := _t * (_bpm / 60.0)
		var sixteenth := int(floor(beat * 4.0))
		var note_phase := fposmod(beat * 4.0, 1.0)
		var env := pow(1.0 - note_phase, 0.65)
		var bass_env := pow(1.0 - fposmod(beat, 1.0), 0.5)
		var sample := 0.0
		if in_cellar:
			var drip := 0.0
			if fposmod(_t, 6.5) > 6.15:
				drip = sin(TAU * 190.0 * _t) * 0.08
			var drone := sin(TAU * 46.0 * _t) * 0.22 + sin(TAU * 47.4 * _t) * 0.1 + sin(TAU * 23.0 * _t) * 0.08
			sample = clampf(drone + drip, -1.0, 1.0)
		else:
			var lead_s := _triangle(_midi(int(lead[sixteenth % lead.size()])), _t) * env * 0.34
			var bass_s := _triangle(_midi(int(_bass[int(floor(beat)) % _bass.size()])), _t) * bass_env * 0.28
			sample = clampf(lead_s + bass_s, -1.0, 1.0)
		_pb.push_frame(Vector2(sample, sample))
		_t += step


func blip_collect() -> void:
	_play_blip(880.0, 0.09)
	_play_blip(1320.0, 0.14)


func blip_talk() -> void:
	_play_blip(520.0, 0.07)


func sting_glitch() -> void:
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = _noise(0.42)
	player.volume_db = -8.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_cellar_drop() -> void:
	if _cellar_voice != null and is_instance_valid(_cellar_voice) and _cellar_voice.playing:
		return
	var clip := _load_cellar_line()
	if clip == null:
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = clip
	player.volume_db = -2.0
	add_child(player)
	player.finished.connect(player.queue_free)
	_cellar_voice = player
	player.play()


func _load_cellar_line() -> AudioStreamWAV:
	if _cellar_stream != null:
		return _cellar_stream
	var file := FileAccess.open("res://audio/into_the_cellar.wav", FileAccess.READ)
	if file == null:
		print("CELLAR LINE MISSING")
		return null
	var raw := file.get_buffer(file.get_length())
	file.close()
	if raw.size() <= 44:
		return null
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 44100
	clip.stereo = true
	clip.data = raw.slice(44)
	_cellar_stream = clip
	return clip


func _play_blip(freq: float, dur: float) -> void:
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = _wav(freq, dur)
	player.volume_db = -8.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _wav(freq: float, dur: float) -> AudioStreamWAV:
	var count := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var env := 1.0 - float(i) / float(count)
		var sample := sin(TAU * freq * float(i) / RATE) * env
		var value := int(clampf(sample, -1.0, 1.0) * 30000.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.stereo = false
	wav.data = data
	return wav


func _noise(dur: float) -> AudioStreamWAV:
	var count := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14013
	for i in count:
		var env := pow(1.0 - float(i) / float(count), 0.55)
		var sample := rng.randf_range(-1.0, 1.0) * env
		sample += sin(TAU * 62.0 * float(i) / RATE) * env * 0.45
		var value := int(clampf(sample, -1.0, 1.0) * 30000.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.stereo = false
	wav.data = data
	return wav


func _midi(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


func _triangle(freq: float, t: float) -> float:
	var frac := fposmod(t * freq, 1.0)
	return 4.0 * absf(frac - 0.5) - 1.0
