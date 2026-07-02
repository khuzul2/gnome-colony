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
const PARTNER_THRESHOLD := 0.6


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


## Partnership [plan T5.2, algo §8]: two unpartnered Adults with MUTUAL
## mate-weight ≥ 0.6, culturally permitted, pair up. `permitted` is the
## culture hook (T6.x norms): Callable(a, b) -> bool, default always true.
## Iteration order over ids is deterministic (sorted), so results replay.
static func form_partnerships(colony: Colony, permitted: Callable = Callable()) -> void:
	var ids := colony.gnomes.keys()
	ids.sort()
	for i in ids.size():
		var a: GnomeData = colony.gnomes[ids[i]]
		if not _eligible(a):
			continue
		for j in range(i + 1, ids.size()):
			var b: GnomeData = colony.gnomes[ids[j]]
			if not _eligible(b):
				continue
			if _mate_weight(a, b.id) < PARTNER_THRESHOLD:
				continue
			if _mate_weight(b, a.id) < PARTNER_THRESHOLD:
				continue
			if permitted.is_valid() and not permitted.call(a, b):
				continue
			a.partner_id = b.id
			b.partner_id = a.id
			break


static func _eligible(g: GnomeData) -> bool:
	return g.is_alive() and g.stage == Enums.LifeStage.ADULT and g.partner_id == -1


static func _mate_weight(g: GnomeData, other_id: int) -> float:
	var edge: Dictionary = g.relationships.get(other_id, {})
	if edge.get("type", "") != "mate":
		return 0.0
	return edge.get("weight", 0.0)


static func decay_tick(colony: Colony, dt_days: float) -> void:
	for g in colony.living():
		for other_id in g.relationships:
			var w: float = g.relationships[other_id]["weight"]
			var decayed := move_toward(w, 0.0, IDLE_DECAY_PER_DAY * dt_days)
			g.relationships[other_id]["weight"] = decayed
