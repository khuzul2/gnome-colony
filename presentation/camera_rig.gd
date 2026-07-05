class_name CameraRig
extends Node3D
## The three-zoom lens [plan T13.4, design §1.7c]: civilization →
## settlement → individual, discrete and clamped. The rig starts at
## SETTLEMENT (the game is aggregate-primary with frequent individual
## zooms). Heights/pitches are presentation numbers. The Eye's dwell
## logic (T13.5) reads this rig; the sim never does.

signal zoom_changed(level: int)

enum Zoom { CIVILIZATION, SETTLEMENT, INDIVIDUAL }

# R5.2 [leg §L-relief]: the old near-top-down angles (−90/−60/−35) hid the
# terrain relief. Tilt oblique so hills read in profile; heights nudge up to keep
# the same ground framing under the shallower pitch. Tuned at Gate A2.
const HEIGHTS := {Zoom.CIVILIZATION: 135.0, Zoom.SETTLEMENT: 42.0, Zoom.INDIVIDUAL: 9.0}
const PITCHES_DEG := {Zoom.CIVILIZATION: -72.0, Zoom.SETTLEMENT: -45.0, Zoom.INDIVIDUAL: -28.0}

# R5.2 [leg §L-relief] pixel-snap grid (km ≈ one internal pixel of ground at each
# zoom): the PRESENTED camera is quantized to this grid so the mosaic grout does
# not crawl on pan. The snap lives in the child Camera3D's offset only — the rig's
# logical `position` stays continuous, so pan precision (T23.2) is untouched.
# Targeting undoes the offset to read the true aim (RunView._ground_point, the
# "pick uses pre-snap transform" rule, [leg §L-ui]). Starting values, tuned Gate A2.
const PIXEL_GRID_KM := {Zoom.CIVILIZATION: 0.6, Zoom.SETTLEMENT: 0.14, Zoom.INDIVIDUAL: 0.03}

var level: int = Zoom.SETTLEMENT
var camera := Camera3D.new()
## Enabled by RunView on the presented stage; off for bare-rig logic/tests.
var snap_enabled := false


func _ready() -> void:
	add_child(camera)
	# T23.1: without an explicit current camera the 3D viewport renders
	# from nothing — a human sees only the HUD over a void. The rig owns
	# the one live camera for the whole run.
	camera.current = true
	_apply()


func zoom_in() -> void:
	_set_level(mini(level + 1, Zoom.INDIVIDUAL))


func zoom_out() -> void:
	_set_level(maxi(level - 1, Zoom.CIVILIZATION))


## Aim the rig at a world point (the camera hangs above it per level).
## The rig's position is the true, continuous aim; the presented camera may be
## pixel-snapped on top of it [R5.2].
func focus(point: Vector3) -> void:
	position = point
	_apply()


func _set_level(new_level: int) -> void:
	if new_level == level:
		return
	level = new_level
	_apply()
	zoom_changed.emit(level)


func _apply() -> void:
	# The child camera hangs at the per-zoom height/pitch. When snapping, its
	# planar offset quantizes the GLOBAL camera position to the pixel grid while
	# the rig's own `position` stays continuous [R5.2, leg §L-relief].
	var offset := Vector2.ZERO
	if snap_enabled:
		var g: float = PIXEL_GRID_KM[level]
		offset.x = roundf(position.x / g) * g - position.x
		offset.y = roundf(position.z / g) * g - position.z
	camera.position = Vector3(offset.x, HEIGHTS[level], offset.y)
	camera.rotation_degrees = Vector3(PITCHES_DEG[level], 0.0, 0.0)
