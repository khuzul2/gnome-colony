class_name Mortality
extends RefCounted
## Mortality [plan T2.3, algo §4/§17]:
##   p_death/day = age_curve(age) + hardship + accident
## age_curve ≈ Gompertz a·exp(b·(age−65)), a=0.00005, b=0.085 — negligible
## until Elder, then climbs. accident baseline 0.00002/day. Hard cap ~115.
## Each component is rolled separately (age → hardship → accident, fixed
## order) so the death cause falls out naturally; for these magnitudes the
## sum-of-components and per-component formulations are equivalent.

const GOMPERTZ_A := 0.00005
const GOMPERTZ_B := 0.085
const ELDER_PIVOT := 65.0
const ACCIDENT_BASE := 0.00002
const AGE_HARD_CAP := 115.0


static func age_curve(age_years: float) -> float:
	return GOMPERTZ_A * exp(GOMPERTZ_B * (age_years - ELDER_PIVOT))


## `medicine_mult` scales the age curve AND hardship [algo §13: medicine
## "lowers mortality a & hardship"] — default 1.0 keeps pre-tech behavior
## (T10.3; callers pass TechEffects.mortality_mult(level)).
static func tick(colony: Colony, dt_days: float, medicine_mult: float = 1.0) -> void:
	for g in colony.living():
		if g.age >= AGE_HARD_CAP:
			_die(g, "age")
			continue
		if Rng.chance(age_curve(g.age) * medicine_mult * dt_days):
			_die(g, "age")
		elif Rng.chance(g.hardship_rate * medicine_mult * dt_days):
			_die(g, "hardship")
		elif Rng.chance(ACCIDENT_BASE * dt_days):
			_die(g, "accident")


static func _die(g: GnomeData, cause: String) -> void:
	g.stage = Enums.LifeStage.DEAD
	EventBus.gnome_died.emit({"id": g.id, "cause": cause, "age": g.age})
