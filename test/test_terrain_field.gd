extends GutTest

## G1.1 — TerrainField is the deterministic, Rng-independent detail source for the
## Gaea terrain skin [gaea §gaea-gen, §gaea-det]. It mirrors Gaea's GaeaNodeNoise
## configuration (SIMPLEX_SMOOTH, FBM octaves/lacunarity, seed+salt, (v+1)/2 → [0,1])
## on the underlying FastNoiseLite, sampled CONTINUOUSLY (height_at needs continuous
## values for picking/nav; Gaea's node samples an integer grid). Anchoring to basins
## is G1.2. These tests pin the two invariants that matter: reproducible from the seed,
## and ZERO draws from the sim's Rng singleton.

const SAMPLES := [
	Vector2(0.0, 0.0),
	Vector2(3.2, -5.1),
	Vector2(-8.0, 7.4),
	Vector2(11.9, 2.3),
]


func _graph(graph_seed: int) -> RegionGraph:
	# RegionGraph.generate draws from Rng — do it BEFORE capturing Rng state so the
	# graph-build draws never confound the TerrainField Rng-independence check.
	Rng.seed_with(graph_seed)
	return RegionGraph.generate(
		{"basin_count": 6, "hazard_density_mult": 1.0, "varied_biomes": true}
	)


func test_same_seed_reproduces_the_field():
	var g := _graph(1)
	var a := TerrainField.new()
	a.generate(g, 4242)
	var b := TerrainField.new()
	b.generate(g, 4242)
	for p in SAMPLES:
		assert_eq(a.detail_at(p), b.detail_at(p), "same seed → identical detail at %s" % p)


func test_different_seed_changes_the_field():
	var g := _graph(1)
	var a := TerrainField.new()
	a.generate(g, 1)
	var b := TerrainField.new()
	b.generate(g, 2)
	var any_diff := false
	for p in SAMPLES:
		if a.detail_at(p) != b.detail_at(p):
			any_diff = true
	assert_true(any_diff, "different seeds → a different detail field")


func test_detail_is_in_unit_range():
	var g := _graph(1)
	var f := TerrainField.new()
	f.generate(g, 7)
	for p in SAMPLES:
		assert_between(f.detail_at(p), 0.0, 1.0, "detail at %s in [0,1]" % p)


func test_generation_draws_nothing_from_the_rng_singleton():
	# THE crux invariant [gaea §gaea-det]: terrain is seeded from its own value and
	# must never advance the sim's Rng stream, or every byte-identical sim-hash test
	# breaks. Build the graph first, then snapshot Rng, then generate + sample.
	var g := _graph(99)
	var before := Rng.get_state()
	var f := TerrainField.new()
	f.generate(g, 12345)
	for p in SAMPLES:
		f.detail_at(p)
	assert_eq(Rng.get_state(), before, "TerrainField must draw ZERO values from the Rng singleton")


# --- G1.2: basin anchoring [gaea §gaea-anchor] ---


func _hi_lo(graph: RegionGraph) -> Dictionary:
	var hi: Dictionary = graph.regions[0]
	var lo: Dictionary = graph.regions[0]
	for r in graph.regions:
		if r["elevation"] > hi["elevation"]:
			hi = r
		if r["elevation"] < lo["elevation"]:
			lo = r
	return {"hi": hi, "lo": lo}


func test_basin_centers_read_their_region_elevation():
	# Detail is attenuated to ~0 at a basin center, so the center still reads (within
	# ANCHOR_TOL, normalized) the region's authored elevation — picking/nav stay right.
	var g := _graph(3)
	var f := TerrainField.new()
	f.generate(g, 555)
	for r in g.regions:
		var got := f.normalize_elevation(f.raw_height(r["center"]))
		var want := f.normalize_elevation(r["elevation"])
		assert_almost_eq(
			got, want, TerrainField.ANCHOR_TOL, "center of basin %d reads its elevation" % r["id"]
		)


func test_basin_ordering_is_preserved():
	# Gaea detail never overrides which basin is higher. hi-vs-lo is a safe proxy for
	# §gaea-anchor's "any two regions": basins sit on a ~10 km ring, far beyond
	# ANCHOR_RADIUS_KM (3.0), so attenuation is 0 at every center and center height =
	# idw_base = the authored elevation order. If ring spacing ever drops below the
	# anchor radius this proxy would need an all-pairs check.
	var g := _graph(4)
	var f := TerrainField.new()
	f.generate(g, 555)
	var ex := _hi_lo(g)
	assert_gt(
		f.raw_height(ex["hi"]["center"]),
		f.raw_height(ex["lo"]["center"]),
		"highest basin stays above lowest"
	)


func test_detail_is_present_between_basins():
	# Between basins (attenuation ~1) the anchored height must differ from the pure-IDW
	# baseline — relief is real, not the old flat interpolation.
	var g := _graph(5)
	var f := TerrainField.new()
	f.generate(g, 555)
	var any_detail := false
	var n := g.regions.size()
	for i in n:
		var a: Vector2 = g.regions[i]["center"]
		var b: Vector2 = g.regions[(i + 1) % n]["center"]
		var mid := (a + b) * 0.5
		if absf(f.raw_height(mid) - f.idw_base(mid)) > 0.0001:
			any_detail = true
	assert_true(any_detail, "detail perturbs the field between basins")
