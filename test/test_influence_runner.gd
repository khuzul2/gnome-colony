extends GutTest

## T7.2 — phenomenon runner [algo §11]: casting applies the world-state
## mutation (per-phenomenon handler) and emits one `phenomenon` stimulus.
## Magnitude and valence potency are STUBS at 1.0 until Phase 8 (T8.3).

var _def := {
	"id": "test_quake",
	"category": 2,
	"valence": "neutral",
	"target": "point",
	"base_intensity": 0.6,
	"event_drama": 0.5,
	"tier": 2,
	"effects":
	{"material": -0.3, "population": -0.1, "discovery": 0.2, "belief": 0.4, "social": 0.0},
	"affordance_req": "any",
	"chain_hooks": [],
	"tail_risk": 0.03,
}


func before_each() -> void:
	Influence.clear_handlers()


func test_cast_emits_stimulus_with_stub_magnitude():
	var colony := Colony.new()
	var world := WorldState.new()
	watch_signals(EventBus)
	Influence.cast(colony, world, _def, "eastern_ridge")
	var params: Array = get_signal_parameters(EventBus, "phenomenon")
	assert_not_null(params)
	var stim: Dictionary = params[0]
	assert_eq(stim["type"], "test_quake")
	assert_eq(stim["place"], "eastern_ridge")
	assert_almost_eq(stim["intensity"], 0.6, 0.0001, "base × magnitude(1.0) × potency(1.0)")
	assert_eq(stim["drama"], 0.5)
	assert_eq(stim["valence"], "neutral")


func test_registered_handler_mutates_world():
	var colony := Colony.new()
	var world := WorldState.new()
	world.sites["quarry"] = ResourceNode.new("stone", 10.0, 10.0, 0.0, 1.0)
	Influence.register_handler(
		"test_quake",
		func(_c: Colony, w: WorldState, stim: Dictionary) -> void:
			w.sites["quarry"].current -= 5.0 * stim["intensity"]
	)
	Influence.cast(colony, world, _def, "quarry")
	assert_almost_eq(world.sites["quarry"].current, 10.0 - 3.0, 0.0001, "world state mutated")


func test_magnitude_hook_scales_intensity():
	var colony := Colony.new()
	var world := WorldState.new()
	watch_signals(EventBus)
	Influence.cast(colony, world, _def, "ridge", 2.0)
	var stim: Dictionary = get_signal_parameters(EventBus, "phenomenon")[0]
	assert_almost_eq(stim["intensity"], 1.2, 0.0001, "Phase 8 will feed real magnitude here")


func test_world_state_container():
	var world := WorldState.new()
	world.sites["s"] = ResourceNode.new("food", 5.0, 5.0, 1.0, 1.0)
	world.hidden_resources["s"] = [ResourceNode.new("iron", 20.0, 20.0, 0.0, 1.0)]
	world.paths["east_pass"] = true
	var revealed := world.reveal_hidden("s")
	assert_eq(revealed.size(), 1)
	assert_eq(world.sites["s_iron"].type, "iron", "hidden ore surfaces as a real site")
	assert_false(world.hidden_resources.has("s"))
