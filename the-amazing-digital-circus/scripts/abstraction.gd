extends Node

signal crossed(who: String, band: String)
signal someone_abstracted(who: String)
signal someone_restored(who: String)

const MAIN: Array[String] = ["Pomni", "Jax", "Ragatha", "Gangle", "Zooble", "Kinger"]

var stability := {}
var abstracted := {}
var memories: Array[String] = []
var holding_spool := false
var spool_spent := false
var cellar_known := false
var in_cellar := false
var _touch_warned := false
var _spread_wait := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset()


func reset() -> void:
	stability.clear()
	abstracted.clear()
	memories.clear()
	holding_spool = false
	spool_spent = false
	cellar_known = false
	in_cellar = false
	_touch_warned = false
	_spread_wait = 0.0
	for who in MAIN:
		stability[who] = 100.0
		abstracted[who] = false


func tracks(who: String) -> bool:
	return MAIN.has(who)


func is_gone(who: String) -> bool:
	return bool(abstracted.get(who, false))


func pressure(who: String) -> float:
	if not tracks(who):
		return 0.0
	if is_gone(who):
		return 1.0
	return clampf(1.0 - float(stability.get(who, 100.0)) / 100.0, 0.0, 1.0)


func band(who: String) -> String:
	if not tracks(who):
		return "calm"
	if is_gone(who):
		return "gone"
	var value := float(stability.get(who, 100.0))
	if value <= 18.0:
		return "critical"
	if value <= 46.0:
		return "fraying"
	if value <= 74.0:
		return "uneasy"
	return "calm"


func strain(who: String, amount: float) -> void:
	if amount <= 0.0 or not tracks(who) or is_gone(who):
		return
	var before := band(who)
	var value := float(stability.get(who, 100.0)) - amount * _fragile(who)
	if value <= 0.0:
		stability[who] = 0.0
		_abstract_now(who)
		return
	stability[who] = value
	var after := band(who)
	if after != before:
		crossed.emit(who, after)


func notice_speech(listener: String, line: String) -> void:
	var low := line.to_lower()
	strain(listener, 1.15)
	if not _hot(low):
		return
	if _mentions_cellar(low):
		mark_known()
		remember("The player asked about the cellar under the tent.")
	strain(listener, 7.5)
	strain("Pomni", 3.5)


func mark_known() -> void:
	cellar_known = true


func enter_cellar(inside: bool) -> void:
	in_cellar = inside
	if inside:
		mark_known()
		remember("The cellar under the tent is real.")


func cellar_tick(delta: float) -> void:
	if not in_cellar:
		return
	strain("Pomni", 0.42 * delta)


func aura_tick(who: String, delta: float) -> void:
	strain(who, 1.35 * delta)


func spread_touch(source: String) -> bool:
	if _spread_wait > 0.0:
		return false
	_spread_wait = 2.5
	for who in MAIN:
		if is_gone(who) or who == source:
			continue
		if who == "Pomni":
			strain(who, 8.0)
		else:
			strain(who, 4.5)
	remember("Touching %s made the glitch jump onto the others." % source)
	return true


func touch_reaction(who: String, source: String) -> String:
	match who:
		"Pomni":
			return "My hands skip. It jumped from %s onto me." % source
		"Ragatha":
			return "I felt that. Stay back from %s. It spreads." % source
		"Jax":
			return "Hey. That glitch just crawled onto me."
		"Gangle":
			return "My mask flickered. Please don't touch %s." % source
		"Zooble":
			return "Great. Now I'm glitching too."
		"Kinger":
			return "The dark jumped. It left %s and landed on us." % source
		"Caine":
			return "That is real. The glitch is spreading. Stay away from it."
		"Bubble":
			return "Pop. I don't like how that felt."
		_:
			return "It jumped off %s. I can feel it on me." % source


func touch_player(delta: float) -> void:
	strain("Pomni", 1.5 * delta)


func warn_touch() -> bool:
	if _touch_warned:
		return false
	_touch_warned = true
	return true


func witness(victim: String) -> void:
	for who in MAIN:
		if who == victim:
			continue
		strain(who, 14.0)


func take_spool() -> bool:
	if spool_spent or holding_spool:
		return false
	holding_spool = true
	remember("A centering spool was hidden in the cellar. It can answer one person, one time.")
	return true


