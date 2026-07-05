extends GutTest

## R7.3 [leg §L-acts] — transient on-map markers for LANDED phenomena, so a cast
## reads as a mark on the world, not just a sound. Diegetic discipline (T14.4):
## only landed phenomena mark; an armed-but-unpressed act does not.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _markers() -> CastMarkers:
	var m := CastMarkers.new()
	m.place_positions = {"home_0": Vector3(1.0, 0.0, 2.0)}
	add_child_autofree(m)
	return m


func _view(seed_value := 1831) -> RunView:
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


func test_a_landed_phenomenon_marks_its_place():
	var m := _markers()
	assert_eq(m._markers.size(), 0, "no marks at first")
	EventBus.phenomenon.emit({"place": "home_0", "valence": "benevolent", "type": "still_air"})
	assert_eq(m._markers.size(), 1, "a landed act marks its place")


func test_a_phenomenon_at_an_unknown_place_is_ignored():
	var m := _markers()
	EventBus.phenomenon.emit({"place": "nowhere", "valence": "neutral"})
	assert_eq(m._markers.size(), 0, "no known position, no mark")


func test_the_marker_clears_after_its_time():
	var m := _markers()
	EventBus.phenomenon.emit({"place": "home_0", "valence": "malevolent"})
	assert_eq(m._markers.size(), 1, "marked")
	m._process(CastMarkers.CAST_MARKER_SECONDS + 0.1)
	assert_eq(m._markers.size(), 0, "…and clears after CAST_MARKER_SECONDS")


func test_teardown_drops_the_subscription():
	var m := _markers()
	assert_true(EventBus.phenomenon.is_connected(m._on_phenomenon), "wired while live")
	remove_child(m)
	assert_false(EventBus.phenomenon.is_connected(m._on_phenomenon), "unwired on teardown")


func test_a_real_cast_marks_the_world_but_arming_alone_does_not():
	var view := _view()
	view.set_speed(0.0)
	assert_eq(view.cast_markers._markers.size(), 0, "a fresh world has no marks")
	# T14.4: arming lands nothing, so it makes no mark.
	assert_true(view.influence_panel.arm("still_air"))
	assert_eq(view.cast_markers._markers.size(), 0, "an armed-but-unpressed act makes no mark")
	# Pressing it (a real, landed cast) marks its place.
	view.select_place(view.run.home)
	assert_gt(view.cast_markers._markers.size(), 0, "a landed cast marks its place")
