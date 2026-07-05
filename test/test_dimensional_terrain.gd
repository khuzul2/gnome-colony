extends GutTest

## Phase R5 — dimensional mosaic terrain [docs/redesign-plan-legibility.md,
## docs/redesign-ravenna-legibility.md §L-relief]. The 3-D heightfield already
## exists (WorldView) but reads flat: region elevations are tiny against a 28 km
## plane. R5.1 amplifies relief to a legible envelope and clamps water flat, while
## keeping height_at consistent with the mesh so picking/nav still land.
##
## This file accretes across the phase: R5.1 = relief envelope + water clamp;
## R5.2 = oblique camera + pixel-snap; R5.3 = stage res + grout + slope-shade.


func _graph() -> RegionGraph:
	Rng.seed_with(51000)
	return RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])


func _extreme_regions(graph: RegionGraph) -> Dictionary:
	var lo: Dictionary = graph.regions[0]
	var hi: Dictionary = graph.regions[0]
	for r in graph.regions:
		if r["elevation"] < lo["elevation"]:
			lo = r
		if r["elevation"] > hi["elevation"]:
			hi = r
	return {"lo": lo, "hi": hi}


# --- R5.1: relief is real, not ~0 -------------------------------------------


func test_relief_span_is_substantial():
	# Gate-A NO-GO: terrain read as a flat sheet. The baked skin must now span a
	# legible vertical relief across the map — not the ~0.1%-of-width it did.
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	var min_y := INF
	var max_y := -INF
	for r in graph.regions:
		var y: float = view.height_at(r["center"])
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y)
	var span := max_y - min_y
	# highest basin → ~RELIEF_KM, lowest → the water plane RELIEF_KM·SEA_LEVEL_T;
	# IDW-at-centres softens the extremes, so assert a substantial band, not equality.
	assert_gt(
		span,
		0.6 * WorldView.RELIEF_KM,
		"the skin has real, legible vertical relief [leg §L-relief]"
	)


func test_heights_stay_within_the_relief_envelope():
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	var floor_y := WorldView.RELIEF_KM * WorldView.SEA_LEVEL_T
	for r in graph.regions:
		var y: float = view.height_at(r["center"])
		assert_between(
			y, floor_y - 0.01, WorldView.RELIEF_KM + 0.01, "basin height inside the envelope"
		)


func test_water_is_a_flat_plane_at_sea_level():
	# Sub-SEA_LEVEL_T ground clamps up to the sea plane so a flat water body reads
	# against the land relief. The lowest-elevation basin sits at t=0 → clamped.
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	var lo: Dictionary = _extreme_regions(graph)["lo"]
	assert_almost_eq(
		view.height_at(lo["center"]),
		WorldView.RELIEF_KM * WorldView.SEA_LEVEL_T,
		0.02,
		"the lowest ground rests on the flat sea plane [leg §L-relief]"
	)


func test_height_at_agrees_with_the_mesh_field():
	# Picking / nav / puppet placement all read height_at; it must be the SAME
	# relief field the mesh is baked from. Higher elevation ⇒ higher (or equal) skin.
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	var ex := _extreme_regions(graph)
	assert_true(
		view.height_at(ex["hi"]["center"]) >= view.height_at(ex["lo"]["center"]),
		"a higher basin sits at least as high on the skin (monotonic relief)"
	)
