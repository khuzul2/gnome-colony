extends GutTest

## T5.3 — fertility [algo §8/§17]: per-season birth chance per fertile pair
## = 0.15 · food_factor · (1 − crowding); partnered, both Adult, bearer
## aged 20–50.


func _pair(colony: Colony, bearer_age: float = 30.0, other_age: float = 30.0) -> Array:
	var a := colony.spawn()
	a.sex = 0
	a.age = bearer_age
	a.stage = Aging.stage_for_age(bearer_age)
	var b := colony.spawn()
	b.sex = 1
	b.age = other_age
	b.stage = Aging.stage_for_age(other_age)
	a.partner_id = b.id
	b.partner_id = a.id
	return [a, b]


func _births(colony: Colony, food: float, crowding: float) -> int:
	var before := colony.gnomes.size()
	Birth.season_tick(colony, food, crowding)
	return colony.gnomes.size() - before


func test_birth_rate_in_expected_band():
	Rng.seed_with(5300)
	var colony := Colony.new()
	for i in 100:
		_pair(colony)
	var births := _births(colony, 1.0, 0.0)
	assert_between(births, 6, 26, "≈15 births expected from 100 fertile pairs per season")


func test_no_food_no_births():
	Rng.seed_with(5301)
	var colony := Colony.new()
	for i in 50:
		_pair(colony)
	assert_eq(_births(colony, 0.0, 0.0), 0)


func test_full_crowding_stops_births():
	Rng.seed_with(5302)
	var colony := Colony.new()
	for i in 50:
		_pair(colony)
	assert_eq(_births(colony, 1.0, 1.0), 0)


func test_bearer_age_gate():
	Rng.seed_with(5303)
	var colony := Colony.new()
	for i in 40:
		_pair(colony, 55.0, 30.0)
	assert_eq(_births(colony, 1.0, 0.0), 0, "bearer beyond 50 is infertile [algo §8]")


func test_unpartnered_adults_do_not_reproduce():
	Rng.seed_with(5304)
	var colony := Colony.new()
	for i in 40:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
	assert_eq(_births(colony, 1.0, 0.0), 0)


func test_child_joins_colony_with_lineage():
	Rng.seed_with(5305)
	var colony := Colony.new()
	var pair := _pair(colony)
	pair[0].generation = 2
	pair[1].generation = 1
	var born := 0
	while born == 0:
		born = _births(colony, 1.0, 0.0)
	var child: GnomeData = colony.gnomes[colony.next_id - 1]
	assert_eq(child.stage, Enums.LifeStage.INFANT)
	assert_eq(child.generation, 3, "child generation = max(parents) + 1")
	assert_eq(child.home_settlement, pair[0].home_settlement)
	assert_true(child.relationships.has(pair[0].id), "kin edge to bearer")
	assert_eq(child.relationships[pair[0].id]["type"], "kin")
	assert_true(pair[0].relationships[child.id]["type"] == "kin")
