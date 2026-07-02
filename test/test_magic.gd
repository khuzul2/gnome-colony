extends GutTest

## T10.4 — the magic branch: studying YOU [algo §13/§17]. A settlement
## accrues magic_understanding:
##   mu += 0.0008 · (0.3 + curiosity_mean) · exposure · science_level /day
## Thresholds (§17): Superstition 0 · Proto-science 0.3 · Prediction 0.5
## (omen/wonder belief-impact ×(1−0.6·mu)) · Harnessing 0.7 (mages) ·
## Resistance 0.85 (wards cut incoming intensity by up to 0.7; heretics
## can defy you). Devout heretics — high faith AND high resistance — must
## remain reachable (§10's secularization is only mild).


func _settlement(mu: float) -> Colony:
	var c := Colony.new()
	var g := c.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	c.magic_understanding[0] = mu
	return c


func test_accrual_is_the_spec_formula():
	var c := _settlement(0.0)
	Magic.accrue(c, 0, 0.5, 1.0, 1.0, 1.0)
	assert_almost_eq(Magic.mu(c, 0), 0.0008 * 0.8, 0.0000001, "one day of full study")
	Magic.accrue(c, 0, 0.5, 1.0, 1.0, 1.0)
	assert_almost_eq(Magic.mu(c, 0), 2.0 * 0.0008 * 0.8, 0.0000001, "…accumulates")


func test_no_exposure_or_science_means_no_understanding():
	var c := _settlement(0.0)
	Magic.accrue(c, 0, 0.9, 0.0, 1.0, 100.0)
	assert_eq(Magic.mu(c, 0), 0.0, "a god who never acts is never studied")
	Magic.accrue(c, 0, 0.9, 1.0, 0.0, 100.0)
	assert_eq(Magic.mu(c, 0), 0.0, "…nor understood without science")


func test_stages_unlock_at_spec_thresholds():
	assert_eq(Magic.stage(0.0), "superstition")
	assert_eq(Magic.stage(0.29), "superstition")
	assert_eq(Magic.stage(0.3), "proto_science")
	assert_eq(Magic.stage(0.5), "prediction")
	assert_eq(Magic.stage(0.7), "harnessing")
	assert_eq(Magic.stage(0.85), "resistance")


func test_prediction_dulls_omens():
	assert_eq(Magic.omen_impact_mult(0.4), 1.0, "below Prediction, portents land in full")
	assert_almost_eq(Magic.omen_impact_mult(0.5), 1.0 - 0.6 * 0.5, 0.0001, "§17: ×(1−0.6·mu)")
	assert_almost_eq(Magic.omen_impact_mult(1.0), 0.4, 0.0001, "an expected portent doesn't awe")


func test_dulled_impact_reaches_the_appraisal():
	var naive := GnomeData.new(0)
	naive.age = 30.0
	naive.stage = Enums.LifeStage.ADULT
	var learned := GnomeData.new(1)
	learned.age = 30.0
	learned.stage = Enums.LifeStage.ADULT
	var stim := {
		"type": "birds_silent",
		"category": 5,
		"place": "the_hollow",
		"intensity": 0.5,
		"drama": 0.5,
		"valence": "neutral",
		"effects": {"belief": 0.6},
	}
	var c := Colony.new()
	Influence.appraise_witnesses(c, stim, [naive])
	Influence.appraise_witnesses(c, stim, [learned], Magic.omen_impact_mult(1.0))
	var naive_fear: float = naive.get_feeling("birds_silent", "fear")
	var learned_fear: float = learned.get_feeling("birds_silent", "fear")
	assert_gt(naive_fear, learned_fear, "prediction makes appraisal analytic, not fearful")
	assert_gt(learned_fear, 0.0, "…but your acts never stop working entirely [§13]")


func test_wards_require_the_resistance_stage():
	var world := WorldState.new()
	Magic.place_ward(world, "the_hollow", 0.7)
	assert_false(world.wards.has("the_hollow"), "harnessing mages cannot ward yet")
	Magic.place_ward(world, "the_hollow", 1.0)
	assert_almost_eq(world.wards["the_hollow"], 0.7, 0.0001, "full understanding, full ward")


func test_a_warded_tile_blunts_the_act():
	Rng.seed_with(10400)
	var c := _settlement(1.0)
	var world := WorldState.new()
	Magic.place_ward(world, "the_hollow", 1.0)
	var def: Dictionary = Catalog.defs()["still_air"]
	var warded := Influence.cast(c, world, def, "the_hollow")
	var open := Influence.cast(c, world, def, "meadow")
	assert_almost_eq(
		warded["intensity"], open["intensity"] * (1.0 - 0.7), 0.0001, "ward cuts up to 0.7 [§13]"
	)


func test_devout_heretics_are_reachable():
	var c := _settlement(0.9)
	var g: GnomeData = c.living()[0]
	g.set_feeling(Devotion.YOU, "faith", 0.9)
	assert_true(Magic.can_defy(c, 0), "resistance-stage settlements breed heretics")
	assert_almost_eq(
		g.get_feeling(Devotion.YOU, "faith"),
		0.9,
		0.0001,
		"…whose faith is untouched — defiance ≠ disbelief"
	)
	var primitive := _settlement(0.5)
	assert_false(Magic.can_defy(primitive, 0), "prediction alone cannot defy the sky")


func test_understanding_round_trips():
	var c := _settlement(0.42)
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(c))
	assert_almost_eq(restored.magic_understanding[0], 0.42, 0.0001)
