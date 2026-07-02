extends GutTest

## T10.3 — tech effects [algo §13/§14/§17]: a discovered tech is a set of
## parameter deltas / unlocks. §17 fixes K = base_K·Σrichness·(1+0.5·ag+
## 0.3·constr) and war_strength = pop·(1+metal)·(0.5+lead); writing's
## durability shipped with T4.5. The remaining magnitudes (§13 names the
## effects, not sizes) are interpretive, documented in tech_effects.gd.


func _known(ids: Array) -> Colony:
	var c := Colony.new()
	var g := c.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	for id in ids:
		g.add_knowledge(id)
	Knowledge.sync(c)
	return c


func test_levels_read_settlement_knowledge():
	var c := _known(["agriculture"])
	assert_eq(TechEffects.level(c, 0, "agriculture"), 1.0)
	assert_eq(TechEffects.level(c, 0, "metallurgy"), 0.0)
	assert_eq(TechEffects.level(c, 3, "agriculture"), 0.0, "another settlement knows nothing")


func test_carrying_capacity_is_the_spec_formula():
	# §17: base_K·Σrichness·(1+0.5·ag+0.3·constr)
	assert_almost_eq(TechEffects.carrying_capacity(50.0, 2.0, 0.0, 0.0), 100.0, 0.0001)
	assert_almost_eq(
		TechEffects.carrying_capacity(50.0, 2.0, 1.0, 0.0), 150.0, 0.0001, "agriculture raises K"
	)
	assert_almost_eq(
		TechEffects.carrying_capacity(50.0, 2.0, 1.0, 1.0),
		180.0,
		0.0001,
		"construction adds its 0.3"
	)


func test_war_strength_is_the_spec_formula():
	# §17: pop·(1+metal)·(0.5+lead)
	assert_almost_eq(TechEffects.war_strength(100.0, 1.0, 0.8), 260.0, 0.0001)
	assert_almost_eq(TechEffects.war_strength(100.0, 0.0, 0.5), 100.0, 0.0001)


func test_medicine_lowers_mortality_and_hardship():
	Rng.seed_with(10300)
	var untreated := Colony.new()
	var treated := Colony.new()
	for c in [untreated, treated]:
		for i in 150:
			var g: GnomeData = c.spawn()
			g.age = 88.0
			g.stage = Enums.LifeStage.ELDER
			g.hardship_rate = 0.01
	for day in 100:
		Mortality.tick(untreated, 1.0)
		Mortality.tick(treated, 1.0, TechEffects.mortality_mult(1.0))
	assert_lt(
		untreated.population(), treated.population(), "medicine keeps more elders alive [§13]"
	)


func test_agriculture_raises_the_birth_rate():
	var births_plain := 0
	var births_farmed := 0
	for i in 40:
		Rng.seed_with(10400 + i)
		births_plain += _births_in_season(1.0)
		Rng.seed_with(10400 + i)
		births_farmed += _births_in_season(TechEffects.fertility_mult(1.0))
	assert_gt(births_farmed, births_plain, "§13: agriculture, +birth rate")


func _births_in_season(fertility_mult: float) -> int:
	var c := Colony.new()
	for i in 20:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.sex = i % 2
	for i in range(0, 20, 2):
		c.gnomes[i].partner_id = i + 1
		c.gnomes[i + 1].partner_id = i
	var before := c.population()
	Birth.season_tick(c, 1.0, 0.0, fertility_mult)
	return c.population() - before


func test_support_multipliers_have_their_documented_shapes():
	assert_almost_eq(TechEffects.work_efficiency(1.0), 1.3, 0.0001, "metallurgy")
	assert_almost_eq(TechEffects.safety_recovery_mult(1.0), 1.3, 0.0001, "construction shelter")
	assert_almost_eq(TechEffects.mortality_mult(0.0), 1.0, 0.0001, "no medicine, no mercy")


func test_unlocks():
	var farmers := _known(["agriculture"])
	assert_true(TechEffects.enables_settlements(farmers, 0), "§13: enables settlements")
	assert_false(TechEffects.can_cross_water(farmers, 0))
	var sailors := _known(["sail"])
	assert_true(TechEffects.can_cross_water(sailors, 0), "§13: sail → new basins")
	assert_false(TechEffects.enables_settlements(sailors, 0))
