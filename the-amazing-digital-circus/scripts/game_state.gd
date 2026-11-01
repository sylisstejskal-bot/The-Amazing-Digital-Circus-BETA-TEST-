extends Node

signal progress_changed
signal adventure_completed
signal adventure_began

const ORB_GOAL := 8

var orbs_found := 0
var completed := false
var adventure_started := false


func reset() -> void:
	orbs_found = 0
	completed = false
	adventure_started = false
	LocalAI.reset()
	Abstraction.reset()
	progress_changed.emit()


func start_adventure() -> void:
	if adventure_started:
		return
	adventure_started = true
	adventure_began.emit()


func collect() -> void:
	if completed:
		return
	orbs_found += 1
	progress_changed.emit()
	if orbs_found >= ORB_GOAL:
		completed = true
		adventure_completed.emit()
