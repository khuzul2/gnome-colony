extends GutTest

## T11.4 — civilization tier [algo §14/§17]: migration flows to the
## best-scoring reachable basin (resources, low crowding, kin ties,
## shared faith); trade lifts both moods and spreads knowledge/belief;
## schism splits when intra-civ belief distance ≥ 0.5 AND a rival
## theology has crystallized; war triggers at rivalry + resource_pressure
## + religious_distance ≥ 1.5 and resolves by relative war_strength — a
## major mortality & belief event. World's end: every settlement empty →
## world_ended, once. §17 fixes the 0.5/1.5 lines and the strength
## formula; scoring weights, casualty fractions, and mood/belief lifts
## are interpretive, documented in civilization.gd.


func _basin(sid: int, adults: float, richness: float, faith: float = 0.0) -> Settlement:
	var s := Settlement.new(sid, 50.0, richness)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	s.belief["faith"] = faith
	return s


func _creed(c: Colony, prophet_id: int, flavor: String) -> void:
	var obj := BeliefObject.make("theology", Devotion.YOU, "faith", 0.5, [prophet_id])
	obj["flavor"] = flavor
	obj["prophet_id"] = prophet_id
	c.beliefs.append(obj)


func test_migrants_choose_the_best_basin():
	var c := Colony.new()
	var home := _basin(0, 40.0, 2.0)
	var lush := _basin(1, 5.0, 3.0)
	var poor := _basin(2, 5.0, 0.5)
	var packed := _basin(3, 120.0, 3.0)
	var chosen := Civilization.choose_basin(c, home, [poor, lush, packed])
	assert_eq(chosen, lush, "resources and room win [§14]")


func test_shared_faith_tips_the_choice():
	var c := Colony.new()
	var home := _basin(0, 40.0, 2.0, 0.8)
	var kindred := _basin(1, 10.0, 2.0, 0.8)
	var heathen := _basin(2, 10.0, 2.0, 0.0)
	assert_eq(
		Civilization.choose_basin(c, home, [heathen, kindred]),
		kindred,
		"migrants follow their faith [§14]"
	)


func test_kin_ties_tip_the_choice():
	var c := Colony.new()
	var home := _basin(0, 40.0, 2.0)
	var strangers := _basin(1, 10.0, 2.0)
	var cousins := _basin(2, 10.0, 2.0)
	var chosen := Civilization.choose_basin(c, home, [strangers, cousins], {2: 1.0})
	assert_eq(chosen, cousins, "kin ties pull [§14]")


func test_migration_moves_heads_and_knowledge():
	var c := Colony.new()
	c.settlement_knowledge[0] = {"fire": true}
	var from_s := _basin(0, 20.0, 2.0)
	var to_s := _basin(1, 10.0, 2.0)
	Civilization.migrate(c, from_s, to_s, 5.0)
	assert_almost_eq(from_s.adults(), 15.0, 0.0001)
	assert_almost_eq(to_s.adults(), 15.0, 0.0001, "heads conserved across basins")
	assert_true(c.settlement_knowledge[1].has("fire"), "migrants carry what they know [§14]")


func test_trade_lifts_moods_and_spreads():
	var c := Colony.new()
	c.settlement_knowledge[0] = {"fire": true}
	c.settlement_knowledge[1] = {"sail": true}
	var a := _basin(0, 20.0, 2.0, 0.6)
	a.mood = 0.5
	var b := _basin(1, 20.0, 2.0, 0.0)
	b.mood = 0.5
	Civilization.trade_route(c, a, b)
	assert_gt(a.mood, 0.5, "trade raises both moods [§14]")
	assert_gt(b.mood, 0.5)
	assert_true(c.settlement_knowledge[0].has("sail"), "…and spreads knowledge")
	assert_true(c.settlement_knowledge[1].has("fire"))
	assert_gt(b.belief["faith"], 0.0, "…and belief drifts along the route")
	assert_lt(a.belief["faith"], 0.6, "both ends move toward each other")


func test_schism_needs_distance_and_a_rival_creed():
	var c := Colony.new()
	var orthodox := _basin(0, 30.0, 2.0, 0.9)
	var apostate := _basin(1, 30.0, 2.0, 0.0)
	apostate.belief["fear"] = 0.7
	apostate.belief["awe"] = 0.8
	assert_false(
		Civilization.schism_due(c, orthodox, apostate),
		"distance alone is drift — §14 also demands a crystallized rival theology"
	)
	_creed(c, 0, "mercy")
	_creed(c, 5, "wrath")
	assert_true(Civilization.schism_due(c, orthodox, apostate), "distance + rival creed = schism")


func test_schism_distance_line_is_half():
	var c := Colony.new()
	_creed(c, 0, "mercy")
	_creed(c, 5, "wrath")
	var a := _basin(0, 30.0, 2.0, 0.9)
	var near := _basin(1, 30.0, 2.0, 0.6)
	assert_false(Civilization.schism_due(c, a, near), "mean-axis distance 0.1 is under the line")
	var far := _basin(2, 30.0, 2.0, 0.9)
	far.belief["faith"] = 0.0
	far.belief["fear"] = 0.7
	far.belief["awe"] = 0.8
	assert_true(Civilization.schism_due(c, a, far), "≥ 0.5 splits [§14/§17]")


func test_schism_splits_a_settlement():
	var c := Colony.new()
	var s := _basin(0, 40.0, 2.0, 0.5)
	var faction := Civilization.split(c, s, 7)
	assert_almost_eq(s.pop() + faction.pop(), 40.0, 0.0001, "a split conserves people")
	assert_eq(faction.sid, 7)
	assert_gt(s.belief["faith"], faction.belief["faith"], "the creeds separate")


func test_war_triggers_at_the_spec_line():
	assert_false(Civilization.war_due(0.5, 0.5, 0.49))
	assert_true(Civilization.war_due(0.5, 0.5, 0.5), "≥ 1.5 [§17]")


func test_war_is_a_mortality_and_belief_event():
	var c := Colony.new()
	c.settlement_knowledge[0] = {"metallurgy": true}
	var ironclad := _basin(0, 50.0, 2.0)
	var militia := _basin(1, 50.0, 2.0)
	var fear_before: float = militia.belief["fear"]
	var report := Civilization.war(c, ironclad, militia)
	assert_eq(report["winner"], ironclad, "pop·(1+metal)·(0.5+lead) decides [§17]")
	assert_lt(militia.pop(), 50.0, "the loser bleeds")
	assert_lt(ironclad.pop(), 50.0, "…and so does the winner")
	assert_gt(50.0 - militia.pop(), 50.0 - ironclad.pop(), "but not equally")
	assert_gt(militia.belief["fear"], fear_before, "war is a belief event too [§14]")


func test_world_ends_once_when_every_hearth_is_cold():
	var c := Colony.new()
	var a := _basin(0, 0.0, 2.0)
	var b := _basin(1, 0.4, 2.0)
	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.world_ended.connect(listener)
	assert_false(Civilization.check_world_end(c, [a, b]), "0.4 of a gnome still tends a fire")
	b.by_stage[Enums.LifeStage.ADULT] = 0.0
	assert_true(Civilization.check_world_end(c, [a, b]))
	assert_true(Civilization.check_world_end(c, [a, b]), "still ended")
	EventBus.world_ended.disconnect(listener)
	assert_eq(events.size(), 1, "the Chronicle closes exactly once [design §1.9]")
