extends GutTest

## T5.6 / Phase-Exit 5 — MILESTONE 1 [plan Phase 5, prototype spec]:
## a 4-gnome colony under DEFAULT WorldConfig survives ≥5 generations
## across 20 seeded runs without dying out >40% of the time, with a
## readable generational text log. No scripting: needs+utility drive
## everything. World scaffold (food node, K) is test wiring, not spec.

const RUNS := 20
const MAX_YEARS := 150
const TARGET_GENERATION := 5
const MAX_FAILURES := 8  # 40% of 20


func test_milestone_one_survival_bar():
	var failures := 0
	var sample_log: Array = []
	for i in RUNS:
		Rng.seed_with(5600 + i)
		var cfg := WorldConfig.new()
		var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
		var runner := SimRunner.new(cfg, food, 60.0)
		runner.run_days(MAX_YEARS * TimeService.DAYS_PER_YEAR, TARGET_GENERATION)
		runner.shutdown()
		var reached: int = runner.max_generation
		var pop: int = runner.colony.population()
		gut.p("run %02d: gen %d · pop %d · year %d" % [i, reached, pop, runner.time.year()])
		if reached < TARGET_GENERATION or pop == 0:
			failures += 1
		if sample_log.is_empty() and reached >= TARGET_GENERATION:
			sample_log = runner.chronicle
	assert_lte(failures, MAX_FAILURES, "≤40%% of colonies may fail (got %d/20)" % failures)

	# The generational log must read like a story, not a metric dump.
	assert_false(sample_log.is_empty(), "at least one successful run logged its history")
	var has_birth := false
	var has_death := false
	for line in sample_log:
		if "born" in line:
			has_birth = true
		if "died" in line:
			has_death = true
	assert_true(has_birth and has_death, "the chronicle records births and deaths")
	for line in sample_log.slice(0, 10):
		gut.p(line)
