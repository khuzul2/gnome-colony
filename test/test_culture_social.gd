extends GutTest

## T7.9 — culture-resolved social outcome [algo §11]: `social: =culture`
## resolves at cast time to swing·(cohesion − fear_level − fracture) —
## the SAME disaster bonds a tight people and shatters a divided one.
## The spec names the terms but no closed forms; interpretive wiring
## (documented in code): swing = stimulus intensity; cohesion = mean
## social/nurturing + a one-culture bonus; fear_level = mean fear toward
## the phenomenon type; fracture = 0.5·(subcultures − 1).
## Boon taint [§11/§18]: a tainted boon's chains ARE its uncanny cost and
## the stimulus carries the taint marker; clean boons cast unmarked.


func _folk(colony: Colony, warmth: float, faith_side: float) -> void:
	for i in 6:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("social", warmth)
		g.set_trait("nurturing", warmth)
		g.set_feeling("unseen_will", "faith", faith_side if i < 3 else 1.0 - faith_side)


func test_same_disaster_bonds_the_cohesive_and_breaks_the_divided():
	var tight := Colony.new()
	_folk(tight, 0.8, 0.5)
	# faith split 0 vs 1 keeps mean belief distance ≥ 0.5 even though the
	# shared blight-fear pulls the vectors together — a real schism.
	var divided := Colony.new()
	_folk(divided, 0.3, 0.0)
	for g in divided.living():
		g.set_feeling("the_blight", "fear", 0.6)

	var def: Dictionary = Catalog.defs()["the_blight"]
	var world := WorldState.new()
	world.affordances["fields"] = ["farmland"]
	Rng.seed_with(7900)
	var bonded := Influence.cast(tight, world, def, "fields")
	Rng.seed_with(7900)
	var broken := Influence.cast(divided, world, def, "fields")

	assert_gt(bonded["social_effect"], 0.0, "catastrophe pulls a tight people together")
	assert_lt(broken["social_effect"], 0.0, "and shatters a divided one")


func test_fixed_social_values_pass_through():
	var colony := Colony.new()
	_folk(colony, 0.5, 0.5)
	var world := WorldState.new()
	var stim := Influence.cast(colony, world, Catalog.defs()["still_air"], "meadow")
	assert_almost_eq(stim["social_effect"], 0.1, 0.0001, "numeric social is used as-is")


func test_tainted_boon_carries_marker_and_cost_chain():
	var world := WorldState.new()
	world.affordances["fields"] = ["drought"]
	var colony := Colony.new()
	_folk(colony, 0.5, 0.5)
	# Find a seed where the 0.10 flood cost fires on the first roll.
	var fired := false
	for seed in range(7910, 7990):
		Rng.seed_with(seed)
		var stimuli := Influence.cast_with_cascade(
			colony, world, Catalog.defs(), "weeping_sky", "fields"
		)
		assert_eq(stimuli[0].get("taint", ""), "tainted", "the gift is marked")
		for s in stimuli:
			if s["type"] == "flood" or String(s["type"]).begins_with("tail:"):
				fired = true
	assert_true(fired, "somewhere in 80 seeded rains, the water kept rising")


func test_clean_boon_has_no_cost_to_fire():
	var world := WorldState.new()
	var colony := Colony.new()
	_folk(colony, 0.5, 0.5)
	var def: Dictionary = Catalog.defs()["standing_stones"]
	assert_eq(def["chain_hooks"], [], "a clean boon owes nothing")
	Rng.seed_with(7999)
	var stimuli := Influence.cast_with_cascade(
		colony, world, Catalog.defs(), "standing_stones", "field_edge"
	)
	assert_eq(stimuli[0].get("taint", ""), "clean")
	for s in stimuli:
		assert_false(s["type"] == "flood", "no hidden bill arrives")
