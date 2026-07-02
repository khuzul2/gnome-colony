class_name Influence
extends RefCounted
## Phenomenon runner [plan T7.2, algo §11]: casting a phenomenon applies
## its world-state mutation (via a handler passed BY THE CALLER — no
## global registry; hidden static state would leak outside the sim's
## declared inputs) and emits ONE `phenomenon` stimulus for appraisal
## (T7.4). Magnitude and valence potency arrive with Phase 8 (T8.3) —
## until then both default to 1.0 (the stub the plan mandates). Chains &
## tail-risk are T7.5. T7.8's catalog owns the id→handler map.


static func cast(
	colony: Colony,
	world: WorldState,
	definition: Dictionary,
	target: String,
	magnitude: float = 1.0,
	valence_potency: float = 1.0,
	handlers: Dictionary = {},
) -> Dictionary:
	var intensity: float = definition["base_intensity"] * magnitude * valence_potency
	var stimulus := {
		"type": definition["id"],
		"place": target,
		"intensity": intensity,
		"drama": definition["event_drama"],
		"valence": definition["valence"],
		"effects": definition["effects"],
	}
	if handlers.has(definition["id"]):
		handlers[definition["id"]].call(colony, world, stimulus)
	EventBus.phenomenon.emit(stimulus)
	return stimulus
