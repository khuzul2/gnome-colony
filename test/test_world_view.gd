extends GutTest

## T13.1 (presentation half) — the heightmap skin [design §2.7b]: a mesh
## baked FROM the region-graph; when a phenomenon reshapes the graph the
## skin re-bakes. The sim never knows the skin exists — presentation
## reads sim, never the reverse (T13.2 adds the grep test).


func _graph() -> RegionGraph:
	Rng.seed_with(13150)
	return RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])


func test_bake_produces_a_mesh_that_reflects_the_graph():
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	assert_not_null(view.mesh_instance.mesh, "a baked ArrayMesh exists")
	# R5.1 [leg §L-relief]: the skin is relief-mapped (not raw elevation) — a
	# basin's height falls in the [SEA_LEVEL_T, 1]·RELIEF_KM envelope. Detailed
	# relief legs live in test_dimensional_terrain.gd.
	var floor_y := WorldView.RELIEF_KM * WorldView.SEA_LEVEL_T
	var sampled: float = view.height_at(graph.regions[0]["center"])
	assert_between(
		sampled, floor_y - 0.01, WorldView.RELIEF_KM + 0.01, "the skin's height is relief-mapped"
	)


func test_reshape_rebakes():
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	var before: float = view.height_at(graph.regions[0]["center"])
	graph.reshape(0, 1.5)
	view.sync(graph)
	var after: float = view.height_at(graph.regions[0]["center"])
	assert_gt(after, before, "the ground the phenomenon raised is visibly higher [T13.1]")


func test_sync_is_lazy():
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph)
	var baked_version := view.baked_version
	view.sync(graph)
	assert_eq(view.baked_version, baked_version, "no version change, no re-bake")


func test_gaea_detail_varies_the_skin_between_basins_yet_anchors_centers():
	# G2.1 [gaea §gaea-gen, §gaea-anchor]: WorldView now bakes the Gaea-detailed field
	# (TerrainField) instead of flat IDW. Between basins the skin varies with the seed —
	# real sub-basin relief is present — while the basin-anchoring zeroes the detail at a
	# center, so height_at (picking/nav/puppet placement) stays seed-independent there.
	var graph := _graph()
	var a := WorldView.new()
	add_child_autofree(a)
	a.sync(graph, 1)
	var b := WorldView.new()
	add_child_autofree(b)
	b.sync(graph, 2)
	var n := graph.regions.size()
	var any_diff := false
	for i in n:
		var mid: Vector2 = (graph.regions[i]["center"] + graph.regions[(i + 1) % n]["center"]) * 0.5
		if a.height_at(mid) != b.height_at(mid):
			any_diff = true
	assert_true(any_diff, "Gaea detail makes the skin seed-dependent between basins")
	var center: Vector2 = graph.regions[0]["center"]
	assert_almost_eq(
		a.height_at(center), b.height_at(center), 1e-4, "basin centers stay anchored across seeds"
	)


func test_bake_grid_is_fine_enough_to_show_detail():
	# G2.2 [gaea §gaea-gen]: the old 24² grid was too coarse to tessellate the Gaea
	# detail; raise it to 64² so sub-basin relief actually shows. walkable_faces (fed to
	# NavWorld) stays consistent: GRID² quads × 2 triangles × 3 vertices.
	assert_eq(WorldView.GRID, 64, "finer bake tessellation [gaea §gaea-gen]")
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, 3)
	assert_eq(
		view.walkable_faces.size(),
		WorldView.GRID * WorldView.GRID * 6,
		"walkable faces scale with the finer grid"
	)


func test_walkable_faces_agree_with_height_at():
	# Phase-Exit G2 invariant [docs/terrain-gaea.md §gaea-invariants]: the navmesh bakes
	# from the SAME detailed field height_at reports, so nav geometry and the visible skin
	# never diverge (nav-safety over the Gaea detail is handled by NavWorld's ledge-span
	# filter, NOT by stripping detail from nav). A detail-heavy seed is deliberately used so
	# the check bites where detail is active — a decouple would fail this here.
	var graph := _graph()
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, 7)
	var faces := view.walkable_faces
	assert_gt(faces.size(), 0, "faces baked")
	for i in range(0, faces.size(), 337):
		var v: Vector3 = faces[i]
		assert_almost_eq(
			v.y,
			view.height_at(Vector2(v.x, v.z)),
			1e-4,
			"nav vertex height == height_at (one field)"
		)
