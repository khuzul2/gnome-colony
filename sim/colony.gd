class_name Colony
extends RefCounted
## Registry of every gnome, living and dead [plan T1.3], plus the aggregate
## vitals read-out [algo §5]. Pure data container — systems mutate it.

var gnomes := {}
var next_id := 0
## Per-settlement known knowledge ids [algo §7] (T4.4): sid → {id: true}.
var settlement_knowledge := {}
## Per-settlement durable (written) records exempt from extinction (T4.5).
var durable_records := {}
## Crystallized belief-objects [algo §9 Layer B] (T6.3) — plain dicts, see
## BeliefObject.make().
var beliefs: Array = []
## World-facing belief tags {subject: {"cursed"/"blessed": strength}} that
## bias utility at those places (T6.3/T6.4).
var place_tags := {}
## Consecutive days each (subject, axis) has met the crystallization
## condition (T6.3 internal state).
var belief_tracker := {}
## Highest per-capita devotion ever reached [algo §10] (T8.2).
var devotion_peak := 0.0
## Ratcheting toolbox tier — once earned, never stripped (T8.2).
var unlocked_tier := 1


func spawn() -> GnomeData:
	var g := GnomeData.new(next_id)
	add(g)
	return g


func add(gnome: GnomeData) -> void:
	gnomes[gnome.id] = gnome
	next_id = maxi(next_id, gnome.id + 1)


func remove(gnome_id: int) -> void:
	gnomes.erase(gnome_id)


func living() -> Array:
	var out := []
	for g in gnomes.values():
		if g.is_alive():
			out.append(g)
	return out


func population() -> int:
	return living().size()


## Aggregate vitals [algo §5]: population by stage, mean traits/needs,
## mean mood (1 − mean of the five primary needs). Settlement-tier state
## builds on this later (T11.2).
func vitals() -> Dictionary:
	var alive := living()
	var by_stage := {}
	var mean_needs := {}
	var mean_traits := {}
	var mood_total := 0.0
	for key in Enums.NEED_KEYS:
		mean_needs[key] = 0.0
	for key in Enums.TRAIT_KEYS:
		mean_traits[key] = 0.0
	for g in alive:
		by_stage[g.stage] = by_stage.get(g.stage, 0) + 1
		var need_sum := 0.0
		for key in Enums.NEED_KEYS:
			mean_needs[key] += g.needs[key]
			need_sum += g.needs[key]
		for key in Enums.TRAIT_KEYS:
			mean_traits[key] += g.traits[key]
		mood_total += 1.0 - need_sum / Enums.NEED_KEYS.size()
	var n := alive.size()
	if n > 0:
		for key in Enums.NEED_KEYS:
			mean_needs[key] /= n
		for key in Enums.TRAIT_KEYS:
			mean_traits[key] /= n
	return {
		"population": n,
		"by_stage": by_stage,
		"mean_needs": mean_needs,
		"mean_traits": mean_traits,
		"mean_mood": mood_total / n if n > 0 else 1.0,
	}
