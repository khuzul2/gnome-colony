class_name CastMarkers
extends Node3D
## R7.3 [leg §L-acts] — transient on-map markers for LANDED phenomena: when an act
## (or a natural event) lands, a Ravenna medallion flashes at its place — a gold
## monogram for a benevolent act, an oxblood ring for a malevolent one, a bone
## pulse otherwise — then shrinks away over CAST_MARKER_SECONDS. So a cast reads as
## a mark on the world, not just a sound.
##
## Owns its EventBus.phenomenon subscription (connected in _ready, dropped in
## _exit_tree). Diegetic discipline holds (T14.4): it fires only off the LANDED
## event, never off arming or a press — an armed-but-unpressed act emits no
## phenomenon, so it makes no marker. RunView feeds `place_positions`; lives inside
## the pixel stage so the markers render through the mosaic.

const CAST_MARKER_SECONDS := 4.0
## In the final second the marker shrinks out (a fade without material alpha).
const FADE_SECONDS := 1.0

## place id → world position, set by RunView (the same map the stage uses).
var place_positions: Dictionary = {}
## Live markers: [{node: Node3D, ttl: float}].
var _markers: Array = []


func _ready() -> void:
	EventBus.phenomenon.connect(_on_phenomenon)


func _exit_tree() -> void:
	if EventBus.phenomenon.is_connected(_on_phenomenon):
		EventBus.phenomenon.disconnect(_on_phenomenon)


func _on_phenomenon(payload: Dictionary) -> void:
	var place: String = payload.get("place", "")
	if not place_positions.has(place):
		return
	var marker := Motifs.build_place_medallion(_kind_for(payload.get("valence", "neutral")))
	if marker == null:
		return
	marker.position = place_positions[place] + Vector3(0.0, 0.1, 0.0)
	add_child(marker)
	_markers.append({"node": marker, "ttl": CAST_MARKER_SECONDS})


func _process(delta: float) -> void:
	var alive: Array = []
	for m in _markers:
		m["ttl"] = float(m["ttl"]) - delta
		if m["ttl"] <= 0.0:
			m["node"].queue_free()
			continue
		var node: Node3D = m["node"]
		node.scale = Vector3.ONE * clampf(m["ttl"] / FADE_SECONDS, 0.0, 1.0)
		alive.append(m)
	_markers = alive


func _kind_for(valence: String) -> String:
	match valence:
		"benevolent":
			return Motifs.BLESSED
		"malevolent":
			return Motifs.CURSED
	return Motifs.NEUTRAL
