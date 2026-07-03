extends GutTest

## T11.3 — promotion fidelity [algo §14]: promoting an individual out of
## a settlement aggregate SAMPLES feelings from the aggregates; demoting
## folds the richer state back. No head-count is ever lost; scalar means
## survive a round-trip within sampling tolerance ("minor divergence is
## acceptable — and, under the Eye, intended"). Trait sampling sd 0.15
## mirrors the §5 founder rolls (interpretive, documented).


func _town(adults: float, children: float = 0.0) -> Settlement:
	var s := Settlement.new(0, 50.0, 2.0)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	s.by_stage[Enums.LifeStage.CHILD] = children
	s.mean_traits["curious"] = 0.7
	s.belief["faith"] = 0.5
	s.belief["fear"] = 0.2
	return s


func test_materialize_conserves_headcount():
	Rng.seed_with(11300)
	var c := Colony.new()
	var s := _town(20.0, 4.0)
	var before := s.pop()
	var drawn := Promotion.materialize(c, s, 6)
	assert_eq(drawn.size(), 6)
	assert_almost_eq(s.pop() + 6.0, before, 0.0001, "no gnome minted from nothing [§14]")
	assert_eq(c.population(), 6, "…and each walks the colony as an individual")
	for g in drawn:
		assert_eq(g.home_settlement, 0)
		assert_true(g.is_alive())


func test_materialized_feelings_are_sampled_from_aggregates():
	Rng.seed_with(11301)
	var c := Colony.new()
	var s := _town(10.0)
	var drawn := Promotion.materialize(c, s, 3)
	for g in drawn:
		assert_almost_eq(
			g.get_feeling(Devotion.YOU, "faith"),
			0.5,
			0.0001,
			"§14: promotion samples feelings from the aggregates"
		)
		assert_almost_eq(g.get_feeling(Devotion.YOU, "fear"), 0.2, 0.0001)


func test_materialized_traits_scatter_around_the_mean():
	Rng.seed_with(11302)
	var c := Colony.new()
	var s := _town(200.0)
	var drawn := Promotion.materialize(c, s, 40)
	var total := 0.0
	var spread := false
	for g in drawn:
		total += g.traits["curious"]
		if absf(g.traits["curious"] - 0.7) > 0.01:
			spread = true
	assert_almost_eq(total / 40.0, 0.7, 0.1, "unbiased around the settlement mean")
	assert_true(spread, "…but individuals, not clones")


func test_round_trip_preserves_the_aggregate():
	Rng.seed_with(11303)
	var c := Colony.new()
	var s := _town(30.0, 6.0)
	var pop_before := s.pop()
	var faith_before: float = s.belief["faith"]
	var curious_before: float = s.mean_traits["curious"]
	var drawn := Promotion.materialize(c, s, 8)
	Promotion.dematerialize(c, s, drawn)
	assert_almost_eq(s.pop(), pop_before, 0.0001, "promote→demote round-trip conserves people")
	assert_eq(c.population(), 0, "the individuals folded away")
	assert_almost_eq(s.belief["faith"], faith_before, 0.05, "scalar means within tolerance")
	assert_almost_eq(s.mean_traits["curious"], curious_before, 0.1)


func test_demotion_folds_lived_experience_back():
	Rng.seed_with(11304)
	var c := Colony.new()
	var s := _town(10.0)
	var drawn := Promotion.materialize(c, s, 2)
	# Under the Eye their fates diverged: one mastered a craft, both saw
	# the unseen will move.
	var hero: GnomeData = drawn[0]
	hero.set_skill("smithing", 0.95)
	hero.add_knowledge("smithing")
	for g in drawn:
		g.set_feeling(Devotion.YOU, "faith", 1.0)
	Promotion.dematerialize(c, s, drawn)
	assert_true(
		c.settlement_knowledge[0].has("smithing"),
		"the craft survives the fold [§7 per-settlement knowledge]"
	)
	assert_gt(s.belief["faith"], 0.5, "…and the witnessed faith pulls the aggregate up [§14]")


func test_materialize_draws_from_the_biggest_buckets():
	Rng.seed_with(11305)
	var c := Colony.new()
	var s := _town(20.0, 2.0)
	var drawn := Promotion.materialize(c, s, 4)
	var adult_count := 0
	for g in drawn:
		if g.stage == Enums.LifeStage.ADULT:
			adult_count += 1
		assert_eq(g.stage, Aging.stage_for_age(g.age), "sampled age agrees with the bucket")
	assert_gte(adult_count, 3, "a mostly-adult town yields mostly adults")


func test_cannot_materialize_more_than_exist():
	Rng.seed_with(11306)
	var c := Colony.new()
	var s := _town(3.0)
	var drawn := Promotion.materialize(c, s, 10)
	assert_eq(drawn.size(), 3, "the aggregate can only yield who it holds")
	assert_almost_eq(s.pop(), 0.0, 0.0001)
