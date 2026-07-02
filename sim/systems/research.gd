class_name Research
extends RefCounted
## Autonomous research [plan T10.2, algo §13/§17]: discovery is a
## settlement-tier stochastic process — the player never picks targets,
## they only author necessity (need_pressure flows from environment and
## the player's phenomena; drought → irrigation).
##   pressure(X) = need_pressure(X) · (0.3 + curiosity_mean)
##                 · surplus_factor · (1 + log(minds)) · institution_factor
##   p_discover(X)/season = clamp01(base_rate · pressure), base_rate 0.01
## INTERPRETIVE notes (PROGRESS.md): log is the natural log (§13 writes
## bare `log`); "minds" = living adults+elders of the settlement; the
## discoverer is the settlement's most curious capable mind (deterministic,
## ties by id) — discovery lands as HELD knowledge so the whole Phase-4
## lifecycle (teaching, decay, extinction, records) applies from day one.

const BASE_RATE := 0.01  # §17: "discover/season clamp(0.01·pressure)"
const CURIOSITY_FLOOR := 0.3


static func pressure(
	need_pressure: float,
	curiosity_mean: float,
	surplus_factor: float,
	minds: int,
	institution_factor: float,
) -> float:
	if minds <= 0:
		return 0.0
	return (
		need_pressure
		* (CURIOSITY_FLOOR + curiosity_mean)
		* surplus_factor
		* (1.0 + log(float(minds)))
		* institution_factor
	)


static func p_discover(pressure_value: float) -> float:
	return clampf(BASE_RATE * pressure_value, 0.0, 1.0)


## One research season for settlement `sid` [§13]: every candidate on the
## TechGraph frontier rolls against its pressure. `need_pressures` maps
## id → environmental need (absent = 0: an unneeded idea stays unthought);
## `institution_factors` maps id → school/guild bonus (absent = 1).
## Returns the ids discovered this season.
static func season_tick(
	colony: Colony,
	sid: int,
	need_pressures: Dictionary,
	surplus_factor: float,
	institution_factors: Dictionary = {},
) -> Array:
	var capable := []
	for g in colony.living():
		if g.home_settlement != sid:
			continue
		if g.stage in [Enums.LifeStage.ADULT, Enums.LifeStage.ELDER]:
			capable.append(g)
	if capable.is_empty():
		return []
	var curiosity_sum := 0.0
	for g in capable:
		curiosity_sum += g.traits["curious"]
	var curiosity_mean := curiosity_sum / capable.size()
	var known: Array = colony.settlement_knowledge.get(sid, {}).keys()
	var found := []
	for id in TechGraph.candidates(known):
		var p_value := pressure(
			need_pressures.get(id, 0.0),
			curiosity_mean,
			surplus_factor,
			capable.size(),
			institution_factors.get(id, 1.0)
		)
		if p_value <= 0.0:
			continue
		if Rng.chance(p_discover(p_value)):
			_discover(colony, sid, id, capable)
			found.append(id)
	return found


## On discovery, X becomes a knowledge-object held by its discoverer
## [§13] — the settlement records it and a living mind carries it.
static func _discover(colony: Colony, sid: int, id: String, capable: Array) -> void:
	var discoverer: GnomeData = capable[0]
	for g in capable:
		var more_curious: bool = g.traits["curious"] > discoverer.traits["curious"]
		var tie: bool = g.traits["curious"] == discoverer.traits["curious"] and g.id < discoverer.id
		if more_curious or tie:
			discoverer = g
	# The idea is born at the teachable proficiency line — knowledge and
	# skill stay consistent, so Phase 4's teach/decay actually operate on
	# a discovery (reviewer catch: a bare id with 0 proficiency would make
	# Skills.teach a silent no-op).
	discoverer.set_skill(id, Skills.TEACHABLE_AT)
	discoverer.add_knowledge(id)
	if not colony.settlement_knowledge.has(sid):
		colony.settlement_knowledge[sid] = {}
	colony.settlement_knowledge[sid][id] = true
