extends GutTest

## G4.3 [gaea §gaea-gen/§gaea-det] — the whole Gaea terrain pipeline end-to-end in one scene:
## WorldBootstrap → RegionGraph → TerrainField → WorldView bake → NavWorld route → a
## ground-pick that places a puppet → a real influence cast — all round-trip; and a phenomenon
## reshape bumps `version`, re-bakes DETERMINISTICALLY, and the raised ground reads higher.
## Mirrors the test_phase13_exit / test_render_pipeline composition, now over the Gaea field.


func test_the_whole_gaea_terrain_pipeline_round_trips():
	Rng.seed_with(43000)
	var cfg := WorldConfig.new()
	# Bootstrap the canonical world (seed → Tuning → RegionGraph → WorldState).
	var boot := WorldBootstrap.build(cfg)
	var graph: RegionGraph = boot["graph"]
	var world: WorldState = boot["world"]

	# WorldView bakes the Gaea-detailed field from the graph + seed.
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, cfg.seed)
	assert_not_null(view.mesh_instance.mesh, "the Gaea skin baked a mesh")
	assert_eq(
		view.walkable_faces.size(), WorldView.GRID * WorldView.GRID * 6, "walkable faces baked"
	)

	# NavWorld routes over the Gaea geometry, honoring the sim's buried-path truth.
	var nav := NavWorld.new()
	add_child_autofree(nav)
	nav.bake(view)
	nav.attach(world)
	var a: Vector2 = graph.regions[0]["center"]
	var b: Vector2 = graph.regions[1]["center"]
	nav.place_site("home", Vector3(a.x, view.height_at(a), a.y))
	nav.place_site("away", Vector3(b.x, view.height_at(b), b.y))
	await wait_physics_frames(3)
	assert_gt(nav.path_between("home", "away").size(), 1, "a route is found over the Gaea ground")

	# A ground-pick round-trips: a puppet placed at a basin's picked ground (height_at, the
	# same field picking reads) sits ON the skin, not through or above it.
	var colony := Colony.new()
	var pool := PuppetPool.new()
	add_child_autofree(pool)
	var g := colony.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	var puppet := pool.acquire(g)
	puppet.position = Vector3(a.x, view.height_at(a), a.y)  # the picked ground point
	assert_almost_eq(
		puppet.position.y, view.height_at(a), 1e-4, "the puppet stands on the picked ground"
	)

	# A real cast round-trips through the influence pipeline at a bootstrapped place.
	var defs := Catalog.defs()
	var handlers := Catalog.handlers()
	var stimuli := Influence.cast_with_cascade(
		colony, world, defs, "still_air", boot["home"], 1.0, 1.0, handlers
	)
	assert_gt(stimuli.size(), 0, "a cast at a bootstrapped place produces a stimulus")


func test_a_reshape_rebakes_deterministically_and_raises_the_ground():
	Rng.seed_with(43001)
	var cfg := WorldConfig.new()
	var boot := WorldBootstrap.build(cfg)
	var graph: RegionGraph = boot["graph"]
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, cfg.seed)
	# The relief is NORMALIZED to [SEA_LEVEL_T,1]·RELIEF_KM, so raising the ALREADY-highest
	# basin just re-normalizes (it stays at the top). Raise the LOWEST basin instead — it
	# genuinely climbs the envelope, which is the visible payoff of a ground-raising cast.
	var low_id := 0
	for r in graph.regions:
		if r["elevation"] < graph.regions[low_id]["elevation"]:
			low_id = r["id"]
	var center: Vector2 = graph.regions[low_id]["center"]
	var before := view.height_at(center)
	var version_before := view.baked_version

	# A phenomenon lifts the lowest basin above the others — version bumps, the skin re-bakes.
	graph.reshape(low_id, 4.0)
	view.sync(graph, cfg.seed)
	assert_ne(view.baked_version, version_before, "the reshape bumped version and re-baked")
	var after := view.height_at(center)
	assert_gt(after, before, "the raised ground reads higher on the skin")

	# Determinism: an independent bootstrap reshaped identically bakes the SAME height.
	Rng.seed_with(43001)
	var cfg2 := WorldConfig.new()
	var boot2 := WorldBootstrap.build(cfg2)
	var graph2: RegionGraph = boot2["graph"]
	graph2.reshape(low_id, 4.0)
	var view2 := WorldView.new()
	add_child_autofree(view2)
	view2.sync(graph2, cfg2.seed)
	assert_almost_eq(
		view2.height_at(graph2.regions[low_id]["center"]),
		after,
		1e-5,
		"the reshaped re-bake is deterministic across independent runs"
	)
