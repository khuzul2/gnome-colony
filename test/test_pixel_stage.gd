extends GutTest

## R1.2 [rav §R-art] — the pixel stage: the 3D world renders into a low-res
## SubViewport (own World3D) upscaled with nearest-neighbor, and window-space
## picking is scaled to viewport space through the stage. The camera, lights,
## terrain and puppets must live inside the stage; picking must round-trip.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _view(seed_value: int = 1751) -> RunView:
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


func test_stage_is_a_low_res_subviewport():
	var view := _view()
	assert_not_null(view.stage, "the pixel stage exists")
	assert_eq(view.stage_world.size.x, PixelStage.INTERNAL_WIDTH, "internal width 512 [R5.3]")
	assert_eq(view.stage_world.size.y, PixelStage.INTERNAL_HEIGHT, "internal height 288 [R5.3]")
	assert_true(view.stage_world.own_world_3d, "the stage owns its World3D")
	assert_eq(
		view.stage.get_node("screen").texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"upscale is nearest-neighbor (crisp tesserae)"
	)


func test_the_world_lives_inside_the_stage():
	var view := _view()
	assert_eq(view.world_view.get_parent(), view.stage_world, "terrain skin is in the stage")
	assert_eq(view.camera.get_parent(), view.stage_world, "the camera rig is in the stage")
	assert_eq(view.pool.get_parent(), view.stage_world, "the puppet pool is in the stage")
	for id in view._puppets:
		assert_eq(
			view._puppets[id].get_parent(), view.pool, "puppets ride the pool inside the stage"
		)
		break


func test_to_viewport_is_identity_when_undisplayed():
	# Headless leaves the stage at size 0 → picking coordinates pass through
	# unchanged, so the analytic unproject→project round-trip still holds.
	var view := _view()
	var p := Vector2(123.0, 45.0)
	assert_eq(view.stage.to_viewport(p), p, "no display size → identity")


func test_to_viewport_scales_a_displayed_window():
	# When shown at a real window size, a window point maps into the internal
	# viewport by the display ratio (robust to the R5.3 resolution change).
	var view := _view()
	var internal := Vector2(PixelStage.INTERNAL_WIDTH, PixelStage.INTERNAL_HEIGHT)
	view.stage.fit_to(internal * 2.0)  # exactly 2× the internal size
	assert_almost_eq(view.stage.to_viewport(internal), internal * 0.5, Vector2(0.5, 0.5))


func test_picking_survives_the_reparent():
	# THE core verb still works with the camera inside the SubViewport: arm,
	# click the home basin's screen projection, it casts there.
	var view := _view()
	view.set_speed(0.0)
	assert_eq(Devotion.total(view.run.runner.colony), 0.0)
	assert_true(view.influence_panel.arm("still_air"))
	var home_pos: Vector3 = view.place_positions[view.run.home]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = view.camera.camera.unproject_position(home_pos)
	view._unhandled_input(click)
	assert_gt(Devotion.total(view.run.runner.colony), 0.0, "click-through-viewport cast landed")
