class_name Skills
extends RefCounted
## Skills / knowledge proficiency [plan T4.1–T4.2, algo §7/§17]:
##   practice: prof += 0.01·(1−prof)·dt
##   teaching: learner.prof += 0.03·(teacher.prof − learner.prof)·q·dt
## The knowledge id (teachability) tracks prof ≥ 0.2 in BOTH directions.
## Decay/un-teachability arrives in T4.3. `teacher_quality` (q) has no
## spec-defined formula — explicit parameter, default 1.0 (PROGRESS.md).

const PRACTICE_RATE := 0.01
const TEACH_RATE := 0.03
const TEACHABLE_AT := 0.2
const DECAY_PER_DAY := 0.002


static func practice(g: GnomeData, skill: String, dt_days: float) -> void:
	var prof: float = g.skills.get(skill, 0.0)
	g.set_skill(skill, prof + PRACTICE_RATE * (1.0 - prof) * dt_days)
	_update_teachability(g, skill)


## Teaching requires the teacher to hold the teachable id and only ever
## pulls the learner UP toward the teacher [algo §7].
static func teach(
	teacher: GnomeData,
	learner: GnomeData,
	skill: String,
	dt_days: float,
	teacher_quality: float = 1.0,
) -> void:
	if not skill in teacher.knowledge:
		return
	var t_prof: float = teacher.skills.get(skill, 0.0)
	var l_prof: float = learner.skills.get(skill, 0.0)
	if t_prof <= l_prof:
		return
	learner.set_skill(skill, l_prof + TEACH_RATE * (t_prof - l_prof) * teacher_quality * dt_days)
	_update_teachability(learner, skill)


## Unused-skill decay [algo §7] (T4.3): every skill NOT in `used_skills`
## loses 0.002/day; falling below 0.2 forfeits the teachable id.
static func decay(g: GnomeData, dt_days: float, used_skills: Array = []) -> void:
	for skill in g.skills:
		if skill in used_skills:
			continue
		g.set_skill(skill, g.skills[skill] - DECAY_PER_DAY * dt_days)
		_update_teachability(g, skill)


static func _update_teachability(g: GnomeData, skill: String) -> void:
	if g.skills.get(skill, 0.0) >= TEACHABLE_AT:
		g.add_knowledge(skill)
	else:
		g.knowledge.erase(skill)
