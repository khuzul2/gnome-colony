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
const PROPAGATION_PER_DAY := 0.04
const FEAR_MULT := 1.5
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


## Batched daily propagation [plan T6.2, algo §9/§17]:
##   nbr.feeling += 0.04·tie·(src.feeling − nbr.feeling), fear ×1.5.
## Cadence is DAILY (every tick) — design-review R3-H1 retired the stale
## "every 4 ticks" wording. Deltas are computed against a tick-start
## snapshot (batched), so influence travels at most one edge per day.
static func propagate_tick(colony: Colony, dt_days: float) -> void:
	var living := colony.living()
	var deltas := []
	for src in living:
		for other_id in src.relationships:
			var nbr: GnomeData = colony.gnomes.get(other_id)
			if nbr == null or not nbr.is_alive():
				continue
			var tie: float = src.relationships[other_id]["weight"]
			if tie == 0.0:
				continue
			for subject in src.feelings:
				for axis in src.feelings[subject]:
					var gap: float = src.feelings[subject][axis] - nbr.get_feeling(subject, axis)
					if gap == 0.0:
						continue
					var rate := PROPAGATION_PER_DAY * (FEAR_MULT if axis == "fear" else 1.0)
					deltas.append([nbr, subject, axis, rate * tie * gap * dt_days])
	for d in deltas:
		d[0].adjust_feeling(d[1], d[2], d[3])


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
