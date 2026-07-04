extends GutTest

## T18.1 — living terrain [PROGRESS Phase 18, algo §18 affordance
## conditions]: home's lived tags re-derive daily from real state —
## farmland once agriculture is known, built_up once construction is,
## crowded past the §14 comfort line, drought while the larder runs
## low — and the world-gen truths (slope, wilds) are never stripped.
## Thresholds the spec leaves open are interpretive, documented in
## terrain.gd.


func _setup(pop: int = 4) -> Dictionary:
	var colony := Colony.new()
	for i in pop:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
	var world := WorldState.new()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	world.sites["forest_0"] = food
	world.affordances["ridge_1"] = ["slope"]
	return {"colony": colony, "world": world, "food": food}


func test_a_quiet_home_carries_no_lived_tags():
	var s := _setup()
	Terrain.refresh(s["colony"], s["world"], "forest_0", s["food"], 60.0)
	assert_false(s["world"].affordances.has("forest_0"), "nothing earned, nothing tagged")


func test_agriculture_makes_farmland():
	var s := _setup()
	s["colony"].settlement_knowledge[0] = {"agriculture": true}
	Terrain.refresh(s["colony"], s["world"], "forest_0", s["food"], 60.0)
	assert_has(s["world"].affordances["forest_0"], "farmland", "fields follow the plough [§18]")


func test_construction_makes_built_up():
	var s := _setup()
	s["colony"].settlement_knowledge[0] = {"construction": true}
	Terrain.refresh(s["colony"], s["world"], "forest_0", s["food"], 60.0)
	assert_has(s["world"].affordances["forest_0"], "built_up", "walls follow the mason [§18]")


func test_crowding_past_comfort_tags_crowded():
	var s := _setup(4)
	Terrain.refresh(s["colony"], s["world"], "forest_0", s["food"], 5.0)
	assert_has(s["world"].affordances["forest_0"], "crowded", "4 souls on K=5 press together")
	Terrain.refresh(s["colony"], s["world"], "forest_0", s["food"], 60.0)
	assert_false("crowded" in s["world"].affordances.get("forest_0", []), "room again, tag gone")


func test_a_low_larder_is_drought():
	var s := _setup()
	s["food"].current = 20.0
	Terrain.refresh(s["colony"], s["world"], "forest_0", s["food"], 60.0)
	assert_has(s["world"].affordances["forest_0"], "drought", "low water [§18 weeping_sky]")
	s["food"].current = 80.0
	Terrain.refresh(s["colony"], s["world"], "forest_0", s["food"], 60.0)
	assert_false("drought" in s["world"].affordances.get("forest_0", []), "the rains returned")


func test_worldgen_tags_survive_refresh():
	var s := _setup()
	s["world"].affordances["forest_0"] = ["slope"]
	Terrain.refresh(s["colony"], s["world"], "forest_0", s["food"], 60.0)
	assert_has(s["world"].affordances["forest_0"], "slope", "terrain truth is never stripped")


func test_bootstrap_tags_the_wilds():
	Rng.seed_with(1)
	var cfg := WorldConfig.new()
	cfg.normalize()
	var built := WorldBootstrap.build(cfg)
	var world: WorldState = built["world"]
	for region in built["graph"].regions:
		var place: String = WorldBootstrap.place_id(region)
		if place == built["home"]:
			assert_false("wilds" in world.affordances.get(place, []), "home is settled ground")
		else:
			assert_has(world.affordances[place], "wilds", "%s is beyond the edge" % place)
			assert_has(world.affordances["%s_edge" % place], "wilds", "…and so is its edge")
