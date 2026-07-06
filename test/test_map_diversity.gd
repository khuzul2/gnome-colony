extends GutTest

## G4.4 [gaea §gaea-det] — every new game is a different map. The map is an injective-enough
## function of the seed across BOTH halves: (a) the sim's RegionGraph basin layout, and (b) the
## Gaea terrain detail — so no two distinct seeds collide on the same world. And the blank-seed
## path is entropy-derived: a blank WorldConfig.seed (== 0) rolls a fresh seed from Rng
## (randomized at boot on Godot 4.7), NOT a fixed constant, so successive new games differ.
## A TYPED seed stays intentionally reproducible (shareable). This pins today's behaviour so a
## future boot-seed or engine-default change cannot silently break map diversity — it does NOT
## relax T15.2's "blank seed rolled through Rng, reproducible under a seeded Rng in tests".


func _graph_signature(seed_value: int) -> Array:
	Rng.seed_with(seed_value)
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var sig := []
	for r in graph.regions:
		sig.append([r["center"].x, r["center"].y, r["elevation"], r["biome"]])
	return sig


func _terrain_hash(seed_value: int) -> String:
	Rng.seed_with(seed_value)
	var graph := RegionGraph.generate(Tuning.resolve(WorldConfig.new())["world"])
	var view := WorldView.new()
	add_child_autofree(view)
	view.sync(graph, seed_value)
	var samples := []
	for i in 40:
		var p := Vector2(-10.0 + i * 0.5, i * 0.3 - 6.0)
		samples.append(view.height_at(p))
	return JSON.stringify(samples).md5_text()


func test_distinct_seeds_give_distinct_basin_layouts():
	# (a) The sim's world shape differs across seeds — centers/elevations/biomes not all equal.
	var seeds := [1, 2, 42, 1831, 99999]
	var sigs := []
	for s in seeds:
		sigs.append(_graph_signature(s))
	for i in seeds.size():
		for j in range(i + 1, seeds.size()):
			assert_ne(
				sigs[i], sigs[j], "seeds %d and %d differ in basin layout" % [seeds[i], seeds[j]]
			)


func test_distinct_seeds_give_distinct_terrain():
	# (b) The Gaea detail differs across seeds — no two seeds collide on the same ground.
	var seeds := [1, 2, 42, 1831, 99999]
	var seen := {}
	for s in seeds:
		var h := _terrain_hash(s)
		assert_false(seen.has(h), "seed %d bakes distinct terrain (no collision)" % s)
		seen[h] = true


func test_a_blank_seed_is_entropy_derived_not_a_constant():
	# A blank WorldConfig.seed (== 0) resolves through the wizard to a value ROLLED from Rng,
	# so it differs whenever the Rng state differs — and Rng is randomized at boot, so it
	# differs per launch. Two fresh wizards under different Rng states roll different seeds.
	Rng.seed_with(111)
	var wa: NewGameWizard = autofree(NewGameWizard.new())
	var seed_a := wa.start().seed
	Rng.seed_with(222)
	var wb: NewGameWizard = autofree(NewGameWizard.new())
	var seed_b := wb.start().seed
	assert_ne(seed_a, seed_b, "a blank seed is rolled from Rng — differs with the Rng state")
	assert_gt(seed_a, 0, "the rolled seed is a real value, not the 0 blank sentinel")


func test_a_typed_seed_is_kept_verbatim_shareable():
	# The flip side: a TYPED (non-zero) seed is reproducible — kept verbatim, never re-rolled —
	# so a shared seed reproduces the same map (T15.2's contract, unrelaxed).
	Rng.seed_with(333)
	var w: NewGameWizard = autofree(NewGameWizard.new())
	w.set_world("seed", 555555)
	assert_eq(w.start().seed, 555555, "a typed seed is kept verbatim (shareable)")
