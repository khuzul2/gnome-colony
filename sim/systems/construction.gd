class_name Construction
extends RefCounted
## Autonomous settlement building [rav §R-set/§R-build, R2.3]. Once per season a
## settlement turns its surplus adult labor into structures — never at the
## player's command. The priority reads the SAME pressures the player (or
## nature) already shapes (§R-infl), so development is the gnomes' response to
## the world you make, legible only in hindsight (design §1.3). Deterministic:
## no Rng — the same state always builds the same thing.
##
## Each season: bank labor, pick the single top-priority BUILDABLE structure
## (prereq met AND under its cap AND priority > 0), and if the bank covers its
## cost, raise one, re-derive the tier, and emit structure_built. Progress
## carries over (banked labor is capped so nothing accrues unboundedly).

## Labor-season cost per structure [rav §R-set].
const COST := {
	"dwelling": 1.0,
	"farm": 1.5,
	"well": 1.5,
	"granary": 3.0,
	"workshop": 4.0,
	"shrine": 2.0,
	"wall": 5.0,
	"market": 4.0,
	"basilica": 8.0,
}
## Half the surplus adult-days (beyond the §17 maintenance load) go to building.
const LABOR_SHARE := 0.5
const MAINTENANCE_LOAD := 0.33  # §17 maintenance ≈ 0.33 actions/day
## Devotion tier a basilica needs [rav §R-build: "devotion tier ≥ III"].
const BASILICA_DEVOTION_TIER := 3
const WALL_CAP := 4.0
const PAIR_CAP := 2.0  # granary / workshop / market
## Regression [rav §R-set]: under-tended structures decay; upkeep scales with
## the total stock, so a shrinking settlement can't hold all it built.
const DECAY_RATE := 0.05
const UPKEEP_PER_STRUCTURE := 0.1


## Surplus adult labor available this season [rav §R-set].
static func labor(s: Settlement) -> float:
	return maxf(0.0, s.adults() - MAINTENANCE_LOAD * s.pop()) * LABOR_SHARE


## One season of building. `pressures` carries the world signals the player
## shapes (§R-infl): hunger, water, has_ore (0/1), war_threat, surplus,
## trade_route (bool). Returns the id built this season, or "" if none.
static func season_tick(colony: Colony, s: Settlement, pressures: Dictionary = {}) -> String:
	# Bank labor, capped at the priciest structure so nothing accrues forever.
	s.build_progress = minf(s.build_progress + labor(s), COST["basilica"])
	var pick := _best_buildable(colony, s, pressures)
	if pick == "":
		return ""
	var cost: float = COST[pick]
	if s.build_progress < cost:
		return ""
	s.build_progress -= cost
	s.structures[pick] = s.structure_count(pick) + 1.0
	# A new structure can cross a tier (farm→village, granary→town, …).
	SettlementSim.update_tier(colony, s)
	EventBus.structure_built.emit({"sid": s.sid, "building": pick, "tier": s.tier})
	return pick


## Regression & abandonment [rav §R-set, R2.5]. When a settlement can't tend
## all it built (labor below its upkeep = 0.1·total stock), every structure
## decays by 0.05·shortfall, floored at 0 (empties are dropped). A regional
## dark age that loses the enabling craft (§7) strips the workshop outright.
## The tier is re-derived and may fall.
static func decay_tick(colony: Colony, s: Settlement) -> void:
	# A dark age took the craft → the workshop can no longer stand.
	if s.structure_count("workshop") > 0.0 and not _prereq_met(colony, s, "workshop", {}):
		s.structures.erase("workshop")
	var total := 0.0
	for id in s.structures:
		total += s.structures[id]
	if total > 0.0:
		var upkeep := UPKEEP_PER_STRUCTURE * total
		var shortfall := maxf(0.0, 1.0 - labor(s) / upkeep) if upkeep > 0.0 else 0.0
		if shortfall > 0.0:
			var decay := DECAY_RATE * shortfall
			for id in s.structures.keys():
				var left := maxf(0.0, s.structures[id] - decay)
				if left <= 0.0:
					s.structures.erase(id)
				else:
					s.structures[id] = left
	SettlementSim.update_tier(colony, s)


## The single highest-priority structure the settlement can build now
## (prereq met, under cap, priority > 0). Ties keep BUILDING_IDS order.
static func _best_buildable(colony: Colony, s: Settlement, pressures: Dictionary) -> String:
	var best := ""
	var best_priority := 0.0
	for id in Settlement.BUILDING_IDS:
		if not _prereq_met(colony, s, id, pressures):
			continue
		if s.structure_count(id) >= _cap(s, id):
			continue
		var priority := _priority(colony, s, id, pressures)
		if priority > best_priority:
			best_priority = priority
			best = id
	return best


## §R-build tech/trade prerequisites (dwelling/well/shrine have none).
static func _prereq_met(colony: Colony, s: Settlement, id: String, pressures: Dictionary) -> bool:
	match id:
		"farm", "granary":
			return TechEffects.level(colony, s.sid, "agriculture") >= 1.0
		"workshop":
			return (
				TechEffects.level(colony, s.sid, "smithing") >= 1.0
				or TechEffects.level(colony, s.sid, "stoneworking") >= 1.0
			)
		"wall":
			return TechEffects.level(colony, s.sid, "construction") >= 1.0
		"basilica":
			return (
				TechEffects.level(colony, s.sid, "construction") >= 1.0
				and colony.unlocked_tier >= BASILICA_DEVOTION_TIER
			)
		"market":
			return (
				TechEffects.level(colony, s.sid, "writing") >= 1.0
				or bool(pressures.get("trade_route", false))
			)
	return true


## §R-set per-tier caps.
static func _cap(s: Settlement, id: String) -> float:
	match id:
		"dwelling":
			return maxf(1.0, s.pop() / 4.0)
		"farm":
			return maxf(1.0, s.pop() / 15.0)
		"shrine", "basilica":
			return 1.0
		"wall":
			return WALL_CAP
		"granary", "workshop", "market":
			return PAIR_CAP
	return INF  # well


## §R-set priority score — reads the pressures the player/nature shape (§R-infl).
static func _priority(colony: Colony, s: Settlement, id: String, pressures: Dictionary) -> float:
	var faith: float = s.belief.get("faith", 0.0)
	var surplus: float = pressures.get("surplus", 0.0)
	match id:
		"dwelling":
			return s.crowding(colony)
		"farm":
			return pressures.get("hunger", 0.0) + 0.3
		"well":
			return pressures.get("water", 0.0)
		"granary":
			return surplus if s.tier >= Enums.SettlementTier.TOWN else 0.0
		"workshop":
			return pressures.get("has_ore", 0.0) + s.mean_traits.get("curious", 0.5)
		"shrine":
			return faith * (1.0 - minf(1.0, s.structure_count("shrine")))
		"basilica":
			return (
				faith * float(colony.unlocked_tier)
				if s.tier >= Enums.SettlementTier.VILLAGE
				else 0.0
			)
		"wall":
			return s.belief.get("fear", 0.0) + pressures.get("war_threat", 0.0)
		"market":
			return surplus
	return 0.0
