extends GutTest

## Phase-Exit 16 [plan]: a long seeded run from 4 gnomes reaches a
## MULTI-SETTLEMENT civilization without crash or unbounded runaway.
## The arc crosses every tier the way the real game does: individuals
## live an epoch at the quickened grain, the grown colony folds into
## the statistical substrate (§14), and the civilization tier carries
## it outward — migration seeds a second basin and both live on. (The
## invariant tests themselves are test_invariants.gd /
## test_diversity_balance.gd, green in this same suite.)


func test_four_gnomes_become_a_civilization():
	Rng.seed_with(16600)
	var cfg := WorldConfig.new()
	cfg.seed = 16600
	# The individual epoch: 40 years from 4 founders.
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var peak := 0
	for day in 40 * TimeService.DAYS_PER_YEAR:
		runner.tick()
		peak = maxi(peak, runner.colony.population())
	assert_gt(runner.colony.population(), 10, "the band became a town")
	assert_lt(peak, 240, "…without runaway [§16]")
	assert_gte(runner.max_generation, 2, "…across generations")
	# The fold [§14]: the town becomes the statistical substrate.
	var home := Settlement.from_colony(runner.colony, 0, 200.0, 2.0)
	assert_almost_eq(
		home.pop(), float(runner.colony.population()), 0.5, "the fold conserves heads [§14]"
	)
	# The civilization tier: seasons of aggregate life, then migration
	# seeds a second basin — multi-settlement.
	var frontier := Settlement.new(1, 200.0, 2.0)
	var settlements := {0: home, 1: frontier}
	for season in 20:
		SettlementSim.season_tick(runner.colony, home, 1.0)
		if frontier.pop() > 0.0:
			SettlementSim.season_tick(runner.colony, frontier, 1.0)
		Civilization.migrate(runner.colony, home, frontier, home.adults() * 0.05)
	var populated := 0
	for sid in settlements:
		if settlements[sid].pop() >= 1.0:
			populated += 1
	gut.p(
		(
			"civilization: home %.1f + frontier %.1f souls, peak %d, gen %d"
			% [home.pop(), frontier.pop(), peak, runner.max_generation]
		)
	)
	assert_eq(populated, 2, "TWO living settlements — a civilization, not a village [exit]")
	assert_false(
		Civilization.check_world_end(runner.colony, settlements.values()), "the world lives on"
	)
	runner.shutdown()
