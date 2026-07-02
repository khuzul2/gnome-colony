extends GutTest

const SEQUENCE_DRAWS := 64
const GAUSS_DRAWS := 10000


func _draw_mixed_sequence() -> Array:
	# One draw of every API method, repeated — proves the whole surface
	# replays identically from a seed, not just randf().
	var out := []
	for i in SEQUENCE_DRAWS:
		out.append(Rng.randf())
		out.append(Rng.randf_range(-3.0, 7.0))
		out.append(Rng.randi_range(0, 1000))
		out.append(Rng.gauss(0.5, 0.15))
		out.append(Rng.chance(0.5))
	return out


func test_same_seed_yields_identical_sequences():
	Rng.seed_with(12345)
	var first := _draw_mixed_sequence()
	Rng.seed_with(12345)
	var second := _draw_mixed_sequence()
	assert_eq(first, second, "identical seed must replay the identical stream")


func test_different_seeds_yield_different_sequences():
	Rng.seed_with(1)
	var first := _draw_mixed_sequence()
	Rng.seed_with(2)
	var second := _draw_mixed_sequence()
	assert_ne(first, second, "different seeds must diverge")


func test_gauss_mean_approaches_mu():
	Rng.seed_with(777)
	var total := 0.0
	for i in GAUSS_DRAWS:
		total += Rng.gauss(0.5, 0.15)
	var mean := total / GAUSS_DRAWS
	# se = sd/sqrt(n) = 0.0015; 0.01 is a generous ~6.7 sigma band.
	assert_almost_eq(mean, 0.5, 0.01, "gauss(mu, sd) mean must approach mu over 10k draws")


func test_randf_range_respects_bounds():
	Rng.seed_with(42)
	for i in SEQUENCE_DRAWS:
		var v := Rng.randf_range(2.0, 3.0)
		assert_between(v, 2.0, 3.0)


func test_randi_range_respects_bounds_and_hits_them():
	Rng.seed_with(42)
	var seen := {}
	for i in 200:
		var v := Rng.randi_range(0, 3)
		assert_between(v, 0, 3)
		seen[v] = true
	assert_eq(seen.size(), 4, "all values of a small int range should occur in 200 draws")


func test_chance_extremes():
	Rng.seed_with(9)
	for i in SEQUENCE_DRAWS:
		assert_false(Rng.chance(0.0), "chance(0) is never true")
		assert_true(Rng.chance(1.0), "chance(1) is always true")
