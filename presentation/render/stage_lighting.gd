class_name StageLighting
extends RefCounted
## R1.4 [rav §R-art]: the late-antique mood — one low, warm gold key light over
## a deep-lapis ambient, so figures read luminous against a dark ground (the
## Ravenna idiom). Replaces RunView's plain daylight. Applied inside the pixel
## stage's own World3D. The "black crush" is realized by the palette floor
## (#080a12) in the mosaic shader, so it lives here as a documented constant,
## not a second grade; the figure rim is a puppet-material property (R1.5).
## Presentation-only.

const KEY_LIGHT := Color("f2d488")  # gold-lit
const KEY_ENERGY := 1.3
const SUN_ELEVATION_DEG := 28.0  # low, warm — late afternoon
const SUN_AZIMUTH_DEG := -35.0
const AMBIENT_BG := Color("0d1b3e")  # night-lapis
const AMBIENT_ENERGY := 0.35
const GLOW_THRESHOLD := 0.85  # bloom on gold only
const BLACK_CRUSH := 0.04  # realized by the palette floor in mosaic.gdshader
const FIGURE_RIM := Color("f2d488")  # applied on puppets in R1.5
const FIGURE_RIM_STRENGTH := 0.4


static func build_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "sun"
	sun.light_color = KEY_LIGHT
	sun.light_energy = KEY_ENERGY
	sun.rotation_degrees = Vector3(-SUN_ELEVATION_DEG, SUN_AZIMUTH_DEG, 0.0)
	return sun


static func build_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = AMBIENT_BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_BG
	env.ambient_light_energy = AMBIENT_ENERGY
	env.glow_enabled = true
	env.glow_hdr_threshold = GLOW_THRESHOLD
	return env
