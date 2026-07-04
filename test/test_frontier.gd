extends GutTest

## T18.2 — the open frontier [PROGRESS Phase 18, algo §14]: the live
## civilization tier. Home's emigration follows §14's own formula
## (crowding + mood + your_phenomena); whole adults fold out through
## Promotion into Civilization.choose_basin's pick; a fracture splinters
## half the colony; frontier basins live aggregate seasons and trade
## with home; the main settlement finally has its production caller;
## the world ends only when EVERY basin is empty.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _run_game(seed_value: int) -> GameRun:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.colony_name = "Frontiertest"
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	return run


func _cross_season(run: GameRun) -> void:
	var season := run.runner.time.season()
	while run.runner.time.season() == season:
		run.advance_day()


## Advance to the season's EVE — mutations applied here still hold at
## the boundary one day later (a whole season of famine/relief would
## erode them first; the flows read the state the season ends in).
func _to_season_eve(run: GameRun) -> void:
	while (run.runner.time.day() + 1) % TimeService.DAYS_PER_SEASON != 0:
		run.advance_day()


func _crowd(run: GameRun, extra: int) -> void:
	for i in extra:
		var g := run.runner.colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = run.home


func test_a_calm_band_keeps_to_one_basin():
	var run := _run_game(1801)
	_cross_season(run)
	assert_eq(run.settlements, {}, "no pressure, no frontier [§14]")


func test_crowding_pushes_migrants_into_a_second_basin():
	var run := _run_game(1802)
	_to_season_eve(run)
	_crowd(run, 56)
	var before := run.runner.colony.population()
	run.advance_day()
	run.advance_day()
	assert_gt(run.settlements.size(), 0, "past the comfort line, people leave [§14]")
	var sid: int = run.settlements.keys()[0]
	assert_gt(run.settlements[sid].pop(), 0.0, "the frontier basin holds real souls")
	assert_lt(run.runner.colony.population(), before, "…who genuinely left home")
	var founded := false
	for event in run.telemetry.events:
		if event.get("type", "") == "settlement_founded":
			founded = true
	assert_true(founded, "the founding enters the chronicle stream [§1.9]")
	assert_eq(run.runner.colony.main_settlement, GameRun.HOME_SID, "home keeps the seat")


func test_a_fracture_splinters_half_the_colony():
	var run := _run_game(1803)
	_to_season_eve(run)
	run.runner.colony.unrest = 0.9
	var before := run.runner.colony.population()
	run.advance_day()
	run.advance_day()
	assert_gt(run.settlements.size(), 0, "unrest ≥ 0.8 splinters a settlement [§14]")
	assert_lte(
		run.runner.colony.population(),
		before - int(before * GameRun.FRACTURE_FRACTION) + 2,
		"roughly half walked out (adults available permitting)"
	)
	assert_eq(run.runner.colony.unrest, 0.0, "the pressure vented [interpretive, documented]")


func test_the_frontier_lives_and_trades():
	var run := _run_game(1804)
	# Knowledge lives on gnomes (Knowledge.sync rebuilds the registry);
	# every founder carries fire so home holds it whoever emigrates.
	for g in run.runner.colony.living():
		g.add_knowledge("fire")
	_to_season_eve(run)
	_crowd(run, 56)
	run.advance_day()
	run.advance_day()
	var sid: int = run.settlements.keys()[0]
	var pop_after_founding: float = run.settlements[sid].pop()
	_cross_season(run)
	assert_ne(run.settlements[sid].pop(), pop_after_founding, "aggregate seasons move the basin")
	assert_true(
		run.runner.colony.settlement_knowledge.get(sid, {}).has("fire"),
		"knowledge trades along the kin route [§14]"
	)


func test_home_death_passes_the_seat_and_the_world_lives():
	var run := _run_game(1805)
	_to_season_eve(run)
	_crowd(run, 56)
	run.advance_day()
	run.advance_day()
	var sid: int = run.settlements.keys()[0]
	for g in run.runner.colony.living():
		g.stage = Enums.LifeStage.DEAD
	watch_signals(EventBus)
	_cross_season(run)
	assert_false(run.runner.colony.world_over, "the frontier carries the world on [§14]")
	assert_signal_not_emitted(EventBus, "world_ended")
	assert_eq(run.runner.colony.main_settlement, sid, "the largest survivor takes the seat")
	for stage in run.settlements[sid].by_stage:
		run.settlements[sid].by_stage[stage] = 0.0
	run.advance_day()
	assert_true(run.runner.colony.world_over, "every basin empty — now it ends")


func test_the_frontier_survives_save_and_resume():
	var run := _run_game(1806)
	_to_season_eve(run)
	_crowd(run, 56)
	run.advance_day()
	run.advance_day()
	var sid: int = run.settlements.keys()[0]
	var pop: float = run.settlements[sid].pop()
	var envelope := run.save()
	run.shutdown()
	_runs.clear()
	var resumed := GameRun.resume(envelope)
	_runs.append(resumed)
	assert_true(resumed.settlements.has(sid), "the frontier rides the envelope")
	assert_almost_eq(resumed.settlements[sid].pop(), pop, 0.0001)
