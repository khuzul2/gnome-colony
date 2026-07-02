extends GutTest

## T8.4 — the tyranny brake [algo §10/§17]:
##   terror tax: unrest += 0.02·max(0, −flavor_balance)·log10(M) per day
##   relief: benevolent acts / met needs / quiet time −0.01/day
##   fracture line at unrest ≥ 0.8; schism pressure +0.01·unrest/season
##   secularization: faith drifts −0.0005·science_level/day (mild)


func _flock(n: int, faith: float, awe: float, fear: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_feeling(Devotion.YOU, "faith", faith)
		g.set_feeling(Devotion.YOU, "awe", awe)
		g.set_feeling(Devotion.YOU, "fear", fear)
	return c


func test_terror_raises_unrest_love_does_not():
	var tyrant := _flock(100, 0.8, 0.1, 0.9)
	var shepherd := _flock(100, 0.8, 0.9, 0.1)
	for day in 30:
		Devotion.unrest_tick(tyrant, 1.0)
		Devotion.unrest_tick(shepherd, 1.0)
	assert_gt(tyrant.unrest, 0.5, "a feared god rules a boiling pot")
	assert_eq(shepherd.unrest, 0.0, "love-faith carries no instability tax")


func test_unrest_rate_matches_formula():
	var c := _flock(100, 0.8, 0.1, 0.9)
	Devotion.unrest_tick(c, 1.0)
	var expected := 0.02 * 0.8 * (log(1.0 + 80.0) / log(10.0))
	assert_almost_eq(c.unrest, expected, 0.0001, "0.02·|flavor|·log10(1+M)")


func test_quiet_time_relieves_unrest():
	var c := _flock(10, 0.5, 0.5, 0.5)
	c.unrest = 0.5
	Devotion.unrest_tick(c, 1.0)
	assert_almost_eq(c.unrest, 0.49, 0.0001, "balanced flavor: only the −0.01/day relief acts")


func test_fracture_line():
	var c := _flock(10, 0.5, 0.0, 0.0)
	c.unrest = 0.79
	assert_false(Devotion.fracture_due(c))
	c.unrest = 0.8
	assert_true(Devotion.fracture_due(c), "at 0.8 the terror-state cracks")


func test_schism_pressure_scales_with_unrest():
	var c := _flock(10, 0.5, 0.0, 0.0)
	c.unrest = 0.6
	assert_almost_eq(Devotion.schism_pressure_per_season(c), 0.006, 0.0001, "0.01·unrest")


func test_secularization_is_mild():
	var c := _flock(10, 0.5, 0.0, 0.0)
	Devotion.secularize_tick(c, 1.0, 1.0)
	for g in c.living():
		assert_almost_eq(g.get_feeling(Devotion.YOU, "faith"), 0.4995, 0.000001)
	var d := Devotion.total(c)
	for day in 96:
		Devotion.secularize_tick(c, 1.0, 1.0)
	assert_gt(Devotion.total(c), d * 0.85, "a year of full science barely dents real faith")


func test_unrest_round_trips():
	var c := _flock(4, 0.5, 0.0, 0.9)
	Devotion.unrest_tick(c, 1.0)
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(c))
	assert_almost_eq(restored.unrest, c.unrest, 0.000001)
