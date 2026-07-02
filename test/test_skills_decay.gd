extends GutTest

## T4.3 — unused decay [algo §7/§17]: prof −0.002/day; below 0.2 the id
## becomes un-teachable (removed from knowledge).


func _crafter() -> GnomeData:
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.ADULT
	g.set_skill("smithing", 0.5)
	g.add_knowledge("smithing")
	return g


func test_unused_skill_decays_at_spec_rate():
	var g := _crafter()
	Skills.decay(g, 1.0)
	assert_almost_eq(g.skills["smithing"], 0.498, 0.000001)


func test_used_skills_are_exempt_from_decay():
	var g := _crafter()
	Skills.decay(g, 1.0, ["smithing"])
	assert_eq(g.skills["smithing"], 0.5)


func test_dropping_below_threshold_loses_teachability():
	var g := _crafter()
	g.set_skill("smithing", 0.201)
	Skills.decay(g, 1.0)
	assert_lt(g.skills["smithing"], 0.2)
	assert_false("smithing" in g.knowledge, "below 0.2 the id is un-teachable")


func test_decay_never_goes_negative():
	var g := _crafter()
	g.set_skill("smithing", 0.001)
	Skills.decay(g, 1.0)
	assert_eq(g.skills["smithing"], 0.0)


func test_relearning_restores_teachability():
	var g := _crafter()
	g.set_skill("smithing", 0.15)
	Skills.decay(g, 1.0)
	assert_false("smithing" in g.knowledge)
	while g.skills["smithing"] < 0.2:
		Skills.practice(g, "smithing", 1.0)
	assert_true("smithing" in g.knowledge, "practice can win the id back")
