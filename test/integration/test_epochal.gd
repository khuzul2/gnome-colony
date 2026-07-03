extends GutTest

## T16.1 — epochal smoke run [plan Phase 16]: fast-forward a DEFAULT
## game across many generations with the full stack composed the way
## the shell runs it (life core + belief/devotion/prophets/magic daily,
## research seasonally). Assert: no crash, population bounded, tech
## advances, generations turn. Bounds are structural tripwires
## (documented), not spec numbers — §16's invariant is "no loop runs
## away unbounded in a normal session".

const YEARS := 60
## Structural runaway tripwire: the food node's carrying capacity is 60;
## crowding + K should hold the colony well under 4× that. Not a §17
## number — a smoke-test ceiling.
const POP_CEILING := 240


func test_an_epoch_passes_without_the_world_breaking():
	Rng.seed_with(16100)
	var cfg := WorldConfig.new()
	cfg.seed = 16100
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var peak_pop := 0
	var last_season := runner.time.season()
	var discovered := []
	for day in YEARS * TimeService.DAYS_PER_YEAR:
		Lod.assign(runner.colony, [], cfg.quicken_budget)
		runner.tick()
		Belief.propagate_tick(runner.colony, 1.0)
		Belief.decay_tick(runner.colony, 1.0)
		Belief.crystallize_tick(runner.colony, 1.0)
		Devotion.update_unlocks(runner.colony)
		Devotion.unrest_tick(runner.colony, 1.0)
		Prophet.tick(runner.colony, 1.0)
		if runner.time.season() != last_season:
			last_season = runner.time.season()
			var known: Array = runner.colony.settlement_knowledge.get(0, {}).keys()
			var needs := {}
			for id in TechGraph.candidates(known):
				needs[id] = 1.0
			var pop := maxf(1.0, runner.colony.population())
			var surplus: float = clampf(food.current / pop, 0.0, 1.0)
			discovered.append_array(Research.season_tick(runner.colony, 0, needs, surplus))
		peak_pop = maxi(peak_pop, runner.colony.population())
		if runner.colony.population() == 0:
			break
	runner.shutdown()
	(
		gut
		. p(
			(
				"epoch: %d years · peak pop %d · final pop %d · gen %d · %d techs %s"
				% [
					runner.time.year(),
					peak_pop,
					runner.colony.population(),
					runner.max_generation,
					discovered.size(),
					discovered,
				]
			)
		)
	)
	assert_gt(runner.colony.population(), 0, "the default game survives the epoch [§16]")
	assert_lt(peak_pop, POP_CEILING, "population never runs away unbounded [§16]")
	assert_gte(runner.max_generation, 3, "generations genuinely turned")
	assert_gt(discovered.size(), 0, "the tech arc moved [T16.1: tech advances]")
