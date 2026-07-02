class_name Needs
extends RefCounted
## Need decay [plan T3.1, algo §3/§17]. Per day: hunger 0.12 · rest 0.10 ·
## social 0.08 · purpose 0.06, each × stage modifier. `safety` is special:
## spiked by threats/appraisal (Phase 7), it RECOVERS −0.06/day toward 0.
## Hardship tracking (sustained ≥0.9 → mortality bonus) is T3.5.

const DECAY_PER_DAY := {"hunger": 0.12, "rest": 0.10, "social": 0.08, "purpose": 0.06}
const SAFETY_RECOVERY_PER_DAY := 0.06
const ADOLESCENT_SOCIAL_MOD := 1.3
const MATURE_PURPOSE_MOD := 1.3

# Hardship [algo §3/§17]: hunger/safety ≥ 0.9 sustained > 5 days
# ⇒ +0.15/day mortality (consumed by Mortality via hardship_rate).
const HARDSHIP_NEEDS := ["hunger", "safety"]
const HARDSHIP_THRESHOLD := 0.9
const HARDSHIP_SUSTAIN_DAYS := 5.0
const HARDSHIP_MORTALITY := 0.15


static func stage_mod(g: GnomeData, need: String) -> float:
	if need == "social" and g.stage == Enums.LifeStage.ADOLESCENT:
		return ADOLESCENT_SOCIAL_MOD
	if need == "purpose" and g.stage in [Enums.LifeStage.ADULT, Enums.LifeStage.ELDER]:
		return MATURE_PURPOSE_MOD
	return 1.0


static func tick(colony: Colony, dt_days: float) -> void:
	for g in colony.living():
		for need in DECAY_PER_DAY:
			g.adjust_need(need, DECAY_PER_DAY[need] * stage_mod(g, need) * dt_days)
		g.adjust_need("safety", -SAFETY_RECOVERY_PER_DAY * dt_days)
		_track_hardship(g, dt_days)


static func _track_hardship(g: GnomeData, dt_days: float) -> void:
	var suffering := false
	for need in HARDSHIP_NEEDS:
		if g.needs[need] >= HARDSHIP_THRESHOLD:
			g.hardship_days[need] += dt_days
		else:
			g.hardship_days[need] = 0.0
		if g.hardship_days[need] > HARDSHIP_SUSTAIN_DAYS:
			suffering = true
	g.hardship_rate = HARDSHIP_MORTALITY if suffering else 0.0
