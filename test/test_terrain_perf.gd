extends GutTest

## G4.2 [gaea §gaea-gen] — the one-time terrain re-bake (on a seed change or a phenomenon
## reshape that bumps `version`) stays under BAKE_BUDGET_MS. This is a ONE-TIME cost, NOT
## per-tick — it never touches test_scale's per-tick budget. Calibration mirrors test_scale
## (Phase-Exit 11 ruling): this shared ~2.10 GHz container runs ~2× the mid-tier-desktop
## reference, so the STRICT BAKE_BUDGET_MS binds on reference hardware while a 2× tripwire
## governs HERE; the raw number prints every run. Wall-clock via Time (banned in sim logic
## only — fine in test code, same precedent as test_scale).

const REFERENCE_BUDGET_MS := 50.0  ## [gaea §gaea-gen] BAKE_BUDGET_MS — binds on reference desktop
const CONTAINER_TRIPWIRE_MS := 100.0  ## 2× — this container is ~half reference single-thread


func test_a_full_rebake_is_under_budget():
	Rng.seed_with(64200)
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, 1)  # warm bake
	var start := Time.get_ticks_usec()
	view.sync(graph, 2)  # a seed change forces a full re-bake (same path a reshape takes)
	var elapsed_ms := (Time.get_ticks_usec() - start) / 1000.0
	gut.p(
		(
			"terrain re-bake: %.1f ms (reference budget %.0f ms · container tripwire %.0f ms)"
			% [elapsed_ms, REFERENCE_BUDGET_MS, CONTAINER_TRIPWIRE_MS]
		)
	)
	assert_lt(elapsed_ms, CONTAINER_TRIPWIRE_MS, "one-time re-bake under the calibrated tripwire")


func test_rebake_is_lazy_only_on_version_or_seed_change():
	# The budget is affordable precisely because the bake is lazy — no re-bake without a
	# version bump or seed change, so it is never a per-tick cost.
	Rng.seed_with(64201)
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, 5)
	var baked := view.baked_version
	view.sync(graph, 5)  # same seed + version ⇒ no re-bake
	assert_eq(view.baked_version, baked, "no version/seed change ⇒ no re-bake")
	graph.reshape(0, 1.0)  # a phenomenon reshape bumps version
	view.sync(graph, 5)
	assert_ne(view.baked_version, baked, "a reshape (version bump) re-bakes")
