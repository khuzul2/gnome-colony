extends GutTest

## T13.3 — NavMesh for LOD-0 [plan Phase 13]: a navigation mesh baked
## from the world skin; materialized gnomes get NavigationAgent3D
## routing. The sim's abstract truth still rules: a leg whose named
## path is buried (WorldState.paths["<site>_path"] = false, T7.3's
## landslide) is refused before the navmesh is even asked.


func _stage() -> Dictionary:
	Rng.seed_with(13300)
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	var nav := NavWorld.new()
	add_child_autofree(nav)
	nav.bake(view)
	var a: Vector2 = graph.regions[0]["center"]
	var b: Vector2 = graph.regions[1]["center"]
	nav.place_site("the_hollow", Vector3(a.x, view.height_at(a), a.y))
	nav.place_site("eastern_ridge", Vector3(b.x, view.height_at(b), b.y))
	return {"nav": nav, "view": view}


func test_a_path_exists_between_two_sites():
	var stage := _stage()
	var nav: NavWorld = stage["nav"]
	nav.attach(WorldState.new())
	await wait_physics_frames(3)
	var path := nav.path_between("the_hollow", "eastern_ridge")
	assert_gt(path.size(), 1, "the navmesh yields a walkable route [T13.3]")
	var goal: Vector3 = nav.site_positions["eastern_ridge"]
	assert_lt(path[path.size() - 1].distance_to(goal), 2.0, "…ending at the ridge")


func test_a_buried_path_refuses_the_leg():
	var stage := _stage()
	var nav: NavWorld = stage["nav"]
	var world := WorldState.new()
	world.paths["eastern_ridge_path"] = false
	nav.attach(world)
	await wait_physics_frames(3)
	assert_eq(
		nav.path_between("the_hollow", "eastern_ridge").size(),
		0,
		"the sim buried that road [T7.3] — the skin honors it"
	)
	world.paths["eastern_ridge_path"] = true
	assert_gt(nav.path_between("the_hollow", "eastern_ridge").size(), 1, "…until it reopens")


func test_materialized_gnomes_get_an_agent():
	var stage := _stage()
	var nav: NavWorld = stage["nav"]
	nav.attach(WorldState.new())
	var puppet := GnomePuppet.new()
	add_child_autofree(puppet)
	var g := GnomeData.new(0)
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	puppet.bind(g)
	puppet.position = nav.site_positions["the_hollow"]
	nav.route(puppet, "eastern_ridge")
	assert_not_null(puppet.agent, "a NavigationAgent3D rides the puppet [T13.3]")
	await wait_physics_frames(3)
	var next := puppet.agent.get_next_path_position()
	assert_gt(
		next.distance_to(nav.site_positions["eastern_ridge"]),
		-1.0,
		"agent produced a next waypoint without erroring"
	)
	assert_eq(
		puppet.agent.target_position, nav.site_positions["eastern_ridge"], "target is the ridge"
	)
