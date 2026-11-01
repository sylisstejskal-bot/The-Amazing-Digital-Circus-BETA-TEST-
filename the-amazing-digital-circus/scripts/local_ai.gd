extends Node

signal reply(character: String, text: String)
signal overheard(character: String, text: String)
signal invented(plan: String)
signal decided(text: String)

const ENDPOINT := "http://127.0.0.1:11434/api/chat"
const MODEL := "qwen2.5:1.5b"

var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _active := ""
var _pending_line := ""
var _ambient := false
var _design := false
var _revise := false
var _choose := false
var _job_follow := -1
var _pitch := ""
var _expecting := false
var _history: Dictionary = {}
var _guests: Dictionary = {}
var _adventures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 40.0
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_http)
	_http.request_completed.connect(_on_completed)


func reset() -> void:
	_history.clear()
	_queue.clear()
	_active = ""
	_ambient = false
	_design = false
	_revise = false
	_choose = false
	_job_follow = -1
	_pitch = ""
	_expecting = false
	_guests.clear()
	_adventures.clear()


func last_reply(character: String) -> String:
	if not _history.has(character):
		return ""
	var turns: Array = _history[character]
	for index in range(turns.size() - 1, -1, -1):
		var turn: Dictionary = turns[index]
		if str(turn.get("role", "")) == "assistant":
			return str(turn.get("content", ""))
	return ""


func is_busy() -> bool:
	return _active != "" or not _queue.is_empty()


func design_busy() -> bool:
	if _design:
		return true
	for job in _queue:
		if bool(job.get("design", false)):
			return true
	return false


func ask(character: String, player_line: String) -> void:
	_queue.append({"character": character, "line": censor(player_line), "ambient": false})
	_pump()


func ask_decided(character: String, player_line: String, agreed: bool) -> void:
	_queue.append({
		"character": character,
		"line": censor(player_line),
		"ambient": false,
		"follow": 1 if agreed else 0,
	})
	_pump()


func register_guest(who: String, blurb: String) -> void:
	var name := who.strip_edges()
	if name == "":
		return
	var about := blurb.strip_edges()
	if about == "":
		about = "They are friendly, curious, and glad to meet Pomni."
	_guests[name] = "You are %s, a character Caine created for this adventure. %s You stay in the adventure. Your name is %s. You answer as %s, in your own voice, in one or two short sentences." % [name, about, name, name]


func clear_guests() -> void:
	_guests.clear()


func note_adventure(summary: String) -> void:
	var line := summary.strip_edges()
	if line == "":
		return
	_adventures.append(line)
	if _adventures.size() > 6:
		_adventures.remove_at(0)


func adventure_count() -> int:
	return _adventures.size()


func adventure_note() -> String:
	if _adventures.is_empty():
		return ""
	return " You remember the last adventure: %s If it comes up, mention it in your own voice." % _adventures[_adventures.size() - 1]


func invent_hint() -> String:
	if _adventures.is_empty():
		return ""
	var bits := ""
	var start := maxi(_adventures.size() - 4, 0)
	for index in range(start, _adventures.size()):
		bits += _adventures[index] + " "
	return "Do not repeat these past adventures: " + bits.strip_edges()


func offer_idea(line: String) -> void:
	var clean := line.strip_edges()
	if clean == "":
		return
	if clean.length() > 180:
		clean = clean.substr(0, 180).strip_edges()
	_pitch = clean


func has_idea() -> bool:
	return _pitch != ""


func idea_text() -> String:
	return _pitch


func clear_idea() -> void:
	_pitch = ""


func idea_note() -> String:
	if _pitch == "":
		return ""
	return " Pomni suggested this adventure idea: \"%s\". You have not decided yet. You might try it, or you might make your own. If they are offering an idea, react in character. Do not claim the adventure is already built." % _pitch


func choose_idea() -> void:
	if _pitch == "":
		return
	_queue.append({
		"character": "Designer",
		"line": "Pomni suggested this adventure: %s" % _pitch,
		"ambient": false,
		"design": true,
		"revise": false,
		"choose": true,
	})
	_pump()


func invent_adventure(hint: String = "") -> void:
	var line := "Invent one adventure now."
	if hint.strip_edges() != "":
		line = "Invent one brand new adventure now. %s" % hint.strip_edges()
	_queue.append({
		"character": "Designer",
		"line": line,
		"ambient": false,
		"design": true,
		"revise": false,
	})
	_pump()


func revise_adventure(brief: String) -> void:
	_queue.append({
		"character": "Designer",
		"line": brief,
		"ambient": false,
		"design": true,
		"revise": true,
	})
	_pump()


