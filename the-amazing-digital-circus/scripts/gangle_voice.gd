extends "res://scripts/caine_voice.gd"


func _api_key() -> String:
	return account_key("gangle")


func _voice_id() -> String:
	return account_voice("gangle")


func _who() -> String:
	return "GANGLE"
