extends GutTest

## Phase-Exit 13 [plan] — the auto half of the manual+auto gate: puppets
## reflect GnomeData; the heightmap matches the region-graph; the camera
## zooms civilization→settlement→individual; a navmesh path is found.
## (The manual half — does it LOOK right — belongs to Fun Check 3.)


func test_the_sim_becomes_visible_without_knowing():
	Rng.seed_with(13900)
	# A world takes shape…
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	# R5.1 [leg §L-relief]: the skin is relief-mapped (amplified + water-clamped),
	# not raw elevation. It still reflects the graph — every basin lands in the
	# relief envelope and higher elevation reads at least as high.
	var floor_y := WorldView.RELIEF_KM * WorldView.SEA_LEVEL_T
	var lo: Dictionary = graph.regions[0]
	var hi: Dictionary = graph.regions[0]
	for region in graph.regions:
		assert_between(
			view.height_at(region["center"]),
			floor_y - 0.01,
			WorldView.RELIEF_KM + 0.01,
			"the heightmap reflects the region-graph at basin %d" % region["id"]
		)
		if region["elevation"] < lo["elevation"]:
			lo = region
		if region["elevation"] > hi["elevation"]:
			hi = region
	assert_true(
		view.height_at(hi["center"]) >= view.height_at(lo["center"]),
		"higher elevation reads at least as high on the skin"
	)
	# …a colony walks it…
	var colony := Colony.new()
	var pool := PuppetPool.new()
	add_child_autofree(pool)
	var puppets := {}
	for i in 4:
		var g := colony.spawn()
		g.age = 30.0 if i > 0 else 2.0
		g.stage = Enums.LifeStage.ADULT if i > 0 else Enums.LifeStage.INFANT
		g.set_feeling(Devotion.YOU, "faith", 0.2 * i)
		puppets[g.id] = pool.acquire(g)
	assert_lt(puppets[0].scale.x, puppets[1].scale.x, "puppets reflect GnomeData (stage scale)")
	colony.gnomes[3].stage = Enums.LifeStage.DEAD
	puppets[3].refresh()
	assert_false(puppets[3].visible, "…and its deaths")
	# …the navmesh yields a road…
	var nav := NavWorld.new()
	add_child_autofree(nav)
	nav.bake(view)
	nav.attach(WorldState.new())
	var a: Vector2 = graph.regions[0]["center"]
	var b: Vector2 = graph.regions[1]["center"]
	nav.place_site("home", Vector3(a.x, view.height_at(a), a.y))
	nav.place_site("away", Vector3(b.x, view.height_at(b), b.y))
	await wait_physics_frames(3)
	assert_gt(nav.path_between("home", "away").size(), 1, "a navmesh path is found")
	# …and the lens sweeps all three heights.
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.zoom_out()
	assert_eq(rig.level, CameraRig.Zoom.CIVILIZATION)
	rig.zoom_in()
	assert_eq(rig.level, CameraRig.Zoom.SETTLEMENT)
	rig.zoom_in()
	assert_eq(rig.level, CameraRig.Zoom.INDIVIDUAL, "civilization→settlement→individual")
