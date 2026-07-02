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
## Structural runaway guard for chain cascades — not a spec number; chain
## probabilities are small, this only stops pathological prob-1.0 cycles.
const MAX_CASCADE := 8


## Affordance rule [design §2.7b, plan T7.8]: phenomena need terrain to
## act on — "any" always casts; otherwise the target place must carry the
## required tag.
static func affordance_met(world: WorldState, place: String, requirement: String) -> bool:
	if requirement == "any":
		return true
	return requirement in world.affordances.get(place, [])


static func cast(
	colony: Colony,
	world: WorldState,
	definition: Dictionary,
	target: String,
	magnitude: float = 1.0,
	valence_potency: float = 1.0,
	handlers: Dictionary = {},
) -> Dictionary:
	if not affordance_met(world, target, definition.get("affordance_req", "any")):
		return {}
	var intensity: float = definition["base_intensity"] * magnitude * valence_potency
	var stimulus := {
		"type": definition["id"],
		"place": target,
		"intensity": intensity,
		"drama": definition["event_drama"],
		"valence": definition["valence"],
		"effects": definition["effects"],
		"social_effect": resolve_social(colony, definition, intensity),
	}
	if definition.has("taint"):
		stimulus["taint"] = definition["taint"]
	if handlers.has(definition["id"]):
		handlers[definition["id"]].call(colony, world, stimulus)
	EventBus.phenomenon.emit(stimulus)
	return stimulus


## Culture-resolved social outcome [plan T7.9, algo §11]:
##   social_effect = swing · (cohesion − fear_level − fracture)
## The spec names the terms without closed forms; interpretive wiring:
##   swing      = the resolved intensity (the event's force)
##   cohesion   = mean(social, nurturing)/1 + 0.5/№subcultures
##                (shared belief bonus: one culture = full bonus)
##   fear_level = mean fear toward this phenomenon type
##   fracture   = 0.5 · (№subcultures − 1), capped at 1
## So the same disaster bonds a tight people and shatters a divided one —
## the reaction is theirs, not yours.
static func resolve_social(colony: Colony, definition: Dictionary, intensity: float) -> float:
	var declared: Variant = definition["effects"]["social"]
	if not declared is String:
		return declared
	var living := colony.living()
	if living.is_empty():
		return 0.0
	var vitals: Dictionary = colony.vitals()
	var subculture_count := maxi(1, Belief.subcultures(colony).size())
	var cohesion: float = (
		0.5 * (vitals["mean_traits"]["social"] + vitals["mean_traits"]["nurturing"])
		+ 0.5 / subculture_count
	)
	var fear_total := 0.0
	for g in living:
		fear_total += g.get_feeling(definition["id"], "fear")
	var fear_level := fear_total / living.size()
	var fracture := minf(1.0, 0.5 * (subculture_count - 1))
	return intensity * (cohesion - fear_level - fracture)


## Cascades [plan T7.5, algo §11]: cast the root phenomenon, then roll its
## chain_hooks (children land at the same place) and the universal tail
## risk (0.03/act, from the definition) — a hit emits an unscripted
## "tail:<id>" stimulus whose size Phase 8 scales with social mass.
## Returns every stimulus emitted, root first.
static func cast_with_cascade(
	colony: Colony,
	world: WorldState,
	catalog: Dictionary,
	root_id: String,
	target: String,
	magnitude: float = 1.0,
	valence_potency: float = 1.0,
	handlers: Dictionary = {},
) -> Array:
	var stimuli := []
	var queue := [root_id]
	while not queue.is_empty() and stimuli.size() < MAX_CASCADE:
		var id: String = queue.pop_front()
		if not catalog.has(id):
			# A consequence marker (famine, cursed_place, flood…): surface
			# it as a traceable stimulus so appraisal/aftermath can react;
			# it chains no further (T7.9).
			var marker := {
				"type": id,
				"place": target,
				"intensity": stimuli[0]["intensity"] if not stimuli.is_empty() else 0.0,
				"drama": stimuli[0]["drama"] if not stimuli.is_empty() else 0.0,
				"valence": "neutral",
				"effects": {},
				"consequence": true,
			}
			if handlers.has(id):
				handlers[id].call(colony, world, marker)
			EventBus.phenomenon.emit(marker)
			stimuli.append(marker)
			continue
		var def: Dictionary = catalog[id]
		var stim := cast(colony, world, def, target, magnitude, valence_potency, handlers)
		if stim.is_empty():
			# Affordance-gated: the act never happened, so it neither
			# chains nor misfires (reviewer catch — a blocked landslide
			# must not roll dam_flood or a tail).
			continue
		stimuli.append(stim)
		for hook in def.get("chain_hooks", []):
			if Rng.chance(hook["prob"]):
				queue.append(hook["phenom"])
		if Rng.chance(def.get("tail_risk", 0.0)):
			var tail := {
				"type": "tail:%s" % id,
				"place": target,
				"intensity": def["base_intensity"] * magnitude,
				"drama": def["event_drama"],
				"valence": "neutral",
				"effects": def["effects"],
			}
			EventBus.phenomenon.emit(tail)
			stimuli.append(tail)
	return stimuli


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
	# Interpretive reading of §9/§11: the definition's belief-effects axis
	# acts as the relevance weight on the §9 appraisal write — §9's formula
	# names intensity·susceptibility only; effects.belief is how hard this
	# particular phenomenon bites on belief.
	# .get() guard: consequence markers carry empty effects (reviewer note).
	var belief_axis: float = absf(stimulus["effects"].get("belief", 0.0))
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
