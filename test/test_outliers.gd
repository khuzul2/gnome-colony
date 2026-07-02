extends GutTest

## T5.7 — outlier births [algo §8]: p_outlier ≈ 0.01/birth, then a type is
## rolled (uniform across genius/touched/mutant/longlived — interpretive,
## spec lists the types without weights). Mutants carry out-of-band,
## heritable trait values; the touched carry high prophet-ripeness.

const MANY_BIRTHS := 2000


func _pair(colony: Colony) -> Array:
	var pair := []
	for sex in [0, 1]:
		var g := colony.spawn()
		g.sex = sex
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		pair.append(g)
	pair[0].partner_id = pair[1].id
	pair[1].partner_id = pair[0].id
	return pair


func _birth_until(colony: Colony, pair: Array, type: String, cap: int = 5000) -> GnomeData:
	for i in cap:
		var child := Birth.spawn_infant(colony, pair[0], pair[1])
		if child.outlier_type == type:
			return child
	return null


func test_outliers_occur_at_expected_rate():
	Rng.seed_with(5700)
	var colony := Colony.new()
	var pair := _pair(colony)
	var outliers := 0
	for i in MANY_BIRTHS:
		if Birth.spawn_infant(colony, pair[0], pair[1]).outlier_type != "":
			outliers += 1
	assert_between(outliers, 8, 40, "≈20 outliers expected in 2000 births at p=0.01")


func test_mutant_trait_exceeds_band_and_is_constitutional():
	Rng.seed_with(5701)
	var colony := Colony.new()
	var pair := _pair(colony)
	var mutant := _birth_until(colony, pair, "mutant")
	assert_not_null(mutant, "a mutant is born within 5000 seeded births")
	var out_of_band := false
	for key in mutant.constitutional_traits:
		if mutant.traits[key] > 1.0 or mutant.traits[key] < 0.0:
			out_of_band = true
	assert_true(out_of_band, "a mutant trait sits outside [0,1] [algo §8]")
	assert_false(mutant.constitutional_traits.is_empty())


func test_mutant_traits_are_heritable_unclamped():
	Rng.seed_with(5702)
	var colony := Colony.new()
	var mutants := []
	for sex in [0, 1]:
		var m := colony.spawn()
		m.sex = sex
		m.age = 30.0
		m.stage = Enums.LifeStage.ADULT
		m.outlier_type = "mutant"
		m.traits["timid"] = 1.4
		m.constitutional_traits = ["timid"]
		mutants.append(m)
	mutants[0].partner_id = mutants[1].id
	mutants[1].partner_id = mutants[0].id
	var child := Birth.spawn_infant(colony, mutants[0], mutants[1])
	assert_gt(child.traits["timid"], 1.0, "blend of two 1.4s stays out of band — no clamp")
	assert_true("timid" in child.constitutional_traits, "the lineage marker propagates")


func test_touched_have_high_prophet_affinity():
	Rng.seed_with(5703)
	var colony := Colony.new()
	var pair := _pair(colony)
	var touched := _birth_until(colony, pair, "touched")
	assert_not_null(touched)
	assert_eq(touched.prophet_affinity, 1.0, "prime prophet material [algo §8/§12]")


func test_genius_curiosity_pinned_constitutional():
	Rng.seed_with(5704)
	var colony := Colony.new()
	var pair := _pair(colony)
	var genius := _birth_until(colony, pair, "genius")
	assert_not_null(genius)
	assert_eq(genius.traits["curious"], 1.0)
	assert_true("curious" in genius.constitutional_traits)


func test_normal_births_have_no_marker():
	Rng.seed_with(5705)
	var colony := Colony.new()
	var pair := _pair(colony)
	var child := Birth.spawn_infant(colony, pair[0], pair[1])
	if child.outlier_type == "":
		assert_eq(child.prophet_affinity, 0.0)
		assert_eq(child.constitutional_traits, [])
