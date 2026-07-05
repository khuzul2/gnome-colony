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


# --- R5.2: oblique camera + pixel-snap --------------------------------------


func test_camera_is_oblique_and_descends_per_spec():
	# The Gate-A view looked near-top-down (−60°), hiding relief; tilt oblique
	# [leg §L-relief]. Heights still fall civ→settlement→individual.
	assert_eq(CameraRig.PITCHES_DEG[CameraRig.Zoom.CIVILIZATION], -72.0)
	assert_eq(CameraRig.PITCHES_DEG[CameraRig.Zoom.SETTLEMENT], -45.0)
	assert_eq(CameraRig.PITCHES_DEG[CameraRig.Zoom.INDIVIDUAL], -28.0)
	assert_eq(CameraRig.HEIGHTS[CameraRig.Zoom.SETTLEMENT], 42.0)
	var rig := CameraRig.new()
	add_child_autofree(rig)
	assert_almost_eq(rig.camera.rotation_degrees.x, -45.0, 0.001, "the settlement view is oblique")


func test_pixel_snap_quantizes_the_presented_camera_but_not_the_rig():
	# Anti-shimmer: the PRESENTED camera holds its pixel cell under a sub-pixel
	# pan, while the rig's logical position stays continuous so pan precision
	# (T23.2) is intact. This resolves the R1.2 deferral [leg §L-relief, §L-ui].
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.snap_enabled = true
	var g: float = CameraRig.PIXEL_GRID_KM[CameraRig.Zoom.SETTLEMENT]
	rig.focus(Vector3(5.0, 0.0, 0.0))
	var cell_x: float = rig.camera.global_position.x
	rig.focus(Vector3(5.0 + g * 0.25, 0.0, 0.0))  # a sub-pixel nudge
	assert_almost_eq(
		rig.camera.global_position.x, cell_x, 1e-5, "the presented camera holds its pixel cell"
	)
	assert_almost_eq(
		rig.position.x,
		5.0 + g * 0.25,
		1e-5,
		"the rig's logical aim stays continuous (pan precision)"
	)
	rig.focus(Vector3(5.0 + g, 0.0, 0.0))  # one whole pixel over
	assert_gt(
		absf(rig.camera.global_position.x - cell_x),
		g * 0.5,
		"a whole-pixel pan steps to the next cell"
	)


func test_snap_is_off_by_default_so_bare_rig_logic_is_exact():
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.focus(Vector3(5.123, 0.0, -2.777))
	assert_almost_eq(rig.camera.global_position.x, 5.123, 1e-5, "no snap when disabled")
	assert_almost_eq(rig.camera.global_position.z, -2.777, 1e-5, "no snap when disabled")


# --- R5.3: finer tesserae + slope-shade -------------------------------------


func test_finer_internal_resolution_and_grout():
	# Gate-A "tesserae too large": raise the internal res and tighten the grout so
	# cells read as laid stone over the relief [leg §L-relief].
	assert_eq(PixelStage.INTERNAL_WIDTH, 512, "finer internal width")
	assert_eq(PixelStage.INTERNAL_HEIGHT, 288, "finer internal height")
	assert_eq(Mosaic.GROUT_PX, 3.0, "tighter grout pitch")


func test_slope_shade_darkens_steep_faces():
	# A flat tessera keeps its palette color; a steep one is darkened up to
	# SLOPE_SHADE so relief reads dimensional [leg §L-relief].
	var c: Color = Palette.COLORS[5]  # pale-green mid-slope
	assert_eq(WorldView.slope_shade(c, 0.0), c, "flat ground keeps its tessera color")
	var steep: Color = WorldView.slope_shade(c, 1.0)
	assert_lt(steep.v, c.v, "a steep face is darker (mosaic relief)")
	assert_almost_eq(
		steep.r, c.r * (1.0 - WorldView.SLOPE_SHADE), 1e-5, "darkened by up to SLOPE_SHADE"
	)
	assert_eq(steep.a, c.a, "alpha is preserved")
