class_name StructureEffects
extends RefCounted
## [rav §R-build, R2.4] — how built structures MODULATE the existing sim flows.
## Every function is INERT at zero of its structure (returns the multiplicative
## identity / adds nothing), so a structure-less settlement behaves EXACTLY as
## before — no double-count with the §14 tech terms these express concretely,
## and every pre-R2 test stays green. Pure & deterministic.
##
## Wired directly (single safe call-site): farm→Settlement.k, dwelling→
## Settlement.crowding, wall→Civilization war strength. The event/colony-level
## effects are exposed here and consumed at their sites (the codebase's
## deferred-consumer pattern): granary→famine deaths, well→drought mortality,
## workshop→craft research, basilica→terror-unrest growth & devotion mass,
## market→trade mood. Their isolation tests gate the numbers.

const FARM_K_PER := 0.15
const FARM_K_CAP := 0.5  # ≈ the §14 0.5·agriculture term — farms can't exceed it
const HOUSING_PER_DWELLING := 4.0
const WELL_DROUGHT_MULT := 0.8  # −20% drought/water mortality
const GRANARY_FAMINE_MULT := 0.7  # −30% famine deaths
const WORKSHOP_RESEARCH_MULT := 1.2
const BASILICA_UNREST_MULT := 0.8  # ×0.8 terror-unrest growth
const BASILICA_DEVOTION_MULT := 1.05
const WALL_STRENGTH_PER := 0.25
const WALL_STRENGTH_CAP := 2.0  # total multiplier caps at ×2
const MARKET_TRADE_MOOD_MULT := 1.5


## Multiply K by this — farms raise carrying capacity, capped at the §14 term.
static func farm_k_bonus(s: Settlement) -> float:
	return 1.0 + minf(FARM_K_PER * s.structure_count("farm"), FARM_K_CAP)


## Capacity ADDED by dwellings (0 without them — crowding then stays pop/K).
static func housing_capacity(s: Settlement) -> float:
	return HOUSING_PER_DWELLING * s.structure_count("dwelling")


static func drought_mortality_mult(s: Settlement) -> float:
	return WELL_DROUGHT_MULT if s.structure_count("well") >= 1.0 else 1.0


static func famine_mult(s: Settlement) -> float:
	return GRANARY_FAMINE_MULT if s.structure_count("granary") >= 1.0 else 1.0


static func research_mult(s: Settlement) -> float:
	return WORKSHOP_RESEARCH_MULT if s.structure_count("workshop") >= 1.0 else 1.0


static func unrest_growth_mult(s: Settlement) -> float:
	return BASILICA_UNREST_MULT if s.structure_count("basilica") >= 1.0 else 1.0


static func devotion_mass_mult(s: Settlement) -> float:
	return BASILICA_DEVOTION_MULT if s.structure_count("basilica") >= 1.0 else 1.0


## War strength multiplier from walls: ×(1 + 0.25·walls), capped at ×2.
static func war_strength_mult(s: Settlement) -> float:
	return 1.0 + minf(WALL_STRENGTH_PER * s.structure_count("wall"), WALL_STRENGTH_CAP - 1.0)


static func trade_mood_mult(s: Settlement) -> float:
	return MARKET_TRADE_MOOD_MULT if s.structure_count("market") >= 1.0 else 1.0
