extends GutTest

## T4.1 — practice asymptote [algo §7/§17]: prof += 0.01·(1−prof)·dt while
## working the skill. Self-taught to 0.2 in ≈22 days (§17 sanity figure).
## Teachability (the knowledge id) tracks prof ≥ 0.2.


func _adult() -> GnomeData:
	var g := GnomeData.new(0)
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	return g


func test_practice_rate_matches_formula():
	var g := _adult()
	Skills.practice(g, "foraging", 1.0)
	assert_almost_eq(g.skills["foraging"], 0.01, 0.000001, "from 0: 0.01·(1−0)·1")
	Skills.practice(g, "foraging", 1.0)
	assert_almost_eq(g.skills["foraging"], 0.01 + 0.01 * 0.99, 0.000001)


func test_gain_curve_approaches_one_asymptotically():
	var g := _adult()
	g.set_skill("foraging", 0.99)
	for i in 1000:
		Skills.practice(g, "foraging", 1.0)
	assert_lt(g.skills["foraging"], 1.0, "asymptote never reached")
	assert_gt(g.skills["foraging"], 0.999)


func test_self_taught_to_teachable_in_about_22_days():
	var g := _adult()
	var day := 0
	while g.skills.get("foraging", 0.0) < 0.2:
		Skills.practice(g, "foraging", 1.0)
		day += 1
	assert_between(day, 20, 25, "§17: self-taught to 0.2 ≈ 22 d")


func test_knowledge_id_granted_at_teachability_threshold():
	var g := _adult()
	# 0.195 + 0.01·(1−0.195) ≈ 0.203 crosses the 0.2 line (0.19 would not).
	g.set_skill("foraging", 0.195)
	Skills.practice(g, "foraging", 1.0)
	assert_true("foraging" in g.knowledge, "crossing 0.2 grants the teachable id")
