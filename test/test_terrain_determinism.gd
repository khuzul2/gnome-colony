extends GutTest

## G4.1 [gaea §gaea-det] — the terrain is deterministic from the world seed and INDEPENDENT
## of the sim's Rng stream. (a) same seed+config ⇒ byte-identical baked terrain (a hash of the
## sampled height + biome-band colour grid); (b) the sim save-envelope hash is byte-identical
## whether or not the Gaea bake path runs during a fixed scripted run — the render layer's
## FastNoiseLite noise generator draws ZERO from Rng, so it can never perturb the sim (re-proves
## the T15.4 render-density invariance now that render owns a noise generator).


## An Rng-FREE hand-built graph, so the only Rng consumer in the (b) tests is the sim itself.
func _hand_graph() -> RegionGraph:
	var g := RegionGraph.new()
	g.regions = [
		{
			"id": 0,
			"center": Vector2(-5.0, 0.0),
			"elevation": 1.0,
			"biome": "meadow",
			"neighbors": [1]
		},
		{
			"id": 1,
			"center": Vector2(5.0, 3.0),
			"elevation": 2.6,
			"biome": "ridge",
			"neighbors": [0]
		},
		{
			"id": 2,
			"center": Vector2(0.0, -6.0),
			"elevation": 1.7,
			"biome": "forest",
			"neighbors": [0]
		},
	]
	return g


## A hash of the terrain's observable output — height + biome-band colour over the bake extent.
func _terrain_hash(seed_value: int) -> String:
	Rng.seed_with(seed_value)
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, seed_value)
	var samples := []
	var n := 24
	var step := 2.0 * WorldView.EXTENT_KM / n
	for gz in n:
		for gx in n:
			var p := Vector2(-WorldView.EXTENT_KM + gx * step, -WorldView.EXTENT_KM + gz * step)
			samples.append(view.height_at(p))
			var col := WorldView.terrain_color_biomed(view._relief_t(p), view._biome_at(p))
			samples.append(col.r)
			samples.append(col.g)
			samples.append(col.b)
	return JSON.stringify(samples).md5_text()


## A short fixed scripted sim run; optionally ALSO bakes + samples the Gaea terrain (the render
## path) alongside it. The sim save-envelope hash must be identical either way.
func _scripted_sim_hash(bake_terrain: bool) -> String:
	Rng.seed_with(5150)
	var cfg := WorldConfig.new()
	cfg.band_size = 6
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var world := WorldState.new()
	var settlements: Array = [Settlement.new(1, 50.0, 2.0)]
	settlements[0].by_stage[Enums.LifeStage.ADULT] = 30.0
	var view: WorldView = null
	if bake_terrain:
		view = WorldView.new()
		add_child_autofree(view)
		view.sync(_hand_graph(), cfg.seed)  # Rng-free graph + Gaea (FastNoiseLite) bake
	for day in 30:
		runner.tick()
		if bake_terrain:
			view.height_at(Vector2(day * 0.4, day * 0.6))  # sample the render field each day
	var save := Serializer.save_to_dict(
		runner.colony, world, settlements, cfg, runner.time, runner.chronicle
	)
	runner.shutdown()
	return JSON.stringify(save).md5_text()


func test_same_seed_config_bakes_identical_terrain():
	assert_eq(_terrain_hash(4242), _terrain_hash(4242), "same seed+config ⇒ byte-identical terrain")


func test_different_seed_bakes_different_terrain():
	assert_ne(_terrain_hash(1), _terrain_hash(2), "distinct seeds ⇒ distinct terrain")


func test_terrain_bake_draws_nothing_from_the_rng_stream():
	# The crux invariant, at the Rng-state grain: build the graph (which DOES draw), snapshot,
	# then bake + sample the terrain — the Rng stream must be byte-identical afterward.
	Rng.seed_with(777)
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var after_graph := Rng.get_state()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, 777)
	for i in 50:
		view.height_at(Vector2(i * 0.3, i * 0.7))
	assert_eq(Rng.get_state(), after_graph, "the Gaea bake + sampling draws ZERO from Rng")


func test_terrain_bake_does_not_perturb_the_sim_save_envelope():
	# The save-envelope grain: a fixed scripted run hashes the same with or without the render
	# bake path interleaved — terrain never leaks into the sim's state or its Rng stream.
	assert_eq(
		_scripted_sim_hash(false),
		_scripted_sim_hash(true),
		"the sim save-envelope hash is byte-identical with vs without the Gaea path"
	)
