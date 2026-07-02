class_name Notability
extends RefCounted
## Notability growth [plan T8.6, algo §14/§17]: the metric that drives LOD
## promotion (≥ 0.6) and leadership rises from notable deeds — surviving or
## causing a major phenomenon, mastering a craft (skill ≥ 0.9), reaching
## Elder, raising many children, prophet/leader status — and decays
## −0.001/day so the famous fade as new figures rise. §17 fixes ONLY the
## decay; the award weights are interpretive (noted in PROGRESS.md), sized
## so prophet/leader status plus one deed crosses the 0.6 promotion line.

const DECAY_PER_DAY := 0.001  # §17: "notability decay −0.001/day"

# Interpretive award weights — §14 lists the deeds, not their sizes.
const DEED := 0.3  # surviving/causing a major phenomenon, Elder, many children
const MASTERY := 0.3  # mastering a craft — once per craft, ever
const PROPHET_LEADER := 0.4  # becoming a prophet or a leader

const MASTERY_LINE := 0.9  # §14: "mastering a craft (skill ≥ 0.9)"

# §14 leader_score = 0.5·notability + 0.3·ambitious + 0.2·relevant_skill,
# relevant_skill = an oratory/leadership skill, or the best skill if none.
const LEADER_SKILLS := ["oratory", "leadership"]


static func award(g: GnomeData, amount: float) -> void:
	g.notability = clampf(g.notability + amount, 0.0, 1.0)


## Daily fade [§17]: the famous are forgotten unless they keep doing deeds.
static func tick(colony: Colony, dt_days: float) -> void:
	for g in colony.living():
		g.notability = maxf(0.0, g.notability - DECAY_PER_DAY * dt_days)


## Craft mastery credit [§14] — fires when a skill stands at ≥ 0.9, and at
## most once per craft per lifetime (the credit set is serialized).
static func on_mastery(g: GnomeData, skill: String) -> void:
	if g.skills.get(skill, 0.0) < MASTERY_LINE:
		return
	if skill in g.mastered_skills:
		return
	g.mastered_skills.append(skill)
	award(g, MASTERY)


## §14 emergent leadership score — consumed by the settlement tier (T11.x);
## no leader is ever appointed by the player.
static func leader_score(g: GnomeData) -> float:
	var relevant := 0.0
	var has_leader_skill := false
	for key in LEADER_SKILLS:
		if g.skills.has(key):
			has_leader_skill = true
			relevant = maxf(relevant, g.skills[key])
	if not has_leader_skill:
		for value in g.skills.values():
			relevant = maxf(relevant, value)
	return 0.5 * g.notability + 0.3 * g.traits["ambitious"] + 0.2 * relevant
