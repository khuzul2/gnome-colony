extends GutTest

## T3.3 — score(a) = Σ need²·relief · trait_mod·culture_mod·belief_mod
## + U(0, 0.05) jitter [algo §6]; work trait_mod = 0.7+0.6·industrious [algo §2].


func _hungry_adult(hunger: float, social: float = 0.0) -> GnomeData:
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.ADULT
	g.set_need("hunger", hunger)
	g.set_need("social", social)
	return g


func test_desperate_hunger_makes_eat_win():
	Rng.seed_with(3300)
	var g := _hungry_adult(1.0, 0.4)
	g.add_knowledge("foraging")
	var ctx := {"teacher_available": true}
	var best := ""
	var best_score := -INF
	for action in Actions.available(g, ctx):
		var s := Utility.score(g, action, ctx)
		if s > best_score:
			best_score = s
			best = action
	assert_eq(best, "eat")


func test_need_squared_makes_urgent_dominate():
	var g := _hungry_adult(0.9, 0.5)
	# eat: 0.81·0.9 = 0.729 · socialize: 0.25·0.7 − tiny purpose term — the
	# margin (>0.4) dwarfs the 0.05 jitter cap, so base scores decide.
	assert_true(
		Utility.base_score(g, "eat") > Utility.base_score(g, "socialize") + 0.05,
		"squared urgency beats linear moderate needs by more than max jitter"
	)


func test_side_costs_subtract():
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.ADULT
	g.set_need("purpose", 0.5)
	g.set_need("rest", 0.8)
	# work relieves purpose but costs rest: 0.25·0.6 − 0.64·0.05 = 0.118
	assert_almost_eq(Utility.base_score(g, "work"), (0.25 * 0.6 - 0.64 * 0.05) * 1.0, 0.0001)


func test_work_trait_mod_scales_with_industrious():
	var lazy := GnomeData.new(0)
	lazy.stage = Enums.LifeStage.ADULT
	lazy.set_need("purpose", 1.0)
	lazy.set_trait("industrious", 0.0)
	var keen := GnomeData.new(1)
	keen.stage = Enums.LifeStage.ADULT
	keen.set_need("purpose", 1.0)
	keen.set_trait("industrious", 1.0)
	var ratio := Utility.base_score(keen, "work") / Utility.base_score(lazy, "work")
	assert_almost_eq(ratio, 1.3 / 0.7, 0.0001, "trait_mod = 0.7+0.6·industrious [algo §2]")


func test_belief_and_culture_mods_multiply():
	var g := _hungry_adult(1.0)
	var base := Utility.base_score(g, "eat")
	var modded := Utility.base_score(g, "eat", {"belief_mods": {"eat": 0.5}})
	assert_almost_eq(modded, base * 0.5, 0.0001)
	var cultured := Utility.base_score(g, "eat", {"culture_mods": {"eat": 1.8}})
	assert_almost_eq(cultured, base * 1.8, 0.0001)


func test_jitter_bounded_and_seeded():
	var g := _hungry_adult(0.6)
	Rng.seed_with(3301)
	var with_jitter := Utility.score(g, "eat")
	var base := Utility.base_score(g, "eat")
	assert_between(with_jitter - base, 0.0, 0.05, "jitter is U(0, 0.05)")
	Rng.seed_with(3301)
	assert_eq(Utility.score(g, "eat"), with_jitter, "same seed, same jitter")
