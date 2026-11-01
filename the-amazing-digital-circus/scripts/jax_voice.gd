extends "res://scripts/caine_voice.gd"


func _api_key() -> String:
	return account_key("jax")


func _voice_id() -> String:
	return account_voice("jax")


func _who() -> String:
	return "JAX"
