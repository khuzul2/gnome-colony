extends GutTest

## T8.3 — magnitude & the temptation [algo §10/§11/§17]:
##   magnitude = base·(1 + 0.9·log10(1 + M)), M = Σ faith (social mass)
##   valence_potency: malevolent ×1.4, benevolent ×0.6, neutral ×1 (δ=0.4)
## Cruelty lands harder than kindness — that is the bargain.


func _flock(n: int, faith: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_feeling(Devotion.YOU, "faith", faith)
	return c


func test_magnitude_grows_monotonically_and_sublinearly():
	var lone := Devotion.magnitude_multiplier(_flock(4, 0.5))
	var town := Devotion.magnitude_multiplier(_flock(400, 0.5))
	var civ := Devotion.magnitude_multiplier(_flock(4000, 0.5))
	assert_gt(town, lone)
	assert_gt(civ, town)
	assert_lt(civ - town, (town - lone) * 10.0, "log-scaled: growth flattens, never runs away")
	assert_almost_eq(lone, 1.0 + 0.9 * (log(3.0) / log(10.0)), 0.0001, "M=2: 1+0.9·log10(3)")


func test_empty_world_is_baseline():
	assert_almost_eq(Devotion.magnitude_multiplier(Colony.new()), 1.0, 0.0001)


func test_valence_potency_delta():
	assert_almost_eq(Devotion.valence_potency("malevolent"), 1.4, 0.0001)
	assert_almost_eq(Devotion.valence_potency("benevolent"), 0.6, 0.0001)
	assert_almost_eq(Devotion.valence_potency("neutral"), 1.0, 0.0001)


func test_cruelty_outhits_kindness_through_the_runner():
	var colony := _flock(50, 0.6)
	var world := WorldState.new()
	world.affordances["fields"] = ["farmland", "drought"]
	Rng.seed_with(8300)
	var blight := Influence.cast_act(colony, world, Catalog.defs()["the_blight"], "fields")
	Rng.seed_with(8300)
	var rain := Influence.cast_act(colony, world, Catalog.defs()["weeping_sky"], "fields")
	# Same base_intensity class (0.6 vs 0.4) — compare per-unit-base instead.
	var blight_per_base: float = blight["intensity"] / 0.6
	var rain_per_base: float = rain["intensity"] / 0.4
	assert_gt(blight_per_base, rain_per_base, "the malevolent act nets more per use")
	assert_almost_eq(blight_per_base / rain_per_base, 1.4 / 0.6, 0.0001, "exactly the δ gap")


func test_cast_act_derives_magnitude_from_the_colony():
	var colony := _flock(100, 0.8)
	var world := WorldState.new()
	Rng.seed_with(8301)
	var stim := Influence.cast_act(colony, world, Catalog.defs()["still_air"], "meadow")
	var expected: float = 0.3 * Devotion.magnitude_multiplier(colony) * 1.0
	assert_almost_eq(stim["intensity"], expected, 0.0001, "a vast devout flock amplifies you")
