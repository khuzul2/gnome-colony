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
	for region in graph.regions:
		assert_almost_eq(
			view.height_at(region["center"]),
			region["elevation"],
			0.2,
			"the heightmap matches the region-graph at basin %d" % region["id"]
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