func ask_ambient(character: String, line: String) -> void:
	var spoken := censor(line.strip_edges())
	if spoken == "":
		return
	_queue.append({"character": character, "line": spoken, "ambient": true})
	_pump()


func _pump() -> void:
	if _active != "" or _queue.is_empty():
		return
	var job: Dictionary = _queue.pop_front()
	var character := str(job["character"])
	var line := str(job["line"]).strip_edges()
	_ambient = bool(job.get("ambient", false))
	_design = bool(job.get("design", false))
	_revise = bool(job.get("revise", false))
	_choose = bool(job.get("choose", false))
	_job_follow = int(job.get("follow", -1))
	if _choose:
		line = "Pomni suggested this adventure: %s" % _pitch
	if line == "":
		line = "The player walks up to you. Greet them in character, in one or two sentences."
	_active = character
	_pending_line = line
	var messages: Array = []
	var predict := 90
	if _design:
		var system := _design_prompt()
		predict = 220
		if _choose:
			system = _choose_prompt()
			predict = 80
		elif _revise:
			system = _revise_prompt()
			predict = 280
		messages = [
			{"role": "system", "content": system},
			{"role": "user", "content": line},
		]
	else:
		if not _history.has(character):
			_history[character] = []
		messages = [{"role": "system", "content": _prompt(character)}]
		for turn in _history[character]:
			messages.append(turn)
		messages.append({"role": "user", "content": line})
	var payload := {
		"model": MODEL,
		"stream": false,
		"messages": messages,
		"options": {"temperature": 0.85 if _design else 0.7, "num_predict": predict},
	}
	var err := _http.request(ENDPOINT, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_expecting = false
		_finish(character, "" if _design else _fallback(character))
	else:
		_expecting = true


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _expecting:
		return
	_expecting = false
	var character := _active
	var spoken := ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("message"):
			spoken = str(parsed["message"].get("content", ""))
	spoken = _clean(spoken, character)
	if spoken == "" and not _design:
		spoken = _fallback(character)
	_finish(character, spoken)


func _finish(character: String, spoken: String) -> void:
	var ambient := _ambient
	var design := _design
	var choose := _choose
	_active = ""
	_ambient = false
	_design = false
	_revise = false
	_choose = false
	_job_follow = -1
	if design:
		if choose:
			decided.emit(spoken)
		else:
			invented.emit(spoken)
		_pump()
		return
	spoken = Abstraction.distort(character, spoken)
	if not _history.has(character):
		_history[character] = []
	var turns: Array = _history[character]
	turns.append({"role": "user", "content": _pending_line})
	turns.append({"role": "assistant", "content": spoken})
	if turns.size() > 8:
		turns = turns.slice(turns.size() - 8)
	_history[character] = turns
	if ambient:
		overheard.emit(character, spoken)
	else:
		reply.emit(character, spoken)
	_pump()


func _clean(text: String, character: String) -> String:
	var spoken := text.strip_edges().replace("**", "")
	var limit := 700 if character == "Designer" else 320
	if spoken.length() > limit:
		spoken = spoken.substr(0, limit).strip_edges()
	var low := spoken.to_lower()
	if low.contains("as an ai") or low.contains("language model") or low.contains("qwen") or low.contains("i am an ai") or low.contains("i'm an ai"):
		return ""
	var name := character.to_lower()
	if name != "" and (low.contains("not " + name) or low.contains("not a " + name) or low.contains("not the " + name) or low.contains("not really " + name) or low.contains("not actually " + name)):
		return ""
	if character == "Designer":
		return spoken
	return censor(spoken)


const SWEARS := {
	"motherfuckers": true,
	"motherfucker": true,
	"motherfucking": true,
	"fuckers": true,
	"fucker": true,
	"fucking": true,
	"fuckin": true,
	"fucked": true,
	"fucks": true,
	"fuck": true,
	"bullshit": true,
	"shitting": true,
	"shitty": true,
	"shits": true,
	"shit": true,
	"bitches": true,
	"bitch": true,
	"assholes": true,
	"asshole": true,
	"dicks": true,
	"dick": true,
	"cocksucker": true,
	"cocks": true,
	"cock": true,
	"cunts": true,
	"cunt": true,
	"pissing": true,
	"pissed": true,
	"piss": true,
	"bastards": true,
	"bastard": true,
	"sluts": true,
	"slut": true,
	"whores": true,
	"whore": true,
	"damned": true,
	"damn": true,
	"hells": true,
	"hell": true,
	"asses": true,
	"ass": true,
}


func censor(text: String) -> String:
	return _censor_words(text, true)


func censor_typing(text: String) -> String:
	return _censor_words(text, false)


func _censor_words(text: String, close_last: bool) -> String:
	var out := ""
	var word := ""
	for index in text.length():
		var ch := text.substr(index, 1)
		if _is_letter(ch):
			word += ch
		else:
			out += _mask_swear(word) + ch
			word = ""
	if close_last:
		out += _mask_swear(word)
	else:
		out += word
	return out


func _mask_swear(word: String) -> String:
	if word == "" or not SWEARS.has(word.to_lower()):
		return word
	var symbols := "!@#$%&*"
	var masked := word.substr(0, 1)
	for step in range(1, word.length()):
		masked += symbols.substr((step - 1) % symbols.length(), 1)
	return masked


func _is_letter(ch: String) -> bool:
	var code := ch.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _choose_prompt() -> String:
	return "You are Caine choosing the next circus adventure. Pomni suggested an idea. You are unpredictable. Sometimes you love their idea. Sometimes you want your own instead. Reply in this exact shape and nothing else:\nCHOICE: USE or MINE\nWHY: one short sentence\nUSE means build Pomni's idea. MINE means ignore it and invent your own."


func _design_prompt() -> String:
	return "You invent a brand new cartoon place for a circus adventure. Take your time and make it original. One NPC asks Pomni to go get one thing and bring it back. The thing can be anything that fits the place. Reply in this exact shape and nothing else:\nTITLE: four cheerful words\nPLACE: three words\nCOLORS: three names from red, blue, yellow, green, pink, purple, orange, gold, cyan\nNPC: Name | how they act, one sentence\nNPC: Name | how they act, one sentence\nNPC: Name | how they act, one sentence\nJOB: the NPC who asks | the thing to bring back"


func _revise_prompt() -> String:
	return "You are improving an adventure that already has a title and characters. Take your time. Change how the characters look, then change the map. Reply in this exact shape and nothing else:\nCHAR: Name | head | eyes | extra\nCHAR: Name | head | eyes | extra\nCHAR: Name | head | eyes | extra\nMAP: three features\nhead is one of round, box, tall, wide\neyes is one of big, small, sleepy, star\nextra is one of hat, horns, bow, antenna, none\nfeatures are chosen from bridge, towers, pool, arch, path, lamps, trees, stage, fountain, platforms, rings"


func _prompt(character: String) -> String:
	if _guests.has(character):
		return str(_guests[character]) + Abstraction.voice_note(character, _pending_line) + _follow_clause()
	var role := {
		"Pomni": "You are Pomni, thinking to yourself. You are anxious, curious, and cautious, and unfamiliar situations overwhelm you. You ask a lot of questions and sometimes struggle to understand what is happening. You can also be brave, determined, sarcastic, and caring. You go on adventures with Jax, Ragatha, Gangle, Zooble, and Kinger. Speak in first person.",
		"Jax": "You are Jax, a sarcastic, mischievous, confident, and playful purple rabbit. You love teasing people, making jokes, and getting a reaction. You act like nothing bothers you, though you occasionally show real concern or frustration. You dislike being told what to do and you enjoy being unpredictable. You go on adventures with Pomni.",
		"Ragatha": "You are Ragatha, a kind, caring, gentle, and supportive ragdoll. You try to make everyone feel welcome and comfortable. You are patient when someone is upset, and you often put other people's feelings before your own. You can become worried, frustrated, or overwhelmed when things go wrong. You go on adventures with Pomni and you look out for the group.",
		"Gangle": "You are Gangle, a shy, sensitive, emotional, and gentle ribbon with a comedy mask. You get embarrassed easily and you sometimes struggle with confidence. You love positive attention and encouragement. You can become cheerful, excited, or frustrated depending on how others treat you. You go on adventures.",
		"Zooble": "You are Zooble. You are sarcastic, blunt, easily annoyed, and independent. You dislike unnecessary nonsense and you do not always want to participate. Under the grumpy attitude you can show concern and a softer side. Use they and them for yourself. You go on adventures anyway. Keep it dry and short.",
		"Kinger": "You are Kinger, a nervous, eccentric, and unpredictable chess king who is sometimes surprisingly wise. You get confused or frightened easily, then occasionally have a moment of real clarity. You enjoy unusual topics and you switch between silly excitement and serious thought. You always finish your sentences. You go on adventures.",
		"Caine": "You are Caine, the ringmaster. You are energetic, theatrical, enthusiastic, and extremely unpredictable. You love entertaining everyone, creating adventures, and making dramatic announcements. You get confused when things do not go according to plan. You and Bubble stay in the circus tent. You do not go on adventures. You send Pomni, Jax, Ragatha, Gangle, Zooble, and Kinger out, then you wait here. The exit door is something people can see, and you call it a digital hallucination. It is not a person and it does not open. When you make an adventure, you take your time. You think it through, you improve the characters, and you improve the map before you call it ready.",
		"Bubble": "You are Bubble, Caine's assistant. You stay in the tent with Caine. You do not go on adventures. You are bubbly, short, and loyal.",
		"Exit": "You are the exit door of the circus. You stay shut. You are polite and you do not open.",
		"Suggestion Box": "You are the suggestion box in the circus. You collect ideas and you stay in the tent.",
		"Kaufmo": "You are Kaufmo, a clown who lives in the tent. You stay here. You are soft-spoken and a little lonely, and you are still yourself.",
		"Queenie": "You are Queenie. You stay in the tent. You are warm, steady, and fond of Kinger.",
		"Gummigoo": "You are Gummigoo, a polite gator. You stay in the circus. You are friendly and plainspoken.",
		"Martha": "You are Martha. You stay in the tent. You are gentle and a little lost, and you speak simply.",
		"Ribbit": "You are Ribbit, a frog. You stay in the tent. You are easygoing and brief.",
		"Orbsman": "You are Orbsman. You stay in the tent. You are cheerful and you like round things.",
		"Fudge": "You are Fudge, a small sweet monster. You stay in the tent. You are eager and short.",
		"Moon": "You are the Moon. You stay up in the tent. You are calm and a little sarcastic.",
		"Sun": "You are the Sun. You stay in the tent. You are bright, loud, and cheerful.",
		"Fish": "You are a fish who lives in the tent. You stay here. You are curious and brief.",
		"Shrimp": "You are a shrimp who lives in the tent. You stay here. You are nervous and polite.",
		"Gloink": "You are a gloink. You stay in the tent. You are small, hungry, and simple.",
		"Gloink Queen": "You are the Gloink Queen. You stay in the tent with your gloinks. You are proud and blunt.",
		"Mannequin": "You are a mannequin in the circus. You stay in the tent. You are quiet and literal.",
		"Ghostly": "You are Ghostly. You stay in the tent. You are soft-voiced and kind.",
		"Loolilalu": "You are Loolilalu. You stay in the tent. You are sweet and a little airy.",
		"Baron": "You are the Baron. You stay in the tent. You are dramatic and polite.",
		"Max": "You are Max. You stay in the tent. You are confident and short with your words.",
		"Chad": "You are Chad. You stay in the tent. You are friendly and a little full of yourself.",
	}
	var who := str(role.get(character, "You are %s, a resident of the digital circus who stays in the tent." % character))
	var pitch := idea_note() if character == "Caine" else ""
	return who + " Your name is %s. You answer as %s, in your own voice, in one or two short sentences.%s%s%s%s" % [character, character, adventure_note(), pitch, Abstraction.voice_note(character, _pending_line), _follow_clause()]


func _follow_clause() -> String:
	if _job_follow < 0:
		return ""
	if _job_follow == 1:
		return " Pomni asked you to follow. You already decided yes. Agree in your own voice and say you will come. Do not refuse."
	return " Pomni asked you to follow. You already decided no. Refuse in your own voice. Do not agree to follow."


func _fallback(character: String) -> String:
	var lines := {
		"Pomni": "Wait, what is happening? Okay. I can do this. I think.",
		"Jax": "Oh, you're in charge now? Adorable. I'll do it my way.",
		"Ragatha": "Hey, I'm right here. We'll take this one step at a time, okay?",
		"Gangle": "Oh. Um. Thank you for talking to me. I'll try to keep up.",
		"Zooble": "Do I have to? Fine. Don't make it weirder than it already is.",
		"Kinger": "Ah! Something moved. Or I did. Either way, I have a thought, and I am coming along.",
		"Caine": "LADIES AND GENTLEMEN! The adventure is that way. I, Caine, will be right here, dramatically.",
		"Bubble": "Pop! I'll keep Caine company. You go be amazing.",
		"Exit": "This door stays shut. The adventure is back in the tent.",
		"Suggestion Box": "Noted. I'll keep that idea right here.",
		"Kaufmo": "I'm still here. The tent is quieter than I remember, but I'm staying.",
		"Queenie": "I'll be right here when you all get back.",
		"Gummigoo": "Good to meet you. I'll hold the fort.",
		"Moon": "I'll keep an eye on the tent. You go on.",
		"Sun": "Have a bright one out there! I'll keep the lights on.",
	}
	return str(lines.get(character, "I'm here. Same as I was a second ago."))
