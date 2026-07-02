class_name Skills
extends RefCounted
## Skills / knowledge proficiency [plan T4.1, algo §7/§17]:
##   practice: prof += 0.01·(1−prof)·dt
## The knowledge id (teachability) tracks prof ≥ 0.2 in BOTH directions.
## Teaching transfer arrives in T4.2, decay/un-teachability in T4.3.

const PRACTICE_RATE := 0.01
const TEACHABLE_AT := 0.2


static func practice(g: GnomeData, skill: String, dt_days: float) -> void:
	var prof: float = g.skills.get(skill, 0.0)
	g.set_skill(skill, prof + PRACTICE_RATE * (1.0 - prof) * dt_days)
	_update_teachability(g, skill)


static func _update_teachability(g: GnomeData, skill: String) -> void:
	if g.skills.get(skill, 0.0) >= TEACHABLE_AT:
		g.add_knowledge(skill)
	else:
		g.knowledge.erase(skill)
