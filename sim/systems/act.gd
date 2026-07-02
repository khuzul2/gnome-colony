class_name Act
extends RefCounted
## Action execution [plan T3.4]: apply the catalog's signed relief deltas
## (negative reduces the need — see the sign convention note in PROGRESS.md)
## plus side-effects. Eating draws one meal from the ctx food node; skill
## practice/teaching effects arrive with Phase 4.

## Units of food one meal draws from the node. An implementation unit —
## tests/world-gen choose node capacities around it.
const MEAL_UNITS := 1.0


static func apply(g: GnomeData, action: String, ctx: Dictionary = {}) -> void:
	if action == "idle" or not Actions.CATALOG.has(action):
		return
	var relief: Dictionary = Actions.CATALOG[action]["relief"]
	for need in relief:
		g.adjust_need(need, relief[need])
	if action == "eat" and ctx.has("food_node"):
		ctx["food_node"].harvest(MEAL_UNITS)
