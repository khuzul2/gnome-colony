class_name SettlementSim
extends RefCounted
## Settlement-tier flows [plan T11.2, algo §14/§7], run once per season:
##   births  = fertility_rate · adults · food_factor · (1 − crowding)
##   deaths  = Σ mortality(stage) · N_stage
##   migration_out = emigration_pressure(crowding, mood, your_phenomena)
##   research = §13 over the settlement's knowledge set
##   belief  = aggregate scalar relaxation (mirrors §9's daily rate)
## §14 fixes the SHAPES; the closed forms it leaves open are INTERPRETIVE
## and documented here + PROGRESS.md:
##  · PAIR_CALIBRATION 0.5 — §14 writes fertility·adults, but the
##    individual model (§8/T5.3) rolls per fertile PAIR; halving `adults`
##    keeps the two tiers consistent (the T11.5 exit test relies on it).
##  · Stage mortality uses the Gompertz curve at a representative mid-band
##    age (+ the accident base); hardship deaths arrive with famine events
##    (T11.4), not as a standing aggregate flow.
##  · Graduation moves band_fraction = season/band_years between buckets.
##  · Emigration pressure = crowding excess past 0.7 (normalized) + 0.5 ·
##    mood shortfall below 0.5 + phenomena pressure (input), capped at 1;
##    at full pressure 5% of the settlement leaves per season, drawn from
##    the adult bucket (migrants are the able-bodied).
##  · Aggregate research reuses §13's exact formulas with the settlement's
##    mean curiosity and adult+elder minds; food_factor doubles as the
##    surplus proxy; a discovery lands in settlement_knowledge directly
##    (aggregate holder — individual holders exist only when materialized,
##    T11.3).

const PAIR_CALIBRATION := 0.5
const MIGRATION_BASE := 0.05
## Main-settlement retention [user feature 2026-07-03, INTERPRETIVE]:
## emigration from the colony's seat is halved — the other half of the
## keep-the-main-settlement-larger bias (Civilization.MAIN_PULL is the
## inbound half). Inert while colony.main_settlement is -1.
const MAIN_RETENTION := 0.5
const CROWDING_COMFORT := 0.7
const MOOD_FLOOR := 0.5
const MOOD_WEIGHT := 0.5

## Representative age per stage for Σ mortality(stage)·N_stage (mid-band;
## Elder is open-ended — 75 is the documented pick).
const STAGE_MID_AGE := {
	Enums.LifeStage.INFANT: 1.5,
	Enums.LifeStage.CHILD: 8.5,
	Enums.LifeStage.ADOLESCENT: 17.0,
	Enums.LifeStage.ADULT: 42.5,
	Enums.LifeStage.ELDER: 75.0,
}
## §17 stage bands as durations (years), for graduation flows.
const BAND_YEARS := {
	Enums.LifeStage.INFANT: 3.0,
	Enums.LifeStage.CHILD: 11.0,
	Enums.LifeStage.ADOLESCENT: 6.0,
	Enums.LifeStage.ADULT: 45.0,
}
const NEXT_STAGE := {
	Enums.LifeStage.INFANT: Enums.LifeStage.CHILD,
	Enums.LifeStage.CHILD: Enums.LifeStage.ADOLESCENT,
	Enums.LifeStage.ADOLESCENT: Enums.LifeStage.ADULT,
	Enums.LifeStage.ADULT: Enums.LifeStage.ELDER,
}


static func season_tick(
	colony: Colony,
	s: Settlement,
	food_factor: float,
	phenomena_pressure: float = 0.0,
	need_pressures: Dictionary = {},
	institution_factors: Dictionary = {},
) -> Dictionary:
	_graduate(s)
	# Crowding is read once, before this season's flows apply — pressure
	# reacts to the season people LIVED through, not the one being written
	# (deliberate; keeps every flow a function of the same state).
	var crowding := s.crowding(colony)
	var births := _births(colony, s, food_factor, crowding)
	s.by_stage[Enums.LifeStage.INFANT] += births
	var deaths := _deaths(colony, s)
	var migration_out := _migration(s, crowding, phenomena_pressure)
	if s.sid == colony.main_settlement:
		migration_out *= MAIN_RETENTION
	s.by_stage[Enums.LifeStage.ADULT] -= migration_out
	var discovered := _research(colony, s, need_pressures, food_factor, institution_factors)
	for axis in s.belief:
		s.belief[axis] *= pow(1.0 - Belief.RELAX_PER_DAY, TimeService.DAYS_PER_SEASON)
	return {
		"births": births,
		"deaths": deaths,
		"migration_out": migration_out,
		"discovered": discovered,
	}


