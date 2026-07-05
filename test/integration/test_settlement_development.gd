extends GutTest

## Phase-Exit R2 [rav §R-set/§R-build/§R-infl] — the whole living-settlement
## arc, sim-side: a settlement grows hamlet→village→town→city IN ORDER (one
## settlement_tier_changed per crossing) as it autonomously builds the gating
## structures, then a famine strips its buildings and drops the tier.


func _colony() -> Colony:
	var c := Colony.new()
	# The crafts a growing settlement has learned; devotion high enough for a
	# basilica (Tier III) — the pressures you shaped, abstracted for the arc.
	c.settlement_knowledge[3] = {"agriculture": true, "construction": true}
	c.unlocked_tier = 3
	return c


func _run(c: Colony, s: Settlement, pop: float, pressures: Dictionary, seasons: int) -> void:
	s.by_stage[Enums.LifeStage.ADULT] = pop
	for i in seasons:
		Construction.season_tick(c, s, pressures)


func _distinct_promotions(s: Settlement) -> Array:
	var tos := []
	for i in get_signal_emit_count(EventBus, "settlement_tier_changed"):
		var payload: Dictionary = get_signal_parameters(EventBus, "settlement_tier_changed", i)[0]
		if payload["sid"] == s.sid and (tos.is_empty() or tos[-1] != payload["to"]):
			tos.append(payload["to"])
	return tos


func test_a_settlement_climbs_hamlet_to_city_in_order():
	var c := _colony()
	var s := Settlement.new(3, 200.0, 4.0)
	s.belief["faith"] = 0.9
	watch_signals(EventBus)
	assert_eq(s.tier, Enums.SettlementTier.HAMLET, "it starts a hamlet")

	# Scarcity → the plough → a village.
	_run(c, s, 20.0, {"hunger": 1.0}, 6)
	assert_eq(s.tier, Enums.SettlementTier.VILLAGE, "pop + a farm → village")

	# Plenty → a granary (and its basilica) → a town.
	_run(c, s, 80.0, {"surplus": 1.0}, 8)
	assert_eq(s.tier, Enums.SettlementTier.TOWN, "pop + construction + a granary → town")

	# Threat → a wall (the basilica already stands) → a city.
	_run(c, s, 300.0, {"war_threat": 1.0, "surplus": 1.0}, 10)
	assert_eq(s.tier, Enums.SettlementTier.CITY, "pop + a basilica + a wall → city")

	# The gating structures actually exist.
	assert_gte(s.structure_count("farm"), 1.0, "the village earned a farm")
	assert_gte(s.structure_count("granary"), 1.0, "the town earned a granary")
	assert_gte(s.structure_count("basilica"), 1.0, "the city earned its basilica")
	assert_gte(s.structure_count("wall"), 1.0, "…and its wall")

	# The promotions fired in ascending order, none skipped.
	assert_eq(
		_distinct_promotions(s),
		[
			Enums.SettlementTier.VILLAGE,
			Enums.SettlementTier.TOWN,
			Enums.SettlementTier.CITY,
		],
		"one crossing per tier, in order"
	)


func test_famine_strips_the_buildings_and_drops_the_tier():
	var c := _colony()
	var s := Settlement.new(3, 200.0, 4.0)
	s.belief["faith"] = 0.9
	_run(c, s, 80.0, {"surplus": 1.0, "hunger": 0.5}, 12)  # a stocked town
	assert_gte(s.tier, Enums.SettlementTier.TOWN, "grew to a town")
	var town_stock := 0.0
	for id in s.structures:
		town_stock += s.structures[id]

	# A famine you caused hollows the settlement — labor collapses.
	s.by_stage[Enums.LifeStage.ADULT] = 1.0
	s.by_stage[Enums.LifeStage.CHILD] = 5.0
	for i in 30:
		Construction.decay_tick(c, s)
	var ruin_stock := 0.0
	for id in s.structures:
		ruin_stock += s.structures[id]
	assert_lt(ruin_stock, town_stock, "neglected buildings fall to ruin")
	assert_lt(s.tier, Enums.SettlementTier.TOWN, "a hollowed town loses its tier")
