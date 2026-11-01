extends "res://scripts/caine_voice.gd"


func _api_key() -> String:
	return account_key("kinger")


func _voice_id() -> String:
	return account_voice("kinger")


func _who() -> String:
	return "KINGER"
