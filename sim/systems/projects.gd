class_name Projects
extends RefCounted
## Multi-tick projects [plan T3.6, algo §6, review C4]: a long-horizon goal
## (explore/build/master…) persists across ticks instead of being re-decided
## daily. The ONLY thing that drops a project is a desperate need — the
## spec's 0.9 line (Needs.HARDSHIP_THRESHOLD), so mild spikes never abandon
## work. Completion applies the §6 create/explore relief (purpose −0.6):
## the project's days were that work.


static func start(g: GnomeData, kind: String, duration_days: float) -> void:
	g.project = {"kind": kind, "progress": 0.0, "duration": duration_days}


static func has_urgent_need(g: GnomeData) -> bool:
	for need in g.needs:
		if g.needs[need] >= Needs.HARDSHIP_THRESHOLD:
			return true
	return false


static func tick(colony: Colony, dt_days: float) -> void:
	for g in colony.living():
		if g.project.is_empty():
			continue
		if has_urgent_need(g):
			g.project = {}
			continue
		g.project["progress"] += dt_days
		if g.project["progress"] >= g.project["duration"]:
			g.adjust_need("purpose", Actions.relief("create")["purpose"])
			g.project = {}
