extends GutTest

## T3.5 — sustained hunger/safety ≥ 0.9 for > 5 days ⇒ +0.15/day mortality
## [algo §3/§17]. Needs tracks the sustained counters; Mortality consumes
## hardship_rate (built in T2.3).


func _adult() -> GnomeData:
	var g := GnomeData.new(0)
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	return g


func _colony_with(g: GnomeData) -> Colony:
	var c := Colony.new()
	c.add(g)
	return c


func test_hardship_rate_kicks_in_after_five_sustained_days():
	var g := _adult()
	var c := _colony_with(g)
	g.set_need("hunger", 1.0)
	for i in 5:
		Needs.tick(c, 1.0)
		g.set_need("hunger", 1.0)
	assert_eq(g.hardship_rate, 0.0, "exactly 5 days is not yet > 5 days")
	Needs.tick(c, 1.0)
	assert_eq(g.hardship_rate, 0.15, "6th sustained day crosses the > 5 days line")


func test_relief_resets_the_counter():
	var g := _adult()
	var c := _colony_with(g)
	g.set_need("hunger", 1.0)
	for i in 4:
		Needs.tick(c, 1.0)
		g.set_need("hunger", 1.0)
	g.set_need("hunger", 0.2)
	Needs.tick(c, 1.0)
	assert_eq(g.hardship_days["hunger"], 0.0, "a real meal resets the sustained counter")
	assert_eq(g.hardship_rate, 0.0)


func test_safety_hardship_also_counts():
	var g := _adult()
	var c := _colony_with(g)
	for i in 7:
		# The daily spike must beat the −0.06 recovery applied inside tick,
		# so the post-tick level stays ≥ 0.9 (1.0 − 0.06 = 0.94).
		g.set_need("safety", 1.0)
		Needs.tick(c, 1.0)
	assert_eq(g.hardship_rate, 0.15)


func test_starvation_eventually_kills():
	Rng.seed_with(3500)
	var g := _adult()
	var c := _colony_with(g)
	var died_at := -1
	for day in 60:
		Needs.tick(c, 1.0)
		Mortality.tick(c, 1.0)
		if not g.is_alive():
			died_at = day
			break
	assert_true(died_at > 5, "death cannot precede the sustained-hardship window")
	assert_true(g.is_alive() == false, "an unfed gnome starves within two months")
