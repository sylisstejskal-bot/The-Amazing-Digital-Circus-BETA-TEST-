extends RefCounted

static func tree_for(who: String) -> Dictionary:
	match who:
		"Caine":
			return _caine_encore() if Game.completed else _caine()
		"Jax":
			return _jax()
		"Ragatha":
			return _ragatha()
		"Gangle":
			return _gangle()
		"Zooble":
			return _zooble()
		"Kinger":
			return _kinger()
		"Bubble":
			return _bubble()
		"Exit":
			return _exit()
		"Suggestion Box":
			return _box()
		_:
			return {
				"start": {
					"text": "Hello.",
					"choices": [{"label": "See you.", "goto": ""}],
				}
			}


static func _caine() -> Dictionary:
	return {
		"start": {
			"text": "WELCOME to the Amazing Digital Circus! I am Caine, your ringmaster, and today's adventure is the Wacky Orb Roundup. Eight bright orbs wandered off around the tent. Gather every one and I will give you a proper curtain call.",
			"choices": [
				{"label": "Where do I start?", "goto": "hint"},
				{"label": "Who else is here?", "goto": "cast"},
				{"label": "Is the exit open?", "goto": "exit"},
				{"label": "I'm on it.", "goto": ""},
			],
		},
		"hint": {
			"text": "Follow the colored beams. The stage, the castle, the lounge, and the far rooms each hid one. If you lose the trail, the arrow at the top of your view points at the nearest orb. I will stay right here.",
			"choices": [
				{"label": "Tell me about the others.", "goto": "cast"},
				{"label": "Off I go.", "goto": ""},
			],
		},
		"cast": {
			"text": "Jax is the tall purple rabbit. Ragatha is the one with the yarn hair, and she will actually help. Gangle, Zooble, and Kinger are all here in the lounge. Bubble is circling me, which is his entire job description and he is wonderful at it.",
			"choices": [
				{"label": "Where are the orbs?", "goto": "hint"},
				{"label": "Thanks, Caine.", "goto": ""},
			],
		},
		"exit": {
			"text": "The exit is a lovely door and a terrible plan. It stays shut. The adventure, the couches, and the applause are all on this side of it.",
			"choices": [
				{"label": "Then I'll explore the tent.", "goto": ""},
				{"label": "Back.", "goto": "start"},
			],
		},
	}


static func _caine_encore() -> Dictionary:
	return {
		"start": {
			"text": "ENCORE! ENCORE! You found every orb and everybody is still exactly who they were at the top of the show. The tent is yours. Walk it, sit anywhere, and come tell me if you want the lights a little brighter.",
			"choices": [
				{"label": "That was fun.", "goto": "fun"},
				{"label": "Keep the lights just like this.", "goto": ""},
			],
		},
		"fun": {
			"text": "Of course it was fun. I am professionally fun, and you were professionally thorough. Take a bow whenever you feel like it. I will be hovering, on cue, for as long as you stay.",
			"choices": [{"label": "See you in the ring.", "goto": ""}],
		},
	}


static func _jax() -> Dictionary:
	var done := "You actually finished it. I'm almost impressed. Don't let it change you. I'm not changing either." if Game.completed else "Oh good, you're upright. Caine lost eight shiny balls and called it an adventure. They're bright. Even the wallpaper could find them."
	return {
		"start": {
			"text": done,
			"choices": [
				{"label": "Any real advice?", "goto": "advice"},
				{"label": "You're in a good mood.", "goto": "mood"},
				{"label": "Later, Jax.", "goto": ""},
			],
		},
		"advice": {
			"text": "Stay on the floor. The pretty drop under the tent is not a shortcut. Sprint if you want, jump if you must, and don't ask me to carry anything. My hands are decorative.",
			"choices": [{"label": "Noted.", "goto": ""}],
		},
		"mood": {
			"text": "I'm in a stable mood. That's different. Enjoy it while the couches are intact.",
			"choices": [{"label": "I'll take it.", "goto": ""}],
		},
	}


static func _ragatha() -> Dictionary:
	var done := "You did it! I knew you would. Caine's going to be insufferable for a bit, in a sweet way. You can relax now." if Game.completed else "Hi! I'm Ragatha. The tent is big the first time, then it just feels like the living room. Caine's orbs are part of today's show, and they're safe to pick up."
	return {
		"start": {
			"text": done,
			"choices": [
				{"label": "Which way is the stage?", "goto": "stage"},
				{"label": "Are you all doing okay?", "goto": "okay"},
				{"label": "Thanks, Ragatha.", "goto": ""},
			],
		},
		"stage": {
			"text": "Head across the checkerboard until you see the red curtains. The castle sits the other way, past the little striped tents. If you get turned around, come back to the couches. We're the landmark.",
			"choices": [{"label": "I'll start walking.", "goto": ""}],
		},
		"okay": {
			"text": "We are. Kinger's clear-headed, Gangle's mask is on, and Jax is being Jax at a volume I can live with. It's a good day in here. Go have the adventure.",
			"choices": [{"label": "I will.", "goto": ""}],
		},
	}


