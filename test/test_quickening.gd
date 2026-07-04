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


func _home_pop(run: GameRun) -> int:
	var count := 0
	for g in run.runner.colony.living():
		if g.home_settlement == GameRun.HOME_SID:
			count += 1
	return count


## The migrant tally the chronicle reports for the LATEST departure —
## "Year N · X souls strike out for <place>".
func _last_migrants_from_chronicle(run: GameRun) -> int:
	var migrants := 0
	for line in run.runner.chronicle:
		if "souls strike out" not in line:
			continue
		var words: PackedStringArray = line.split(" ")
		for i in range(1, words.size()):
			if words[i] == "souls":
				migrants = int(words[i - 1])
	return migrants


## T22.1 regression [PROGRESS Phase 22 BLOCKER]: a fracture fires in the
## SAME season a gaze holds quickened souls. Home-grain heads must
## conserve exactly — before the fix, quickened frontier adults (fresh,
## notability 0) sorted to the front of the migrant pool and were folded
## into the target basin while still referenced by `quickened`, minting
## phantom heads. Also pins T22.2's boundary fold and that a later
## gaze-off still restores the basin exactly, migration and all.
func test_a_same_season_fracture_under_the_gaze_conserves_heads():
	var run := _run_game(2201)
	var found := _found_frontier(run)
	var sid: int = found[0]
	run.attention_places = [found[1]]
	run.advance_day()
	assert_true(run.quickened.has(sid), "precondition: the gaze holds a quickened knot")
	_to_season_eve(run)
	run.runner.colony.unrest = 0.9
	var colony: Colony = run.runner.colony
	# Home folk carry lived notability; the fresh-sampled quickened sit
	# at 0.0 — exactly the state that put them FIRST in the old migrant
	# sort (least notable leave). The fix must ignore them regardless.
	for g in colony.living():
		if g.home_settlement == GameRun.HOME_SID:
			g.notability = 0.5
	var home_eve := _home_pop(run)
	var births := [0]
	var home_deaths := [0]
	var on_born := func(p: Dictionary) -> void:
		if colony.gnomes[p["id"]].home_settlement == GameRun.HOME_SID:
			births[0] += 1
	var on_died := func(p: Dictionary) -> void:
		if colony.gnomes[p["id"]].home_settlement == GameRun.HOME_SID:
			home_deaths[0] += 1
	EventBus.born.connect(on_born)
	EventBus.gnome_died.connect(on_died)
	run.advance_day()  # the boundary: fracture emigration + the T22.2 fold
	EventBus.born.disconnect(on_born)
	EventBus.gnome_died.disconnect(on_died)
	assert_eq(run.quickened, {}, "the boundary folds every quickened soul back [T22.2]")
	var migrants := _last_migrants_from_chronicle(run)
	assert_gt(migrants, 0, "precondition: the fracture sent a splinter this season")
	assert_eq(
		_home_pop(run),
		home_eve + births[0] - home_deaths[0] - migrants,
		(
			"home-grain heads conserve exactly through a gaze-season fracture — "
			+ "a quickened soul picked as a HOME migrant would mint a phantom head [T22.1]"
		)
	)
	# The holding gaze re-materializes the day after the fold…
	run.advance_day()
	assert_true(run.quickened.has(sid), "the holding gaze re-quickens after the boundary fold")
	for g in run.quickened[sid]:
		assert_true(colony.gnomes.has(g.id), "quickened arrays reference only registry souls")
		assert_eq(g.home_settlement, sid, "…each belonging to its own basin")
	# …and a gaze-off still restores the basin head-for-head, exactly as
	# the pre-migration invariant proved.
	var basin_pop: float = run.settlements[sid].pop()
	var live := 0
	for g in run.quickened[sid]:
		if g.is_alive():
			live += 1
	run.attention_places = []
	run.advance_day()
	assert_almost_eq(
		run.settlements[sid].pop(),
		basin_pop + live,
		0.0001,
		"gaze-off after a same-season migration still conserves heads [T22.1]"
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
