extends GutTest

## T7.5 — cascades [algo §11]: each chain_hook rolls its prob and, on a
## hit, the child phenomenon is cast at the same place; every act also
## rolls the universal 0.03 tail risk, emitting an unscripted "tail:<id>"
## stimulus (its size scales with social mass in Phase 8). MAX_CASCADE
## bounds runaway loops — a structural guard, not a spec number.


func _def(id: String, hooks: Array) -> Dictionary:
	return {
		"id": id,
		"category": 2,
		"valence": "neutral",
		"target": "point",
		"base_intensity": 0.5,
		"event_drama": 0.5,
		"tier": 2,
		"effects":
		{"material": -0.2, "population": 0.0, "discovery": 0.1, "belief": 0.3, "social": 0.0},
		"affordance_req": "any",
		"chain_hooks": hooks,
		"tail_risk": 0.03,
	}


func _catalog() -> Dictionary:
	return {
		"slide": _def("slide", [{"phenom": "flood", "prob": 1.0}]),
		"flood": _def("flood", []),
		"never": _def("never", [{"phenom": "flood", "prob": 0.0}]),
		"ouroboros": _def("ouroboros", [{"phenom": "ouroboros", "prob": 1.0}]),
	}


func test_certain_chain_casts_the_child():
	Rng.seed_with(7500)
	var colony := Colony.new()
	var world := WorldState.new()
	var stimuli := Influence.cast_with_cascade(colony, world, _catalog(), "slide", "gorge")
	var types := stimuli.map(func(s: Dictionary) -> String: return s["type"])
	assert_true("slide" in types)
	assert_true("flood" in types, "the slide dammed the stream; the valley floods")
	assert_eq(stimuli[1]["place"], "gorge", "the chain lands where the parent did")


func test_zero_probability_chain_never_fires():
	Rng.seed_with(7501)
	var colony := Colony.new()
	var world := WorldState.new()
	for i in 50:
		var stimuli := Influence.cast_with_cascade(colony, world, _catalog(), "never", "gorge")
		var types := stimuli.map(func(s: Dictionary) -> String: return s["type"])
		assert_false("flood" in types)


func test_tail_risk_fires_at_spec_frequency():
	Rng.seed_with(7502)
	var colony := Colony.new()
	var world := WorldState.new()
	var tails := 0
	for i in 1000:
		var stimuli := Influence.cast_with_cascade(colony, world, _catalog(), "flood", "gorge")
		for s in stimuli:
			if String(s["type"]).begins_with("tail:"):
				tails += 1
	assert_between(tails, 10, 60, "≈30 misfires expected in 1000 casts at 0.03")


func test_gated_act_neither_chains_nor_misfires():
	Rng.seed_with(7504)
	var colony := Colony.new()
	var world := WorldState.new()
	var gated := _def("gated", [{"phenom": "flood", "prob": 1.0}])
	gated["affordance_req"] = "slope"
	var catalog := {"gated": gated, "flood": _def("flood", [])}
	watch_signals(EventBus)
	var stimuli := Influence.cast_with_cascade(colony, world, catalog, "gated", "flatland")
	assert_eq(stimuli, [], "an act that never happened leaves no trace")
	assert_signal_not_emitted(EventBus, "phenomenon")


func test_cascade_depth_is_bounded():
	Rng.seed_with(7503)
	var colony := Colony.new()
	var world := WorldState.new()
	var stimuli := Influence.cast_with_cascade(colony, world, _catalog(), "ouroboros", "gorge")
	assert_lte(stimuli.size(), Influence.MAX_CASCADE + 2, "a self-chaining act cannot run away")
