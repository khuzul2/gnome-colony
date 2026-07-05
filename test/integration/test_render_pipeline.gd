extends GutTest

## Phase-Exit R1 — the Ravenna mosaic render pipeline, end to end on a live
## RunView: the 3D world renders into a 384×216 stage, the mosaic material maps
## to the 16 tesserae, the lighting is gold-on-lapis, motifs mark belief, and
## picking still round-trips through the reparented viewport. GPU-exact
## quantization/grout is the human's call at Playtest Gate A (headless uses a
## dummy rasterizer with no pixel readback); this asserts the wiring + the CPU
## palette guarantee (every mapped color lands on the palette → >95% on-palette
## by construction).

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _view(seed_value: int = 1791) -> RunView:
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


func test_the_world_renders_into_a_low_res_stage():
	var view := _view()
	assert_eq(view.stage_world.size, Vector2i(384, 216), "internal resolution 384×216")
	assert_true(view.stage_world.own_world_3d, "the stage owns its World3D")
	assert_eq(view.camera.camera.get_viewport(), view.stage_world, "the camera renders into it")


func test_the_mosaic_material_maps_to_16_tesserae():
	var view := _view()
	var material := (view.stage.get_node("screen") as TextureRect).material as ShaderMaterial
	assert_not_null(material, "the stage screen carries the mosaic material")
	var lut: Texture2D = material.get_shader_parameter("palette_lut")
	assert_eq(lut.get_width(), 16, "the palette LUT has 16 entries")


func test_the_light_is_gold_on_lapis():
	var view := _view()
	var sun := view.stage_world.get_node("sun") as DirectionalLight3D
	assert_eq(sun.light_color, StageLighting.KEY_LIGHT, "gold key light")
	var env := (view.stage_world.get_node("environment") as WorldEnvironment).environment
	assert_eq(env.background_color, StageLighting.AMBIENT_BG, "deep-lapis ground")


func test_every_mapped_color_lands_on_the_palette():
	# The CPU mirror of the shader's palette-map: sweep the color cube and
	# assert 100% of samples snap to a palette entry (so the rendered frame is
	# on-palette by construction, well past the >95% bar).
	var palette := {}
	for c in Palette.COLORS:
		palette[c] = true
	var on := 0
	var total := 0
	for r in 6:
		for g in 6:
			for b in 6:
				var mapped := Mosaic.quantize(Color(r / 5.0, g / 5.0, b / 5.0))
				total += 1
				if palette.has(mapped):
					on += 1
	assert_eq(on, total, "all %d sampled colors map onto the palette" % total)


func test_picking_and_motifs_survive_the_pipeline():
	var view := _view()
	view.set_speed(0.0)
	# Picking round-trips through the reparented viewport.
	assert_true(view.influence_panel.arm("still_air"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = view.camera.camera.unproject_position(view.place_positions[view.run.home])
	view._unhandled_input(click)
	assert_gt(Devotion.total(view.run.runner.colony), 0.0, "arm + click casts through the stage")
	# A belief tag raises its mosaic medallion.
	view.run.runner.colony.place_tags[view.run.home] = {"blessed": 0.9}
	view._refresh_motifs()
	assert_true(view._motifs.has(view.run.home), "blessed ground gets its gold medallion")
