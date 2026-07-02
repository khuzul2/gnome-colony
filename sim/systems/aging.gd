class_name Aging
extends RefCounted
## Aging & stage transitions [plan T2.2, algo §4/§17].
## Stage bands (years): Infant 0–3 · Child 3–14 · Adolescent 14–20 ·
## Adult 20–65 · Elder 65+. Crossing a band emits `stage_changed`.

const INFANT_UNTIL := 3.0
const CHILD_UNTIL := 14.0
const ADOLESCENT_UNTIL := 20.0
const ADULT_UNTIL := 65.0


static func stage_for_age(age_years: float) -> int:
	if age_years < INFANT_UNTIL:
		return Enums.LifeStage.INFANT
	if age_years < CHILD_UNTIL:
		return Enums.LifeStage.CHILD
	if age_years < ADOLESCENT_UNTIL:
		return Enums.LifeStage.ADOLESCENT
	if age_years < ADULT_UNTIL:
		return Enums.LifeStage.ADULT
	return Enums.LifeStage.ELDER


## Advance every living gnome by `dt_days`; transition stages on band
## crossings. Death is Mortality's job (T2.3), never Aging's.
static func tick(colony: Colony, dt_days: float) -> void:
	for g in colony.living():
		g.age += dt_days / TimeService.DAYS_PER_YEAR
		var new_stage := stage_for_age(g.age)
		if new_stage != g.stage:
			var old_stage: int = g.stage
			g.stage = new_stage
			EventBus.stage_changed.emit({"id": g.id, "from": old_stage, "to": new_stage})
