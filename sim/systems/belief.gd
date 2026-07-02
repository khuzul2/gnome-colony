class_name Belief
extends RefCounted
## Layer A — the scalar belief substrate [plan T6.1, algo §9/§17]: cheap
## per-(subject, axis) feelings on every gnome.
##   appraisal write:  feeling += intensity·susceptibility − habituation
##   habituation:      +0.15 per repeat of the same phenomenon type,
##                     recovering −0.02/day
##   relaxation:       feeling += −0.03·(feeling − baseline)·dt  (≈23 d)
## susceptibility(traits, theology) has no closed formula in the spec —
## implemented as 0.5 + 0.5·relevant_trait (∈[0.5,1]; fear→timid,
## faith→devout, awe→curious, reverence→devout — interpretive, PROGRESS.md).
## Theology feedback into susceptibility arrives with Phase 8's theology.

const RELAX_PER_DAY := 0.03
const HABITUATION_STEP := 0.15
const HABITUATION_RECOVERY_PER_DAY := 0.02
const FEELING_BASELINE := 0.0
const AXIS_TRAIT := {"fear": "timid", "faith": "devout", "awe": "curious", "reverence": "devout"}


static func susceptibility(g: GnomeData, axis: String) -> float:
	var trait_key: String = AXIS_TRAIT.get(axis, "")
	if trait_key == "":
		return 1.0
	return 0.5 + 0.5 * g.traits.get(trait_key, 0.5)


## One witnessed stimulus: write the feeling through the gnome's traits,
## dampened by habituation to that phenomenon type (never inverted), then
## deepen the habituation.
static func appraise(
	g: GnomeData, subject: String, axis: String, intensity: float, phenomenon_type: String = ""
) -> void:
	var dampening: float = g.habituation.get(phenomenon_type, 0.0) if phenomenon_type != "" else 0.0
	var delta := maxf(0.0, intensity * susceptibility(g, axis) - dampening)
	if delta > 0.0:
		g.adjust_feeling(subject, axis, delta)
	if phenomenon_type != "":
		g.habituation[phenomenon_type] = dampening + HABITUATION_STEP


## Daily relaxation of feelings toward baseline + habituation recovery.
static func decay_tick(colony: Colony, dt_days: float) -> void:
	for g in colony.living():
		for subject in g.feelings:
			for axis in g.feelings[subject]:
				var f: float = g.feelings[subject][axis]
				g.feelings[subject][axis] = f - RELAX_PER_DAY * (f - FEELING_BASELINE) * dt_days
		for ptype in g.habituation.keys():
			var h: float = g.habituation[ptype] - HABITUATION_RECOVERY_PER_DAY * dt_days
			if h <= 0.0:
				g.habituation.erase(ptype)
			else:
				g.habituation[ptype] = h