## §14 trade: partners spread knowledge both ways — the re-spread path
## that ends a regional dark age. Returns the newly shared ids. (Belief
## spread rides migration/trade at the civilization tier, T11.4.)
static func trade(colony: Colony, a_sid: int, b_sid: int) -> Array:
	for sid in [a_sid, b_sid]:
		if not colony.settlement_knowledge.has(sid):
			colony.settlement_knowledge[sid] = {}
	var a: Dictionary = colony.settlement_knowledge[a_sid]
	var b: Dictionary = colony.settlement_knowledge[b_sid]
	var spread := []
	for id in b:
		if not a.has(id):
			a[id] = true
			spread.append(id)
	for id in a:
		if not b.has(id):
			b[id] = true
			spread.append(id)
	spread.sort()
	return spread


static func _graduate(s: Settlement) -> void:
	var season_years := TimeService.DAYS_PER_SEASON / float(TimeService.DAYS_PER_YEAR)
	# Oldest band first so a cohort can't graduate twice in one season.
	for stage in [
		Enums.LifeStage.ADULT,
		Enums.LifeStage.ADOLESCENT,
		Enums.LifeStage.CHILD,
		Enums.LifeStage.INFANT,
	]:
		var moving: float = s.by_stage[stage] * season_years / BAND_YEARS[stage]
		s.by_stage[stage] -= moving
		s.by_stage[NEXT_STAGE[stage]] += moving


static func _births(colony: Colony, s: Settlement, food_factor: float, crowding: float) -> float:
	var ag := TechEffects.level(colony, s.sid, "agriculture")
	# §17 unrest effects (wired at T16.5): −0.3·unrest on the aggregate
	# birth flow, same line as the individual grain [algo §10].
	return (
		Birth.SEASON_BIRTH_CHANCE
		* PAIR_CALIBRATION
		* s.adults()
		* food_factor
		* maxf(0.0, 1.0 - crowding)
		* TechEffects.fertility_mult(ag)
		* (1.0 - 0.3 * colony.unrest)
	)


static func _deaths(colony: Colony, s: Settlement) -> float:
	var med := TechEffects.mortality_mult(TechEffects.level(colony, s.sid, "medicine"))
	var total := 0.0
	for stage in STAGE_MID_AGE:
		var daily: float = Mortality.age_curve(STAGE_MID_AGE[stage]) * med + Mortality.ACCIDENT_BASE
		var lost: float = minf(
			s.by_stage[stage], s.by_stage[stage] * daily * TimeService.DAYS_PER_SEASON
		)
		s.by_stage[stage] -= lost
		total += lost
	return total


static func _migration(s: Settlement, crowding: float, phenomena_pressure: float) -> float:
	var pressure := clampf(
		(
			maxf(0.0, crowding - CROWDING_COMFORT) / (1.0 - CROWDING_COMFORT)
			+ MOOD_WEIGHT * maxf(0.0, MOOD_FLOOR - s.mood)
			+ phenomena_pressure
		),
		0.0,
		1.0
	)
	return minf(s.adults(), s.pop() * MIGRATION_BASE * pressure)


static func _research(
	colony: Colony,
	s: Settlement,
	need_pressures: Dictionary,
	surplus_factor: float,
	institution_factors: Dictionary,
) -> Array:
	# Truncated on purpose: research needs at least one WHOLE capable mind
	# — a 0.9-adult remnant does not run experiments.
	var minds := int(s.adults() + s.by_stage[Enums.LifeStage.ELDER])
	if minds <= 0:
		return []
	var known: Array = colony.settlement_knowledge.get(s.sid, {}).keys()
	var found := []
	for id in TechGraph.candidates(known):
		var pressure_value := Research.pressure(
			need_pressures.get(id, 0.0),
			s.mean_traits["curious"],
			surplus_factor,
			minds,
			institution_factors.get(id, 1.0)
		)
		if pressure_value <= 0.0:
			continue
		if Rng.chance(Research.p_discover(pressure_value)):
			if not colony.settlement_knowledge.has(s.sid):
				colony.settlement_knowledge[s.sid] = {}
			colony.settlement_knowledge[s.sid][id] = true
			found.append(id)
	return found
