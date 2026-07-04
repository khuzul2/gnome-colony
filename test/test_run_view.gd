extends GutTest

## T17.4 — RunView [PROGRESS Phase 17]: the in-run binding — WorldView
## skins the graph, puppets mirror gnomes under the render crowd cap,
## the camera's dwell feeds the Eye into Lod, the InfluencePanel's
## paint routes into GameRun.cast with the aftermath page open, speed
## buttons pace the days, and §7.4 autosave cadence emits save
## requests. Presentation reads the sim and feeds only legitimate
## inputs (acts, attention).

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _view(seed_value: int = 1741, mutate: Callable = Callable()) -> RunView:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	if mutate.is_valid():
		mutate.call(view)
	add_child_autofree(view)
	return view


func test_binds_the_generated_world():
	var view := _view()
	assert_eq(view.world_view.baked_version, view.run.graph.version, "the skin baked the graph")
	assert_true(view.place_positions.has(view.run.home), "every basin has a stage position")
	assert_eq(view.influence_panel.buttons.size(), Catalog.defs().size(), "all 15 acts built")
	assert_eq(view.puppet_count(), 4, "one puppet per founder under the default cap")


func test_the_render_crowd_cap_is_presentation_only():
	var view := _view(
		1742, func(v: RunView) -> void: v.settings.set_value("graphics", "render_crowd_density", 2)
	)
	assert_eq(view.puppet_count(), 2, "only the cap is drawn [setup §7.1]")
	assert_eq(view.run.runner.colony.population(), 4, "…while everyone still exists in the sim")


func test_speed_paces_the_days():
	var view := _view()
	view.set_speed(1.0)
	view._process(3.0)
	assert_eq(view.run.runner.time.day(), 3, "one day per accumulated second at 1 d/s [slice]")
	view.set_speed(0.0)
	view._process(5.0)
	assert_eq(view.run.runner.time.day(), 3, "pause stops the world")


func test_painting_the_armed_act_casts_it():
	var view := _view()
	view.set_speed(0.0)
	assert_true(view.influence_panel.arm("still_air"))
	view.select_place(view.run.home)
	assert_gt(Devotion.total(view.run.runner.colony), 0.0, "the paint became a witnessed cast")
	assert_gt(view.aftermath.timeline.size(), 0, "the aftermath page opened on the act")
	assert_eq(view.influence_panel.armed(), "", "the act disarmed after landing [T14.1]")


func test_an_unarmed_click_is_inert():
	var view := _view()
	view.select_place(view.run.home)
	assert_eq(Devotion.total(view.run.runner.colony), 0.0, "no armed act, no cast")


func test_dwell_feeds_the_eye_into_lod():
	var view := _view()
	view.set_speed(0.0)
	view.camera.focus(view.place_positions[view.run.home])
	for i in 25:
		view._process(0.1)
	assert_has(view.run.attention_places, view.run.home, "2 s of dwell promotes [§17 via T13.5]")


func test_civilization_zoom_never_gazes():
	var view := _view()
	view.set_speed(0.0)
	view.camera.focus(view.place_positions[view.run.home])
	view.camera.zoom_out()
	assert_eq(view.camera.level, CameraRig.Zoom.CIVILIZATION)
	for i in 25:
		view._process(0.1)
	assert_eq(view.run.attention_places, [], "the wide view is absence [T13.5]")


func test_season_autosave_cadence_emits():
	var view := _view()
	watch_signals(view)
	view.set_speed(30.0)
	view._process(1.0)
	assert_gte(view.run.runner.time.day(), TimeService.DAYS_PER_SEASON, "a season passed")
	assert_signal_emitted_with_parameters(view, "save_requested", ["auto"])


func test_autosave_off_stays_silent():
	var view := _view(
		1743, func(v: RunView) -> void: v.settings.set_value("gameplay", "autosave", "off")
	)
	watch_signals(view)
	view.set_speed(30.0)
	view._process(1.0)
	assert_signal_not_emitted(view, "save_requested")


func test_hud_buttons_request_save_and_menu():
	var view := _view()
	watch_signals(view)
	view.hud.get_node("controls/save").pressed.emit()
	assert_signal_emitted_with_parameters(view, "save_requested", ["manual"])
	view.hud.get_node("controls/menu").pressed.emit()
	assert_signal_emitted(view, "menu_requested")
