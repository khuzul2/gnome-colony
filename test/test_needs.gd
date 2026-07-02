extends GutTest

## T3.1 — need decay/day [algo §3/§17]: hunger 0.12 · rest 0.10 ·
## social 0.08 · purpose 0.06; safety RECOVERS −0.06/day toward 0.
## Stage mods: social ×1.3 Adolescent; purpose ×1.3 Adult/Elder.


func _adult() -> GnomeData:
	var g := GnomeData.new(0)
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	return g


func _colony_with(g: GnomeData) -> Colony:
	var c := Colony.new()
	c.add(g)
	return c


func test_base_decay_rates_after_one_day():
	var g := _adult()
	Needs.tick(_colony_with(g), 1.0)
	assert_almost_eq(g.needs["hunger"], 0.12, 0.0001)
	assert_almost_eq(g.needs["rest"], 0.10, 0.0001)
	assert_almost_eq(g.needs["social"], 0.08, 0.0001)
	assert_almost_eq(g.needs["purpose"], 0.06 * 1.3, 0.0001, "adult purpose decays ×1.3")


func test_adolescent_social_modifier():
	var g := GnomeData.new(0)
	g.age = 16.0
	g.stage = Enums.LifeStage.ADOLESCENT
	Needs.tick(_colony_with(g), 1.0)
	assert_almost_eq(g.needs["social"], 0.08 * 1.3, 0.0001)
	assert_almost_eq(g.needs["purpose"], 0.06, 0.0001, "purpose mod is Adult/Elder only")


func test_child_has_no_stage_modifiers():
	var g := GnomeData.new(0)
	g.age = 8.0
	g.stage = Enums.LifeStage.CHILD
	Needs.tick(_colony_with(g), 1.0)
	assert_almost_eq(g.needs["social"], 0.08, 0.0001)
	assert_almost_eq(g.needs["purpose"], 0.06, 0.0001)


func test_safety_recovers_toward_zero():
	var g := _adult()
	g.set_need("safety", 0.5)
	Needs.tick(_colony_with(g), 1.0)
	assert_almost_eq(g.needs["safety"], 0.44, 0.0001, "safety −0.06/day toward 0")
	g.set_need("safety", 0.03)
	Needs.tick(_colony_with(g), 1.0)
	assert_eq(g.needs["safety"], 0.0, "never overshoots below 0")


func test_needs_clamp_at_one():
	var g := _adult()
	for i in 20:
		Needs.tick(_colony_with(g), 1.0)
	assert_eq(g.needs["hunger"], 1.0)
	assert_eq(g.needs["rest"], 1.0)


func test_dead_gnomes_do_not_decay():
	var g := _adult()
	g.stage = Enums.LifeStage.DEAD
	Needs.tick(_colony_with(g), 1.0)
	assert_eq(g.needs["hunger"], 0.0)
