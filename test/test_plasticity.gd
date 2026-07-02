extends GutTest

## T5.5 — plasticity [algo §2/§17]: while young, trait += 0.02·(env_mean −
## trait)/day; fades to ~0 by Adult (linear taper across Adolescence —
## interpretive: §2 gives "0.02/day while young → ~0 by Adult" without a
## curve). Constitutional (outlier) traits are exempt [algo §2].


func _colony_with_culture(mean_curious: float) -> Colony:
	var c := Colony.new()
	for i in 4:
		var adult := c.spawn()
		adult.age = 30.0
		adult.stage = Enums.LifeStage.ADULT
		adult.set_trait("curious", mean_curious)
	return c


func _child(colony: Colony, age: float, curious: float) -> GnomeData:
	var g := colony.spawn()
	g.age = age
	g.stage = Aging.stage_for_age(age)
	g.set_trait("curious", curious)
	return g


func test_child_drifts_toward_culture_mean():
	var c := _colony_with_culture(0.9)
	var kid := _child(c, 8.0, 0.1)
	var env: float = c.vitals()["mean_traits"]["curious"]
	Culture.plasticity_tick(c, 1.0)
	var expected := 0.1 + 0.02 * (env - 0.1)
	assert_almost_eq(kid.traits["curious"], expected, 0.0001)


func test_drift_works_downward_too():
	var c := _colony_with_culture(0.1)
	var kid := _child(c, 8.0, 0.9)
	Culture.plasticity_tick(c, 1.0)
	assert_lt(kid.traits["curious"], 0.9)


func test_adolescent_plasticity_tapers():
	var c := _colony_with_culture(0.9)
	var teen := _child(c, 17.0, 0.1)
	var env: float = c.vitals()["mean_traits"]["curious"]
	Culture.plasticity_tick(c, 1.0)
	# age 17 is halfway through 14→20, so half strength: 0.01/day.
	var expected := 0.1 + 0.01 * (env - 0.1)
	assert_almost_eq(teen.traits["curious"], expected, 0.0001)


func test_adults_do_not_drift():
	var c := _colony_with_culture(0.9)
	var grown := _child(c, 30.0, 0.1)
	Culture.plasticity_tick(c, 1.0)
	assert_eq(grown.traits["curious"], 0.1)


func test_constitutional_traits_are_exempt():
	var c := _colony_with_culture(0.9)
	var kid := _child(c, 8.0, 0.1)
	kid.constitutional_traits = ["curious"]
	Culture.plasticity_tick(c, 1.0)
	assert_eq(kid.traits["curious"], 0.1, "outlier traits never wash back to the mean [algo §2]")
