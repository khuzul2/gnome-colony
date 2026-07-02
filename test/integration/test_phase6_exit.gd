extends GutTest

## Phase-Exit 6: a seeded scenario crystallizes a place-taboo and gnomes'
## utility for acting there drops (avoidance). Note the emergent shape the
## numbers force: fear relaxes 3%/day and habituation blunts repeats of
## the SAME act, so a single shock can never hold ≥0.7 for a season —
## only sustained, VARIED dread crystallizes ("you must vary or escalate",
## algo §9). Three distinct frights across the season keep the ridge
## terrifying long enough for the taboo to set.


func test_sustained_varied_dread_births_a_taboo_and_avoidance():
	Rng.seed_with(6900)
	var colony := Colony.new()
	for i in 8:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("timid", 0.8)

	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.belief_formed.connect(listener)

	var frights := ["landslide", "quake", "rockfall", "sinkhole"]
	for day in 32:
		if day % 8 == 0:
			var fright: String = frights[day / 8]
			for g in colony.living():
				Belief.appraise(g, "eastern_ridge", "fear", 1.0, fright)
		Belief.propagate_tick(colony, 1.0)
		Belief.decay_tick(colony, 1.0)
		Belief.crystallize_tick(colony, 1.0)
	EventBus.belief_formed.disconnect(listener)

	assert_eq(events.size(), 1, "one taboo crystallized")
	assert_eq(events[0]["kind"], "taboo")
	assert_eq(events[0]["subject"], "eastern_ridge")

	# Avoidance: the same gnome scores work-at-the-ridge below neutral work.
	var mod := Belief.place_mod(colony, "eastern_ridge")
	assert_lt(mod, 1.0)
	var worker := GnomeData.new(99)
	worker.stage = Enums.LifeStage.ADULT
	worker.set_need("purpose", 0.8)
	var neutral := Utility.base_score(worker, "work")
	var at_ridge := Utility.base_score(worker, "work", {"belief_mods": {"work": mod}})
	assert_lt(at_ridge, neutral, "the colony now avoids the very ground you marked")


func test_single_shock_fades_without_crystallizing():
	Rng.seed_with(6901)
	var colony := Colony.new()
	for i in 8:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("timid", 0.8)
	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.belief_formed.connect(listener)
	for g in colony.living():
		Belief.appraise(g, "eastern_ridge", "fear", 1.0, "landslide")
	for day in 40:
		Belief.propagate_tick(colony, 1.0)
		Belief.decay_tick(colony, 1.0)
		Belief.crystallize_tick(colony, 1.0)
	EventBus.belief_formed.disconnect(listener)
	assert_eq(events.size(), 0, "one fright is a story, not a taboo — memory fades")
