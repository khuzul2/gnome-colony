extends GutTest

## Phase-Exit 3: a hungry colony with a food source recovers (mean hunger
## falls) over seeded ticks with NO scripting — self-direction via needs +
## utility only.


func test_hungry_colony_recovers_by_choosing_to_eat():
	Rng.seed_with(3900)
	var colony := Colony.new()
	for i in 6:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_need("hunger", 0.8)
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)

	var initial_mean: float = colony.vitals()["mean_needs"]["hunger"]
	for day in 14:
		Needs.tick(colony, 1.0)
		var ctx := {"food_available": food.current > 0.0, "food_node": food}
		for g in colony.living():
			Act.apply(g, Decide.choose(g, ctx), ctx)
		food.regrow(1.0)
		Projects.tick(colony, 1.0)
		Mortality.tick(colony, 1.0)

	var final_mean: float = colony.vitals()["mean_needs"]["hunger"]
	assert_eq(colony.population(), 6, "nobody starves with food on hand")
	assert_lt(final_mean, initial_mean, "mean hunger falls — the colony fed itself")
	assert_lt(final_mean, 0.3, "recovered hunger sits well below the desperate line")
	assert_true(food.current < 100.0 or food.regrowth >= 6.0, "food was actually consumed")
