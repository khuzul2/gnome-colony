class_name SoundDirector
extends Node
## Diegetic sound [PROGRESS T19.2, design §2.7c]: world sounds fire
## ONLY off EventBus — a landed phenomenon, a life event — never as
## act-confirmation stingers (T14.4's invariant holds: pressing a
## panel button reaches no sound; only the world answering does). UI
## clicks are menu chrome on the UI bus (setup §7.2). Missing files
## skip silently; last_played is the test hook.

const DIR := "res://assets/sounds"
const CORE_EVENTS := {
	"born": "event_born",
	"gnome_died": "event_died",
	"stage_changed": "event_stage_changed",
	"knowledge_lost": "event_knowledge_lost",
	"belief_formed": "event_belief_formed",
	"main_settlement_changed": "event_main_settlement_changed",
	"world_ended": "event_world_ended",
}
const AMBIENCE := [
	"ambience_season_0",
	"ambience_season_1",
	"ambience_season_2",
	"ambience_season_3",
	"ambience_wrongness",
	"ambience_ward",
]
const UI := ["ui_click", "ui_back", "ui_save", "ui_refused"]
## Civilization-season cues [T22.3]: EventBus signal → wav base, the
## same _on_event path as CORE_EVENTS (kept separate — these arrive
## from the shell's season flows, not SimRunner's daily tick).
const EXTRA_EVENT_SIGNALS := {
	"settlement_founded": "event_settlement_founded",
	"discovery_made": "event_discovery",
	"colony_fractured": "event_fracture",
	"war_waged": "event_war",
	"schism_split": "event_schism",
}
const EXTRA_EVENTS := [
	"event_settlement_founded",
	"event_discovery",
	"event_fracture",
	"event_war",
	"event_schism",
]
const POOL := 6

var settings: GameSettings = null
var last_played := ""

var _players: Array = []
var _next := 0


func _ready() -> void:
	for i in POOL:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	EventBus.phenomenon.connect(_on_phenomenon)
	for signal_name in CORE_EVENTS:
		EventBus.connect(signal_name, _on_event.bind(CORE_EVENTS[signal_name]))
	for signal_name in EXTRA_EVENT_SIGNALS:
		EventBus.connect(signal_name, _on_event.bind(EXTRA_EVENT_SIGNALS[signal_name]))


func _exit_tree() -> void:
	EventBus.phenomenon.disconnect(_on_phenomenon)
	for signal_name in CORE_EVENTS:
		EventBus.disconnect(signal_name, _on_event.bind(CORE_EVENTS[signal_name]))
	for signal_name in EXTRA_EVENT_SIGNALS:
		EventBus.disconnect(signal_name, _on_event.bind(EXTRA_EVENT_SIGNALS[signal_name]))


## Menu chrome only — never wired to influence acts.
func ui(sound_name: String) -> void:
	_play(sound_name, "ui")


func _on_phenomenon(payload: Dictionary) -> void:
	var type := str(payload.get("type", ""))
	if type.begins_with("tail:"):
		type = type.substr(5)
	var base := (
		"consequence_%s" % type if payload.get("consequence", false) else "phenomenon_%s" % type
	)
	_play(base, "sfx")


func _on_event(_payload: Dictionary, base: String) -> void:
	_play(base, "sfx")


func _play(base: String, bus: String) -> void:
	var path := "%s/%s.wav" % [DIR, base]
	last_played = path
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	player.stream = stream
	if settings != null:
		var level: float = (
			float(settings.get_value("audio", bus)) * float(settings.get_value("audio", "master"))
		)
		player.volume_db = linear_to_db(maxf(0.0001, level))
	player.play()