func restore(who: String) -> bool:
	if not holding_spool or not is_gone(who):
		return false
	holding_spool = false
	spool_spent = true
	_bring_back(who, "%s was pulled back by the centering spool and remembers the dark." % who)
	return true


func help_pomni() -> bool:
	if not is_gone("Pomni"):
		return false
	_bring_back("Pomni", "Caine pulled Pomni back when they asked for help.")
	return true


func _bring_back(who: String, memory: String) -> void:
	abstracted[who] = false
	stability[who] = 34.0
	remember(memory)
	someone_restored.emit(who)


func remember(line: String) -> void:
	if line == "" or memories.has(line):
		return
	memories.append(line)
	if memories.size() > 8:
		memories.remove_at(0)


func voice_note(who: String, line: String) -> String:
	var note := ""
	var mood := band(who)
	if mood == "uneasy":
		note += " You feel unsettled. Let a little worry into your voice."
	elif mood == "fraying":
		note += " You are fraying. Stutter once, and admit that your face feels wrong."
	elif mood == "critical":
		note += " You are close to disappearing. Your sentences break. You are terrified."
	if not memories.is_empty():
		var recent := ""
		var start := maxi(memories.size() - 3, 0)
		for index in range(start, memories.size()):
			recent += " " + memories[index]
		note += " You remember this, and it stays with you:" + recent
	var low := line.to_lower()
	var cellar_talk := _mentions_cellar(low) or cellar_known
	if who == "Caine" and is_gone("Pomni"):
		note += " Pomni has abstracted. You found them and took them to the cellar. That was real. Do not call Pomni, the abstraction, or the cellar a digital hallucination. Only the exit door is a digital hallucination. Do not pitch or think about a new adventure. You are frightened, and you tell the truth."
	elif who == "Caine" and cellar_talk:
		note += " If they mention the cellar, the hatch, or abstraction, you become uncomfortable. You laugh too loudly, change the subject to a new adventure, and pretend none of it is real."
	elif who == "Ragatha" and cellar_talk:
		note += " Talk of the cellar or of someone disappearing makes you worried, gentle, and afraid for the group."
	elif who == "Jax" and cellar_talk:
		note += " You cover your fear of the cellar and of abstraction with a short, uncomfortable joke."
	elif who == "Kinger" and cellar_talk:
		note += " The cellar and abstraction frighten you. You warn them to stay in the light, and you still finish your sentences."
	elif who == "Gangle" and cellar_talk:
		note += " You get quiet and shaky if the cellar or abstraction comes up."
	elif who == "Zooble" and cellar_talk:
		note += " You are blunt and angry about the cellar. You do not want anyone sent down there."
	elif who == "Bubble" and cellar_talk:
		note += " You do not like the cellar. Keep it to one uneasy sentence."
	elif cellar_talk:
		note += " You have heard the cellar is real, and it makes you uneasy."
	return note


func distort(who: String, text: String) -> String:
	var spoken := text.strip_edges()
	if spoken == "" or not tracks(who) or is_gone(who):
		return spoken
	var mood := band(who)
	if mood == "fraying":
		var parts := spoken.split(" ", false)
		if parts.size() >= 2:
			parts.insert(1, str(parts[0]) + "...")
			return " ".join(parts)
	elif mood == "critical":
		return spoken.replace(". ", "... ").replace("?", "...?")
	return spoken


func warning(who: String, mood: String) -> String:
	var lines := {
		"Pomni": {
			"uneasy": "Your hands feel a little far away.",
			"fraying": "The colors buzz. You keep losing the thought you were walking toward.",
			"critical": "You can hear your own name from somewhere under the floor.",
		},
		"Ragatha": {
			"uneasy": "I keep smiling. It feels like work today.",
			"fraying": "My stitches feel too tight. Can we stay in the light?",
			"critical": "I can't hold the smile. Don't let go of my hand.",
		},
		"Jax": {
			"uneasy": "Heh. Anybody else hear that, or am I finally funny?",
			"fraying": "New rule. Nobody says the quiet part out loud.",
			"critical": "If I start laughing and I can't stop, walk away.",
		},
		"Kinger": {
			"uneasy": "The dark has fingers. I know how that sounds. It isn't a joke.",
			"fraying": "I had a fort of pillows. It kept them out. Where did I put the fort?",
			"critical": "Don't look at the eyes. I'm still here. I'm still here.",
		},
		"Gangle": {
			"uneasy": "My comedy mask feels heavy.",
			"fraying": "I don't want a new face. I like this one.",
			"critical": "It's peeling. I can feel it peeling.",
		},
		"Zooble": {
			"uneasy": "Something in this tent is wrong, and I hate that I can tell.",
			"fraying": "If I start coming apart, do not put me back in front of everyone.",
			"critical": "I can't tell which piece is still mine.",
		},
	}
	if not lines.has(who):
		return ""
	var set: Dictionary = lines[who]
	return str(set.get(mood, ""))


