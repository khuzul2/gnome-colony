extends GutTest

## T11.5 / Phase-Exit 11 [plan]: a 10,000-population world advances a
## year within the ⚙️ perf budget, and the settlement-aggregate flows
## match an individually-simulated control within tolerance.
## Budget status — HUMAN RULING 2026-07-03 ("option 1"): the plan's
## marks (≤ 10 ms @ 5k / ≤ 16 ms @ 20k; 12 ms interpolated @ 10k) bind
## on their own stated reference — a MID-TIER DESKTOP. This container is
## a shared 2.10 GHz Xeon (~half reference single-thread) and the §2.2
## port hatch is offline-blocked, so HERE the 24 ms regression tripwire
## governs (the pre-optimization 40 ms code fails it; achieved: 40 →
## ~16.4 ms, behavior-preserving), and the STRICT 12 ms bound is
## re-verified on real hardware at T16's final pass (PROGRESS.md Notes
## carries the reminder). Raw numbers print every run. Wall-clock is
## measured HERE in test code (Time is banned in sim logic only).
## Save/load and RAM budget legs belong to T12.1 and T16.

const WORLD_POP := 10_000
const SETTLEMENT_COUNT := 20
const QUICKENED := 300
const DAYS := TimeService.DAYS_PER_YEAR
const TICK_BUDGET_MS := 12.0
const REGRESSION_TRIPWIRE_MS := 24.0


func test_ten_thousand_souls_advance_a_year_in_budget():
	Rng.seed_with(11500)
	var cfg := WorldConfig.new()
	cfg.band_size = 8
	var food := ResourceNode.new("food", 2000.0, 2000.0, 200.0, 1.0)
	var runner := SimRunner.new(cfg, food, 600.0)
	# 20 aggregate basins carry the world's weight…
	var settlements := []
	var per_settlement := float(WORLD_POP) / SETTLEMENT_COUNT
	for i in SETTLEMENT_COUNT:
		var s := Settlement.new(i, 300.0, 2.0)
		s.by_stage[Enums.LifeStage.ADULT] = per_settlement * 0.5
		s.by_stage[Enums.LifeStage.CHILD] = per_settlement * 0.25
		s.by_stage[Enums.LifeStage.INFANT] = per_settlement * 0.15
		s.by_stage[Enums.LifeStage.ELDER] = per_settlement * 0.1
		settlements.append(s)
	# …while the quicken budget's worth of individuals live under the Eye.
	Promotion.materialize(runner.colony, settlements[0], QUICKENED - runner.colony.population())
	assert_eq(runner.colony.population(), QUICKENED)
	Lod.assign(runner.colony, [], cfg.quicken_budget)

	var world_pop_before := _world_pop(runner.colony, settlements)
	var last_season := -1
	var start := Time.get_ticks_usec()
	for day in DAYS:
		runner.tick()
		if runner.time.season() != last_season:
			last_season = runner.time.season()
			for s in settlements:
				SettlementSim.season_tick(runner.colony, s, 1.0)
			Civilization.trade_route(runner.colony, settlements[0], settlements[1])
	var elapsed_ms := (Time.get_ticks_usec() - start) / 1000.0
	runner.shutdown()

	var avg_tick := elapsed_ms / DAYS
	(
		gut
		. p(
			(
				"10k world · year in %.0f ms · avg tick %.2f ms (strict budget %.0f ms · tripwire %.0f ms)"
				% [elapsed_ms, avg_tick, TICK_BUDGET_MS, REGRESSION_TRIPWIRE_MS]
			)
		)
	)
	assert_lt(
		avg_tick,
		REGRESSION_TRIPWIRE_MS,
		"governing bound on this container (human ruling; strict 12 ms re-verified at T16)"
	)

	var world_pop_after := _world_pop(runner.colony, settlements)
	assert_gt(world_pop_after, world_pop_before * 0.8, "no aggregate population crash")
	assert_lt(world_pop_after, world_pop_before * 1.3, "no runaway boom")
	assert_false(Civilization.check_world_end(runner.colony, settlements))


func test_aggregate_matches_individual_control_within_tolerance():
	# The formal consistency leg: the same founding band simulated
	# individually and as flows for three years. Tolerance ±50% or ±4
	# heads, whichever is looser (documented — the tiers legitimately
	# diverge: partnership lag, integer vs fractional births).
	Rng.seed_with(11501)
	var cfg := WorldConfig.new()
	cfg.band_size = 8
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var aggregate := Settlement.from_colony(runner.colony, 0, 30.0, 2.0)
	var mirror := Colony.new()
	for season in 12:
		runner.run_days(TimeService.DAYS_PER_SEASON)
		SettlementSim.season_tick(mirror, aggregate, 1.0)
	runner.shutdown()
	var individual := float(runner.colony.population())
	var flows := aggregate.pop()
	gut.p("3-year control: individual %.0f vs flows %.1f" % [individual, flows])
	assert_almost_eq(flows, individual, maxf(4.0, 0.5 * individual), "tiers agree within tolerance")


func _world_pop(colony: Colony, settlements: Array) -> float:
	var total := float(colony.population())
	for s in settlements:
		total += s.pop()
	return total