static func _gangle() -> Dictionary:
	var done := "You found all of them. I watched the colors come back toward the lounge. It was really nice. Thank you for being gentle with them." if Game.completed else "Um. Hi. I'm Gangle. I like the quiet parts between Caine's announcements. The orbs are pretty, especially the red one, if you see it."
	return {
		"start": {
			"text": done,
			"choices": [
				{"label": "Want to come with me?", "goto": "come"},
				{"label": "You doing alright?", "goto": "alright"},
				{"label": "I'll be careful.", "goto": ""},
			],
		},
		"come": {
			"text": "I'll cheer from the couch. I'm a very good quiet cheer. You'll hear it if you listen for someone not yelling.",
			"choices": [{"label": "I'll listen for it.", "goto": ""}],
		},
		"alright": {
			"text": "I am. Ribbons where the ribbons go, mask where the mask goes. You don't have to worry about me today.",
			"choices": [{"label": "Glad to hear it.", "goto": ""}],
		},
	}


static func _zooble() -> Dictionary:
	var done := "Fetch quest: complete. I'm putting that on a nonexistent resume. You can stop sprinting. The tent will still be here." if Game.completed else "Zooble. Caine made a fetch quest. I want that written down somewhere. The orbs are harmless. Pick them up and he'll do the firework thing he rehearses when he thinks we're not looking."
	return {
		"start": {
			"text": done,
			"choices": [
				{"label": "Anything I should avoid?", "goto": "avoid"},
				{"label": "You could sound more excited.", "goto": "excited"},
				{"label": "Thanks.", "goto": ""},
			],
		},
		"avoid": {
			"text": "Holes. If the floor ends, that is the void, and the void is not on the scavenger list. Caine will yank you back, but it's undignified. Use the stairs like a person.",
			"choices": [{"label": "Floors only. Got it.", "goto": ""}],
		},
		"excited": {
			"text": "This is my excited. You'll know I'm upset if I start rearranging my own parts. I'm not. We're fine.",
			"choices": [{"label": "Good enough.", "goto": ""}],
		},
	}


static func _kinger() -> Dictionary:
	var done := "All eight, home safe. I counted on my gloves. I still have the right number of fingers, and you have the right number of orbs. Wonderful arithmetic." if Game.completed else "Hello. I'm Kinger. This is the lounge. Couches are for sitting, the floor is for adventures, and the glowing things are the things Caine asked you to find. I find that nicely organized."
	return {
		"start": {
			"text": done,
			"choices": [
				{"label": "Did you see any orbs?", "goto": "saw"},
				{"label": "How are you feeling?", "goto": "feel"},
				{"label": "Thanks, Kinger.", "goto": ""},
			],
		},
		"saw": {
			"text": "One glow toward the stage curtains. Another by the little castle. A third, I think, was minding its own business near the therapy room. If it shines and hovers, it is yours. If it has wings, it is a butterfly, and it is mine.",
			"choices": [{"label": "I'll check the curtains.", "goto": ""}],
		},
		"feel": {
			"text": "Clear. The pillow fort in my head is stacked the way I left it. If that changes I will tell you in a complete sentence. Deal?",
			"choices": [{"label": "Deal.", "goto": ""}],
		},
	}


static func _bubble() -> Dictionary:
	var done := "ALL ORBS ACCOUNTED FOR. I would eat one to celebrate, but I checked, and they are not food. Caine checked too. We agree. Pop!" if Game.completed else "BUBBLE, reporting for pop! I orbit, I assist, and I do not confuse orbs with lunch. That was a whole meeting."
	return {
		"start": {
			"text": done,
			"choices": [
				{"label": "What do you do, exactly?", "goto": "job"},
				{"label": "Boop.", "goto": "boop"},
				{"label": "Carry on.", "goto": ""},
			],
		},
		"job": {
			"text": "Moral support with a highlight! Caine points, I go 'ooh', the adventure feels five percent more amazing. It is a science.",
			"choices": [{"label": "Science.", "goto": ""}],
		},
		"boop": {
			"text": "Hey! Gentle! I am a sphere on a schedule. Boop received. Boop returned. Pop.",
			"choices": [{"label": "Fair.", "goto": ""}],
		},
	}


static func _exit() -> Dictionary:
	return {
		"start": {
			"text": "The exit is painted, hinged, and not on today's program. Caine keeps it shut so nobody walks into a half-loaded nowhere. The show is back toward the couches.",
			"choices": [
				{"label": "Worth a try.", "goto": "try"},
				{"label": "Back to the tent.", "goto": ""},
			],
		},
		"try": {
			"text": "Tried and admired. The door respects the attempt. It is still a door in the same way a picture of a sandwich is lunch.",
			"choices": [{"label": "Alright. Orbs it is.", "goto": ""}],
		},
	}


static func _box() -> Dictionary:
	return {
		"start": {
			"text": "SUGGESTION BOX. Caine reads these between adventures. Compliments, orb locations, and requests for more couches are welcome. He files the scary ideas under 'no thank you' and leaves them there.",
			"choices": [
				{"label": "Suggest: more curtain calls.", "goto": "more"},
				{"label": "Suggest: leave everyone as they are.", "goto": "stay"},
				{"label": "Close the slot.", "goto": ""},
			],
		},
		"more": {
			"text": "Submitted. Caine will pretend he thought of it. You will know it worked when the fireworks start.",
			"choices": [{"label": "Perfect.", "goto": ""}],
		},
		"stay": {
			"text": "Submitted in very large letters. The box even underlined it. Everybody stays who they are. That's the note on top.",
			"choices": [{"label": "Good.", "goto": ""}],
		},
	}
