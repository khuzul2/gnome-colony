class_name TerrainField
extends RefCounted
## The Gaea detail source for the terrain skin [gaea §gaea-gen, §gaea-det].
## Presentation-only: it reads the sim's RegionGraph read-only and never touches the
## sim. It produces a deterministic, sub-basin DETAIL field that G1.2 anchors to the
## basins (attenuating detail near basin centers so height_at(center) still reads the
## region elevation) and G2 feeds into WorldView._raw_height.
##
## HOW IT USES GAEA. It mirrors Gaea's noise node (GaeaNodeNoise,
## addons/gaea/runtime/graph_nodes/root/sampling/noise/noise.gd) EXACTLY — same
## SIMPLEX_SMOOTH default, FBM fractal (octaves + lacunarity), `seed + salt`
## derivation, and `(v + 1) / 2` → [0,1] normalization — on the FastNoiseLite that
## Gaea's node forwards to (`_get_noise_value` = `noise.get_noise_2d`). We sample that
## FastNoiseLite CONTINUOUSLY (float world-km) rather than on Gaea's integer generation
## grid, because height_at must be continuous for picking / nav / puppet placement.
## Gaea's async/threaded graph GENERATOR is deliberately NOT used: it defaults to a
## random per-generate seed and runs off the main thread, both at odds with the sim's
## deterministic + synchronous + headless contract. The addon stays vendored/enabled
## for its richer graph/biome features, which G3 can layer on the palette bands.
##
## DETERMINISM [gaea §gaea-det]. The noise is seeded from the world seed
## (WorldConfig.seed) plus a fixed salt — NEVER the Rng singleton, never Time — so a
## full generation draws ZERO from the sim's Rng stream (test_terrain_field.gd pins it)
## and identical seeds reproduce the field.

## [gaea §gaea-gen] — STARTING values, tunable at Gate G.
const DETAIL_OCTAVES := 4
const DETAIL_FREQ_PER_KM := 0.08
## Gaea's GaeaNodeNoise defaults (noise.gd): SIMPLEX_SMOOTH + lacunarity 2.0. Mirrored
## here so the field matches what Gaea would produce; not new tunable spec numbers.
const NOISE_TYPE := FastNoiseLite.TYPE_SIMPLEX_SMOOTH
const DETAIL_LACUNARITY := 2.0
## Fixed sub-seed offset [gaea §gaea-det: "a fixed offset or hash"] — structural, not
## the Rng singleton. Decouples the detail seed from any other seed derived from the
## world seed.
const DETAIL_SALT := 0x7A11

var _noise: FastNoiseLite
## Held for G1.2's basin anchoring (attenuate detail near basin centers); unused by the
## raw detail field in G1.1.
var _graph: RegionGraph


## Build the detail field for a world. `seed_value` is WorldConfig.seed (or any int) —
## the field is a pure function of it; no Rng/Time is consulted.
func generate(graph: RegionGraph, seed_value: int) -> void:
	_graph = graph
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value + DETAIL_SALT
	_noise.noise_type = NOISE_TYPE
	_noise.frequency = DETAIL_FREQ_PER_KM
	_noise.fractal_octaves = DETAIL_OCTAVES
	_noise.fractal_lacunarity = DETAIL_LACUNARITY


## Detail noise in [0,1] at a world-plane point (km). Mirrors Gaea's GaeaNodeNoise
## normalization; deterministic; draws nothing from the Rng singleton.
func detail_at(point: Vector2) -> float:
	var raw := _noise.get_noise_2d(point.x, point.y)
	return (raw + 1.0) * 0.5
