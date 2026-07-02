class_name Actions
extends RefCounted
## Action catalog [plan T3.2, algo §6]. `relief` vectors are per use:
## negative = reduces that need, small positives = side costs. Stage gates
## and context requirements decide availability; scoring is T3.3's job.
## "create" is the §6 "create/explore" row (Adult-only; curious↑ biases the
## score via trait_mod, not the gate).
##
## ctx keys (all optional):
##   food_available (default true — abundant until the world exists),
##   teacher_available (default false — learning needs a teacher/source),
##   caregiver_available (default true).

const CATALOG := {
	"eat":
	{
		"relief": {"hunger": -0.9},
		"stages":
		[
			Enums.LifeStage.INFANT,
			Enums.LifeStage.CHILD,
			Enums.LifeStage.ADOLESCENT,
			Enums.LifeStage.ADULT,
			Enums.LifeStage.ELDER,
		],
	},
	"rest":
	{
		"relief": {"rest": -0.9},
		"stages":
		[
			Enums.LifeStage.INFANT,
			Enums.LifeStage.CHILD,
			Enums.LifeStage.ADOLESCENT,
			Enums.LifeStage.ADULT,
			Enums.LifeStage.ELDER,
		],
	},
	"socialize":
	{
		"relief": {"social": -0.7, "purpose": -0.1},
		"stages":
		[
			Enums.LifeStage.CHILD,
			Enums.LifeStage.ADOLESCENT,
			Enums.LifeStage.ADULT,
			Enums.LifeStage.ELDER,
		],
	},
	"work":
	{
		"relief": {"rest": 0.05, "purpose": -0.6},
		"stages": [Enums.LifeStage.ADOLESCENT, Enums.LifeStage.ADULT, Enums.LifeStage.ELDER],
	},
	"learn":
	{
		"relief": {"social": -0.05, "purpose": -0.4},
		"stages":
		[
			Enums.LifeStage.CHILD,
			Enums.LifeStage.ADOLESCENT,
			Enums.LifeStage.ADULT,
			Enums.LifeStage.ELDER,
		],
	},
	"teach":
	{
		"relief": {"social": -0.2, "purpose": -0.5},
		"stages": [Enums.LifeStage.ADULT, Enums.LifeStage.ELDER],
	},
	"create":
	{
		"relief": {"purpose": -0.6},
		"stages": [Enums.LifeStage.ADULT],
	},
}


static func relief(action: String) -> Dictionary:
	return CATALOG[action]["relief"]


static func available(g: GnomeData, ctx: Dictionary = {}) -> Array:
	if not g.is_alive():
		return []
	var out := []
	for action in CATALOG:
		if not g.stage in CATALOG[action]["stages"]:
			continue
		if action == "eat":
			if not ctx.get("food_available", true):
				continue
			if g.stage == Enums.LifeStage.INFANT and not ctx.get("caregiver_available", true):
				continue
		if action == "learn" and not ctx.get("teacher_available", false):
			continue
		if action == "teach" and g.knowledge.is_empty():
			continue
		out.append(action)
	return out
