extends "res://scripts/caine_voice.gd"


func _api_key() -> String:
	return account_key("bubble")


func _voice_id() -> String:
	return account_voice("bubble")


func _who() -> String:
	return "BUBBLE"
