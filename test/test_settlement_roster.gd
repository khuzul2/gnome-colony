extends GutTest

## R6.2 [leg §L-hud] — the settlement roster: the player must see how many
## colonies exist, where, and which is the seat. The panel renders pre-built row
## models; RunView assembles them from the home colony (individual grain, absent
## from run.settlements) plus the frontier fold, so nothing is omitted.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _roster() -> SettlementRoster:
	var r := SettlementRoster.new()
	add_child_autofree(r)
	return r


func _model(sid: int, tier: String, pop: int, seat: bool) -> Dictionary:
	return {"sid": sid, "name": "Basin %d" % sid, "tier": tier, "pop": pop, "seat": seat}


func _view(seed_value := 1791) -> RunView:
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


# --- the panel (model-driven) -----------------------------------------------


func test_renders_a_row_per_model():
	var r := _roster()
	r.refresh([_model(0, "city", 250, true), _model(1, "village", 20, false)])
	assert_eq(r.entries.size(), 2, "a row per model")
	assert_eq(r.overflow, 0, "nothing hidden")
	assert_eq(r.entries[0]["tier"], "city", "the model is rendered verbatim")


func test_caps_at_max_rows_with_overflow():
	var r := _roster()
	var rows := []
	for i in 11:
		rows.append(_model(i, "hamlet", 5, false))
	r.refresh(rows)
	assert_eq(r.entries.size(), SettlementRoster.MAX_ROWS, "capped at MAX_ROWS")
	assert_eq(r.overflow, 11 - SettlementRoster.MAX_ROWS, "the rest fold into +N more")


func test_a_row_click_asks_to_focus_that_settlement():
	var r := _roster()
	r.refresh([_model(0, "city", 100, true), _model(2, "hamlet", 5, false)])
	var got := [-1]
	r.focus_settlement.connect(func(sid: int) -> void: got[0] = sid)
	(r._rows.get_child(1) as Button).pressed.emit()  # the second row = sid 2
	assert_eq(got[0], 2, "clicking a row focuses THAT settlement")


# --- RunView assembles the models -------------------------------------------


func test_the_roster_leads_with_home_and_shows_it():
	var view := _view()
	var rows := view._roster_rows()
	assert_eq(rows[0]["sid"], GameRun.HOME_SID, "home leads the roster")
	assert_eq(rows[0]["pop"], view.run.runner.colony.population(), "home pop read verbatim")
	assert_true(rows[0]["seat"], "home is the seat when none is elected yet")
	assert_gt(view.settlement_roster.entries.size(), 0, "the mounted panel shows at least home")


func test_a_roster_row_click_moves_the_camera_to_that_basin():
	var view := _view()
	view.camera.focus(Vector3(99.0, 0.0, 99.0))  # park the camera away
	view._on_focus_settlement(GameRun.HOME_SID)
	var home_pos: Vector3 = view.place_positions[view.run.home]
	assert_almost_eq(
		Vector2(view.camera.position.x, view.camera.position.z),
		Vector2(home_pos.x, home_pos.z),
		Vector2(0.001, 0.001),
		"the camera pans to the clicked basin"
	)
