class_name AmbienceDirector
extends Node
## Diegetic ambience [plan T14.4, design §2.7c — locked intent]: the
## director turns sim state into ambience-layer PARAMETERS (the audio
## bus glue consumes them later; headless tests read them directly).
## Silence is the primary instrument — a landed still_air/birds_silent
## stimulus mutes its place and the world only breathes back after a
## fade (presentation seconds). Tainted beats raise a "wrongness"
## detune ("familiar, slightly wrong"). Music is the colony's culture
## made audible: nothing until a rite crystallizes; a theology adds a
## hymn whose temper is the devotion flavor (§10's sign(awe−fear)) —
## thin and urgent under terror, warm under love. Act feedback is
## STRICTLY diegetic: the director never listens to any UI signal — no
## stinger, no confirmation — only EventBus.phenomenon (the world
## itself) moves a layer. Audio reads the sim, never touches it (§2.1).

## Presentation numbers: how long a stilled place takes to breathe
## again, and how quickly wrongness clears.
const SILENCE_FADE_SECONDS := 30.0
const WRONGNESS_FADE_SECONDS := 45.0
## The §18 acts whose landing IS an audio subtraction.
const SILENCING_TYPES := ["still_air", "birds_silent"]

## place → current level [0,1]; decayed by update(dt).
var _silence := {}
var _wrongness := {}


func _ready() -> void:
	EventBus.phenomenon.connect(_on_phenomenon)


## Wall-clock decay: silence and wrongness fade linearly over their
## presentation windows; the game drives this per frame.
func update(dt_seconds: float) -> void:
	_fade(_silence, dt_seconds / SILENCE_FADE_SECONDS)
	_fade(_wrongness, dt_seconds / WRONGNESS_FADE_SECONDS)


## The ambience-layer parameters for one place, read fresh from the
## sim: season bed, local mood room-tone (§5 via Heatmap — the same
## substrate the map paints), silence/wrongness levels, and the
## emergent music layer.
func params(colony: Colony, time: TimeService, place: String) -> Dictionary:
	var moods := Heatmap.from_gnomes(colony)
	return {
		"season": time.season(),
		"mood": moods[place]["mood"] if moods.has(place) else 1.0,
		"silence": _silence.get(place, 0.0),
		"wrongness": _wrongness.get(place, 0.0),
		"music": _music(colony),
	}


## §2.7c: the soundtrack is their culture, audible. A crystallized rite
## brings the first melody; a theology brings hymns tempered by the
## devotion flavor. Theology outranks rite (the god's music is louder
## than the harvest's) — presentation layering, not sim state.
func _music(colony: Colony) -> String:
	var has_rite := false
	var has_theology := false
	for belief_obj in colony.beliefs:
		match belief_obj["kind"]:
			"rite":
				has_rite = true
			"theology":
				has_theology = true
	if has_theology:
		return "hymn_urgent" if Devotion.flavor_balance(colony) < 0.0 else "hymn_warm"
	if has_rite:
		return "rite_melody"
	return "none"


## The world is the only feedback channel: a landed stimulus moves the
## layers. Silencing acts mute their place at their intensity; a
## tainted boon detunes it.
func _on_phenomenon(payload: Dictionary) -> void:
	var place: String = payload.get("place", "")
	if place == "":
		return
	if payload.get("type", "") in SILENCING_TYPES:
		var level: float = clampf(payload.get("intensity", 0.0), 0.0, 1.0)
		_silence[place] = maxf(_silence.get(place, 0.0), level)
	if payload.get("taint", "") == "tainted":
		var detune: float = clampf(payload.get("intensity", 0.0), 0.0, 1.0)
		_wrongness[place] = maxf(_wrongness.get(place, 0.0), detune)


func _fade(levels: Dictionary, step: float) -> void:
	for place in levels.keys():
		levels[place] = maxf(0.0, levels[place] - step)
		if levels[place] == 0.0:
			levels.erase(place)
