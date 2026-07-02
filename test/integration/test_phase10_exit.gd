extends GutTest

## Phase-Exit 10 [plan]: prereqs gate discovery; environmental pressure
## raises the discovery rate; reaching the magic thresholds unlocks
## prediction then wards; a warded tile reduces incoming phenomenon
## intensity. Two arcs: necessity-driven tech, and the god-vs-mages
## co-evolution.


func _minds(n: int, curious: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("curious", curious)
	return c


func test_necessity_and_prereqs_drive_the_tech_arc():
	Rng.seed_with(10901)
	var c := _minds(20, 0.8)
	Knowledge.sync(c)
	# A drought presses for irrigation — but you cannot irrigate what you
	# have never farmed. 40 pressured seasons find nothing.
	var drought := {"irrigation": 8.0}
	var found := []
	for season in 40:
		found += Research.season_tick(c, 0, drought, 1.0)
	assert_does_not_have(found, "irrigation", "prereqs gate discovery [§7]")
	# The same pressure aimed at farming fires…
	var seasons_to_agriculture := 0
	while not "agriculture" in found and seasons_to_agriculture < 100:
		found += Research.season_tick(c, 0, {"agriculture": 8.0}, 1.0)
		seasons_to_agriculture += 1
	assert_has(found, "agriculture", "environmental pressure raises the rate [§13]")
	# …and NOW the drought can teach them irrigation.
	var seasons_to_irrigation := 0
	while not "irrigation" in found and seasons_to_irrigation < 100:
		found += Research.season_tick(c, 0, drought, 1.0)
		seasons_to_irrigation += 1
	assert_has(found, "irrigation", "necessity finds its answer once the ground is ready")


func test_the_god_vs_mages_coevolution():
	Rng.seed_with(10902)
	var c := _minds(6, 0.9)
	var world := WorldState.new()
	var omen: Dictionary = Catalog.defs()["birds_silent"]
	var stim := Influence.cast_act(c, world, omen, "the_hollow")
	assert_eq(Magic.impact_mult_for(c, 0, stim), 1.0, "superstition: the portent lands in full")
	# Generations of exposure and scholarship…
	var days_to_prediction := 0
	while Magic.stage(Magic.mu(c, 0)) != "prediction":
		Magic.accrue(c, 0, 0.9, 1.0, 1.0, 1.0)
		days_to_prediction += 1
	assert_lt(Magic.impact_mult_for(c, 0, stim), 1.0, "prediction: the omen is expected now")
	assert_eq(world.wards.size(), 0, "…but prediction alone cannot ward")
	Magic.place_ward(world, "the_hollow", Magic.mu(c, 0))
	assert_eq(world.wards.size(), 0, "the ward attempt fizzles below resistance")
	# …then resistance, and the first ward rises.
	while Magic.mu(c, 0) < 0.95:
		Magic.accrue(c, 0, 0.9, 1.0, 1.0, 1.0)
	assert_eq(Magic.stage(Magic.mu(c, 0)), "resistance", "prediction, THEN wards — in order")
	Magic.place_ward(world, "the_hollow", Magic.mu(c, 0))
	assert_true(world.wards.has("the_hollow"))
	var warded := Influence.cast_act(c, world, omen, "the_hollow")
	var open := Influence.cast_act(c, world, omen, "meadow")
	assert_lt(warded["intensity"], open["intensity"], "the warded tile blunts your act [§13]")
	assert_almost_eq(
		warded["intensity"],
		open["intensity"] * (1.0 - world.wards["the_hollow"]),
		0.0001,
		"answered, not absolute"
	)
