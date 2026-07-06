extends GutTest

## G3 [gaea §gaea-gen] — biome-varied palette bands + water detail that read through the
## Ravenna mosaic while staying 100% on the 16-colour palette (mosaic discipline; the
## test_render_pipeline >95%-on-palette guarantee holds). The region biome
## (meadow/forest/ridge/marsh) biases WorldView.terrain_color's band selection — COMPOSED
## with, not replacing, the elevation banding — and water below R5's SEA_LEVEL_T reads as
## the flat lapis plane. G3.1 legs (biome bands) here; G3.2 adds the water legs.


func _palette_has(c: Color) -> bool:
	for entry in Palette.COLORS:
		if entry == c:
			return true
	return false


# --- G3.1: biome-varied palette bands ---


func test_biome_band_is_deterministic():
	# Pure function of (t, biome): same inputs ⇒ same on-palette colour.
	assert_eq(
		WorldView.terrain_color_biomed(0.6, "forest"),
		WorldView.terrain_color_biomed(0.6, "forest"),
		"same elevation + biome ⇒ same band"
	)


func test_forest_and_ridge_differ_at_equal_elevation():
	# §gaea-gen: forest skews greener, ridge ochre/gold — so the SAME elevation reads
	# differently by biome (composed with, not replacing, the elevation band).
	var any_diff := false
	for t in [0.3, 0.5, 0.8]:
		if (
			WorldView.terrain_color_biomed(t, "forest")
			!= WorldView.terrain_color_biomed(t, "ridge")
		):
			any_diff = true
	assert_true(any_diff, "forest vs ridge pick different bands at equal elevation")


func test_every_biome_band_stays_on_palette():
	# Mosaic discipline: no biome/elevation combination may leave the 16-colour palette.
	for biome in RegionGraph.BIOMES:
		for i in 21:
			var t := i / 20.0
			assert_true(
				_palette_has(WorldView.terrain_color_biomed(t, biome)),
				"terrain_color_biomed(%.2f, %s) is on-palette" % [t, biome]
			)


func test_meadow_matches_the_base_elevation_bands():
	# meadow is the neutral base — identical to the un-biomed terrain_color(t), so a
	# Uniform-variety world (all meadow) renders exactly as it did before G3.
	for i in 21:
		var t := i / 20.0
		assert_eq(
			WorldView.terrain_color_biomed(t, "meadow"),
			WorldView.terrain_color(t),
			"meadow band == base terrain_color at t=%.2f" % t
		)


func test_water_band_stays_lapis_across_biomes():
	# Water is water: the lowest elevation band reads the lapis water colour for every
	# biome (composes with R5's SEA_LEVEL_T flat-plane clamp — see G3.2).
	for biome in RegionGraph.BIOMES:
		assert_eq(
			WorldView.terrain_color_biomed(0.05, biome),
			Palette.COLORS[1],
			"%s lowland/water is lapis" % biome
		)


func test_unknown_biome_falls_back_to_meadow():
	# Defensive: an unexpected biome string reads the neutral base, never off-palette/crash.
	assert_eq(
		WorldView.terrain_color_biomed(0.5, "tundra_nonexistent"),
		WorldView.terrain_color_biomed(0.5, "meadow"),
		"unknown biome falls back to meadow"
	)


# --- G3.2: water bodies compose with the R5 sea clamp ---


func test_below_sea_relief_is_the_flat_water_plane():
	# R5.1's clamp: any normalized height below SEA_LEVEL_T maps to the single flat water y,
	# so low ground — including Gaea detail that dips under — forms a coherent water surface
	# rather than noisy mud.
	var water_y := WorldView.RELIEF_KM * WorldView.SEA_LEVEL_T
	assert_almost_eq(WorldView._relief_y(0.0), water_y, 1e-5, "the deepest maps to the water plane")
	assert_almost_eq(
		WorldView._relief_y(WorldView.SEA_LEVEL_T * 0.5),
		water_y,
		1e-5,
		"sub-sea ground is flat water"
	)
	assert_gt(
		WorldView._relief_y(WorldView.SEA_LEVEL_T + 0.2),
		water_y,
		"above sea level rises off the water plane"
	)


func test_below_sea_reads_lapis_for_every_biome():
	# Water is water regardless of the surrounding country's biome.
	for biome in RegionGraph.BIOMES:
		assert_eq(
			WorldView.terrain_color_biomed(WorldView.SEA_LEVEL_T * 0.5, biome),
			Palette.COLORS[1],
			"%s sub-sea reads lapis water" % biome
		)


func test_the_lowest_basin_reads_as_flat_lapis_water():
	# Integration over a real Gaea bake: the lowest basin center normalizes to ~0 (< the
	# SEA_LEVEL_T threshold), so it must sit on the flat water plane AND read lapis — coherent
	# water at the bottom of the world, composed with the biome bands and Gaea detail.
	Rng.seed_with(31337)
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, 5)
	var low: Dictionary = graph.regions[0]
	for r in graph.regions:
		if r["elevation"] < low["elevation"]:
			low = r
	var center: Vector2 = low["center"]
	var water_y := WorldView.RELIEF_KM * WorldView.SEA_LEVEL_T
	assert_lt(view._relief_t(center), WorldView.SEA_LEVEL_T, "the lowest basin center is below sea")
	assert_almost_eq(view.height_at(center), water_y, 1e-4, "…sits on the flat water plane")
	assert_eq(
		WorldView.terrain_color_biomed(view._relief_t(center), view._biome_at(center)),
		Palette.COLORS[1],
		"…and reads lapis water"
	)
