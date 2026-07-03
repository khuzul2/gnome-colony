extends GutTest

## Natural environmental events [user feature 2026-07-03]: an OPT-IN
## per-event scheduler — nature firing catalog phenomena unbidden. Off by
## default (§1.8b sole authorship untouched); frequency chosen event by
## event; the whole influence pipeline (affordances, chains, appraisal)
## is reused so a natural landslide behaves exactly like a cast one.
## Ladder and neutral-magnitude choices are interpretive, documented in
## natural_events.gd.

const YEAR := float(TimeService.DAYS_PER_YEAR)


func _config(enabled: bool = true, frequencies: Dictionary = {}) -> WorldConfig:
	var cfg := WorldConfig.new()
	cfg.environmental_events = enabled
	cfg.event_frequencies = frequencies
	cfg.normalize()
	return cfg


func _world_with_slope() -> WorldState:
	var world := WorldState.new()
	world.sites["eastern_ridge"] = ResourceNode.new("stone", 10.0, 10.0, 0.1, 1.0)
	world.affordances["eastern_ridge"] = ["slope"]
	world.paths["eastern_ridge_path"] = true
	world.sites["the_hollow"] = ResourceNode.new("food", 50.0, 50.0, 5.0, 1.0)
	return world


func _band_at(place: String, count: int = 4) -> Colony:
	var colony := Colony.new()
	for i in count:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = place
	return colony


func test_option_off_resolves_to_no_probabilities():
	assert_eq(NaturalEvents.daily_probs(_config(false)), {}, "off = the world never acts alone")


func test_default_frequency_covers_every_catalog_event():
	var probs := NaturalEvents.daily_probs(_config())
	assert_eq(probs.size(), Catalog.defs().size(), "absent ids run at the default level")
	for event_id in probs:
		assert_almost_eq(probs[event_id], 1.0 / YEAR, 0.000001, "occasional = once a year (mean)")


func test_per_event_levels_resolve_event_by_event():
	var probs := NaturalEvents.daily_probs(
		_config(true, {"landslide": "frequent", "the_blight": "rare", "day_twice": "off"})
	)
	assert_almost_eq(
		probs["landslide"], 1.0 / TimeService.DAYS_PER_SEASON, 0.000001, "frequent = once a season"
	)
	assert_almost_eq(probs["the_blight"], 1.0 / (4.0 * YEAR), 0.000001, "rare = once in 4 years")
	assert_false(probs.has("day_twice"), "off silences that one event alone")
	assert_almost_eq(probs["still_air"], 1.0 / YEAR, 0.000001, "the rest keep the default")


func test_disabled_tick_consumes_no_randomness():
	Rng.seed_with(9001)
	var before: int = Rng.get_state()
	var out := NaturalEvents.tick(_band_at("the_hollow"), _world_with_slope(), {}, Catalog.defs())
	assert_eq(out, [], "nothing fires")
	assert_eq(Rng.get_state(), before, "no probs = zero Rng draws — replays stay byte-identical")


func test_certain_event_fires_through_the_full_pipeline():
	Rng.seed_with(9002)
	var colony := _band_at("eastern_ridge")
	var world := _world_with_slope()
	watch_signals(EventBus)
	var out := NaturalEvents.tick(
		colony, world, {"landslide": 1.0}, Catalog.defs(), Catalog.handlers()
	)
	assert_signal_emitted(EventBus, "phenomenon")
	assert_gt(out.size(), 0, "the hit returns its stimuli")
	assert_eq(out[0]["type"], "landslide")
	assert_eq(out[0]["place"], "eastern_ridge", "slope affordance steers the strike")
	assert_almost_eq(
		out[0]["intensity"], 0.6, 0.000001, "neutral magnitude: nature lands at base intensity"
	)
	assert_lt(
		world.sites["eastern_ridge"].current, 10.0, "the handler ran — the site really buried"
	)


func test_witnesses_appraise_the_natural_event():
	Rng.seed_with(9003)
	var colony := _band_at("eastern_ridge", 8)
	var out := NaturalEvents.tick(
		colony, _world_with_slope(), {"landslide": 1.0}, Catalog.defs(), Catalog.handlers()
	)
	assert_gt(out.size(), 0)
	var feared := 0
	for g in colony.living():
		if g.get_feeling("landslide", "fear") > 0.0:
			feared += 1
	assert_gt(feared, 0, "those on the ridge fear the slide — author unknown, deed felt")


func test_event_without_legal_ground_fizzles():
	Rng.seed_with(9004)
	var world := WorldState.new()
	world.sites["the_hollow"] = ResourceNode.new("food", 50.0, 50.0, 5.0, 1.0)
	watch_signals(EventBus)
	var out := NaturalEvents.tick(
		_band_at("the_hollow"), world, {"landslide": 1.0}, Catalog.defs(), Catalog.handlers()
	)
	assert_eq(out, [], "no slope anywhere — the landslide has nothing to act on")
	assert_signal_not_emitted(EventBus, "phenomenon")


func test_same_seed_same_history():
	var runs := []
	for attempt in 2:
		Rng.seed_with(9005)
		var colony := _band_at("eastern_ridge")
		var world := _world_with_slope()
		var types := []
		for day in 60:
			for stim in NaturalEvents.tick(
				colony,
				world,
				{"landslide": 0.1, "still_air": 0.1},
				Catalog.defs(),
				Catalog.handlers()
			):
				types.append(stim["type"])
		runs.append(types)
	assert_gt(runs[0].size(), 0, "60 days at 0.1/day: something happened")
	assert_eq(runs[0], runs[1], "seeded nature replays exactly [CLAUDE.md determinism invariant]")


func test_sim_runner_rolls_nature_daily_when_opted_in():
	Rng.seed_with(9006)
	var cfg := _config(true, {})
	# Everything but the always-castable calm spell off: a clean signal.
	for event_id in Catalog.defs():
		cfg.event_frequencies[event_id] = "off"
	cfg.event_frequencies["still_air"] = "frequent"
	cfg.normalize()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var world := WorldState.new()
	world.sites["the_hollow"] = food
	var runner := SimRunner.new(cfg, food, 60.0, null, null, world)
	watch_signals(EventBus)
	runner.run_days(2 * TimeService.DAYS_PER_YEAR)
	runner.shutdown()
	assert_signal_emitted(EventBus, "phenomenon", "a once-a-season-mean event fires in two years")
	var found := false
	for line in runner.chronicle:
		if line.contains("still_air") and line.contains("no hand behind it"):
			found = true
	assert_true(found, "natural events enter the chronicle as authorless history")


func test_sim_runner_without_world_never_rolls():
	Rng.seed_with(9007)
	var cfg := WorldConfig.new()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	watch_signals(EventBus)
	runner.run_days(30)
	runner.shutdown()
	assert_signal_not_emitted(
		EventBus, "phenomenon", "default config + no world = the pre-feature runner, untouched"
	)
