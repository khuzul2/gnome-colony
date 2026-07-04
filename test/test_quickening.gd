extends GutTest

## T21.1 — the Eye quickens the frontier [PROGRESS Phase 21, algo §14]:
## dwelling on a populated frontier basin materializes up to
## GameRun.QUICKENED_PER_BASIN of its souls through the proven
## Promotion pair; the gaze leaving folds them back, heads conserved.
## Quickened souls stand at their basin (day-trip staging skips them)
## and ride the save envelope as ordinary colony members — resume
## regroups them so a later gaze-off still dematerializes.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _run_game(seed_value: int) -> GameRun:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.colony_name = "Quickentest"
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	return run


## Advance to the season's EVE [test_frontier.gd pattern] so the crowd
## planted here still holds at the boundary one day later.
func _to_season_eve(run: GameRun) -> void:
	while (run.runner.time.day() + 1) % TimeService.DAYS_PER_SEASON != 0:
		run.advance_day()


func _crowd(run: GameRun, extra: int) -> void:
	for i in extra:
		var g := run.runner.colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = run.home


## Crowd home past the §14 comfort line so emigration founds a frontier
## basin; returns [sid, its place id].
func _found_frontier(run: GameRun) -> Array:
	_to_season_eve(run)
	_crowd(run, 56)
	run.advance_day()
	run.advance_day()
	assert_gt(run.settlements.size(), 0, "precondition: the frontier founded")
	var sid: int = run.settlements.keys()[0]
	return [sid, _place_for(run, sid)]


func _place_for(run: GameRun, sid: int) -> String:
	for region in run.graph.regions:
		if region["id"] == sid:
			return WorldBootstrap.place_id(region)
	return ""


func _frontier_folk(run: GameRun) -> Array:
	var folk := []
	for g in run.runner.colony.living():
		if g.home_settlement != GameRun.HOME_SID:
			folk.append(g)
	return folk


func test_the_gaze_materializes_frontier_souls():
	var run := _run_game(2101)
	var found := _found_frontier(run)
	var sid: int = found[0]
	var colony_before := run.runner.colony.population()
	var basin_before: float = run.settlements[sid].pop()
	run.attention_places = [found[1]]
	run.advance_day()
	assert_true(run.quickened.has(sid), "the attended basin quickens [T21.1]")
	var count: int = run.quickened[sid].size()
	assert_gt(count, 0, "real souls step out of the aggregate")
	assert_lte(count, GameRun.QUICKENED_PER_BASIN, "the per-basin knot stays small")
	assert_eq(
		run.runner.colony.population(),
		colony_before + count,
		"the colony gained exactly the materialized heads"
	)
	assert_almost_eq(
		run.settlements[sid].pop(),
		basin_before - count,
		0.0001,
		"the basin's buckets drained by the same heads — conservation"
	)


func test_quickened_souls_stand_at_their_basin_and_stay():
	var run := _run_game(2102)
	var found := _found_frontier(run)
	var sid: int = found[0]
	var place: String = found[1]
	run.attention_places = [place]
	run.advance_day()
	for g in run.quickened[sid]:
		if g.is_alive():
			assert_eq(g.location, place, "materialized souls stand at the frontier")
	run.advance_day()
	for g in run.quickened[sid]:
		if g.is_alive():
			assert_eq(g.location, place, "staging skips frontier folk — they keep standing there")


func test_the_gaze_leaving_folds_them_back():
	var run := _run_game(2103)
	var found := _found_frontier(run)
	var sid: int = found[0]
	var basin_before: float = run.settlements[sid].pop()
	run.attention_places = [found[1]]
	run.advance_day()
	run.attention_places = []
	run.advance_day()
	assert_eq(run.quickened, {}, "gaze off — the souls fold back into the aggregate")
	assert_eq(_frontier_folk(run).size(), 0, "no quickened body lingers in the colony")
	assert_almost_eq(
		run.settlements[sid].pop(),
		basin_before,
		0.0001,
		"head-counts restore exactly (scalar means fold as running averages)"
	)


func test_save_and_resume_regroup_the_quickened():
	var run := _run_game(2104)
	var found := _found_frontier(run)
	var sid: int = found[0]
	run.attention_places = [found[1]]
	run.advance_day()
	var count: int = run.quickened[sid].size()
	var envelope := run.save()
	run.shutdown()
	_runs.clear()
	var resumed := GameRun.resume(envelope)
	_runs.append(resumed)
	assert_true(resumed.quickened.has(sid), "resume regroups the quickened by basin")
	assert_eq(resumed.quickened[sid].size(), count, "same souls, same count across the envelope")
	resumed.attention_places = []
	resumed.advance_day()
	assert_eq(resumed.quickened, {}, "a later gaze-off still dematerializes after a load")
