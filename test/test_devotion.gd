extends GutTest

## T8.1 — devotion [algo §10]: D = Σ faith-in-you across the living (so it
## grows with belief AND population); d̄ = D/pop; flavor_balance =
## mean(awe − fear) toward you. "You" is the substrate subject
## "unseen_will" (the attribution seed's wording, §9).


func _believer(colony: Colony, faith: float, awe: float = 0.0, fear: float = 0.0) -> GnomeData:
	var g := colony.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	g.set_feeling(Devotion.YOU, "faith", faith)
	g.set_feeling(Devotion.YOU, "awe", awe)
	g.set_feeling(Devotion.YOU, "fear", fear)
	return g


func test_total_devotion_sums_faith():
	var c := Colony.new()
	_believer(c, 0.5)
	_believer(c, 0.3)
	assert_almost_eq(Devotion.total(c), 0.8, 0.0001)


func test_devotion_grows_with_population_at_equal_faith():
	var small := Colony.new()
	for i in 4:
		_believer(small, 0.5)
	var town := Colony.new()
	for i in 40:
		_believer(town, 0.5)
	assert_gt(Devotion.total(town), Devotion.total(small), "total weight scales with the flock")
	assert_almost_eq(
		Devotion.per_capita(small), Devotion.per_capita(town), 0.0001, "…but depth does not"
	)


func test_dead_believers_do_not_count():
	var c := Colony.new()
	var g := _believer(c, 1.0)
	_believer(c, 0.4)
	g.stage = Enums.LifeStage.DEAD
	assert_almost_eq(Devotion.total(c), 0.4, 0.0001)


func test_flavor_balance_sign():
	var loved := Colony.new()
	_believer(loved, 0.5, 0.8, 0.1)
	_believer(loved, 0.5, 0.6, 0.2)
	assert_gt(Devotion.flavor_balance(loved), 0.0, "love-faith: awe outweighs fear")
	var feared := Colony.new()
	_believer(feared, 0.5, 0.1, 0.9)
	assert_lt(Devotion.flavor_balance(feared), 0.0, "terror-faith")


func test_empty_colony_is_faithless_but_stable():
	var c := Colony.new()
	assert_eq(Devotion.total(c), 0.0)
	assert_eq(Devotion.per_capita(c), 0.0)
	assert_eq(Devotion.flavor_balance(c), 0.0)
