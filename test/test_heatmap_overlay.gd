extends GutTest

## T21.4 (overlay quarter) — the heatmap overlay: a standalone HUD
## widget that renders Heatmap's two grains (quickened gnomes +
## statistical settlement folds) as one Label row per place, with the
## quickened grain winning where both speak. toggle() flips
## visibility; refresh() follows the substrate. Pure chrome — every
## number on screen comes from the tested Heatmap readers.


func _gnome_at(colony: Colony, place: String, need_level: float, fear: float) -> GnomeData:
	var g := colony.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	g.location = place
	for key in Enums.NEED_KEYS:
		g.needs[key] = need_level
	g.set_feeling(Devotion.YOU, "fear", fear)
	return g


func _overlay(colony: Colony, settlements: Dictionary, place_of: Dictionary) -> HeatmapOverlay:
	var overlay := HeatmapOverlay.new()
	add_child_autofree(overlay)
	overlay.build(colony, settlements, place_of)
	return overlay


func test_one_row_per_place_across_both_grains():
	var colony := Colony.new()
	_gnome_at(colony, "the_hollow", 0.8, 0.6)
	_gnome_at(colony, "the_hollow", 0.6, 0.2)
	var s := Settlement.new(3, 10.0, 1.0)
	s.mood = 0.35
	s.belief = {"faith": 0.5, "awe": 0.3, "fear": 0.1}
	var overlay := _overlay(colony, {3: s}, {3: "fern_gully"})
	assert_eq(overlay.rows.size(), 2, "a quickened place and a folded place, one row each")
	var hollow: Label = overlay.rows["the_hollow"]
	assert_string_contains(hollow.text, "mood 0.30", "1 − mean(needs), fixed-point [algo §5]")
	assert_string_contains(hollow.text, "fear 0.40", "mean feeling over locals")
	var gully: Label = overlay.rows["fern_gully"]
	assert_string_contains(gully.text, "mood 0.35", "the fold IS the reading [§14]")
	assert_string_contains(gully.text, "faith 0.50")


func test_the_quickened_grain_wins_where_both_speak():
	var colony := Colony.new()
	_gnome_at(colony, "the_hollow", 0.8, 0.6)
	var s := Settlement.new(0, 10.0, 1.0)
	s.mood = 0.95
	var overlay := _overlay(colony, {0: s}, {0: "the_hollow"})
	assert_eq(overlay.rows.size(), 1, "one place, one row — the grains merge")
	assert_string_contains(
		overlay.rows["the_hollow"].text,
		"mood 0.20",
		"living gnomes outrank the statistical fold for a watched place"
	)


func test_toggle_flips_visibility():
	var overlay := _overlay(Colony.new(), {}, {})
	assert_true(overlay.visible, "a Control starts visible")
	overlay.toggle()
	assert_false(overlay.visible, "toggled off")
	overlay.toggle()
	assert_true(overlay.visible, "…and back on")


func test_refresh_follows_the_substrate_without_duplicating_rows():
	var colony := Colony.new()
	var g := _gnome_at(colony, "the_hollow", 0.8, 0.0)
	var overlay := _overlay(colony, {}, {})
	assert_string_contains(overlay.rows["the_hollow"].text, "mood 0.20")
	for key in Enums.NEED_KEYS:
		g.needs[key] = 0.2
	overlay.refresh()
	assert_string_contains(
		overlay.rows["the_hollow"].text, "mood 0.80", "substrate moves, rows follow"
	)
	assert_eq(overlay.rows.size(), 1, "rebuilt, not appended")
	var labels := 0
	for child in overlay.get_node("places").get_children():
		if child is Label:
			labels += 1
	assert_eq(labels, 1, "exactly one Label row per place in the tree too")
