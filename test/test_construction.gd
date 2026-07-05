extends GutTest

## R2.3 [rav §R-set/§R-infl] — autonomous construction: each season a
## settlement banks surplus labor and raises the single top-priority buildable
## structure, driven by the pressures the player/nature shape. Deterministic
## (no Rng): the same state always builds the same thing.


func _settlement(adults: float, pop_extra: float = 0.0) -> Settlement:
	var s := Settlement.new(4, 100.0, 3.0)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	s.by_stage[Enums.LifeStage.CHILD] = pop_extra
	s.build_progress = 20.0  # pre-banked so the top pick completes this season
	return s


func _colony(techs: Array = []) -> Colony:
	var c := Colony.new()
	var known := {}
	for t in techs:
		known[t] = true
	c.settlement_knowledge[4] = known
	return c


func test_labor_is_surplus_adults_beyond_maintenance():
	var s := _settlement(10.0)
	s.by_stage[Enums.LifeStage.CHILD] = 10.0  # pop 20, adults 10
	# (10 − 0.33·20)·0.5 = (10 − 6.6)·0.5 = 1.7
	assert_almost_eq(Construction.labor(s), 1.7, 0.0001)


func test_hunger_builds_a_farm():
	var s := _settlement(30.0)
	var built := Construction.season_tick(_colony(["agriculture"]), s, {"hunger": 0.9})
	assert_eq(built, "farm", "scarcity drives the plough")
	assert_eq(s.structure_count("farm"), 1.0)


func test_fear_builds_a_wall():
	var s := _settlement(40.0)
	s.belief["fear"] = 0.8
	var built := Construction.season_tick(_colony(["construction"]), s, {"war_threat": 0.4})
	assert_eq(built, "wall", "dread and threat raise a wall")


func test_faith_builds_a_shrine():
	var s := _settlement(20.0)
	s.belief["faith"] = 0.9
	var built := Construction.season_tick(_colony(), s, {})
	assert_eq(built, "shrine", "reverence raises a shrine (no prereq)")


func test_prereq_gates_the_farm():
	var s := _settlement(30.0)
	# Hunger is high but agriculture is unknown → the farm is not buildable;
	# the settlement raises housing instead, never a farm.
	var built := Construction.season_tick(_colony(), s, {"hunger": 0.9})
	assert_ne(built, "farm", "no plough without agriculture")
	assert_eq(s.structure_count("farm"), 0.0, "…and no farm rises")


func test_no_labor_no_building():
	var s := _settlement(2.0)
	s.build_progress = 0.0
	s.by_stage[Enums.LifeStage.CHILD] = 10.0  # adults 2, pop 12 → labor 0
	var built := Construction.season_tick(_colony(["agriculture"]), s, {"hunger": 1.0})
	assert_eq(built, "", "no surplus hands, no building")


func test_completion_emits_and_crosses_a_tier():
	var s := _settlement(20.0)  # pop 20 ≥ village floor
	watch_signals(EventBus)
	var built := Construction.season_tick(_colony(["agriculture"]), s, {"hunger": 0.9})
	assert_eq(built, "farm")
	assert_eq(s.tier, Enums.SettlementTier.VILLAGE, "the first farm makes a village")
	assert_signal_emitted(EventBus, "structure_built")
	assert_signal_emitted(EventBus, "settlement_tier_changed")


func test_caps_block_overbuilding_a_shrine():
	var s := _settlement(20.0)
	s.belief["faith"] = 0.9
	s.structures["shrine"] = 1.0  # already at the cap of 1
	var built := Construction.season_tick(_colony(), s, {})
	assert_ne(built, "shrine", "a settlement raises only one shrine")


func test_progress_carries_when_underfunded():
	var s := _settlement(3.0)  # tiny: one season's labor ≈ 1.0 < shrine cost 2
	s.build_progress = 0.0
	s.belief["faith"] = 0.9
	var built := Construction.season_tick(_colony(), s, {})
	assert_eq(built, "", "a lean season can't finish the shrine")
	assert_gt(s.build_progress, 0.0, "…but its labor banks toward next season")
	assert_lt(s.build_progress, Construction.COST["shrine"], "…still short of the cost")
