extends GutTest

## T10.2 — discovery process [algo §13/§17]: research is a stochastic
## settlement-tier process; the player never picks targets.
##   pressure(X) = need_pressure · (0.3 + curiosity_mean) · surplus_factor
##                 · (1 + log(minds)) · institution_factor
##   p_discover(X)/season = clamp01(0.01 · pressure)   [§17 base_rate]
## need_pressure comes from environment & the player's phenomena — an
## INPUT here (drought → irrigation…); institution factors default 1.


func _settlement(n: int, curious: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("curious", curious)
	return c


func test_pressure_formula_is_exact():
	# 2.0 · (0.3+0.5) · 1.0 · (1+ln 10) · 1.0
	var expected := 2.0 * 0.8 * 1.0 * (1.0 + log(10.0)) * 1.0
	assert_almost_eq(Research.pressure(2.0, 0.5, 1.0, 10, 1.0), expected, 0.0001)


func test_p_discover_clamps_to_one():
	assert_almost_eq(Research.p_discover(4.0), 0.04, 0.0001, "base_rate 0.01 [§17]")
	assert_eq(Research.p_discover(500.0), 1.0, "clamp01")
	assert_eq(Research.p_discover(0.0), 0.0, "no pressure, no progress")


func test_more_minds_press_harder():
	var few := Research.pressure(1.0, 0.5, 1.0, 4, 1.0)
	var many := Research.pressure(1.0, 0.5, 1.0, 40, 1.0)
	assert_gt(many, few, "§13: (1 + log(minds)) — population is a research engine")


func test_no_surplus_no_research():
	assert_eq(Research.pressure(3.0, 0.9, 0.0, 50, 1.0), 0.0, "starving colonies don't wonder")


func test_need_steers_discovery():
	# Drought-pressured irrigation is found; the unpressured rest is not.
	Rng.seed_with(10200)
	var c := _settlement(20, 0.8)
	for g in c.living():
		g.add_knowledge("agriculture")
	Knowledge.sync(c)
	var found := []
	for season in 60:
		found += Research.season_tick(c, 0, {"irrigation": 8.0}, 1.0)
		if "irrigation" in found:
			break
	assert_has(found, "irrigation", "drought → irrigation [§13 need_pressure]")
	assert_eq(found.size(), 1, "no pressure on anything else — nothing else fired")


func test_prereqs_gate_even_under_pressure():
	Rng.seed_with(10201)
	var c := _settlement(20, 0.8)
	Knowledge.sync(c)
	var found := []
	for season in 60:
		found += Research.season_tick(c, 0, {"irrigation": 8.0}, 1.0)
	assert_does_not_have(found, "irrigation", "no agriculture, no irrigation [§7]")


func test_pressure_raises_the_rate():
	var low_hits := 0
	var high_hits := 0
	for i in 30:
		Rng.seed_with(10300 + i)
		var low := _settlement(12, 0.5)
		Knowledge.sync(low)
		for season in 10:
			if not Research.season_tick(low, 0, {"fire": 1.0}, 1.0).is_empty():
				low_hits += 1
				break
	for i in 30:
		Rng.seed_with(10400 + i)
		var high := _settlement(12, 0.5)
		Knowledge.sync(high)
		for season in 10:
			if not Research.season_tick(high, 0, {"fire": 10.0}, 1.0).is_empty():
				high_hits += 1
				break
	assert_gt(high_hits, low_hits, "10× need pressure finds fire in more worlds")


func test_discovery_becomes_held_teachable_knowledge():
	Rng.seed_with(10202)
	var c := _settlement(10, 0.9)
	Knowledge.sync(c)
	var found := []
	for season in 80:
		found += Research.season_tick(c, 0, {"fire": 6.0}, 1.0)
		if not found.is_empty():
			break
	assert_has(found, "fire")
	assert_true(c.settlement_knowledge[0].has("fire"), "the settlement knows it [§13]")
	var holder_exists := false
	for g in c.living():
		if "fire" in g.knowledge:
			holder_exists = true
	assert_true(holder_exists, "…and a living discoverer HOLDS it (teachable, losable, §7)")
