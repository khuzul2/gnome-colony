class_name Influence
extends RefCounted
## Phenomenon runner [plan T7.2, algo §11]: casting a phenomenon applies
## its world-state mutation (via a handler passed BY THE CALLER — no
## global registry; hidden static state would leak outside the sim's
## declared inputs) and emits ONE `phenomenon` stimulus for appraisal
## (T7.4). Magnitude and valence potency arrive with Phase 8 (T8.3) —
## until then both default to 1.0 (the stub the plan mandates). Chains &
## tail-risk are T7.5. T7.8's catalog owns the id→handler map.

const CURIOUS_DISCOVERY_THRESHOLD := 0.6
const SAFETY_SPIKE_BASE := 0.3


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


## Per-witness appraisal [plan T7.4, algo §11/§9]: witnesses default to the
## living gnomes AT the stimulus place. Each writes fear toward the place
## AND the phenomenon type (one habituation bump per event), spikes safety
## by intensity·(0.3+timid) — the prototype-spec formula — and, if curious
## enough, banks a discovery memory instead of only dread.
static func appraise_witnesses(
	colony: Colony, stimulus: Dictionary, witnesses: Variant = null
) -> void:
	var present: Array = witnesses if witnesses != null else []
	if witnesses == null:
		for g in colony.living():
			if g.location == stimulus["place"]:
				present.append(g)
	var belief_axis: float = absf(stimulus["effects"]["belief"])
	var felt: float = stimulus["intensity"] * belief_axis
	for g in present:
		Belief.appraise(g, stimulus["place"], "fear", felt, stimulus["type"], false)
		Belief.appraise(g, stimulus["type"], "fear", felt, stimulus["type"], true)
		var spike: float = stimulus["intensity"] * (SAFETY_SPIKE_BASE + g.traits["timid"])
		g.set_need("safety", maxf(g.needs["safety"], spike))
		if g.traits["curious"] > CURIOUS_DISCOVERY_THRESHOLD:
			var memory := {
				"event": "discovery_opportunity",
				"place": stimulus["place"],
				"type": stimulus["type"],
			}
			g.remember(memory)
