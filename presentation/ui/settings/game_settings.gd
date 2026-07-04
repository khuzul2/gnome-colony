class_name GameSettings
extends RefCounted
## Global settings [plan T15.4, setup §7]: device-level, persistent in
## user://settings.cfg, and PRESENTATION-ONLY by construction — the
## renderer/audio/input layers read these; the sim cannot (sim/ never
## references presentation, enforced by test). Every default below is a
## presentation number. Render Crowd Density caps how many puppets are
## DRAWN in a dense scene (§7.1) — the sim-affecting quicken budget is
## deliberately a WorldConfig gameplay value, not a settings key, and
## set_value refuses unknown keys so it can never be smuggled in.
## Per-game options (§1–§5) live in the save; this file is the machine's.

const DEFAULTS := {
	"graphics":
	{
		"resolution": "1920x1080",
		"window_mode": "windowed",
		"quality": "high",
		"vsync": true,
		"fps_cap": 60,
		"shadows": "medium",
		"view_distance": "medium",
		"render_crowd_density": 200,
		"ui_scale": 1.0,
	},
	"audio":
	{
		"master": 1.0,
		"music": 0.8,
		"sfx": 1.0,
		"ambient": 1.0,
		"ui": 0.8,
		"mute_on_focus_loss": false,
	},
	"controls":
	{
		"camera_scheme": "orbit",
		"edge_scroll": true,
		"pan_sensitivity": 1.0,
		"zoom_sensitivity": 1.0,
		"rotate_sensitivity": 1.0,
		"invert_zoom": false,
		"controller_enabled": true,
		"controller_layout": "default",
		# §7.3 key rebinding [T21.4]: single-char key names, presentation
		# defaults (input chrome; the sim never reads a key). The action
		# list here IS the whitelist — SettingsView rebuilds the dict from
		# these keys only, so an unknown action has nowhere to live.
		"bindings":
		{
			"pan_up": "W",
			"pan_down": "S",
			"pan_left": "A",
			"pan_right": "D",
			"zoom_in": "E",
			"zoom_out": "Q",
		},
	},
	"gameplay":
	{
		"default_speed": 1.0,
		"autosave": "season",
		"autosave_slots": 3,
		"pause_on_focus_loss": true,
		"hints": "full",
		"tutorial": true,
		"confirmations": true,
		"locale": "en",
		"time_display": "years",
	},
	"accessibility":
	{
		"colorblind": "off",
		"text_size": 1.0,
		"ui_scale": 1.0,
		"reduce_motion": false,
		"high_contrast": false,
		"hold_vs_toggle": "hold",
		"dyslexia_font": false,
		"narration": false,
	},
}

var values := {}


func _init() -> void:
	values = DEFAULTS.duplicate(true)


## Whitelisted writes only: a key the spec doesn't name (say, a
## quicken budget) has nowhere to live here.
func set_value(section: String, key: String, value: Variant) -> bool:
	if not DEFAULTS.has(section) or not DEFAULTS[section].has(key):
		return false
	values[section][key] = value
	return true


func get_value(section: String, key: String) -> Variant:
	return values.get(section, {}).get(key)


## The renderer's puppet budget [§7.1 Render Crowd Density].
func drawn_cap() -> int:
	return int(values["graphics"]["render_crowd_density"])


func save(path: String = "user://settings.cfg") -> void:
	var cfg := ConfigFile.new()
	for section in values:
		for key in values[section]:
			cfg.set_value(section, key, values[section][key])
	cfg.save(path)


static func load_from(path: String = "user://settings.cfg") -> GameSettings:
	var out := GameSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return out
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			out.set_value(section, key, cfg.get_value(section, key))
	return out
