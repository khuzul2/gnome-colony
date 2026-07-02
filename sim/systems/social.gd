class_name Social
extends RefCounted
## Relationship dynamics [plan T5.1, algo §8/§17]: typed edges in [-1,1],
## interaction step w += 0.05·sign·compat, idle decay −0.001/day toward 0.
## compat "rises with trait similarity" (no closed formula in the spec):
## implemented as 1 − mean |Δtrait| over the trait catalog — monotone in
## similarity, ∈[0,1] for in-band traits (noted in PROGRESS.md).
## Culture-defined norms multiply into compat later (T6.x hooks).

const INTERACT_STEP := 0.05
const IDLE_DECAY_PER_DAY := 0.001


static func compat(a: GnomeData, b: GnomeData) -> float:
	var diff_sum := 0.0
	for key in Enums.TRAIT_KEYS:
		diff_sum += absf(a.traits[key] - b.traits[key])
	return 1.0 - diff_sum / Enums.TRAIT_KEYS.size()


## One interaction between a and b: both directed edges move by
## 0.05·sign·compat and adopt `type`.
static func interact(a: GnomeData, b: GnomeData, type: String, sign_value: float) -> void:
	var step := INTERACT_STEP * sign_value * compat(a, b)
	var a_weight: float = a.relationships.get(b.id, {}).get("weight", 0.0)
	var b_weight: float = b.relationships.get(a.id, {}).get("weight", 0.0)
	a.set_relationship(b.id, type, a_weight + step)
	b.set_relationship(a.id, type, b_weight + step)


static func decay_tick(colony: Colony, dt_days: float) -> void:
	for g in colony.living():
		for other_id in g.relationships:
			var w: float = g.relationships[other_id]["weight"]
			var decayed := move_toward(w, 0.0, IDLE_DECAY_PER_DAY * dt_days)
			g.relationships[other_id]["weight"] = decayed
