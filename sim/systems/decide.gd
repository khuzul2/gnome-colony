class_name Decide
extends RefCounted
## Decision step [plan T3.4, algo §6]: score every stage/context-available
## action (Utility, with jitter) and pick the max. "idle" is the fallback
## when nothing is available — a no-op, not a catalog action. An active,
## non-urgent project short-circuits scoring and returns "project:<kind>"
## (T3.6).


static func choose(g: GnomeData, ctx: Dictionary = {}) -> String:
	# An active project holds the gnome's day unless a need is desperate
	# (≥0.9) — long-horizon behavior isn't re-decided each tick (T3.6).
	if not g.project.is_empty() and not Projects.has_urgent_need(g):
		return "project:%s" % g.project["kind"]
	var best := "idle"
	var best_score := -INF
	for action in Actions.available(g, ctx):
		# Inlined Utility.score (base + jitter): one call layer fewer on
		# the hottest loop in the sim (T11.5) — identical math and an
		# identical Rng stream.
		var s := Utility.base_score(g, action, ctx) + Rng.randf_range(0.0, Utility.JITTER_MAX)
		if s > best_score:
			best_score = s
			best = action
	return best
