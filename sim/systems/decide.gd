class_name Decide
extends RefCounted
## Decision step [plan T3.4, algo §6]: score every stage/context-available
## action (Utility, with jitter) and pick the max. "idle" is the fallback
## when nothing is available — a no-op, not a catalog action.


static func choose(g: GnomeData, ctx: Dictionary = {}) -> String:
	# An active project holds the gnome's day unless a need is desperate
	# (≥0.9) — long-horizon behavior isn't re-decided each tick (T3.6).
	if not g.project.is_empty() and not Projects.has_urgent_need(g):
		return "project:%s" % g.project["kind"]
	var best := "idle"
	var best_score := -INF
	for action in Actions.available(g, ctx):
		var s := Utility.score(g, action, ctx)
		if s > best_score:
			best_score = s
			best = action
	return best
