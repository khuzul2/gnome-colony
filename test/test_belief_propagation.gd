extends GutTest

## T6.2 — batched daily propagation [algo §9/§17]:
##   nbr.feeling += 0.04·tie·(src.feeling − nbr.feeling), fear ×1.5.
## Runs every tick (= daily): design-review R3-H1 killed the old
## "every 4 ticks" cadence. Batched = deltas computed from the tick-start
## snapshot, so nothing hops two edges in one day.


func _linked(colony: Colony, a_id: int, b_id: int, weight: float) -> void:
	colony.gnomes[a_id].set_relationship(b_id, "friend", weight)
	colony.gnomes[b_id].set_relationship(a_id, "friend", weight)


func _colony(n: int) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
	return c


func test_feeling_flows_along_edges_at_spec_rate():
	var c := _colony(2)
	_linked(c, 0, 1, 1.0)
	c.gnomes[0].set_feeling("ridge", "awe", 1.0)
	Belief.propagate_tick(c, 1.0)
	assert_almost_eq(c.gnomes[1].get_feeling("ridge", "awe"), 0.04, 0.0001)


func test_fear_propagates_one_and_a_half_times_faster():
	var c := _colony(2)
	_linked(c, 0, 1, 1.0)
	c.gnomes[0].set_feeling("ridge", "fear", 1.0)
	c.gnomes[0].set_feeling("ridge", "awe", 1.0)
	Belief.propagate_tick(c, 1.0)
	assert_almost_eq(c.gnomes[1].get_feeling("ridge", "fear"), 0.06, 0.0001, "fear is loud ×1.5")
	assert_almost_eq(c.gnomes[1].get_feeling("ridge", "awe"), 0.04, 0.0001)


func test_weak_ties_carry_less():
	var c := _colony(2)
	_linked(c, 0, 1, 0.5)
	c.gnomes[0].set_feeling("ridge", "awe", 1.0)
	Belief.propagate_tick(c, 1.0)
	assert_almost_eq(c.gnomes[1].get_feeling("ridge", "awe"), 0.02, 0.0001)


func test_batched_update_never_hops_two_edges_in_one_day():
	var c := _colony(3)
	_linked(c, 0, 1, 1.0)
	_linked(c, 1, 2, 1.0)
	c.gnomes[0].set_feeling("ridge", "fear", 1.0)
	Belief.propagate_tick(c, 1.0)
	assert_gt(c.gnomes[1].get_feeling("ridge", "fear"), 0.0)
	assert_eq(c.gnomes[2].get_feeling("ridge", "fear"), 0.0, "two hops need two days")


func test_neighbours_converge_over_time():
	var c := _colony(2)
	_linked(c, 0, 1, 1.0)
	c.gnomes[0].set_feeling("ridge", "awe", 1.0)
	for day in 200:
		Belief.propagate_tick(c, 1.0)
	var a: float = c.gnomes[0].get_feeling("ridge", "awe")
	var b: float = c.gnomes[1].get_feeling("ridge", "awe")
	assert_almost_eq(a, b, 0.02, "mutual edges average the pair out")
	assert_between(b, 0.4, 0.6, "they meet near the middle")


func test_dead_gnomes_neither_send_nor_receive():
	var c := _colony(2)
	_linked(c, 0, 1, 1.0)
	c.gnomes[0].set_feeling("ridge", "awe", 1.0)
	c.gnomes[0].stage = Enums.LifeStage.DEAD
	Belief.propagate_tick(c, 1.0)
	assert_eq(c.gnomes[1].get_feeling("ridge", "awe"), 0.0, "the dead tell no tales")
