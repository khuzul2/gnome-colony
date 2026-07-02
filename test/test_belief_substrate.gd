extends GutTest

## T6.1 — scalar substrate [algo §9/§17]: per-(subject, axis) feelings.
## Appraisal write: feeling += intensity·susceptibility − habituation;
## habituation +0.15/repeat, −0.02/day; feelings relax −0.03·(f−base)/day
## (half-life ≈ 23 days). susceptibility(traits) has no closed formula in
## the spec — implemented as 0.5 + 0.5·relevant_trait (fear→timid,
## faith→devout, awe→curious, reverence→devout), ∈ [0.5, 1].


func _gnome(timid: float = 0.5) -> GnomeData:
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.ADULT
	g.set_trait("timid", timid)
	return g


func test_susceptibility_scales_with_relevant_trait():
	var brave := _gnome(0.0)
	var coward := _gnome(1.0)
	Belief.appraise(brave, "eastern_ridge", "fear", 0.6, "landslide")
	Belief.appraise(coward, "eastern_ridge", "fear", 0.6, "landslide")
	assert_almost_eq(brave.get_feeling("eastern_ridge", "fear"), 0.6 * 0.5, 0.0001)
	assert_almost_eq(coward.get_feeling("eastern_ridge", "fear"), 0.6 * 1.0, 0.0001)


func test_habituation_dampens_repeats():
	# intensity 0.3 keeps the running total below the 1.0 clamp so the
	# dampening arithmetic stays observable.
	var g := _gnome(1.0)
	Belief.appraise(g, "ridge", "fear", 0.3, "landslide")
	var first: float = g.get_feeling("ridge", "fear")
	assert_almost_eq(first, 0.3, 0.0001)
	Belief.appraise(g, "ridge", "fear", 0.3, "landslide")
	var second_delta: float = g.get_feeling("ridge", "fear") - first
	assert_almost_eq(second_delta, 0.3 - 0.15, 0.0001, "second hit lands 0.15 weaker")
	Belief.appraise(g, "ridge", "fear", 0.3, "landslide")
	var after_third: float = g.get_feeling("ridge", "fear")
	assert_almost_eq(after_third, 0.45, 0.0001, "third hit (0.3 − 0.30) no longer lands")


func test_habituation_recovers_over_time():
	var colony := Colony.new()
	var g := _gnome(1.0)
	colony.add(g)
	Belief.appraise(g, "ridge", "fear", 0.6, "landslide")
	assert_almost_eq(g.habituation["landslide"], 0.15, 0.0001)
	for day in 8:
		Belief.decay_tick(colony, 1.0)
	assert_eq(g.habituation.get("landslide", 0.0), 0.0, "0.15 fades at 0.02/day in ~8 days")


func test_feelings_relax_proportionally():
	var colony := Colony.new()
	var g := _gnome()
	colony.add(g)
	g.set_feeling("spring", "awe", 0.8)
	Belief.decay_tick(colony, 1.0)
	assert_almost_eq(g.get_feeling("spring", "awe"), 0.8 - 0.03 * 0.8, 0.0001)
	for day in 22:
		Belief.decay_tick(colony, 1.0)
	assert_between(
		g.get_feeling("spring", "awe"), 0.35, 0.45, "≈half-life 23 days [algo §9] (0.8→~0.4)"
	)


func test_negative_intensity_never_writes():
	var g := _gnome(1.0)
	g.habituation["landslide"] = 1.0
	Belief.appraise(g, "ridge", "fear", 0.2, "landslide")
	assert_eq(g.get_feeling("ridge", "fear"), 0.0, "habituation can null but never invert a hit")
