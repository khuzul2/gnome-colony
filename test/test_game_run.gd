extends GutTest

## T17.2 — GameRun orchestrator [PROGRESS Phase 17]: the run a player
## actually plays — SimRunner + the epochal daily stack (Lod ← attention,
## belief propagate/decay/crystallize, devotion unlocks/unrest, prophets,
## the slice's documented Magic glue) + seasonal research + the slice's
## cast composition + save/resume with the RNG stream. Pure composition
## of proven pieces; every number it carries is promoted slice/epochal
## glue, documented in game_run.gd.


func _cfg(seed_value: int = 1701) -> WorldConfig:
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.colony_name = "Testholme"
	cfg.normalize()
	return cfg


func _fresh(seed_value: int = 1701) -> GameRun:
	return GameRun.new_game(_cfg(seed_value))


func test_new_game_founds_the_band_in_a_generated_world():
	var run := _fresh()
	assert_eq(run.runner.colony.population(), 4, "the §5 band steps out")
	assert_eq(run.world.sites[run.home], run.food, "home site IS the larder [slice wiring]")
	assert_eq(run.graph.regions.size(), 6, "medium world, 6 basins")
	for g in run.runner.colony.living():
		assert_ne(g.location, "", "staging gives everyone a place to stand [slice glue]")
	run.shutdown()


func test_days_advance_the_whole_stack():
	var run := _fresh()
	for day in 5:
		run.advance_day()
	assert_eq(run.runner.time.day(), 5)
	assert_gt(
		run.telemetry.summary(run.runner.colony)["peak_pop"],
		0,
		"telemetry watches every day [T16.3: one stream, two readers]"
	)
	run.shutdown()


func test_a_witnessed_cast_writes_devotion():
	var run := _fresh()
	assert_eq(Devotion.total(run.runner.colony), 0.0)
	var stimuli := run.cast("still_air", run.home)
	assert_gt(stimuli.size(), 0, "the Tier-I act lands")
	assert_gt(Devotion.total(run.runner.colony), 0.0, "witnessed act writes faith [slice §8]")
	run.shutdown()


func test_locked_acts_are_refused():
	var run := _fresh()
	assert_eq(run.runner.colony.unlocked_tier, 1)
	assert_eq(run.cast("day_twice", run.home), [], "a Tier-VI act cannot be cast at Tier I")
	run.shutdown()


func test_seasons_turn_and_research_rolls():
	var run := _fresh()
	var turned := 0
	for day in TimeService.DAYS_PER_SEASON * 2:
		if run.advance_day()["season_changed"]:
			turned += 1
	assert_gt(turned, 0, "the season latch fires through the shell")
	run.shutdown()


func test_save_resume_continues_the_exact_run():
	var run := _fresh(1702)
	for day in 20:
		run.advance_day()
	run.cast("still_air", run.home)
	for day in 10:
		run.advance_day()
	var envelope := run.save()
	var control_days := 10
	for day in control_days:
		run.advance_day()
	var uninterrupted := run.save()
	run.shutdown()
	var resumed := GameRun.resume(envelope)
	for day in control_days:
		resumed.advance_day()
	var continued := resumed.save()
	resumed.shutdown()
	assert_eq(
		JSON.stringify(continued),
		JSON.stringify(uninterrupted),
		"a loaded run continues the uninterrupted sequence exactly [T12.2 through the shell]"
	)


func test_two_identical_scripted_runs_are_byte_identical():
	var envelopes := []
	for attempt in 2:
		var run := _fresh(1703)
		for day in 15:
			run.advance_day()
			if run.runner.time.day() == 7:
				run.cast("still_air", run.home)
		envelopes.append(JSON.stringify(run.save()))
		run.shutdown()
	assert_eq(envelopes[0], envelopes[1], "seed+config+acts reproduce the run [CLAUDE.md]")


func test_the_envelope_carries_the_shell_state():
	var run := _fresh()
	run.advance_day()
	var envelope := run.save()
	assert_true(envelope.has("region_graph"), "the world's shape saves [T13.1 deferred key]")
	assert_eq(envelope["home"], run.home)
	assert_true(envelope.has("telemetry"), "run history survives a load [chronicle input]")
	assert_true(envelope.has("exposure"), "the magic-exposure glue survives a load")
	run.shutdown()
	# Peak fidelity across a load [T17.2 reviewer catch]: restored
	# telemetry keeps the HISTORICAL peak, not just the loaded pop.
	var saved_peak: int = envelope["telemetry"]["peak_pop"]
	var resumed := GameRun.resume(envelope)
	assert_eq(
		resumed.telemetry.summary(resumed.runner.colony)["peak_pop"],
		saved_peak,
		"summary() reads the true peak after a load"
	)
	resumed.shutdown()


func test_extinction_latches_the_worlds_end():
	var run := _fresh()
	watch_signals(EventBus)
	for g in run.runner.colony.living():
		g.stage = Enums.LifeStage.DEAD
	run.advance_day()
	assert_true(run.runner.colony.world_over, "the latch closes on total extinction [§14]")
	assert_signal_emitted(EventBus, "world_ended")
	run.shutdown()
