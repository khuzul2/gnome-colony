class_name Promotion
extends RefCounted
## Promotion fidelity [plan T11.3, algo §14]: the bridge between the
## settlement aggregate and individual fidelity. Materializing SAMPLES a
## person from the statistics — feelings copied from the aggregate belief
## scalars exactly (§14's wording), traits scattered N(mean, 0.15) (the
## §5 founder sd — interpretive), age uniform within the drawn stage band,
## needs spread evenly from the aggregate mood. Dematerializing folds the
## richer lived state back: head-counts exactly, scalar means as running
## averages, held knowledge into the settlement set (§7). Memories and
## relationships are consciously dropped at the fold — §14: "minor
## divergence is acceptable — and, under the Eye, intended."

const TRAIT_SAMPLE_SD := 0.15
## Age spans per stage for sampling (§17 bands; Elder's open band is
## capped at 90 for draws — below the 115 hard cap, documented).
const BAND_SPAN := {
	Enums.LifeStage.INFANT: [0.0, 3.0],
	Enums.LifeStage.CHILD: [3.0, 14.0],
	Enums.LifeStage.ADOLESCENT: [14.0, 20.0],
	Enums.LifeStage.ADULT: [20.0, 65.0],
	Enums.LifeStage.ELDER: [65.0, 90.0],
}


## Draw up to `count` individuals out of the aggregate (largest bucket
## first — deterministic; the variety lives in the Rng-sampled bodies).
## Returns the materialized gnomes, registered on the colony.
static func materialize(colony: Colony, s: Settlement, count: int) -> Array:
	var drawn := []
	for i in count:
		var stage := _largest_bucket(s)
		if stage == -1:
			break
		s.by_stage[stage] -= 1.0
		drawn.append(_sample(colony, s, stage))
	return drawn


## Fold individuals back into the statistics: buckets exactly, scalar
## means as running averages, knowledge into the settlement set. The
## gnome objects leave the colony registry.
static func dematerialize(colony: Colony, s: Settlement, gnomes: Array) -> void:
	for g in gnomes:
		# The dead are skipped, not folded: their head-count already left
		# the buckets at materialize-time and Mortality counted the death —
		# folding a corpse would resurrect it statistically. They stay in
		# the registry of every gnome, living and dead (reviewer note).
		if not g.is_alive():
			continue
		var pop_before := s.pop()
		s.by_stage[g.stage] += 1.0
		for key in Enums.TRAIT_KEYS:
			s.mean_traits[key] = _fold_mean(s.mean_traits[key], pop_before, g.traits[key])
		for axis in s.belief:
			s.belief[axis] = _fold_mean(
				s.belief[axis], pop_before, g.get_feeling(Devotion.YOU, axis)
			)
		var need_sum := 0.0
		for key in Enums.NEED_KEYS:
			need_sum += g.needs[key]
		s.mood = _fold_mean(s.mood, pop_before, 1.0 - need_sum / Enums.NEED_KEYS.size())
		if not colony.settlement_knowledge.has(s.sid):
			colony.settlement_knowledge[s.sid] = {}
		for id in g.knowledge:
			colony.settlement_knowledge[s.sid][id] = true
		colony.remove(g.id)


static func _largest_bucket(s: Settlement) -> int:
	var best := -1
	# 0.999, not 1.0: a float-precision fudge so a bucket that is "one
	# whole gnome" minus rounding dust still yields them (reviewer note).
	var best_count := 0.999
	for stage in s.by_stage:
		if s.by_stage[stage] > best_count:
			best_count = s.by_stage[stage]
			best = stage
	return best


static func _sample(colony: Colony, s: Settlement, stage: int) -> GnomeData:
	var g := colony.spawn()
	g.home_settlement = s.sid
	var span: Array = BAND_SPAN[stage]
	# The hair below the band's top keeps a knife-edge draw of exactly
	# span[1] from landing in the NEXT stage (reviewer note).
	g.age = Rng.randf_range(span[0], span[1] - 0.001)
	g.stage = stage
	g.sex = Rng.randi_range(0, 1)
	for key in Enums.TRAIT_KEYS:
		g.set_trait(key, s.mean_traits[key] + Rng.gauss(0.0, TRAIT_SAMPLE_SD))
	for axis in s.belief:
		g.set_feeling(Devotion.YOU, axis, s.belief[axis])
	var need_each: float = clampf(1.0 - s.mood, 0.0, 1.0)
	for key in Enums.NEED_KEYS:
		g.set_need(key, need_each)
	return g


static func _fold_mean(mean: float, pop_before: float, value: float) -> float:
	return (mean * pop_before + value) / (pop_before + 1.0)
