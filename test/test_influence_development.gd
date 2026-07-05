extends GutTest

## R2.6 [rav §R-infl] — player actions steer development INDIRECTLY: the
## construction pressures are derived from the world/belief/place-tags the
## player shapes (never a build command). A drought pushes farms/wells, revealed
## ore pushes a workshop, a blessed tag draws a shrine, a cursed tag abandons.


func _settlement(adults: float) -> Settlement:
	var s := Settlement.new(6, 100.0, 3.0)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	s.build_progress = 20.0
	return s


func _colony(techs: Array = []) -> Colony:
	var c := Colony.new()
	var known := {}
	for t in techs:
		known[t] = true
	c.settlement_knowledge[6] = known
	return c


func test_drought_reads_as_scarcity():
	var world := WorldState.new()
	world.affordances["ridge"] = ["slope", "drought"]
	var p := Construction.pressures_from(_colony(), world, "ridge")
	assert_eq(p["hunger"], 1.0, "a drought place presses hunger")
	assert_eq(p["water"], 1.0, "…and water")


func test_revealed_ore_reads_as_workshop_fuel():
	var world := WorldState.new()
	world.sites["ridge_iron_0"] = ResourceNode.new("iron", 30.0, 30.0, 0.0, 1.5)
	var p := Construction.pressures_from(_colony(), world, "ridge")
	assert_eq(p["has_ore"], 1.0, "ore at the place fuels a workshop")


func test_place_tags_pass_through():
	var world := WorldState.new()
	var c := _colony()
	c.place_tags["spring"] = {"blessed": 0.8}
	var p := Construction.pressures_from(c, world, "spring")
	assert_almost_eq(p["blessed"], 0.8, 0.0001, "a blessed tag flows into the pressures")


func test_a_drought_shifts_building_toward_the_plough():
	# Same settlement, agriculture known: a drought's hunger/water makes the farm
	# the pick over the default housing.
	var s := _settlement(30.0)
	var built := Construction.season_tick(
		_colony(["agriculture"]), s, {"hunger": 1.0, "water": 1.0}
	)
	assert_eq(built, "farm", "scarcity you caused becomes their plough")


func test_a_blessed_place_draws_a_shrine():
	# Plain ground with no faith raises housing, not a shrine…
	var plain := Construction.season_tick(_colony(), _settlement(30.0), {})
	assert_ne(plain, "shrine", "plain ground draws no shrine")
	# …but a blessed place-tag draws a shrine there even without faith.
	var built := Construction.season_tick(_colony(), _settlement(30.0), {"blessed": 0.9})
	assert_eq(built, "shrine", "sanctified ground draws a shrine there")


func test_a_cursed_place_is_abandoned():
	var s := _settlement(30.0)
	s.belief["faith"] = 0.9  # would build a shrine…
	var built := Construction.season_tick(_colony(), s, {"cursed": 1.0})
	assert_eq(built, "", "fully cursed ground is shunned — nothing is raised")


func test_the_mapping_is_indirect_only():
	# pressures_from reads world/belief/tags, never a build directive — there is
	# no key that names a structure to place.
	var world := WorldState.new()
	world.affordances["x"] = ["drought"]
	var p := Construction.pressures_from(_colony(), world, "x")
	for key in p:
		assert_false(key in Settlement.BUILDING_IDS, "no pressure names a building to place")
