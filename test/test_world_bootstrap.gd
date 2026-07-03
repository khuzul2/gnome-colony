extends GutTest

## T17.1 — world bootstrap [PROGRESS Phase 17, DONE.md handover note 3]:
## WorldConfig → Tuning world block → RegionGraph → a playable WorldState,
## deterministically per seed. NO new gameplay numbers: the sites promote
## the canonical integration-fixture composition (epochal food node, the
## slice's ridge pattern), bent only by Tuning's already-resolved
## abundance multiplier — defaults reproduce the tested fixture exactly.
## (Probed layout, seed 1 @ medium: forest_0 home, ridge_1/ridge_2.)


func _build(seed_value: int = 1, mutate: Callable = Callable()) -> Dictionary:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	if mutate.is_valid():
		mutate.call(cfg)
	cfg.normalize()
	return WorldBootstrap.build(cfg)


func test_default_world_is_the_tested_fixture():
	var out := _build()
	assert_eq(out["home"], "forest_0", "home is region 0, named by biome")
	var food: ResourceNode = out["food"]
	assert_eq(food.type, "food")
	assert_eq(food.capacity, 100.0, "the epochal fixture larder [test_epochal.gd]")
	assert_eq(food.regrowth, 10.0)
	assert_eq(food.richness, 1.0)
	assert_eq(out["capacity"], 60.0, "the fixture K every integration run uses")
	var world: WorldState = out["world"]
	assert_eq(world.sites[out["home"]], food, "the home site IS the larder — burying it starves")


func test_ridge_basins_carry_the_slice_pattern():
	var out := _build()
	var world: WorldState = out["world"]
	var stone: ResourceNode = world.sites["ridge_1"]
	assert_eq(stone.type, "stone", "ridge basins get the slice's stone site")
	assert_eq(stone.capacity, 40.0)
	assert_eq(world.hidden_resources["ridge_1"][0].type, "iron", "…with iron under the scar")
	assert_eq(world.affordances["ridge_1"], ["slope"], "…and ground a landslide can act on")
	assert_true(world.paths["ridge_1_path"], "…reachable until something buries the road")
	assert_false(world.paths.has("forest_0_path"), "home needs no road to itself")


func test_every_other_basin_is_a_reachable_place():
	var out := _build()
	var world: WorldState = out["world"]
	var graph: RegionGraph = out["graph"]
	for region in graph.regions:
		var place: String = WorldBootstrap.place_id(region)
		if place == out["home"]:
			continue
		assert_true(world.paths.has("%s_path" % place), "%s has a road" % place)


func test_abundance_bends_the_larder():
	var lush := _build(1, func(cfg: WorldConfig) -> void: cfg.resource_abundance = "lush")
	assert_eq(lush["food"].capacity, 150.0, "lush ×1.5 [Tuning ABUNDANCE_MULT]")
	assert_eq(lush["food"].regrowth, 15.0)
	assert_eq(lush["capacity"], 90.0)
	var sparse := _build(1, func(cfg: WorldConfig) -> void: cfg.resource_abundance = "sparse")
	assert_eq(sparse["food"].capacity, 60.0, "sparse ×0.6")
	assert_eq(sparse["capacity"], 36.0)


func test_region_size_sets_the_basin_count():
	var small := _build(1, func(cfg: WorldConfig) -> void: cfg.region_size = "small")
	assert_eq(small["graph"].regions.size(), 3, "small = 3 basins [setup §4]")


func test_uniform_variety_collapses_the_biomes():
	var out := _build(1, func(cfg: WorldConfig) -> void: cfg.biome_variety = "uniform")
	for region in out["graph"].regions:
		assert_eq(region["biome"], "meadow", "uniform worlds keep one biome")


func test_a_ridge_home_stays_the_cleared_hollow():
	# Probed: seed 6 rolls ridge at region 0 AND region 1 — the edge the
	# reviewer flagged: home must stay the hollow, its ridge name only.
	var out := _build(6)
	assert_eq(out["home"], "ridge_0", "home rolled the ridge biome this seed")
	var world: WorldState = out["world"]
	assert_eq(world.sites["ridge_0"].type, "food", "the band cleared its ground — larder, not scar")
	assert_false(world.affordances.has("ridge_0"), "no hazard affordance on home, ever [slice]")
	assert_false(world.hidden_resources.has("ridge_0"))
	assert_eq(world.affordances["ridge_1"], ["slope"], "other ridge basins still carry the pattern")
	assert_eq(world.sites["ridge_1"].type, "stone")


func test_same_seed_same_world():
	var first := _build(7)
	var second := _build(7)
	assert_eq(
		Serializer.world_to_dict(second["world"]),
		Serializer.world_to_dict(first["world"]),
		"the world reproduces from its seed [CLAUDE.md determinism]"
	)
	assert_eq(
		Serializer.region_graph_to_dict(second["graph"]),
		Serializer.region_graph_to_dict(first["graph"])
	)
	var other := _build(8)
	assert_ne(
		Serializer.region_graph_to_dict(other["graph"]),
		Serializer.region_graph_to_dict(first["graph"]),
		"a different seed is a different world"
	)
