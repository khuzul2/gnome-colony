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
const CRYSTALLIZE_STRENGTH := 0.7
const MIN_HOLDERS_FLOOR := 5
const MIN_HOLDERS_FRACTION := 0.03
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


## Crystallization [plan T6.3, algo §9 Layer B]: when ≥ max(5, 3% of the
## settlement) living gnomes hold a (subject, axis) feeling at ≥ 0.7 for a
## full season, it crystallizes into a named belief-object. Strength =
## mean backing feeling × holder fraction. Taboos curse the place-tag,
## place-reverence blesses it; belief_formed fires once per object.
static func crystallize_tick(colony: Colony, dt_days: float) -> void:
	var living := colony.living()
	var pop := living.size()
	if pop == 0:
		return
	var min_holders := maxi(MIN_HOLDERS_FLOOR, ceili(MIN_HOLDERS_FRACTION * pop))
	var qualifying := {}
	for g in living:
		for subject in g.feelings:
			for axis in g.feelings[subject]:
				if g.feelings[subject][axis] >= CRYSTALLIZE_STRENGTH:
					var key := "%s|%s" % [subject, axis]
					if not qualifying.has(key):
						qualifying[key] = {"holders": [], "total": 0.0}
					qualifying[key]["holders"].append(g.id)
					qualifying[key]["total"] += g.feelings[subject][axis]
	for key in colony.belief_tracker.keys():
		if not qualifying.has(key) or qualifying[key]["holders"].size() < min_holders:
			colony.belief_tracker.erase(key)
	for key in qualifying:
		var holders: Array = qualifying[key]["holders"]
		if holders.size() < min_holders:
			continue
		colony.belief_tracker[key] = colony.belief_tracker.get(key, 0.0) + dt_days
		if colony.belief_tracker[key] < TimeService.DAYS_PER_SEASON:
			continue
		var parts: PackedStringArray = key.split("|")
		var subject := String(parts[0])
		var axis := String(parts[1])
		var mean_feeling: float = qualifying[key]["total"] / holders.size()
		var strength: float = mean_feeling * (float(holders.size()) / pop)
		for kind in BeliefObject.kinds_for_axis(axis):
			if _has_object(colony, kind, subject):
				continue
			colony.beliefs.append(BeliefObject.make(kind, subject, axis, strength, holders))
			if kind == "place_reverence":
				_tag_place(colony, subject, "blessed", mean_feeling)
			EventBus.belief_formed.emit(
				{"kind": kind, "subject": subject, "axis": axis, "strength": strength}
			)


## Behavioral effect of beliefs about a place [plan T6.4, algo §6/§9]:
## the belief_mod multiplier for acting there. Sources multiply:
##   · a taboo OBJECT on the place → ×(1 − 0.5·strength)  (avoidance)
##   · a "cursed" tag (written by phenomena/chains, Phase 7) → same map
##   · a "blessed" tag (place-reverence) → ×(1 + 0.8·strength)
## §6 bounds belief_mod to ~[0.5, 1.8]; the linear maps reach exactly those
## endpoints at full strength (interpretive). Contested ground pulls both
## ways.
static func place_mod(colony: Colony, place: String) -> float:
	var mod := 1.0
	for b in colony.beliefs:
		if b["kind"] == "taboo" and b["subject"] == place:
			mod *= 1.0 - 0.5 * clampf(b["strength"], 0.0, 1.0)
	var tags: Dictionary = colony.place_tags.get(place, {})
	if tags.has("cursed"):
		mod *= 1.0 - 0.5 * clampf(tags["cursed"], 0.0, 1.0)
	if tags.has("blessed"):
		mod *= 1.0 + 0.8 * clampf(tags["blessed"], 0.0, 1.0)
	return mod


static func _has_object(colony: Colony, kind: String, subject: String) -> bool:
	for b in colony.beliefs:
		if b["kind"] == kind and b["subject"] == subject:
			return true
	return false


static func _tag_place(colony: Colony, subject: String, tag: String, strength: float) -> void:
	if not colony.place_tags.has(subject):
		colony.place_tags[subject] = {}
	colony.place_tags[subject][tag] = strength


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
