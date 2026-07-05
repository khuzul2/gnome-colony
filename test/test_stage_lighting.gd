extends GutTest

## R1.4 [rav §R-art] — the late-antique lighting: a low warm gold key light
## and a deep-lapis ambient replace RunView's daylight, and the values match
## §R-art. Headless can't judge the look (Gate A does); it can gate the
## resources RunView builds.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func test_key_light_is_low_warm_gold():
	var sun := StageLighting.build_sun()
	assert_eq(sun.light_color, Color("f2d488"), "gold key light [§R-art]")
	assert_almost_eq(sun.light_energy, 1.3, 0.001, "energy 1.3")
	assert_almost_eq(sun.rotation_degrees.x, -28.0, 0.001, "28° elevation (low, warm)")


func test_environment_is_deep_lapis_with_gold_bloom():
	var env := StageLighting.build_environment()
	assert_eq(env.background_color, Color("0d1b3e"), "night-lapis ground/sky")
	assert_eq(env.ambient_light_color, Color("0d1b3e"), "deep-lapis ambient")
	assert_almost_eq(env.ambient_light_energy, 0.35, 0.001, "dim ambient (figures on dark)")
	assert_true(env.glow_enabled, "bloom on")
	assert_almost_eq(env.glow_hdr_threshold, 0.85, 0.001, "bloom threshold 0.85 (gold only)")


func test_runview_lights_the_stage_in_the_ravenna_register():
	Rng.seed_with(1771)
	var cfg := WorldConfig.new()
	cfg.seed = 1771
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	add_child_autofree(view)
	var sun := view.stage_world.get_node("sun") as DirectionalLight3D
	assert_eq(sun.light_color, StageLighting.KEY_LIGHT, "the run's sun is the gold key light")
	var env := (view.stage_world.get_node("environment") as WorldEnvironment).environment
	assert_eq(env.background_color, StageLighting.AMBIENT_BG, "…over deep-lapis")
