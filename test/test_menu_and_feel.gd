extends GutTest

## R8 [leg §L-ui] — menu & camera feel. R8.1: the chrome wears the Ravenna skin
## and the New-Game wizard fills its screen instead of collapsing to a zero-size
## Control that overflowed onto the action buttons (the Gate-A "Quick Start over
## Balanced Saga" overlap). R8.2: pan/zoom feel — the camera eases toward its pan
## target framerate-independently instead of snapping (the Gate-A "clunky" feel).

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _view(seed_value := 1861) -> RunView:
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


func _key(name: String, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = OS.find_keycode_from_string(name)
	event.pressed = pressed
	return event


func test_the_menu_wears_the_ravenna_skin():
	var menu := MainMenu.new()
	add_child_autofree(menu)
	menu.build()
	var button: Button = menu.buttons["new_game"]
	assert_eq(
		button.get_theme_color("font_color"),
		Palette.COLORS[Palette.CREAM],
		"menu items take cream body text, not the engine default"
	)
	assert_eq(
		button.get_theme_color("font_hover_color"),
		Palette.COLORS[Palette.GOLD_LIT],
		"…and gold-lit on hover"
	)


func test_the_menu_centres_its_column_on_a_lapis_ground():
	var menu := MainMenu.new()
	add_child_autofree(menu)
	menu.build()
	var grounded := false
	for child in menu.get_children():
		if child is PanelContainer:
			var style := (child as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
			if style != null and style.bg_color == Palette.COLORS[Palette.NIGHT_LAPIS]:
				grounded = true
	assert_true(grounded, "the menu sits on a night-lapis ground")


func test_the_wizard_view_fills_its_slot_not_a_zero_size_control():
	# The Gate-A overlap: WizardView was a bare Control with no expand flags, so a
	# parent VBox gave it ~0 height and its preset cards overflowed onto the action
	# buttons. EXPAND_FILL means it takes the free space instead.
	var view := WizardView.new()
	view.wizard = NewGameWizard.new()
	add_child_autofree(view)
	assert_eq(view.size_flags_vertical, Control.SIZE_EXPAND_FILL, "the wizard view fills its slot")
	var grounded := false
	for child in view.get_children():
		if child is PanelContainer:
			grounded = true
	assert_true(grounded, "…on a night-lapis ground, with the pages skinned")


func test_the_wizard_still_shows_exactly_one_page_under_the_skin():
	# The skin/heading additions must not break the one-page-visible contract.
	var view := WizardView.new()
	view.wizard = NewGameWizard.new()
	add_child_autofree(view)
	var visible_pages := 0
	for n in range(1, NewGameWizard.PAGES + 1):
		if view.get_node("column/page_%d" % n).visible:
			visible_pages += 1
	assert_eq(visible_pages, 1, "exactly one page shows [§2]")


func test_the_mounted_wizard_screen_can_give_the_pages_space():
	# [R8.1 review] Assert on the ACTUAL shell-mounted wizard, not a standalone one:
	# the screen box must be full-rect (so it HAS free space to distribute) and the
	# mounted wizard view must expand-fill it — the two facts that together prevent
	# the Gate-A overlap.
	var shell := GameShell.new()
	shell.save_dir = "user://test_menu_feel/saves"
	shell.chronicle_dir = "user://test_menu_feel/chron"
	shell.settings_path = "user://test_menu_feel/settings.cfg"
	shell.codex_path = "user://test_menu_feel/codex.json"
	add_child_autofree(shell)
	var box: Control = shell.screens["wizard"]
	assert_almost_eq(box.anchor_right, 1.0, 0.001, "the wizard screen fills the viewport (right)")
	assert_almost_eq(box.anchor_bottom, 1.0, 0.001, "…and bottom — so it has space to give")
	assert_eq(
		shell.wizard_view.size_flags_vertical,
		Control.SIZE_EXPAND_FILL,
		"the mounted wizard view expand-fills, so the pages can't overflow the buttons"
	)


func test_the_camera_eases_rather_than_teleporting():
	# [R8.2] the Gate-A "clunky" pan: the camera now EASES toward the target — it
	# moves toward it but lags it in a single frame, instead of snapping.
	var view := _view()
	view.set_speed(0.0)
	var start := Vector2(view.camera.position.x, view.camera.position.z)
	view._unhandled_input(_key("D", true))
	view._process(0.1)
	var cam := Vector2(view.camera.position.x, view.camera.position.z)
	var target := Vector2(view._cam_target.x, view._cam_target.z)
	assert_gt(cam.distance_to(start), 0.0, "the camera moves toward the aim")
	assert_gt(
		target.distance_to(start),
		cam.distance_to(start),
		"…but lags the target in one frame (eased, not teleported)"
	)


func test_pan_easing_is_framerate_independent():
	# Holding pan the same TOTAL time reaches the same place whether stepped in one
	# big frame or many small ones (linear target integration + exponential ease).
	var coarse := _view(1862)
	var fine := _view(1862)
	for view in [coarse, fine]:
		view.set_speed(0.0)
		view._unhandled_input(_key("D", true))
	coarse._process(1.0)
	for i in 10:
		fine._process(0.1)
	# release and let both settle onto the (identical) target
	coarse._unhandled_input(_key("D", false))
	fine._unhandled_input(_key("D", false))
	for i in 20:
		coarse._process(0.1)
		fine._process(0.1)
	var cp := Vector2(coarse.camera.position.x, coarse.camera.position.z)
	var fp := Vector2(fine.camera.position.x, fine.camera.position.z)
	assert_almost_eq(
		cp.distance_to(fp), 0.0, 0.02, "same total pan time → same place, any framerate"
	)
