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
