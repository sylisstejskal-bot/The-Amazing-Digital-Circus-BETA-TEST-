extends "res://scripts/caine_voice.gd"


func _api_key() -> String:
	return account_key("zooble")


func _voice_id() -> String:
	return account_voice("zooble")


func _who() -> String:
	return "ZOOBLE"
