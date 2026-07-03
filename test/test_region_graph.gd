extends GutTest

## T13.1 (sim half) — the region-graph [design §2.7b, setup §4]: the
## world is a graph of basins (position, elevation, biome, neighbors),
## generated from seed + the Tuning world block, reshapable by phenomena
## (a version counter tells skins to re-bake). All randomness through
## Rng: same seed + params → the same world. Layout numbers (ring
## radius, jitter, elevation band) are world-gen scaffolding, not §17
## gameplay numbers (documented in region_graph.gd).


func _params() -> Dictionary:
	return Tuning.resolve(WorldConfig.new())["world"]


func test_generation_honors_basin_count():
	Rng.seed_with(13100)
	var graph := RegionGraph.generate(_params())
	assert_eq(graph.regions.size(), 6, "Medium = 6 basins [setup §4]")
	var small := WorldConfig.new()
	small.region_size = "small"
	Rng.seed_with(13100)
	assert_eq(RegionGraph.generate(Tuning.resolve(small)["world"]).regions.size(), 3)


func test_same_seed_same_world():
	Rng.seed_with(13101)
	var a := RegionGraph.generate(_params())
	Rng.seed_with(13101)
	var b := RegionGraph.generate(_params())
	for i in a.regions.size():
		assert_eq(a.regions[i]["center"], b.regions[i]["center"], "deterministic world-gen")
		assert_eq(a.regions[i]["elevation"], b.regions[i]["elevation"])
		assert_eq(a.regions[i]["biome"], b.regions[i]["biome"])


func test_regions_are_connected_and_typed():
	Rng.seed_with(13102)
	var graph := RegionGraph.generate(_params())
	for region in graph.regions:
		assert_gt(region["neighbors"].size(), 0, "no basin is an island (ring adjacency)")
		assert_true(region["elevation"] >= 0.0)
		assert_true(region["biome"] != "")
	var uniform := WorldConfig.new()
	uniform.biome_variety = "uniform"
	Rng.seed_with(13102)
	var flat := RegionGraph.generate(Tuning.resolve(uniform)["world"])
	var biomes := {}
	for region in flat.regions:
		biomes[region["biome"]] = true
	assert_eq(biomes.size(), 1, "Uniform variety = one biome [setup §4]")


func test_reshape_bumps_the_version():
	Rng.seed_with(13103)
	var graph := RegionGraph.generate(_params())
	var before := graph.version
	var elevation_before: float = graph.regions[0]["elevation"]
	graph.reshape(0, -0.4)
	assert_eq(graph.version, before + 1, "skins watch the version to re-bake [T13.1]")
	assert_almost_eq(graph.regions[0]["elevation"], maxf(0.0, elevation_before - 0.4), 0.0001)


func test_graph_round_trips():
	Rng.seed_with(13104)
	var graph := RegionGraph.generate(_params())
	graph.reshape(2, 0.3)
	var restored := Serializer.region_graph_from_dict(Serializer.region_graph_to_dict(graph))
	assert_eq(restored.version, graph.version)
	assert_eq(restored.regions.size(), graph.regions.size())
	assert_eq(restored.regions[2]["elevation"], graph.regions[2]["elevation"])
