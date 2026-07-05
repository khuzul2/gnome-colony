extends GutTest

## R1.6 [rav §R-art] — the Ravenna motifs: a gold sacred medallion over
## BLESSED ground, a red ring over CURSED ground, and the Chi-Rho-like
## monogram drawn procedurally. RunView marks each basin's belief tag. GPU
## look is judged at Gate A; here we gate the structure + colors.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func test_border_colors_match_the_palette():
	assert_eq(Motifs.border_color(Motifs.BLESSED), Palette.COLORS[Palette.GOLD], "blessed → gold")
	assert_eq(Motifs.border_color(Motifs.CURSED), Palette.COLORS[10], "cursed → terracotta")
	assert_eq(Motifs.border_color("plain").a, 0.0, "untagged → no marker")


func test_the_monogram_is_drawn_in_gold():
	var img := Motifs.monogram_image(32)
	assert_eq(img.get_width(), 32)
	var gold_pixels := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				gold_pixels += 1
	assert_gt(gold_pixels, 0, "the monogram has gold strokes on transparent")


func test_blessed_medallion_carries_the_monogram():
	var blessed := Motifs.build_place_medallion(Motifs.BLESSED)
	assert_not_null(blessed, "a blessed place gets a medallion")
	assert_not_null(blessed.get_node("monogram"), "…with the sacred monogram")
	var ring := blessed.get_node("ring") as MeshInstance3D
	var mat := ring.material_override as StandardMaterial3D
	assert_eq(mat.albedo_color, Palette.COLORS[Palette.GOLD], "the ring is gold")
	blessed.free()


func test_cursed_medallion_is_a_red_ring_without_monogram():
	var cursed := Motifs.build_place_medallion(Motifs.CURSED)
	assert_not_null(cursed, "a cursed place gets a ring")
	assert_false(cursed.has_node("monogram"), "no sacred monogram over cursed ground")
	cursed.free()
	assert_null(Motifs.build_place_medallion("plain"), "untagged ground gets nothing")


func test_kind_for_prefers_reverence_over_dread():
	assert_eq(Motifs.kind_for({"blessed": 0.5, "cursed": 0.9}), Motifs.BLESSED, "reverence reads")
	assert_eq(Motifs.kind_for({"cursed": 0.3}), Motifs.CURSED)
	assert_eq(Motifs.kind_for({}), "", "no tag, no marker")


func test_runview_marks_tagged_basins():
	Rng.seed_with(1781)
	var cfg := WorldConfig.new()
	cfg.seed = 1781
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	add_child_autofree(view)
	var home := run.home
	assert_false(view._motifs.has(home), "an untagged home has no medallion")
	run.runner.colony.place_tags[home] = {"blessed": 0.8}
	view._refresh_motifs()
	assert_true(view._motifs.has(home), "a blessed tag raises a medallion")
	assert_eq(view._motifs[home].get_parent(), view.stage_world, "…inside the pixel stage")
	run.runner.colony.place_tags[home] = {}
	view._refresh_motifs()
	assert_false(view._motifs.has(home), "clearing the tag removes the medallion")
