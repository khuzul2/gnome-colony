class_name Influence
extends RefCounted
## Phenomenon runner [plan T7.2, algo §11]: casting a phenomenon applies
## its world-state mutation (via a registered per-phenomenon handler) and
## emits ONE `phenomenon` stimulus for appraisal (T7.4). Magnitude and
## valence potency arrive with Phase 8 (T8.3) — until then both default
## to 1.0 (the stub the plan mandates). Chains & tail-risk are T7.5.

static var _handlers := {}


static func register_handler(phenomenon_id: String, handler: Callable) -> void:
	_handlers[phenomenon_id] = handler


static func clear_handlers() -> void:
	_handlers.clear()


static func cast(
	colony: Colony,
	world: WorldState,
	definition: Dictionary,
	target: String,
	magnitude: float = 1.0,
	valence_potency: float = 1.0,
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
	if _handlers.has(definition["id"]):
		_handlers[definition["id"]].call(colony, world, stimulus)
	EventBus.phenomenon.emit(stimulus)
	return stimulus
