class_name Terrain
extends RefCounted
## Living terrain [PROGRESS T18.1, algo §18]: the affordance conditions
## §18 writes as LIVED state, re-derived from what the colony actually
## is — farmland follows the plough (agriculture known), built_up
## follows the mason (construction known), crowded follows §14's
## comfort line, drought follows a low larder ("active drought / low
## water"). World-gen truths (slope, wilds) are never stripped: only
## the lived tags are rewritten. INTERPRETIVE numbers (spec names the
## conditions, not thresholds; documented here + PROGRESS): crowded at
## pop/K > SettlementSim.CROWDING_COMFORT (0.7 — the §14 constant that
## already exists); drought when the larder holds less than a quarter
## of capacity.

const LIVED_TAGS := ["farmland", "built_up", "crowded", "drought"]
const DROUGHT_LARDER_FRACTION := 0.25


## One pass over home's tags: keep every non-lived tag, re-earn the
## lived ones from current state. Idempotent; call daily.
static func refresh(
	colony: Colony,
	world: WorldState,
	home: String,
	food: ResourceNode,
	capacity: float,
	home_sid: int = 0,
) -> void:
	var tags := []
	for tag in world.affordances.get(home, []):
		if not tag in LIVED_TAGS:
			tags.append(tag)
	var known: Dictionary = colony.settlement_knowledge.get(home_sid, {})
	if known.has("agriculture"):
		tags.append("farmland")
	if known.has("construction"):
		tags.append("built_up")
	if capacity > 0.0 and colony.population() / capacity > SettlementSim.CROWDING_COMFORT:
		tags.append("crowded")
	if food.capacity > 0.0 and food.current / food.capacity < DROUGHT_LARDER_FRACTION:
		tags.append("drought")
	if tags.is_empty():
		world.affordances.erase(home)
	else:
		world.affordances[home] = tags
