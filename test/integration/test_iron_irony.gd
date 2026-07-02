extends GutTest

## T7.6 / Phase-Exit 7 — MILESTONE 2, the iron irony [design §3.4]:
## a seeded landslide kills some, exposes iron, frightens witnesses; a
## `cursed` tag lands (§18's cursed-place chain — "the spot turns taboo in
## memory"); and the survivors now avoid the very iron you exposed.


func _setup() -> Array:
	var colony := Colony.new()
	for i in 16:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("timid", 0.7)
		g.set_trait("curious", 0.4)
		g.location = "eastern_ridge" if i < 8 else "village"
	var world := WorldState.new()
	world.affordances["eastern_ridge"] = ["slope"]
	world.sites["eastern_ridge"] = ResourceNode.new("stone", 10.0, 10.0, 0.1, 1.0)
	world.hidden_resources["eastern_ridge"] = [ResourceNode.new("iron", 30.0, 30.0, 0.0, 1.0)]
	world.paths["eastern_ridge_path"] = true
	return [colony, world]


func test_the_iron_irony():
	# Find the seed where fate cooperates fully: someone dies AND the
	# cursed-place chain (0.20) fires. Deterministic thereafter.
	var chosen_seed := -1
	for seed in range(7600, 7700):
		Rng.seed_with(seed)
		var probe := _setup()
		var death_count := [0]
		var listener := func(_p: Dictionary) -> void: death_count[0] += 1
		EventBus.gnome_died.connect(listener)
		Influence.cast_with_cascade(
			probe[0],
			probe[1],
			Catalog.defs(),
			"landslide",
			"eastern_ridge",
			1.0,
			1.0,
			Catalog.handlers()
		)
		EventBus.gnome_died.disconnect(listener)
		var cursed: bool = probe[0].place_tags.get("eastern_ridge", {}).has("cursed")
		if death_count[0] > 0 and cursed:
			chosen_seed = seed
			break
	assert_gt(chosen_seed, 0, "within 100 seeds the full irony plays out")

	# Replay the chosen fate and walk the whole pipeline.
	Rng.seed_with(chosen_seed)
	var setup := _setup()
	var colony: Colony = setup[0]
	var world: WorldState = setup[1]
	var before := colony.population()

	var stimuli: Array = Influence.cast_with_cascade(
		colony, world, Catalog.defs(), "landslide", "eastern_ridge", 1.0, 1.0, Catalog.handlers()
	)
	Influence.appraise_witnesses(colony, stimuli[0])

	# 1. It killed.
	assert_lt(colony.population(), before, "the hillside took someone")
	# 2. It exposed the iron.
	assert_true(world.sites.has("eastern_ridge_iron"), "the scar glints with ore")
	# 3. It frightened the witnesses.
	var frightened := 0
	for g in colony.living():
		if g.location == "eastern_ridge" and g.get_feeling("eastern_ridge", "fear") > 0.0:
			frightened += 1
	assert_gt(frightened, 0, "the survivors carry the mountain's wrath")
	# 4. The cursed tag landed.
	assert_true(colony.place_tags["eastern_ridge"].has("cursed"))
	# 5. THE IRONY: they avoid the iron you gave them.
	var mod := Belief.place_mod(colony, "eastern_ridge")
	assert_lt(mod, 1.0)
	var miner := GnomeData.new(99)
	miner.stage = Enums.LifeStage.ADULT
	miner.set_need("purpose", 0.8)
	var neutral := Utility.base_score(miner, "work")
	var at_iron := Utility.base_score(miner, "work", {"belief_mods": {"work": mod}})
	assert_lt(
		at_iron, neutral, "to unlock the iron you created, you must now shift belief [design §3.4]"
	)
