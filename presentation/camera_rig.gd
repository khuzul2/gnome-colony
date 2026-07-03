class_name CameraRig
extends Node3D
## The three-zoom lens [plan T13.4, design §1.7c]: civilization →
## settlement → individual, discrete and clamped. The rig starts at
## SETTLEMENT (the game is aggregate-primary with frequent individual
## zooms). Heights/pitches are presentation numbers. The Eye's dwell
## logic (T13.5) reads this rig; the sim never does.

signal zoom_changed(level: int)

enum Zoom { CIVILIZATION, SETTLEMENT, INDIVIDUAL }

const HEIGHTS := {Zoom.CIVILIZATION: 120.0, Zoom.SETTLEMENT: 35.0, Zoom.INDIVIDUAL: 8.0}
const PITCHES_DEG := {Zoom.CIVILIZATION: -90.0, Zoom.SETTLEMENT: -60.0, Zoom.INDIVIDUAL: -35.0}

var level: int = Zoom.SETTLEMENT
var camera := Camera3D.new()


func _ready() -> void:
	add_child(camera)
	_apply()


func zoom_in() -> void:
	_set_level(mini(level + 1, Zoom.INDIVIDUAL))


func zoom_out() -> void:
	_set_level(maxi(level - 1, Zoom.CIVILIZATION))


## Aim the rig at a world point (the camera hangs above it per level).
func focus(point: Vector3) -> void:
	position = point


func _set_level(new_level: int) -> void:
	if new_level == level:
		return
	level = new_level
	_apply()
	zoom_changed.emit(level)


func _apply() -> void:
	camera.position = Vector3(0.0, HEIGHTS[level], 0.0)
	camera.rotation_degrees = Vector3(PITCHES_DEG[level], 0.0, 0.0)
