extends "res://scripts/caine_voice.gd"


func _api_key() -> String:
	return account_key("ragatha")


func _voice_id() -> String:
	return account_voice("ragatha")


func _who() -> String:
	return "RAGATHA"
