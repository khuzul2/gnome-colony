extends GutTest

## T16.2 — tuning invariants [algo §16, "stability invariants to
## preserve while tuning"]: (a) the early game is RECOVERABLE — a small
## colony climbs out of one bad season; (b) no loop runs away unbounded
## within a session — population, unrest, per-capita devotion, social-
## mass magnitude, and food all stay in their bands the whole run;
## (c) extinction is rare enough to hurt, common enough to matter — the
## spec names no frequency, so the band [1,9]/10 under a calibrated
## harsh regime is INTERPRETIVE (documented; probe notes in-line).


func test_one_bad_season_is_survivable():
	Rng.seed_with(16201)
	var cfg := WorldConfig.new()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	runner.run_days(2 * TimeService.DAYS_PER_YEAR)
	var before: int = runner.colony.population()
	assert_gt(before, 0, "two good years first")
	# One bad season [§16a]: a drought — the larder empties and regrowth
	# falls to a fifth. (Severity is INTERPRETIVE: the spec sizes no
	# "bad season"; total zero-food for 24 days proved to be a cataclysm
	# that leaves one survivor, which is §16c's territory, not §16a's.)
	var regrowth := food.regrowth
	food.regrowth = regrowth * 0.2
	food.current = 0.0
	for day in TimeService.DAYS_PER_SEASON:
		runner.tick()
	food.regrowth = regrowth
	runner.run_days(4 * TimeService.DAYS_PER_YEAR)
	runner.shutdown()
	var after: int = runner.colony.population()
	gut.p("bad season: pop %d → famine → %d four years on" % [before, after])
	assert_gt(after, 0, "the colony climbs out of one bad season [§16]")
	assert_gte(after, before / 2, "…genuinely recovering, not merely lingering")


func test_no_loop_runs_away_within_a_session():
	Rng.seed_with(16202)
	var cfg := WorldConfig.new()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var last_season := runner.time.season()
	for day in 20 * TimeService.DAYS_PER_YEAR:
		runner.tick()
		Belief.propagate_tick(runner.colony, 1.0)
		Belief.decay_tick(runner.colony, 1.0)
		Belief.crystallize_tick(runner.colony, 1.0)
		Devotion.update_unlocks(runner.colony)
		Devotion.unrest_tick(runner.colony, 1.0)
		if runner.time.season() != last_season:
			last_season = runner.time.season()
			var pop := runner.colony.population()
			assert_lt(pop, 240, "population bounded by K [§16b] (day %d)" % day)
			assert_between(runner.colony.unrest, 0.0, 1.0, "unrest stays a fraction [§10]")
			assert_lte(
				Devotion.per_capita(runner.colony), 1.0, "per-capita devotion is a [0,1] mean [§10]"
			)
			assert_lt(
				Devotion.magnitude_multiplier(runner.colony),
				10.0,
				"log-scaled social mass never explodes [§10/§16b]"
			)
			assert_lte(
				food.current, food.capacity + 0.001, "the larder respects its capacity [§15]"
			)
	runner.shutdown()
	assert_gt(runner.colony.population(), 0, "…and the session ends with a living colony")


func test_extinction_sits_in_the_hurting_band():
	# Calibration (probe, this container, 2026-07-03): cap 15 / regrowth
	# 2.0 over 100 years → 3/10 extinct across seeds 16200-16209;
	# abundance (regrowth ≥ 2.5) gave 0/10, famine (≤ 1.0) gave 9-10/10.
	# The [1,9] band is the INTERPRETIVE reading of §16's "rare enough
	# to hurt, common enough to matter" — deterministic under these seeds.
	var extinct := 0
	var pops := []
	for i in 10:
		Rng.seed_with(16200 + i)
		var cfg := WorldConfig.new()
		var food := ResourceNode.new("food", 15.0, 15.0, 2.0, 1.0)
		var runner := SimRunner.new(cfg, food, 15.0)
		runner.run_days(100 * TimeService.DAYS_PER_YEAR)
		pops.append(runner.colony.population())
		if runner.colony.population() == 0:
			extinct += 1
		runner.shutdown()
	gut.p("harsh century: %d/10 extinct, survivors %s" % [extinct, pops])
	assert_gte(extinct, 1, "extinction is common enough to matter [§16c]")
	assert_lte(extinct, 9, "…and rare enough that a colony can still make it")
