extends GutTest

## T17.4 — RunView [PROGRESS Phase 17]: the in-run binding — WorldView
## skins the graph, puppets mirror gnomes under the render crowd cap,
## the camera's dwell feeds the Eye into Lod, the InfluencePanel's
## paint routes into GameRun.cast with the aftermath page open, speed
## buttons pace the days, and §7.4 autosave cadence emits save
## requests. Presentation reads the sim and feeds only legitimate
## inputs (acts, attention). [T22.4] the readout also carries the
## frontier count/souls/main seat, the Eye's quickened knot, and a
## fracture-risk warning (presentation thresholds 0.6/0.75 against
## Devotion.FRACTURE_LINE). [T22.6] a paint at a frontier place casts
## THERE — the root stimulus names that place.

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


func _key(name: String, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = OS.find_keycode_from_string(name)
	event.pressed = pressed
	return event


func test_the_world_is_lit_and_the_camera_renders():
	# [T23.1] Without these the 3D viewport is a black void behind the HUD.
	# [R1.2] The lights/camera now live inside the pixel stage's SubViewport.
	var view := _view()
	assert_true(view.camera.camera.current, "the rig camera renders the viewport")
	assert_eq(view.camera.camera.get_viewport(), view.stage_world, "…which is the pixel stage")
	assert_not_null(view.stage_world.get_node("sun"), "a directional sun lights the world")
	var env := view.stage_world.get_node("environment") as WorldEnvironment
	assert_not_null(env, "a WorldEnvironment supplies ambient + sky")
	assert_not_null(env.environment, "…with a real Environment resource")


func test_bindings_drive_the_camera():
	# [T23.2] WASD from Settings pans the rig; E/Q and the wheel zoom it.
	var view := _view()
	view.set_speed(0.0)
	var before := view.camera.position
	view._unhandled_input(_key("W", true))
	view._process(0.1)
	assert_lt(view.camera.position.z, before.z, "W pans north (−Z)")
	var held := view.camera.position
	view._unhandled_input(_key("W", false))
	view._process(0.1)
	assert_eq(view.camera.position, held, "releasing the key stops the pan")
	assert_eq(view.camera.level, CameraRig.Zoom.SETTLEMENT)
	view._unhandled_input(_key("E", true))
	assert_eq(view.camera.level, CameraRig.Zoom.INDIVIDUAL, "E zooms in")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	view._unhandled_input(wheel)
	assert_eq(view.camera.level, CameraRig.Zoom.SETTLEMENT, "wheel down zooms out")
	# [T23 review] the rig rides the ground height as it pans…
	assert_almost_eq(
		view.camera.position.y,
		view.world_view.height_at(Vector2(view.camera.position.x, view.camera.position.z)),
		0.001,
		"the camera keeps its clearance over uneven terrain"
	)
	# …and a diagonal pan is normalized, not ~1.41× faster.
	view._unhandled_input(_key("A", true))
	view._unhandled_input(_key("W", true))
	var flat := Vector2(view.camera.position.x, view.camera.position.z)
	view._process(0.1)
	var moved := Vector2(view.camera.position.x, view.camera.position.z).distance_to(flat)
	assert_almost_eq(moved, RunView.PAN_SPEED * 0.1, 0.01, "diagonal pan speed matches one axis")


func test_a_click_targets_the_basin_under_the_cursor():
	# [T23.3] THE core verb: arm an act, click the world, it casts there.
	# [R5.2, leg §L-ui] and picking reads the PRE-snap aim under the pixel-snapped
	# presented camera: with the rig deliberately parked off the pixel grid (so the
	# snap correction is ~half a cell, not zero), _ground_point must equal the
	# UNSNAPPED hit and differ from the naive post-snap hit by exactly the offset —
	# a load-bearing guard (reverting the fix makes _ground_point return `post`).
	var view := _view()
	view.set_speed(0.0)
	assert_true(view.camera.snap_enabled, "the presented camera is pixel-snapped")
	var home: String = view.run.home
	var home_pos: Vector3 = view.place_positions[home]
	var g: float = CameraRig.PIXEL_GRID_KM[view.camera.level]
	var aim := home_pos
	aim.x = (floorf(aim.x / g) + 0.5) * g  # halfway between grid lines
	view.camera.focus(aim)
	var cam := view.camera.camera
	var snap_off := Vector3(cam.position.x, 0.0, cam.position.z)
	assert_gt(snap_off.length(), g * 0.2, "the presented camera is really displaced off-grid")
	var screen := cam.unproject_position(home_pos)
	var vp := view.stage.to_viewport(screen)
	var normal := cam.project_ray_normal(vp)
	var plane := Plane(Vector3.UP, view._pick_plane_y)
	var pre: Vector3 = plane.intersects_ray(cam.project_ray_origin(vp) - snap_off, normal)
	var post: Vector3 = plane.intersects_ray(cam.project_ray_origin(vp), normal)
	assert_almost_eq(
		pre.distance_to(post), snap_off.length(), 1e-4, "snap shifts the naive pick by the offset"
	)
	assert_almost_eq(
		(view._ground_point(screen) as Vector3).distance_to(pre),
		0.0,
		1e-4,
		"picking reads the pre-snap aim, not the quantized one"
	)
	# …and the core verb still lands the cast at that basin.
	assert_eq(Devotion.total(view.run.runner.colony), 0.0)
	assert_true(view.influence_panel.arm("still_air"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = cam.unproject_position(home_pos)
	view._unhandled_input(click)
	assert_gt(
		Devotion.total(view.run.runner.colony),
		0.0,
		"arm + click open ground = a witnessed cast at that basin"
	)
	assert_gt(view.aftermath.timeline.size(), 0, "the aftermath page opened on the act")


func test_the_pick_resolves_the_nearest_gnome():
	# [T23.3] The individual-kind routing (no stock catalog act targets a
	# gnome — same disclosure as T14.1 — but the resolver is exercised).
	var view := _view()
	var target: GnomePuppet = view._puppets[view._puppets.keys()[0]]
	var found := view._nearest_gnome(target.position)
	assert_eq(found, target.data, "the closest puppet's gnome is picked")


func test_hover_highlights_the_pick_while_armed():
	# [T23.4] Learnability: the ring marks where the armed act would land.
	var view := _view()
	view.influence_panel.arm("still_air")
	var home_pos: Vector3 = view.place_positions[view.run.home]
	var motion := InputEventMouseMotion.new()
	motion.position = view.camera.camera.unproject_position(home_pos)
	view._unhandled_input(motion)
	assert_eq(view.hovered_place, view.run.home, "hover marks the basin under the cursor")
	assert_true(view._highlight.visible, "the ring shows")
	view.influence_panel.disarm()
	view._unhandled_input(motion)
	assert_eq(view.hovered_place, "", "disarming clears the hover")
	assert_false(view._highlight.visible, "…and hides the ring")


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


## The first non-home region — a stand-in frontier basin for HUD tests.
func _frontier_region(view: RunView) -> Dictionary:
	for region in view.run.graph.regions:
		if region["id"] != GameRun.HOME_SID:
			return region
	return {}


func test_hud_names_the_frontier_and_its_main_seat():
	var view := _view()
	var region := _frontier_region(view)
	var sid: int = region["id"]
	var s := Settlement.new(sid, 200.0, 2.0)
	s.by_stage[Enums.LifeStage.ADULT] = 12.0
	view.run.settlements[sid] = s
	view.run.runner.colony.main_settlement = sid
	view._refresh_hud()
	var text: String = view._hud_label.text
	assert_string_contains(
		text, "frontier: 1 settlement", "the readout counts the frontier [T22.4]"
	)
	assert_string_contains(text, "12 souls", "…with its aggregate souls")
	assert_string_contains(
		text, "seat %s" % WorldBootstrap.place_id(region), "…naming the main seat's place"
	)


func test_hud_reports_the_eyes_quickened_souls():
	var view := _view()
	var region := _frontier_region(view)
	var living: Array = view.run.runner.colony.living()
	view.run.quickened[region["id"]] = [living[0], living[1]]
	view._refresh_hud()
	assert_string_contains(
		view._hud_label.text,
		"the Eye holds 2 souls at %s" % WorldBootstrap.place_id(region),
		"the quickened knot is reported [T22.4]"
	)


func test_hud_warns_as_unrest_nears_the_fracture_line():
	var view := _view()
	var colony := view.run.runner.colony
	colony.unrest = 0.2
	view._refresh_hud()
	assert_false("fracture line" in view._hud_label.text, "calm unrest carries no warning")
	colony.unrest = 0.7
	view._refresh_hud()
	assert_string_contains(
		view._hud_label.text,
		"fracture line (%.1f)" % Devotion.FRACTURE_LINE,
		"0.7 warns [T22.4 presentation thresholds 0.6/0.75]"
	)
	assert_false("looms" in view._hud_label.text, "…in the milder register below 0.75")
	colony.unrest = 0.77
	view._refresh_hud()
	assert_string_contains(view._hud_label.text, "looms", "≥ 0.75 sharpens the wording")


## T22.6 — targeting truth: a paint at a FRONTIER place casts THERE.
func test_a_cast_lands_at_the_selected_frontier_place():
	var view := _view()
	view.set_speed(0.0)
	var region := _frontier_region(view)
	var sid: int = region["id"]
	var place := WorldBootstrap.place_id(region)
	var s := Settlement.new(sid, 200.0, 2.0)
	s.by_stage[Enums.LifeStage.ADULT] = 8.0
	view.run.settlements[sid] = s
	watch_signals(EventBus)
	assert_true(view.influence_panel.arm("still_air"))
	view.select_place(place)
	assert_signal_emitted(EventBus, "phenomenon", "the paint became a cast [T22.6]")
	var payload: Dictionary = get_signal_parameters(EventBus, "phenomenon", 0)[0]
	assert_eq(payload["place"], place, "…and its root stimulus landed at the frontier place")
