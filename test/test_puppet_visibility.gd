extends GutTest

## R6.1 [leg §L-hud] — the top BLOCKER: at Gate A the player could not tell
## gnomes existed. Founder adults projected to only ~6 px and vanished into the
## mosaic at the aggregate zooms. A per-zoom view_scale keeps them legible; this
## asserts an adult clears PUPPET_MIN_PX (measured by real projection into the
## 512×288 stage viewport), that figures grow as the eye pulls back, and that they
## sit on the relief surface rather than being buried by R5.1's amplified terrain.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _view(seed_value := 1781) -> RunView:
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


func _an_adult(view: RunView) -> GnomePuppet:
	for id in view._puppets:
		var p: GnomePuppet = view._puppets[id]
		if p.data != null and p.data.stage == Enums.LifeStage.ADULT:
			return p
	return null


## The puppet's on-screen height in internal (stage-viewport) pixels.
func _projected_px(view: RunView, puppet: GnomePuppet) -> float:
	var cam := view.camera.camera
	var body_h: float = (puppet.body.mesh as CapsuleMesh).height * puppet.scale.y
	var base := cam.unproject_position(puppet.position)
	var top := cam.unproject_position(puppet.position + Vector3(0.0, body_h, 0.0))
	return base.distance_to(top)


func _go_to(view: RunView, level: int) -> void:
	while view.camera.level < level:
		view.camera.zoom_in()
	while view.camera.level > level:
		view.camera.zoom_out()


func test_an_adult_clears_the_minimum_size_at_the_play_zooms():
	# The floor holds at the two PLAY zooms (settlement, individual). The
	# civilization view is the world map — settlements read via their locators, not
	# individual bodies (scaling a gnome to 6 px at map range would dwarf the map).
	var view := _view()
	var adult := _an_adult(view)
	assert_not_null(adult, "a founder adult is on stage")
	for level in [CameraRig.Zoom.SETTLEMENT, CameraRig.Zoom.INDIVIDUAL]:
		_go_to(view, level)
		assert_gt(
			_projected_px(view, adult),
			RunView.PUPPET_MIN_PX,
			"an adult reads at least PUPPET_MIN_PX at play zoom %d" % level
		)


func test_figures_grow_as_the_eye_pulls_back():
	var view := _view()
	var adult := _an_adult(view)
	_go_to(view, CameraRig.Zoom.INDIVIDUAL)
	var near := adult.scale.y
	_go_to(view, CameraRig.Zoom.CIVILIZATION)
	assert_gt(adult.scale.y, near, "figures scale up at the wider zooms so they stay legible")


func test_figures_stand_on_the_relief_surface():
	var view := _view()
	var adult := _an_adult(view)
	var ground := view.world_view.height_at(Vector2(adult.position.x, adult.position.z))
	assert_almost_eq(
		adult.position.y, ground, 0.001, "the figure stands on the local relief, not buried"
	)
