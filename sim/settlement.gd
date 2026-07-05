class_name Settlement
extends RefCounted
## Settlement-tier aggregate [plan T11.2, algo §14]: fractional stage
## buckets, mean traits, mood, and aggregate belief scalars toward the
## unseen will — the statistical body a folded population lives in.
## Plain data; SettlementSim owns the flow equations. Knowledge stays on
## Colony.settlement_knowledge (§7, per-settlement) — not duplicated here.

## Building catalog [rav §R-build], canonical order — the ids a settlement can
## hold in `structures`. Costs/prereqs/effects live in Construction (R2.3).
const BUILDING_IDS := [
	"dwelling", "farm", "well", "granary", "workshop", "shrine", "basilica", "wall", "market"
]

var sid: int
var base_k: float
var richness_sum: float
## LifeStage → fractional head-count (DEAD never tracked).
var by_stage := {}
var mean_traits := {}
var mood := 1.0
## Aggregate feelings toward Devotion.YOU [§9 scalars, settlement grain].
var belief := {"faith": 0.0, "awe": 0.0, "fear": 0.0}
## Building-id → fractional count [rav §R-build]; the autonomous build stock.
var structures := {}
## Development tier [rav §R-set], re-derived each season by SettlementSim (R2.2).
var tier := Enums.SettlementTier.HAMLET


func _init(settlement_id: int = 0, k_base: float = 0.0, richness: float = 0.0) -> void:
	sid = settlement_id
	base_k = k_base
	richness_sum = richness
	for stage in [
		Enums.LifeStage.INFANT,
		Enums.LifeStage.CHILD,
		Enums.LifeStage.ADOLESCENT,
		Enums.LifeStage.ADULT,
		Enums.LifeStage.ELDER,
	]:
		by_stage[stage] = 0.0
	for key in Enums.TRAIT_KEYS:
		mean_traits[key] = 0.5


func pop() -> float:
	var total := 0.0
	for stage in by_stage:
		total += by_stage[stage]
	return total


func adults() -> float:
	return by_stage[Enums.LifeStage.ADULT]


## Fractional count of a built structure (0 when never built) [rav §R-build].
func structure_count(building_id: String) -> float:
	return structures.get(building_id, 0.0)


## §17: K = base_K · Σrichness · (1 + 0.5·agriculture + 0.3·construction).
func k(colony: Colony) -> float:
	return TechEffects.carrying_capacity(
		base_k,
		richness_sum,
		TechEffects.level(colony, sid, "agriculture"),
		TechEffects.level(colony, sid, "construction")
	)


func crowding(colony: Colony) -> float:
	var capacity := k(colony)
	return pop() / capacity if capacity > 0.0 else 1.0


## Aggregate a living population into settlement statistics — the same
## fold T11.3's demotion uses. Mood from §5 vitals; belief = mean
## feelings toward the unseen will.
static func from_colony(
	colony: Colony, settlement_id: int, k_base: float, richness: float
) -> Settlement:
	var s := Settlement.new(settlement_id, k_base, richness)
	var locals := []
	for g in colony.living():
		if g.home_settlement == settlement_id:
			locals.append(g)
	if locals.is_empty():
		return s
	for key in Enums.TRAIT_KEYS:
		s.mean_traits[key] = 0.0
	var mood_sum := 0.0
	for g in locals:
		s.by_stage[g.stage] += 1.0
		var need_sum := 0.0
		for key in Enums.NEED_KEYS:
			need_sum += g.needs[key]
		mood_sum += 1.0 - need_sum / Enums.NEED_KEYS.size()
		for key in Enums.TRAIT_KEYS:
			s.mean_traits[key] += g.traits[key]
		for axis in s.belief:
			s.belief[axis] += g.get_feeling(Devotion.YOU, axis)
	for key in Enums.TRAIT_KEYS:
		s.mean_traits[key] /= locals.size()
	for axis in s.belief:
		s.belief[axis] /= locals.size()
	s.mood = mood_sum / locals.size()
	return s
