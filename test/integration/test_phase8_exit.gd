extends GutTest

## Phase-Exit 8 [plan]: rising belief raises D; a tier unlocks at its
## threshold; the same phenomenon's magnitude grows SUB-linearly with D.
## The full loop: dramatic acts → witnesses attribute an unseen will
## (T8.5) → D = Σ faith climbs (T8.1) → d̄_peak crosses a rung and the
## toolbox opens (T8.2) → the colony's faith feeds back into how hard
## the next act lands, log-scaled so power is felt but never runaway
## (T8.3).


func _flock(n: int, devout: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("devout", devout)
	return c


func test_dramatic_acts_raise_devotion_until_a_tier_unlocks():
	Rng.seed_with(8800)
	var colony := _flock(10, 0.5)
	var world := WorldState.new()
	var defs := Catalog.defs()
	assert_eq(Devotion.total(colony), 0.0, "a young colony believes in nothing")
	assert_eq(colony.unlocked_tier, 1)

	# Cast the same Tier-I act season after season; every witnessed stimulus
	# writes a little faith toward the unseen will (§9's attribution seed).
	var last_d := 0.0
	var tier_two_at_dbar := -1.0
	for i in 6:
		var stim := Influence.cast_act(colony, world, defs["still_air"], "meadow")
		Devotion.attribute(colony, stim["drama"], 0.0, stim["valence"])
		var d := Devotion.total(colony)
		assert_gt(d, last_d, "each witnessed act deepens belief — D rises")
		last_d = d
		var was_locked := colony.unlocked_tier < 2
		Devotion.update_unlocks(colony)
		if was_locked and colony.unlocked_tier >= 2:
			tier_two_at_dbar = colony.devotion_peak
	assert_gte(colony.unlocked_tier, 2, "sustained faith opens the second rung")
	assert_gte(tier_two_at_dbar, 0.15, "…and not before §17's d̄ = 0.15 line")
	assert_lt(tier_two_at_dbar, 0.30, "…but at the first crossing, not late")


func test_magnitude_grows_sublinearly_with_devotion():
	Rng.seed_with(8801)
	var world := WorldState.new()
	var defs := Catalog.defs()
	# Four equally-spaced devotion masses D = 0, 10, 20, 30 (30 gnomes at
	# faith 0 / ⅓ / ⅔ / 1). still_air is neutral, so potency stays 1 and
	# intensity isolates the D-dependence.
	var intensities := []
	for level in [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]:
		var colony := _flock(30, 0.5)
		for g in colony.living():
			g.set_feeling(Devotion.YOU, "faith", level)
		var stim := Influence.cast_act(colony, world, defs["still_air"], "meadow")
		intensities.append(stim["intensity"])
	for i in 3:
		assert_gt(intensities[i + 1], intensities[i], "more faith always hits harder")
	var first_step: float = intensities[1] - intensities[0]
	var second_step: float = intensities[2] - intensities[1]
	var third_step: float = intensities[3] - intensities[2]
	assert_lt(second_step, first_step, "…but each equal slice of D buys less")
	assert_lt(third_step, second_step, "log10 growth — power is felt, never unbounded")
