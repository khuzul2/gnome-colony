extends GutTest

## T8.5 — the attribution seed [algo §9/§17]: dramatic, inexplicable events
## write a small belief toward "an unseen will":
##   you_faith += α·attribution·event_drama, α = 0.25
##   attribution = clamp(0.3 + 0.7·devout − 0.8·magic_understanding)
## Flavor rides along (interpretive): malevolent drama seeds fear of you,
## other drama seeds awe — feeding flavor_balance (§10).


func _witnesses(n: int, devout: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("devout", devout)
	return c


func test_a_cataclysm_bootstraps_belief_from_zero():
	var c := _witnesses(10, 0.5)
	assert_eq(Devotion.total(c), 0.0)
	Devotion.attribute(c, 1.0, 0.0, "malevolent")
	var expected_each := 0.25 * (0.3 + 0.7 * 0.5) * 1.0
	assert_almost_eq(Devotion.total(c), expected_each * 10.0, 0.0001)
	assert_almost_eq(
		c.living()[0].get_feeling(Devotion.YOU, "faith"), expected_each, 0.0001, "≈0.16, not 0.65"
	)


func test_devout_witnesses_attribute_more():
	var skeptics := _witnesses(1, 0.0)
	var zealots := _witnesses(1, 1.0)
	Devotion.attribute(skeptics, 0.8, 0.0, "neutral")
	Devotion.attribute(zealots, 0.8, 0.0, "neutral")
	assert_gt(Devotion.total(zealots), Devotion.total(skeptics))
	assert_almost_eq(Devotion.total(skeptics), 0.25 * 0.3 * 0.8, 0.0001)


func test_magic_literacy_explains_you_away():
	var primitive := _witnesses(1, 0.5)
	var enlightened := _witnesses(1, 0.5)
	Devotion.attribute(primitive, 1.0, 0.0, "neutral")
	Devotion.attribute(enlightened, 1.0, 1.0, "neutral")
	assert_lt(Devotion.total(enlightened), Devotion.total(primitive))
	var suppressed: float = clampf(0.3 + 0.35 - 0.8, 0.0, 1.0)
	assert_almost_eq(Devotion.total(enlightened), 0.25 * suppressed, 0.0001)


func test_full_literacy_can_silence_the_gods():
	var c := _witnesses(1, 0.0)
	Devotion.attribute(c, 1.0, 1.0, "neutral")
	assert_eq(Devotion.total(c), 0.0, "attribution clamps at zero — nothing is willed anymore")


func test_flavor_rides_the_valence():
	var terrorized := _witnesses(1, 0.5)
	Devotion.attribute(terrorized, 1.0, 0.0, "malevolent")
	var g: GnomeData = terrorized.living()[0]
	assert_gt(g.get_feeling(Devotion.YOU, "fear"), 0.0, "a cruel wonder seeds dread of you")
	assert_eq(g.get_feeling(Devotion.YOU, "awe"), 0.0)
	var awed := _witnesses(1, 0.5)
	Devotion.attribute(awed, 1.0, 0.0, "benevolent")
	assert_gt(awed.living()[0].get_feeling(Devotion.YOU, "awe"), 0.0)


func test_explicit_witness_subset():
	var c := _witnesses(4, 0.5)
	var chosen: Array = [c.living()[0]]
	Devotion.attribute(c, 1.0, 0.0, "neutral", chosen)
	assert_gt(c.living()[0].get_feeling(Devotion.YOU, "faith"), 0.0)
	assert_eq(c.living()[1].get_feeling(Devotion.YOU, "faith"), 0.0, "the unwitnessed stay unmoved")
