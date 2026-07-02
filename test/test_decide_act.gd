extends GutTest

## T3.4 — decide picks the max-scoring available action; act applies relief
## and side-effects. Food flows through a §15 resource node.


func _adult_with(needs: Dictionary) -> GnomeData:
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.ADULT
	for k in needs:
		g.set_need(k, needs[k])
	return g


func test_decide_picks_eat_when_starving():
	Rng.seed_with(3400)
	var g := _adult_with({"hunger": 1.0, "social": 0.3})
	assert_eq(Decide.choose(g, {"food_available": true}), "eat")


func test_decide_respects_availability():
	Rng.seed_with(3401)
	var g := _adult_with({"hunger": 1.0, "rest": 0.4})
	assert_ne(
		Decide.choose(g, {"food_available": false}),
		"eat",
		"a starving gnome without food must choose something else"
	)


func test_decide_returns_idle_when_nothing_available():
	# "rest" is ungated, so a living gnome always has at least one action;
	# the idle fallback is reachable only when available() is empty (dead).
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.DEAD
	assert_eq(Decide.choose(g, {}), "idle")


func test_hungry_infant_without_caregiver_falls_back_to_rest():
	Rng.seed_with(3402)
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.INFANT
	g.set_need("hunger", 1.0)
	g.set_need("rest", 0.2)
	var choice := Decide.choose(g, {"food_available": true, "caregiver_available": false})
	assert_eq(choice, "rest", "an unfed infant can only rest — hardship does the rest (T3.5)")


func test_act_applies_relief_and_clamps():
	var g := _adult_with({"hunger": 0.8})
	Act.apply(g, "eat", {})
	assert_almost_eq(g.needs["hunger"], 0.0, 0.0001, "0.8 − 0.9 clamps to 0")


func test_act_applies_side_costs():
	var g := _adult_with({"purpose": 0.9, "rest": 0.2})
	Act.apply(g, "work", {})
	assert_almost_eq(g.needs["purpose"], 0.3, 0.0001)
	assert_almost_eq(g.needs["rest"], 0.25, 0.0001, "work costs +0.05 rest")


func test_eat_consumes_from_food_node():
	var node := ResourceNode.new("food", 10.0, 10.0, 0.5, 1.0)
	var g := _adult_with({"hunger": 1.0})
	Act.apply(g, "eat", {"food_node": node})
	assert_almost_eq(node.current, 9.0, 0.0001, "one meal draws 1.0 unit")


func test_resource_node_harvest_and_regrowth():
	var node := ResourceNode.new("food", 10.0, 2.0, 0.5, 1.0)
	assert_almost_eq(node.harvest(3.0), 2.0, 0.0001, "cannot draw more than current")
	assert_eq(node.current, 0.0)
	node.regrow(4.0)
	assert_almost_eq(node.current, 2.0, 0.0001, "0.5/day × 4 days")
	node.regrow(100.0)
	assert_eq(node.current, 10.0, "regrowth caps at capacity")


func test_idle_is_a_safe_noop():
	var g := _adult_with({"hunger": 0.5})
	var before := g.needs.duplicate()
	Act.apply(g, "idle", {})
	assert_eq(g.needs, before)
