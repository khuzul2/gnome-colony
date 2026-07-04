extends GutTest

## T21.3 — aggregate war & schism go live [PROGRESS Phase 21, algo
## §14/§17]: at the civilization season GameRun derives §17's inputs
## from Settlement aggregates only. religious_distance = the schism
## metric (mean |Δ| over belief axes) read at the season's EVE (the
## documented test_frontier convention — season_tick's relax would put
## the 0.5 line out of reach of any [0,1] belief otherwise);
## resource_pressure = the pair's mean crowding; rivalry = min/max pop
## (evenly-matched neighbors contest hardest — interpretive, documented
## in game_run.gd). Doctrinal schism needs ≥ 2 prophet creeds and splits
## the larger settlement into the first free basin; §14's unrest term is
## an Rng roll (the deferred orchestrator roll civilization.gd names).
## Home (the individual grain) fights and splits in NEITHER — §14's civ
## flows are aggregate. Hand-built settlements ARE legitimate setup:
## the dict is the shell's own state, seeded at the season eve.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _run_game(seed_value: int) -> GameRun:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.colony_name = "Conflicttest"
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	return run


## Advance to the season's EVE [test_frontier.gd pattern]: state seeded
## here is exactly what the boundary's conflict flows read one day later.
func _to_season_eve(run: GameRun) -> void:
	while (run.runner.time.day() + 1) % TimeService.DAYS_PER_SEASON != 0:
		run.advance_day()


## Hand-build a live frontier aggregate in a chosen basin.
func _settle(run: GameRun, sid: int, adults: float, belief: Dictionary = {}) -> Settlement:
	var s := Settlement.new(sid, GameRun.FRONTIER_BASE_K, GameRun.FRONTIER_RICHNESS)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	for axis in belief:
		s.belief[axis] = belief[axis]
	run.settlements[sid] = s
	return s


## A crystallized prophet creed [test_civilization.gd helper] — two of
## these make a "rival theology" for Civilization.schism_due.
func _creed(c: Colony, prophet_id: int, flavor: String) -> void:
	var obj := BeliefObject.make("theology", Devotion.YOU, "faith", 0.5, [prophet_id])
	obj["flavor"] = flavor
	obj["prophet_id"] = prophet_id
	c.beliefs.append(obj)


func _events_of(run: GameRun, kind: String) -> int:
	var count := 0
	for event in run.telemetry.events:
		if event.get("type", "") == kind:
			count += 1
	return count


func _chronicle_has(run: GameRun, needle: String) -> bool:
	for line in run.runner.chronicle:
		if needle in line:
			return true
	return false


func test_a_doctrinal_split_schisms_into_a_free_basin():
	var run := _run_game(2131)
	_to_season_eve(run)
	# Basins 1 and 3 are NOT ring-neighbors (no war can muddy this) but
	# stand ≥ 0.5 apart on the belief axes: (0.9+0.8+0.7)/3 = 0.8.
	var orthodox := _settle(run, 1, 60.0, {"faith": 0.9, "awe": 0.8, "fear": 0.7})
	_settle(run, 3, 40.0)
	_creed(run.runner.colony, 0, "mercy")
	_creed(run.runner.colony, 5, "wrath")
	run.advance_day()
	assert_true(run.settlements.has(2), "the LARGER side splits into the first free basin [§14]")
	assert_almost_eq(
		run.settlements[2].pop(), orthodox.pop(), 0.001, "split halves every bucket — conservation"
	)
	assert_eq(_events_of(run, "schism"), 1, "the schism enters the telemetry stream [§1.9]")
	assert_true(_chronicle_has(run, "schism"), "…and the chronicle names it")


func test_distance_without_a_rival_creed_stays_whole():
	var run := _run_game(2132)
	_to_season_eve(run)
	_settle(run, 1, 60.0, {"faith": 0.9, "awe": 0.8, "fear": 0.7})
	_settle(run, 3, 40.0)
	run.advance_day()
	assert_eq(run.settlements.size(), 2, "distance alone is drift — §14 demands a rival theology")
	assert_eq(_events_of(run, "schism"), 0)


func test_crowded_evenly_matched_neighbors_go_to_war():
	var run := _run_game(2133)
	_to_season_eve(run)
	# Basins 2 and 3 ARE ring-neighbors; K = 200·2 = 400, so ~0.8
	# crowding each; near-equal pops → rivalry ≈ 0.94; faith gap 0.3.
	var stronger := _settle(run, 2, 320.0, {"faith": 0.9})
	var weaker := _settle(run, 3, 300.0)
	run.runner.colony.settlement_knowledge[2] = {"metallurgy": true}
	var before: float = stronger.pop() + weaker.pop()
	run.advance_day()
	assert_eq(_events_of(run, "war"), 1, "rivalry + pressure + distance ≥ 1.5 → war [§17]")
	assert_lt(
		stronger.pop() + weaker.pop(),
		before - 30.0,
		"war is a major mortality event — both sides bleed past season noise [§14]"
	)
	assert_gt(weaker.belief["fear"], 0.15, "the loser learns fear [§14]")
	assert_gt(weaker.belief["fear"], stronger.belief["fear"], "…more than the winner does")
	assert_true(_chronicle_has(run, "war"), "the chronicle names winner and loser")


func test_a_calm_pair_does_neither():
	var run := _run_game(2134)
	_to_season_eve(run)
	_settle(run, 2, 40.0, {"faith": 0.5})
	_settle(run, 3, 40.0, {"faith": 0.5})
	run.advance_day()
	assert_eq(run.settlements.size(), 2, "no free-basin faction appeared")
	assert_eq(_events_of(run, "war"), 0, "1.0 + 0.1 + 0 stays under the 1.5 line [§17]")
	assert_eq(_events_of(run, "schism"), 0)


func test_at_most_one_war_per_season():
	var run := _run_game(2135)
	_to_season_eve(run)
	# Both (1,2) and (2,3) are adjacent qualifying pairs — one war only.
	_settle(run, 1, 300.0)
	_settle(run, 2, 310.0)
	_settle(run, 3, 300.0)
	run.advance_day()
	assert_eq(_events_of(run, "war"), 1, "one war a season — the first pair in sorted order")


func test_home_joins_no_war_however_provoked():
	var run := _run_game(2136)
	_to_season_eve(run)
	# Basin 5 neighbors home (basin 0) on the ring and would qualify
	# against it on every input — but §14's civ flows are aggregate and
	# home's grain is individual: no pair, no war.
	_settle(run, 5, 350.0, {"faith": 0.9, "awe": 0.9, "fear": 0.9})
	run.advance_day()
	assert_eq(_events_of(run, "war"), 0, "the mirror fights in neither [T21.3, documented]")
	assert_eq(_events_of(run, "schism"), 0)
