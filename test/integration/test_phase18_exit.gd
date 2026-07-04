extends GutTest

## Phase-Exit 18 [PROGRESS Phase 18]: the closed gaps, composed — a
## drained larder tags drought and the drought-gated act really lands;
## crowding opens the frontier and the founding enters history; the
## wizard chrome reaches the config. (Frontier succession/world-end
## legs live in test_frontier.gd; chrome unit suites cover the rest.)


func test_the_world_answers_a_wrathful_god():
	Rng.seed_with(1899)
	var cfg := WorldConfig.new()
	cfg.seed = 1899
	cfg.colony_name = "Exit18"
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	run.food.current = 10.0
	run.advance_day()
	assert_has(run.world.affordances[run.home], "drought", "the low larder is lived terrain")
	var stimuli := run.cast("weeping_sky", run.home)
	assert_gt(stimuli.size(), 0, "the drought-gated mercy lands at last [T18.1, §18]")
	while (run.runner.time.day() + 1) % TimeService.DAYS_PER_SEASON != 0:
		run.advance_day()
	for i in 56:
		var g := run.runner.colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = run.home
	run.advance_day()
	run.advance_day()
	assert_gt(run.settlements.size(), 0, "pressure opened the frontier [T18.2, §14]")
	var screen := ChronicleScreen.new()
	add_child_autofree(screen)
	var record := screen.compose(run.runner.colony, run.telemetry.events, {})
	assert_gt(record["settlements"], 0, "the founding is history [§1.9]")
	run.shutdown()


func test_the_chrome_reaches_the_config():
	Rng.seed_with(1898)
	var view := WizardView.new()
	view.wizard = NewGameWizard.new()
	add_child_autofree(view)
	var spin: SpinBox = view.get_node("column/page_2/band_size")
	spin.value = 6
	assert_eq(view.wizard.start().band_size, 6, "a widget writes the world [T18.3]")
