extends GutTest

## Main settlement [user feature 2026-07-03]: the colony keeps a principal
## settlement — development biases toward keeping it the larger one
## (inbound MAIN_PULL on migration choice, outbound MAIN_RETENTION on
## emigration), the seat is sticky while it lives, and when it dies off
## the largest survivor succeeds it. Weights are interpretive, documented
## in civilization.gd / settlement_sim.gd.


func _basin(sid: int, adults: float, richness: float = 2.0) -> Settlement:
	var s := Settlement.new(sid, 50.0, richness)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	return s


func test_largest_settlement_is_anointed_first():
	var c := Colony.new()
	assert_eq(c.main_settlement, -1, "a fresh colony has no seat")
	watch_signals(EventBus)
	var chosen := Civilization.update_main_settlement(c, [_basin(0, 10.0), _basin(1, 25.0)])
	assert_eq(chosen, 1, "the bigger settlement takes the seat")
	assert_eq(c.main_settlement, 1)
	assert_signal_emitted_with_parameters(
		EventBus, "main_settlement_changed", [{"sid": 1, "previous": -1}]
	)


func test_the_seat_is_sticky_while_it_lives():
	var c := Colony.new()
	c.main_settlement = 0
	watch_signals(EventBus)
	var chosen := Civilization.update_main_settlement(c, [_basin(0, 5.0), _basin(1, 50.0)])
	assert_eq(chosen, 0, "a living main settlement keeps the seat even outgrown")
	assert_signal_not_emitted(EventBus, "main_settlement_changed")


func test_succession_when_the_main_settlement_dies_off():
	var c := Colony.new()
	c.main_settlement = 0
	var dead := _basin(0, 0.0)
	var town := _basin(1, 8.0)
	var city := _basin(2, 30.0)
	watch_signals(EventBus)
	var chosen := Civilization.update_main_settlement(c, [dead, town, city])
	assert_eq(chosen, 2, "the largest survivor succeeds the fallen seat")
	assert_signal_emitted_with_parameters(
		EventBus, "main_settlement_changed", [{"sid": 2, "previous": 0}]
	)


func test_equal_pops_succeed_deterministically_by_sid():
	var c := Colony.new()
	c.main_settlement = 9
	var chosen := Civilization.update_main_settlement(c, [_basin(4, 12.0), _basin(3, 12.0)])
	assert_eq(chosen, 3, "ties break to the lowest sid — replays agree")


func test_no_survivors_empties_the_seat():
	var c := Colony.new()
	c.main_settlement = 0
	watch_signals(EventBus)
	var chosen := Civilization.update_main_settlement(c, [_basin(0, 0.0), _basin(1, 0.005)])
	assert_eq(chosen, -1, "below ALIVE_EPSILON nobody can hold the seat")
	assert_signal_emitted_with_parameters(
		EventBus, "main_settlement_changed", [{"sid": -1, "previous": 0}]
	)


func test_migrants_prefer_the_main_settlement():
	var c := Colony.new()
	var home := _basin(0, 40.0)
	var plain := _basin(1, 10.0)
	var seat := _basin(2, 10.0)
	assert_eq(
		Civilization.choose_basin(c, home, [plain, seat]),
		plain,
		"without a seat, equal basins tie to list order — the control"
	)
	c.main_settlement = 2
	assert_eq(
		Civilization.choose_basin(c, home, [plain, seat]),
		seat,
		"MAIN_PULL draws migrants toward the seat — the bias that keeps it larger"
	)


func test_the_main_settlement_holds_its_people():
	# Two identical over-crowded settlements, one season each; the seat
	# must bleed exactly MAIN_RETENTION of the control's emigration.
	var flows := []
	for main_sid in [-1, 0]:
		Rng.seed_with(4242)
		var c := Colony.new()
		c.main_settlement = main_sid
		var s := _basin(0, 60.0, 1.0)
		flows.append(SettlementSim.season_tick(c, s, 1.0)["migration_out"])
	assert_gt(flows[0], 0.0, "crowding past comfort pushes people out — the control")
	assert_almost_eq(
		flows[1],
		flows[0] * SettlementSim.MAIN_RETENTION,
		0.0001,
		"the seat keeps half who would have left"
	)


func test_main_settlement_survives_save_and_load():
	var c := Colony.new()
	c.main_settlement = 3
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(c))
	assert_eq(restored.main_settlement, 3)
	var pre_feature := Serializer.colony_to_dict(Colony.new())
	pre_feature.erase("main_settlement")
	assert_eq(
		Serializer.colony_from_dict(pre_feature).main_settlement,
		-1,
		"pre-feature saves load with no seat, not a crash"
	)
