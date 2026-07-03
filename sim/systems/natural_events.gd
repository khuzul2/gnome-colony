class_name NaturalEvents
extends RefCounted
## Random environmental events [user feature 2026-07-03]: an OPT-IN daily
## scheduler that fires catalog phenomena unbidden — nature acting without
## the player's hand. Off by default (WorldConfig.environmental_events);
## §1.8b's sole-authorship experience is untouched unless the player asks
## for a livelier world at New Game. Frequency is chosen EVENT BY EVENT
## (WorldConfig.event_frequencies); events reuse the whole influence
## pipeline (affordance gating, wards, chains, tails, appraisal) so a
## natural landslide behaves exactly like a cast one — witnesses cannot
## tell the author, only the deed.
## INTERPRETIVE numbers (no spec section covers natural events; documented
## here + PROGRESS.md):
##  · frequency ladder = mean one event per 4 years / 1 year / 1 season,
##    rolled as 1/interval per day via Rng.chance;
##  · natural casts land at neutral magnitude 1.0 and valence potency 1.0
##    (base intensity — devotion never amplifies what you did not do);
##  · the target is an Rng pick among affordance-met sites (sorted ids,
##    deterministic); an event with no legal ground fizzles silently;
##  · witnesses appraise at the default belief impact (the per-settlement
##    prediction damp is orchestrator wiring, same deferral as T10.4).

const FREQUENCY_INTERVAL_DAYS := {
	"rare": 4.0 * TimeService.DAYS_PER_YEAR,
	"occasional": 1.0 * TimeService.DAYS_PER_YEAR,
	"frequent": 1.0 * TimeService.DAYS_PER_SEASON,
}


## Resolve the config into id → per-day probability. Empty when the
## option is off; an id absent from event_frequencies runs at the
## default level; "off" removes that event alone.
static func daily_probs(cfg: WorldConfig) -> Dictionary:
	if not cfg.environmental_events:
		return {}
	var out := {}
	for event_id in Catalog.defs():
		var level: String = cfg.event_frequencies.get(event_id, WorldConfig.DEFAULT_EVENT_FREQUENCY)
		if level == "off":
			continue
		out[event_id] = 1.0 / FREQUENCY_INTERVAL_DAYS[level]
	return out


## One sim-day of nature: roll every scheduled event (sorted ids so the
## Rng draw order is reproducible), cast the hits with their full cascade,
## and appraise the on-site witnesses. Returns every stimulus emitted.
static func tick(
	colony: Colony,
	world: WorldState,
	probs: Dictionary,
	defs: Dictionary,
	handlers: Dictionary = {},
) -> Array:
	var stimuli := []
	var ids := probs.keys()
	ids.sort()
	for event_id in ids:
		if not Rng.chance(probs[event_id]):
			continue
		var target := pick_target(world, defs[event_id])
		if target == "":
			continue
		var burst := Influence.cast_with_cascade(
			colony, world, defs, event_id, target, 1.0, 1.0, handlers
		)
		for stim in burst:
			Influence.appraise_witnesses(colony, stim)
		stimuli.append_array(burst)
	return stimuli


## Nature strikes where it can: an Rng pick among the sites whose
## affordances allow this event ("" when nowhere qualifies). Sorted ids
## keep the draw independent of dictionary insertion order.
static func pick_target(world: WorldState, definition: Dictionary) -> String:
	var places := world.sites.keys()
	places.sort()
	var eligible := []
	for place in places:
		if Influence.affordance_met(world, place, definition.get("affordance_req", "any")):
			eligible.append(place)
	if eligible.is_empty():
		return ""
	return eligible[Rng.randi_range(0, eligible.size() - 1)]
