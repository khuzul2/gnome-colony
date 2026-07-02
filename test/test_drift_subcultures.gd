extends GutTest

## T6.5 — drift & subcultures [algo §9]: each transmission of a belief
## object carries a 3% mutation chance (details shift → traditions
## diverge); gnomes clustering at belief-vector distance ≥ 0.5 form a
## distinct subculture (greedy seed clustering over sorted ids —
## deterministic; the spec names no algorithm).


func _colony(n: int) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
	return c


func test_transmission_adds_holder():
	var c := _colony(2)
	c.beliefs.append(BeliefObject.make("rite", "harvest_feast", "awe", 0.8, [0]))
	Rng.seed_with(6500)
	Belief.transmit(c, 0, 1)
	assert_true(1 in c.beliefs[0]["holders"])
	assert_eq(c.beliefs[0]["holders"].size(), 2)


func test_drift_occurs_at_three_percent():
	Rng.seed_with(6501)
	var mutations := 0
	const TRIALS := 2000
	for i in TRIALS:
		var c := _colony(2)
		c.beliefs.append(BeliefObject.make("rite", "feast", "awe", 0.8, [0]))
		Belief.transmit(c, 0, 1)
		if c.beliefs[0]["variant"] > 0:
			mutations += 1
	assert_between(mutations, 30, 95, "≈60 mutations expected in 2000 transmissions at 3%")


func test_transmission_is_idempotent_for_existing_holders():
	var c := _colony(2)
	c.beliefs.append(BeliefObject.make("rite", "feast", "awe", 0.8, [0, 1]))
	Rng.seed_with(6502)
	Belief.transmit(c, 0, 1)
	assert_eq(c.beliefs[0]["holders"].size(), 2, "no duplicate holders")


func test_homogeneous_colony_is_one_subculture():
	var c := _colony(6)
	for g in c.living():
		g.set_feeling("unseen_will", "faith", 0.8)
	assert_eq(Belief.subcultures(c).size(), 1)


func test_divergent_beliefs_split_a_subculture():
	var c := _colony(6)
	for g in c.living():
		if g.id < 3:
			g.set_feeling("unseen_will", "faith", 0.9)
			g.set_feeling("eastern_ridge", "fear", 0.9)
		else:
			g.set_feeling("unseen_will", "faith", 0.1)
			g.set_feeling("eastern_ridge", "fear", 0.1)
	var clusters := Belief.subcultures(c)
	assert_eq(clusters.size(), 2, "belief-vector distance ≥0.5 ⇒ schism candidates [algo §9/§14]")
	assert_eq(clusters[0], [0, 1, 2])
	assert_eq(clusters[1], [3, 4, 5])


func test_mild_disagreement_stays_one_culture():
	var c := _colony(6)
	for g in c.living():
		g.set_feeling("unseen_will", "faith", 0.5 + 0.03 * g.id)
	assert_eq(Belief.subcultures(c).size(), 1, "distance < 0.5 is just diversity")
