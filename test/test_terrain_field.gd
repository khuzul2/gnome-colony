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