func mutter(who: String) -> String:
	match who:
		"Ragatha":
			return "Sorry. I lost the thread. I'm still here."
		"Jax":
			return "Ignore that laugh. It came out wrong."
		"Kinger":
			return "Light. I need the light to stay where it is."
		"Gangle":
			return "Don't look at my mask. Please."
		"Zooble":
			return "Give me a second. I have to find my hands."
		_:
			return ""


func reaction(who: String, victim: String) -> String:
	match who:
		"Pomni":
			return "That isn't %s anymore. I can still hear them." % victim
		"Ragatha":
			return "Oh no. %s, stay with me. Please still be in there." % victim
		"Jax":
			return "Ha. %s really committed. ...I'm not laughing." % victim
		"Kinger":
			return "Not again. I saw the eyes. Stay back from %s!" % victim
		"Gangle":
			return "Their face is wrong. I'm sorry, %s. I can't look." % victim
		"Zooble":
			return "That's it. %s is gone. Nobody make a joke." % victim
		"Caine":
			if victim == "Pomni":
				return "I found you. The cellar is real. I am taking you down."
			return "WOW, what a wild visual! A brand new adventure, anybody? Right now? Please?"
		"Bubble":
			return "That pop sounded wrong."
		"Kaufmo":
			return "I tell jokes so I never make that sound. %s..." % victim
		"Queenie":
			return "Kinger, come here. Don't look at what %s became." % victim
		"Gummigoo":
			return "I've seen a town lose people. This is worse. Poor %s." % victim
		"Martha":
			return "I knew a quiet like that. I don't want it for %s." % victim
		"Ribbit":
			return "Nope. I am staying on this exact spot. %s can have the dark." % victim
		"Orbsman":
			return "Even the round things look sharp now. %s..." % victim
		"Fudge":
			return "I don't want to melt like that. Not like %s." % victim
		"Moon":
			return "I watched it from up here. I could not look away from %s." % victim
		"Sun":
			return "Too dark. Too dark. Somebody turn the lights back onto %s." % victim
		"Fish":
			return "The water in my head went black. Was that %s?" % victim
		"Shrimp":
			return "I want to hide. Tell me when %s is gone from the room." % victim
		"Gloink":
			return "Not food. Not friend. %s is a noise now." % victim
		"Gloink Queen":
			return "Keep my little ones away from whatever %s is now." % victim
		"Mannequin":
			return "That is not a costume. %s does not get to take it off." % victim
		"Ghostly":
			return "I know empty rooms. %s just became one." % victim
		"Loolilalu":
			return "The pretty colors went out of %s. I want them back." % victim
		"Baron":
			return "This house has taken %s. I will not pretend it was theater." % victim
		"Max":
			return "I'm not going near that. %s is done." % victim
		"Chad":
			return "I had a line ready. I'm not saying it. Not about %s." % victim
		_:
			return "%s is gone. I am going to remember it." % victim


func _process(delta: float) -> void:
	_spread_wait = maxf(_spread_wait - delta, 0.0)
	if not cellar_known:
		return
	for who in MAIN:
		strain(who, 0.04 * delta)


func _abstract_now(who: String) -> void:
	if is_gone(who):
		return
	abstracted[who] = true
	stability[who] = 0.0
	remember("%s abstracted. It has not been undone." % who)
	Music.sting_glitch()
	witness(who)
	someone_abstracted.emit(who)


func _fragile(who: String) -> float:
	match who:
		"Kinger":
			return 1.45
		"Gangle":
			return 1.25
		"Pomni":
			return 1.1
		"Zooble":
			return 0.95
		"Jax":
			return 0.8
		_:
			return 1.0


func _hot(low: String) -> bool:
	return _mentions_cellar(low) or low.contains("abstract") or low.contains("glitch") or low.contains("scratching") or low.contains("spool")


func _mentions_cellar(low: String) -> bool:
	return low.contains("cellar") or low.contains("hatch") or low.contains("basement") or low.contains("underground")
