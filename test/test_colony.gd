extends GutTest


func _colony_of(n: int) -> Colony:
	var c := Colony.new()
	for i in n:
		c.spawn()
	return c


func test_spawn_assigns_sequential_ids():
	var c := _colony_of(3)
	assert_eq(c.gnomes.keys(), [0, 1, 2])
	assert_eq(c.next_id, 3)
	assert_eq(c.gnomes[1].id, 1)


func test_add_existing_gnome_respects_next_id():
	var c := Colony.new()
	var g := GnomeData.new(5)
	c.add(g)
	assert_eq(c.gnomes[5], g)
	assert_eq(c.next_id, 6, "next_id must move past manually added ids")
	assert_eq(c.spawn().id, 6)


func test_remove():
	var c := _colony_of(2)
	c.remove(0)
	assert_false(c.gnomes.has(0))
	assert_eq(c.living().size(), 1)


func test_living_filters_dead():
	var c := _colony_of(4)
	c.gnomes[2].stage = Enums.LifeStage.DEAD
	var alive := c.living()
	assert_eq(alive.size(), 3)
	for g in alive:
		assert_true(g.is_alive())


func test_population_counts_living_only():
	var c := _colony_of(4)
	c.gnomes[0].stage = Enums.LifeStage.DEAD
	assert_eq(c.population(), 3)


func test_vitals_aggregates_living_population():
	var c := _colony_of(3)
	c.gnomes[0].stage = Enums.LifeStage.ADULT
	c.gnomes[1].stage = Enums.LifeStage.ADULT
	c.gnomes[2].stage = Enums.LifeStage.DEAD
	c.gnomes[0].set_need("hunger", 0.4)
	c.gnomes[1].set_need("hunger", 0.8)
	c.gnomes[0].set_trait("curious", 0.2)
	c.gnomes[1].set_trait("curious", 0.6)
	var v: Dictionary = c.vitals()
	assert_eq(v["population"], 2)
	assert_eq(v["by_stage"][Enums.LifeStage.ADULT], 2)
	assert_almost_eq(v["mean_needs"]["hunger"], 0.6, 0.0001)
	assert_almost_eq(v["mean_traits"]["curious"], 0.4, 0.0001)
	# mood = 1 − mean(needs) over the five primary needs [algo §5]
	var expected_mood := 1.0 - (0.4 + 0.8) / 2.0 / 5.0
	assert_almost_eq(v["mean_mood"], expected_mood, 0.0001)


func test_vitals_of_empty_colony_is_sane():
	var c := Colony.new()
	var v: Dictionary = c.vitals()
	assert_eq(v["population"], 0)
	assert_eq(v["mean_mood"], 1.0, "no needs unmet in an empty colony — vacuous but stable")
