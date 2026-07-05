extends GutTest

## R1.3 [rav §R-art] — the mosaic post-process material: the shader loads, the
## ShaderMaterial is wired to the 16-color LUT and §R-art's constants, and
## RunView mounts it on the pixel stage. GPU-exact quantization/grout is judged
## at Playtest Gate A (headless has no pixel readback); here we gate the
## spec-wiring and the CPU mirror.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func test_shader_resource_loads():
	var shader := load(Mosaic.SHADER_PATH)
	assert_not_null(shader, "the mosaic shader file loads")
	assert_true(shader is Shader, "…as a Shader resource")


func test_material_is_wired_to_the_palette_and_spec_constants():
	var material := Mosaic.make_material()
	assert_true(material is ShaderMaterial, "make_material builds a ShaderMaterial")
	assert_not_null(material.shader, "…with the mosaic shader")
	var lut: Texture2D = material.get_shader_parameter("palette_lut")
	assert_not_null(lut, "the palette LUT is bound")
	assert_eq(lut.get_width(), 16, "…a 16-entry LUT")
	assert_eq(
		material.get_shader_parameter("grout_px"),
		Mosaic.GROUT_PX,
		"grout pitch = 3 [R5.3, leg §L-relief]"
	)
	assert_eq(
		material.get_shader_parameter("grout_color"),
		Palette.COLORS[Palette.GROUT],
		"grout color = near-black (index 15)"
	)
	assert_eq(material.get_shader_parameter("grout_alpha"), Mosaic.GROUT_ALPHA)
	assert_eq(material.get_shader_parameter("jitter"), Mosaic.JITTER)
	assert_eq(material.get_shader_parameter("gold_lift"), Mosaic.GOLD_LIFT)
	assert_eq(
		material.get_shader_parameter("internal_size"),
		Vector2(PixelStage.INTERNAL_WIDTH, PixelStage.INTERNAL_HEIGHT),
		"internal size matches the stage"
	)


func test_cpu_quantize_mirrors_the_palette():
	# The shader's palette-map and this CPU mirror must agree (motifs/masks
	# rely on it); a near-color snaps to the nearest tessera.
	var near := Color("245a8c").lerp(Color.BLACK, 0.02)
	assert_eq(Mosaic.quantize(near), Palette.COLORS[2], "snaps to mid-blue")
	assert_eq(Mosaic.quantize(Palette.COLORS[7]), Palette.COLORS[7], "exact entry is fixed")


func test_runview_mounts_the_material_on_the_stage():
	Rng.seed_with(1761)
	var cfg := WorldConfig.new()
	cfg.seed = 1761
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	add_child_autofree(view)
	var screen := view.stage.get_node("screen") as TextureRect
	var screen_material := screen.material as ShaderMaterial
	assert_not_null(screen_material, "the stage screen carries a mosaic ShaderMaterial")
	assert_not_null(screen_material.get_shader_parameter("palette_lut"), "…wired to the palette")
