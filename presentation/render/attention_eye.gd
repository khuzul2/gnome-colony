class_name AttentionEye
extends Node3D
## R7.4 [leg §L-acts] — a faint ring on the ground at each region the Eye is
## currently attending (the dwell→quicken gaze, T13.5), so the player understands
## WHERE gnomes are quickened (materialized as walking bodies) versus folded into
## the aggregate. Presentation-only; RunView feeds it run.attention_places each
## frame. Lives inside the pixel stage so the ring reads through the mosaic.

const RING_ALPHA := 0.35  ## faint — a hint of the god's gaze, not a spotlight
const RING_INNER := 2.2
const RING_OUTER := 2.6

var _rings := {}  ## place id → MeshInstance3D


## Show a ring at each currently-attended place, clearing those the gaze has left.
func refresh(attended: Array, positions: Dictionary) -> void:
	var wanted := {}
	for place in attended:
		if positions.has(place):
			wanted[place] = true
	for place in _rings.keys():
		if not wanted.has(place):
			_rings[place].queue_free()
			_rings.erase(place)
	for place in wanted:
		if _rings.has(place):
			continue
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = RING_INNER
		torus.outer_radius = RING_OUTER
		ring.mesh = torus
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)  # lie flat on the ground
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var col: Color = Palette.COLORS[Palette.GOLD_LIT]
		col.a = RING_ALPHA
		mat.albedo_color = col
		ring.material_override = mat
		ring.position = positions[place] + Vector3(0.0, 0.05, 0.0)
		add_child(ring)
		_rings[place] = ring


func count() -> int:
	return _rings.size()


func has_ring(place: String) -> bool:
	return _rings.has(place)
