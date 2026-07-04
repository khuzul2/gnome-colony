class_name MusicDirector
extends Node
## Music resolution [PROGRESS T20.2]: maps the AmbienceDirector's music
## state (theology outranks rite, T14.4) to a track, with the season
## bed as the "none" fallback, plus screen moments (menu, the lament).
## assets/music holds EMPTY .mp3 placeholders + a Suno brief per track
## (dungeon synth palette) — the folder is .gdignore'd until real
## tracks land (remove .gdignore then), so play() checks availability
## through FileAccess and skips silently. Volume: settings music bus.

const DIR := "res://assets/music"
const STATE_TRACKS := {
	"rite_melody": "rite_melody",
	"hymn_warm": "hymn_warm",
	"hymn_urgent": "hymn_urgent",
}
const SEASON_TRACKS := ["season_spring", "season_summer", "season_autumn", "season_winter"]
const SCREEN_TRACKS := {"menu": "menu_theme", "chronicles": "world_end_lament"}
const EVENT_TRACKS := {"settlement_founded": "frontier_founding"}

var settings: GameSettings = null
## Test hook: the last track the director resolved to.
var last_track := ""

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)


func track_for(music_state: String, season: int) -> String:
	if STATE_TRACKS.has(music_state):
		return "%s/%s.mp3" % [DIR, STATE_TRACKS[music_state]]
	return "%s/%s.mp3" % [DIR, SEASON_TRACKS[season % SEASON_TRACKS.size()]]


func screen_track(screen: String) -> String:
	return "%s/%s.mp3" % [DIR, SCREEN_TRACKS.get(screen, "menu_theme")]


## Load-if-real: empty placeholders (and the .gdignore era) skip
## silently; a real track plays looped on the music bus volume.
func play(track_path: String) -> void:
	last_track = track_path
	if not FileAccess.file_exists(track_path):
		return
	if FileAccess.get_file_as_bytes(track_path).size() == 0:
		return
	if not ResourceLoader.exists(track_path):
		return
	var stream: AudioStream = load(track_path)
	if stream == null:
		return
	_player.stream = stream
	if settings != null:
		var level: float = (
			float(settings.get_value("audio", "music"))
			* float(settings.get_value("audio", "master"))
		)
		_player.volume_db = linear_to_db(maxf(0.0001, level))
	_player.play()
