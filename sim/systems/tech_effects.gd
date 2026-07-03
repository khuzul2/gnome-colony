class_name TechEffects
extends RefCounted
## Tech effects [plan T10.3, algo §13/§14/§17]: each discovered tech is a
## set of parameter deltas / unlocks. §17 fixes two formulas outright —
##   K            = base_K · Σrichness · (1 + 0.5·agriculture + 0.3·construction)
##   war_strength = pop · (1 + metallurgy) · (0.5 + leadership)
## — and writing's durability shipped with T4.5. §13 names the remaining
## effects without sizes; those magnitudes are INTERPRETIVE (PROGRESS.md):
## medicine cuts mortality/hardship by 40% at full level, agriculture
## lifts fertility 30%, metallurgy work output 30%, construction shelter
## (safety recovery) 30%. A settlement's tech LEVEL is binary for now —
## 1.0 once the id is known there (T11.2 kept it binary; graded levels
## are deferred to T11.4/T12 if the flows prove to need them).
## Consumers: Mortality.tick takes the
## medicine multiplier, Birth.season_tick the fertility one; war strength
## and sail/settlement unlocks are consumed by T11.x (DEFERRED there).

const K_AGRICULTURE := 0.5  # §17
const K_CONSTRUCTION := 0.3  # §17
const MEDICINE_CUT := 0.4  # interpretive
const FERTILITY_LIFT := 0.3  # interpretive
const EFFICIENCY_LIFT := 0.3  # interpretive
const SHELTER_LIFT := 0.3  # interpretive


## Binary settlement tech level (interpretive until T11.2's aggregates).
static func level(colony: Colony, sid: int, id: String) -> float:
	return 1.0 if colony.settlement_knowledge.get(sid, {}).has(id) else 0.0


## §17: K = base_K · Σrichness · (1 + 0.5·ag + 0.3·constr).
static func carrying_capacity(
	base_k: float, richness_sum: float, agriculture: float, construction: float
) -> float:
	return (
		base_k * richness_sum * (1.0 + K_AGRICULTURE * agriculture + K_CONSTRUCTION * construction)
	)


## §17: war_strength = pop · (1 + metallurgy) · (0.5 + leadership_quality).
static func war_strength(pop: float, metallurgy: float, leadership_quality: float) -> float:
	return pop * (1.0 + metallurgy) * (0.5 + leadership_quality)


## Medicine [§13: "lowers mortality a & hardship"] — one multiplier for both.
static func mortality_mult(medicine: float) -> float:
	return 1.0 - MEDICINE_CUT * medicine


## Agriculture [§13: "+birth rate"].
static func fertility_mult(agriculture: float) -> float:
	return 1.0 + FERTILITY_LIFT * agriculture


## Metallurgy [§13: "+work efficiency"] — consumer lands with T11.2's flows.
static func work_efficiency(metallurgy: float) -> float:
	return 1.0 + EFFICIENCY_LIFT * metallurgy


## Construction [§13: "+shelter (safety)"] — consumer lands with T11.2.
static func safety_recovery_mult(construction: float) -> float:
	return 1.0 + SHELTER_LIFT * construction


## Agriculture [§13: "enables settlements"] — consumed by T11.2.
static func enables_settlements(colony: Colony, sid: int) -> bool:
	return level(colony, sid, "agriculture") > 0.0


## Sail [§13: "cross water → reach new basins"] — consumed by T11.4.
static func can_cross_water(colony: Colony, sid: int) -> bool:
	return level(colony, sid, "sail") > 0.0
