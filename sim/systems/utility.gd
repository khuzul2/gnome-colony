class_name Utility
extends RefCounted
## Utility scoring [plan T3.3, algo §6]:
##   score(a) = Σ_need [need² · relief(a,need)] · trait_mod · culture_mod
##              · belief_mod + U(0, 0.05)
## relief here is the REDUCTION (−delta), so side costs (positive deltas in
## the catalog) subtract naturally. The only spec-defined trait_mod is
## work ×(0.7+0.6·industrious) [algo §2]; culture/belief mods default to 1
## and are supplied via ctx by the culture system (T6.4).

const JITTER_MAX := 0.05
const WORK_MOD_BASE := 0.7
const WORK_MOD_SLOPE := 0.6

## Shared read-only default so hot-path .get() calls don't allocate a
## fresh Dictionary per score (T11.5 perf). Never written.
const NO_MODS := {}


static func trait_mod(g: GnomeData, action: String) -> float:
	if action == "work":
		return WORK_MOD_BASE + WORK_MOD_SLOPE * g.traits["industrious"]
	return 1.0


static func base_score(g: GnomeData, action: String, ctx: Dictionary = {}) -> float:
	var total := 0.0
	var relief: Dictionary = Actions.relief(action)
	for need in relief:
		var need_level: float = g.needs.get(need, 0.0)
		total += need_level * need_level * -relief[need]
	var culture_mod: float = ctx.get("culture_mods", NO_MODS).get(action, 1.0)
	var belief_mod: float = ctx.get("belief_mods", NO_MODS).get(action, 1.0)
	return total * trait_mod(g, action) * culture_mod * belief_mod


static func score(g: GnomeData, action: String, ctx: Dictionary = {}) -> float:
	return base_score(g, action, ctx) + Rng.randf_range(0.0, JITTER_MAX)
