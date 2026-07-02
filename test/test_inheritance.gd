extends GutTest

## T5.4 — inheritance per trait [algo §8/§17]:
##   child.trait = clamp(0.5·(p1+p2) + N(0, 0.05)), plus a rare large
##   mutation: 2% chance of an extra +N(0, 0.2). Skills are NOT inherited.

const BIRTHS := 500


func _parents(colony: Colony) -> Array:
	var pair := []
	for sex in [0, 1]:
		var g := colony.spawn()
		g.sex = sex
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_skill("foraging", 0.9)
		g.add_knowledge("foraging")
		pair.append(g)
	pair[0].partner_id = pair[1].id
	pair[1].partner_id = pair[0].id
	return pair


func test_child_traits_blend_around_parent_mean():
	Rng.seed_with(5400)
	var colony := Colony.new()
	var pair := _parents(colony)
	pair[0].set_trait("curious", 0.8)
	pair[1].set_trait("curious", 0.4)
	var total := 0.0
	var n := 50
	for i in n:
		var child := Birth.spawn_infant(colony, pair[0], pair[1])
		total += child.traits["curious"]
		assert_between(child.traits["curious"], 0.3, 0.9, "within a wide band of the 0.6 mean")
	assert_almost_eq(total / n, 0.6, 0.05, "children average the parent mean")


func test_skills_are_not_inherited():
	Rng.seed_with(5401)
	var colony := Colony.new()
	var pair := _parents(colony)
	var child := Birth.spawn_infant(colony, pair[0], pair[1])
	assert_eq(child.skills, {}, "skills must be taught, never inherited [algo §8]")
	assert_eq(child.knowledge, [])


func test_rare_large_mutation_frequency():
	Rng.seed_with(5402)
	var colony := Colony.new()
	var pair := _parents(colony)
	var large_deviations := 0
	var draws := 0
	for i in BIRTHS:
		var child := Birth.spawn_infant(colony, pair[0], pair[1])
		for key in Enums.TRAIT_KEYS:
			draws += 1
			if absf(child.traits[key] - 0.5) > 0.2:
				large_deviations += 1
	# P(|N(0,0.05)| > 0.2) ≈ 6e-5 — essentially only large-mutation rolls
	# (2% × P(|N(0,~0.206)| > 0.2) ≈ 0.66%) land out here. 4000 draws ⇒
	# ≈26 expected; [5, 80] is a generous seeded band.
	assert_between(large_deviations, 5, 80, "rare large mutations occur at ≈0.7% of trait draws")
	assert_eq(draws, BIRTHS * Enums.TRAIT_KEYS.size())


func test_untraited_scaffold_spawn_keeps_defaults():
	Rng.seed_with(5403)
	var colony := Colony.new()
	var orphan := Birth.spawn_infant(colony)
	for key in Enums.TRAIT_KEYS:
		assert_eq(orphan.traits[key], 0.5, "no parents, no inheritance — neutral defaults")
