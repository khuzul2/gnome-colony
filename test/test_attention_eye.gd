extends GutTest

## R7.4 [leg §L-acts] — the Eye affordance: a faint ring marks each region the
## gaze is currently attending (dwell→quicken, T13.5), so the player sees WHERE
## souls are quickened. The ring appears on dwell and clears when the gaze releases.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _eye() -> AttentionEye:
	var e := AttentionEye.new()
	add_child_autofree(e)
	return e


func _view(seed_value := 1841) -> RunView:
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


func test_a_ring_marks_each_attended_place_and_clears_on_release():
	var eye := _eye()
	eye.refresh(["home_0"], {"home_0": Vector3.ZERO})
	assert_true(eye.has_ring("home_0"), "the attended place gets a ring")
	assert_eq(eye.count(), 1, "one gaze, one ring")
	eye.refresh([], {"home_0": Vector3.ZERO})
	assert_eq(eye.count(), 0, "the ring clears when the gaze releases")


func test_only_known_places_get_a_ring():
	var eye := _eye()
	eye.refresh(["nowhere"], {"home_0": Vector3.ZERO})
	assert_eq(eye.count(), 0, "no mapped position, no ring")


func test_dwelling_lights_the_eye_ring():
	var view := _view()
	view.set_speed(0.0)
	view.camera.focus(view.place_positions[view.run.home])
	for i in 25:  # ~2.5 s of dwell promotes the gaze [T13.5]
		view._process(0.1)
	assert_has(view.run.attention_places, view.run.home, "dwell promotes the gaze")
	assert_true(view.attention_eye.has_ring(view.run.home), "…and the Eye ring marks it")
