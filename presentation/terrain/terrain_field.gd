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

## [gaea §gaea-gen] — detail height as a fraction of the relief span; STARTING value.
const DETAIL_AMPLITUDE_T := 0.35
## [gaea §gaea-anchor] — within this radius of a basin center the detail is attenuated
## toward 0, so the center keeps its authored elevation; beyond it, full detail.
const ANCHOR_RADIUS_KM := 3.0
## [gaea §gaea-anchor] — max normalized-height error allowed at a basin center.
const ANCHOR_TOL := 0.05

var _noise: FastNoiseLite
## Read read-only for the IDW base and the basin-anchor attenuation (never mutated).
var _graph: RegionGraph
## Elevation bounds of the graph's basins — the span the detail amplitude scales by and
## normalize_elevation maps over (the same bounds WorldView bakes its palette bands on).
var _min_e := 0.0
var _span := 1.0


## Build the field for a world. `seed_value` is WorldConfig.seed (or any int) — the field
## is a pure function of it; no Rng/Time is consulted.
func generate(graph: RegionGraph, seed_value: int) -> void:
	_graph = graph
	var min_e := INF
	var max_e := -INF
	for region in graph.regions:
		min_e = minf(min_e, region["elevation"])
		max_e = maxf(max_e, region["elevation"])
	_min_e = min_e
	_span = maxf(0.001, max_e - min_e)
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


## The large-scale basin field: inverse-distance-weighted region elevation (the same
## authority WorldView baked before Gaea — G2 routes WorldView._raw_height through this).
func idw_base(point: Vector2) -> float:
	var weight_sum := 0.0
	var height := 0.0
	for region in _graph.regions:
		var d2: float = maxf(0.01, point.distance_squared_to(region["center"]))
		var w := 1.0 / d2
		weight_sum += w
		height += w * region["elevation"]
	return height / weight_sum if weight_sum > 0.0 else 0.0


## [gaea §gaea-anchor] — 0 at a basin center, ramping to 1 beyond ANCHOR_RADIUS_KM of the
## NEAREST basin center, so centers keep their elevation and open ground gets full detail.
func _attenuation(point: Vector2) -> float:
	var nearest_km := INF
	for region in _graph.regions:
		nearest_km = minf(nearest_km, point.distance_to(region["center"]))
	return smoothstep(0.0, ANCHOR_RADIUS_KM, nearest_km)


## [gaea §gaea-anchor] — the anchored raw height: basin field + attenuated Gaea detail,
## the detail scaled to DETAIL_AMPLITUDE_T of the elevation span and centered on 0 so it
## lifts and lowers the ground symmetrically. Same units as idw_base (so WorldView's R5
## relief normalization applies unchanged in G2).
func raw_height(point: Vector2) -> float:
	var detail := (detail_at(point) - 0.5) * DETAIL_AMPLITUDE_T * _span
	return idw_base(point) + _attenuation(point) * detail


## Map a raw elevation to [0,1] over the graph's basin bounds (WorldView's _relief_t uses
## the same bounds); the space the ANCHOR_TOL guarantee is stated in.
func normalize_elevation(elevation: float) -> float:
	return clampf((elevation - _min_e) / _span, 0.0, 1.0)
