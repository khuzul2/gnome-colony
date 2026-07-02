class_name Magic
extends RefCounted
## The magic branch — studying YOU [plan T10.4, algo §13/§17]. A
## settlement accrues magic_understanding (mu ∈ [0,1]):
##   mu += 0.0008 · (0.3 + curiosity_mean) · exposure · science_level /day
## and climbs a locked co-evolution ladder (§17 thresholds):
##   Superstition 0 · Proto-science 0.3 · Prediction 0.5 (omen/wonder
##   belief-impact ×(1−0.6·mu)) · Harnessing 0.7 (mages) · Resistance 0.85
##   (wards cut incoming intensity by up to 0.7; heretics can defy you).
## INTERPRETIVE (documented in PROGRESS.md): the prediction damp applies
## to Omens ⑤ and Wonders ⑦ (§13 says "Omen & Wonder"); ward strength
## ramps linearly across the resistance band (0.85 → 1.0 maps 0 → 0.7 —
## §13 says only "up to 0.7"); mage BEHAVIOR (minor phenomena) is beyond
## this task — the stage gate is what ships here.

const ACCRUAL_RATE := 0.0008  # §17
const CURIOSITY_FLOOR := 0.3  # §13 (same floor as research)

const STAGE_PROTO := 0.3
const STAGE_PREDICTION := 0.5
const STAGE_HARNESSING := 0.7
const STAGE_RESISTANCE := 0.85

const PREDICTION_DAMP := 0.6  # §17: ×(1−0.6·mu)
const WARD_MAX := 0.7  # §13: "reduce incoming phenomenon intensity by up to 0.7"

## §18 categories whose belief-impact prediction dulls [§13 "Omen & Wonder"].
const PREDICTED_CATEGORIES := [5, 7]


static func mu(colony: Colony, sid: int) -> float:
	return colony.magic_understanding.get(sid, 0.0)


## Daily accrual [§13/§17]: exposure counts the player's recent phenomena
## (an input — the environment tier supplies it), science_level the
## settlement's [0,1] scholarship.
static func accrue(
	colony: Colony,
	sid: int,
	curiosity_mean: float,
	exposure: float,
	science_level: float,
	dt_days: float,
) -> void:
	var gain := (
		ACCRUAL_RATE * (CURIOSITY_FLOOR + curiosity_mean) * exposure * science_level * dt_days
	)
	colony.magic_understanding[sid] = clampf(mu(colony, sid) + gain, 0.0, 1.0)


static func stage(mu_value: float) -> String:
	if mu_value >= STAGE_RESISTANCE:
		return "resistance"
	if mu_value >= STAGE_HARNESSING:
		return "harnessing"
	if mu_value >= STAGE_PREDICTION:
		return "prediction"
	if mu_value >= STAGE_PROTO:
		return "proto_science"
	return "superstition"


## Prediction [§13/§17]: from mu ≥ 0.5, omen/wonder belief-impact is
## ×(1−0.6·mu) — an expected portent doesn't awe. Below the stage, 1.0.
static func omen_impact_mult(mu_value: float) -> float:
	if mu_value < STAGE_PREDICTION:
		return 1.0
	return 1.0 - PREDICTION_DAMP * mu_value


## Convenience for callers wiring a stimulus: dampen only the predicted
## categories (⑤ omens, ⑦ wonders) of the witnessing settlement.
static func impact_mult_for(colony: Colony, sid: int, stimulus: Dictionary) -> float:
	if not stimulus.get("category", 0) in PREDICTED_CATEGORIES:
		return 1.0
	return omen_impact_mult(mu(colony, sid))


## Resistance [§13]: at mu ≥ 0.85 wards can be raised; strength ramps
## linearly across the band (interpretive) to the 0.7 cap at mu = 1.
static func ward_reduction(mu_value: float) -> float:
	if mu_value < STAGE_RESISTANCE:
		return 0.0
	return WARD_MAX * (mu_value - STAGE_RESISTANCE) / (1.0 - STAGE_RESISTANCE)


## Raise a ward on a place — a no-op below the resistance stage.
static func place_ward(world: WorldState, place: String, mu_value: float) -> void:
	var reduction := ward_reduction(mu_value)
	if reduction <= 0.0:
		return
	world.wards[place] = reduction


## Heresy [§13]: at the resistance stage gnomes CAN defy you — and since
## secularization is only mild (§10), defiance never requires disbelief:
## the devout heretic (high faith, high resistance) stays reachable.
static func can_defy(colony: Colony, sid: int) -> bool:
	return mu(colony, sid) >= STAGE_RESISTANCE
