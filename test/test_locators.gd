extends GutTest

## R6.3 [leg §L-hud] — on-world locators + life pulse: a floating name-plate over
## each colony's basin so settlements are findable on the map, and a births/deaths
## pulse so the player can tell the colony is alive and growing (or dying).

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _view(seed_value := 1801) -> RunView:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	add_child_autofree(view)
	return view


func test_a_locator_floats_over_each_colony():
	var view := _view()
	var rows := view._roster_rows()
	assert_gt(view._locators.size(), 0, "at least the home locator exists")
	for model in rows:
		var sid: int = model["sid"]
		assert_true(view._locators.has(sid), "a locator per colony")
		var label: Label3D = view._locators[sid]
		var place: String = view.sid_places.get(sid, view.run.home)
		var basin: Vector3 = view.place_positions[place]
		assert_almost_eq(label.position.x, basin.x, 0.001, "the plate sits over the basin (x)")
		assert_almost_eq(label.position.z, basin.z, 0.001, "the plate sits over the basin (z)")
		assert_gt(label.position.y, basin.y, "…and floats above it")
		assert_true(str(model["name"]) in label.text, "the plate names the settlement")


func test_the_life_pulse_counts_births_and_deaths():
	# Drive the handlers directly — a bare emit on the global EventBus would also
	# hit the live SimRunner, which expects a real payload. The wiring is asserted
	# separately below.
	var view := _view()
	assert_true(EventBus.born.is_connected(view._on_born), "the pulse listens for births")
	assert_true(EventBus.gnome_died.is_connected(view._on_died), "…and for deaths")
	assert_eq(view._season_births, 0, "the pulse starts empty")
	view._on_born({})
	view._on_born({})
	view._on_died({})
	assert_eq(view._season_births, 2, "births are counted")
	assert_eq(view._season_deaths, 1, "deaths are counted")
	view._refresh_hud()
	assert_true("+2 born" in view._hud_label.text, "the pulse reads in the HUD")
	assert_true("−1 died" in view._hud_label.text, "…both halves")


func test_the_pulse_resets_when_the_season_turns():
	var view := _view()
	view._on_born({})
	assert_eq(view._season_births, 1, "a birth is counted")
	view._pulse_season = -99  # pretend the last refresh was a different season
	view._refresh_hud()
	assert_eq(view._season_births, 0, "the turn of the season resets the pulse")
	assert_eq(view._pulse_season, view.run.runner.time.season(), "…and re-anchors to now")


func test_a_birth_on_the_season_turn_opens_the_new_season_not_lost():
	# Regression [R6.3 review]: an event on the very tick the season turns must open
	# the NEW season's tally, not be added to the old count and then wiped to 0.
	var view := _view()
	view._on_born({})
	view._on_born({})
	assert_eq(view._season_births, 2, "two births in the current season")
	# the season has turned since the last roll (pulse is now stale) and a birth
	# fires on that crossing tick — it must count as the first of the new season.
	view._pulse_season = view.run.runner.time.season() + 1
	view._on_born({})
	assert_eq(
		view._season_births, 1, "the crossing birth opens the new season (not lost, not +old)"
	)
	assert_eq(view._pulse_season, view.run.runner.time.season(), "…and the pulse re-anchored")
