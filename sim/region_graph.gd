class_name RegionGraph
extends RefCounted
## The world's shape [plan T13.1 sim half, design §2.7b, setup §4]: a
## graph of basins — center (abstract km), elevation, biome, neighbors —
## generated from the seeded Rng + Tuning's world block, and reshaped by
## phenomena (each reshape bumps `version` so skins know to re-bake).
## Plain data; the heightmap SKIN lives in presentation/world_view.gd.
## Layout constants below are world-gen scaffolding (structure, not §17
## gameplay numbers — noted in PROGRESS.md): basins sit on a jittered
## ring (guaranteed ring adjacency — no unreachable island basins),
## elevations draw from a hazard-scaled band, biomes from a small pool.

const RING_RADIUS_KM := 10.0
const JITTER_KM := 2.0
const ELEVATION_BASE := 1.0
const ELEVATION_SPAN := 2.0
const BIOMES := ["meadow", "forest", "ridge", "marsh"]

var regions: Array = []
var version := 0


## World-gen [setup §4]: `world_params` is Tuning.resolve(cfg)["world"].
## Hazardous worlds are more rugged (elevation span scales with hazard
## density); Uniform variety collapses the biome pool to its first entry.
static func generate(world_params: Dictionary) -> RegionGraph:
	var graph := RegionGraph.new()
	var count: int = world_params["basin_count"]
	var span: float = ELEVATION_SPAN * world_params["hazard_density_mult"]
	for i in count:
		var angle := TAU * i / count
		var center := (
			Vector2.from_angle(angle) * RING_RADIUS_KM
			+ Vector2(
				Rng.randf_range(-JITTER_KM, JITTER_KM), Rng.randf_range(-JITTER_KM, JITTER_KM)
			)
		)
		var biome: String = BIOMES[0]
		if world_params["varied_biomes"]:
			biome = BIOMES[Rng.randi_range(0, BIOMES.size() - 1)]
		(
			graph
			. regions
			. append(
				{
					"id": i,
					"center": center,
					"elevation": ELEVATION_BASE + Rng.randf() * span,
					"biome": biome,
					"neighbors": [(i - 1 + count) % count, (i + 1) % count],
				}
			)
		)
	return graph


## Phenomena reshape the ground [design §2.7b]: elevation moves (floored
## at sea level) and the version tells every skin to re-bake.
func reshape(region_id: int, delta_elevation: float) -> void:
	var region: Dictionary = regions[region_id]
	region["elevation"] = maxf(0.0, region["elevation"] + delta_elevation)
	version += 1
