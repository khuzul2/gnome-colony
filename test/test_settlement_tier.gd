extends GutTest

## R2.2 [rav §R-set] — the development tier is derived from population AND
## structure/tech gates, with ±10% pop hysteresis so a settlement doesn't
## flicker at a boundary. update_tier emits settlement_tier_changed on a real
## change only.


func _settlement(pop: float) -> Settlement:
	var s := Settlement.new(7, 100.0, 3.0)
	s.by_stage[Enums.LifeStage.ADULT] = pop
	return s


func _colony(construction: bool) -> Colony:
	var c := Colony.new()
	c.settlement_knowledge[7] = {"agriculture": true}
	if construction:
		c.settlement_knowledge[7]["construction"] = true
	return c


func test_hamlet_until_a_village_earns_its_first_farm():
	var c := _colony(false)
	var s := _settlement(5.0)
	assert_eq(SettlementSim.tier_of(c, s), Enums.SettlementTier.HAMLET, "tiny = hamlet")
	s.by_stage[Enums.LifeStage.ADULT] = 20.0
	assert_eq(SettlementSim.tier_of(c, s), Enums.SettlementTier.HAMLET, "pop alone isn't a village")
	s.structures["farm"] = 1.0
	assert_eq(
		SettlementSim.tier_of(c, s), Enums.SettlementTier.VILLAGE, "pop≥12 + a farm = village"
	)


func test_town_needs_pop_construction_and_a_granary():
	var s := _settlement(70.0)
	s.structures["farm"] = 1.0
	s.structures["granary"] = 1.0
	assert_eq(
		SettlementSim.tier_of(_colony(false), s),
		Enums.SettlementTier.VILLAGE,
		"no construction → still a village"
	)
	assert_eq(
		SettlementSim.tier_of(_colony(true), s),
		Enums.SettlementTier.TOWN,
		"pop≥60 + construction + granary = town"
	)


func test_city_needs_a_basilica_and_a_wall():
	var c := _colony(true)
	var s := _settlement(300.0)
	s.structures = {"farm": 1.0, "granary": 1.0, "basilica": 1.0}
	assert_eq(SettlementSim.tier_of(c, s), Enums.SettlementTier.TOWN, "no wall yet → town")
	s.structures["wall"] = 1.0
	assert_eq(
		SettlementSim.tier_of(c, s), Enums.SettlementTier.CITY, "pop≥250 + basilica + wall = city"
	)


func test_hysteresis_holds_a_city_through_a_dip():
	var c := _colony(true)
	var s := _settlement(300.0)
	s.structures = {"farm": 1.0, "granary": 1.0, "basilica": 1.0, "wall": 1.0}
	s.tier = Enums.SettlementTier.CITY
	s.by_stage[Enums.LifeStage.ADULT] = 230.0  # above the 0.9·250 = 225 floor
	assert_eq(SettlementSim.tier_of(c, s), Enums.SettlementTier.CITY, "a shallow dip stays a city")
	s.by_stage[Enums.LifeStage.ADULT] = 220.0  # below the floor
	assert_eq(SettlementSim.tier_of(c, s), Enums.SettlementTier.TOWN, "a real fall demotes")


func test_update_tier_emits_only_on_change():
	var c := _colony(true)
	var s := _settlement(20.0)
	s.structures["farm"] = 1.0
	watch_signals(EventBus)
	assert_true(SettlementSim.update_tier(c, s), "hamlet→village is a change")
	assert_eq(s.tier, Enums.SettlementTier.VILLAGE)
	assert_signal_emitted_with_parameters(
		EventBus,
		"settlement_tier_changed",
		[{"sid": 7, "from": Enums.SettlementTier.HAMLET, "to": Enums.SettlementTier.VILLAGE}]
	)
	assert_false(SettlementSim.update_tier(c, s), "no change → no event")
