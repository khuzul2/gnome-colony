class_name Civilization
extends RefCounted
## Civilization tier [plan T11.4, algo §14/§17]: the flows BETWEEN
## settlements. §17 fixes the schism distance (0.5, same metric as T6.5:
## mean |Δ| over the belief axes), the war trigger (≥ 1.5) and the war
## strength formula (via TechEffects). The closed forms §14 names without
## numbers are INTERPRETIVE, documented here + PROGRESS.md:
##  · basin score = richness + 2·(1 − crowding) + kin + (1 − faith gap):
##    equal weights except room, which §14 lists twice in spirit
##    (resources AND low crowding are the material draw).
##  · migrate: heads leave the adult bucket and arrive as adults; means
##    blend by head-count; migrants carry their settlement's knowledge
##    (§14: "migration move[s] ids between settlements").
##  · trade lifts both moods +0.05 and blends belief scalars 10% toward
##    each other; knowledge spread reuses SettlementSim.trade.
##  · split halves every bucket; the departing faction takes the
##    LOW-faith half of the creed (mean ± 0.15 separation, clamped) —
##    schisms part along belief lines.
##  · war casualties: loser 15%·min(2, strength ratio), winner 5%;
##    both sides gain fear (+0.2 loser / +0.1 winner) — §14's "major
##    mortality & belief event". Outcome is deterministic in strengths.
## DEFERRED consumers (reviewer note — promised "T11.4" by earlier tasks,
## honored at the world orchestrator instead, T12/T16 wiring): the
## orchestrator rolls Devotion.schism_pressure_per_season and
## Devotion.fracture_due each season alongside schism_due, and feeds
## Prophet.check_schism's factions into split() when individual prophets
## drive the break; exit tests compose these by hand meanwhile.
## check_world_end's caller must pass the COMPLETE settlement list — a
## missing basin falsifies the verdict (the orchestrator is the sole
## intended caller).

const SCHISM_DISTANCE := 0.5  # §17 (same line as T6.5's subcultures)
const WAR_THRESHOLD := 1.5  # §17

const ROOM_WEIGHT := 2.0
## Main-settlement pull [user feature 2026-07-03, INTERPRETIVE]: the
## colony's seat draws migrants as strongly as a full kin tie — the bias
## that keeps the main settlement the larger one. Inert while
## colony.main_settlement is -1 (no candidate ever matches).
const MAIN_PULL := 1.0
const TRADE_MOOD_LIFT := 0.05
const TRADE_BELIEF_BLEND := 0.1
const SPLIT_FAITH_SEPARATION := 0.15
const LOSER_CASUALTY := 0.15
const WINNER_CASUALTY := 0.05
const CASUALTY_RATIO_CAP := 2.0
const WAR_FEAR_LOSER := 0.2
const WAR_FEAR_WINNER := 0.1

## §14 says "every settlement's population reaches 0" — but aggregate
## buckets decay multiplicatively and never hit exact zero, so a
## hundredth of a gnome counts as nobody (structural guard, not a
## gameplay number).
const ALIVE_EPSILON := 0.01


## §14 migration: the best-scoring REACHABLE basin — the caller supplies
## the reachable candidates (sail gating via TechEffects.can_cross_water)
## and optional kin ties {sid: [0,1]}. Deterministic: ties keep the first
## candidate in list order.
static func choose_basin(
	colony: Colony, from_s: Settlement, candidates: Array, kin: Dictionary = {}
) -> Settlement:
	var best: Settlement = null
	var best_score := -INF
	for s in candidates:
		var score: float = (
			s.richness_sum
			+ ROOM_WEIGHT * (1.0 - s.crowding(colony))
			+ kin.get(s.sid, 0.0)
			+ (1.0 - absf(from_s.belief["faith"] - s.belief["faith"]))
			+ (MAIN_PULL if s.sid == colony.main_settlement else 0.0)
		)
		if score > best_score:
			best_score = score
			best = s
	return best


## Move `count` adults between basins: means blend by head-count and the
## migrants carry their settlement's knowledge with them [§14].
static func migrate(colony: Colony, from_s: Settlement, to_s: Settlement, count: float) -> void:
	var moving := minf(count, from_s.adults())
	if moving <= 0.0:
		return
	from_s.by_stage[Enums.LifeStage.ADULT] -= moving
	var pop_before := to_s.pop()
	to_s.by_stage[Enums.LifeStage.ADULT] += moving
	var weight := moving / (pop_before + moving) if pop_before + moving > 0.0 else 1.0
	for key in Enums.TRAIT_KEYS:
		to_s.mean_traits[key] = lerpf(to_s.mean_traits[key], from_s.mean_traits[key], weight)
	for axis in to_s.belief:
		to_s.belief[axis] = lerpf(to_s.belief[axis], from_s.belief[axis], weight)
	to_s.mood = lerpf(to_s.mood, from_s.mood, weight)
	SettlementSim.trade(colony, from_s.sid, to_s.sid)


## §14 trade: complementary partners — both moods rise, knowledge spreads
## (SettlementSim.trade), and belief drifts along the route.
static func trade_route(colony: Colony, a: Settlement, b: Settlement) -> Array:
	a.mood = clampf(a.mood + TRADE_MOOD_LIFT, 0.0, 1.0)
	b.mood = clampf(b.mood + TRADE_MOOD_LIFT, 0.0, 1.0)
	for axis in a.belief:
		var mid: float = 0.5 * (a.belief[axis] + b.belief[axis])
		a.belief[axis] = lerpf(a.belief[axis], mid, TRADE_BELIEF_BLEND)
		b.belief[axis] = lerpf(b.belief[axis], mid, TRADE_BELIEF_BLEND)
	return SettlementSim.trade(colony, a.sid, b.sid)


## §14 schism trigger: belief-vector distance ≥ 0.5 (mean |Δ| over the
## aggregate axes, T6.5's metric) AND a rival theology has crystallized
## (two or more prophet creeds on the colony). The split is separate.
static func schism_due(colony: Colony, a: Settlement, b: Settlement) -> bool:
	var creeds := 0
	for belief_obj in colony.beliefs:
		if belief_obj["kind"] == "theology" and belief_obj.has("prophet_id"):
			creeds += 1
	if creeds < 2:
		return false
	var total := 0.0
	for axis in a.belief:
		total += absf(a.belief[axis] - b.belief[axis])
	return total / a.belief.size() >= SCHISM_DISTANCE


## Split a settlement into factions along the creed line: every bucket
## halves; the departing faction takes the low-faith half [interpretive].
static func split(colony: Colony, s: Settlement, new_sid: int) -> Settlement:
	var faction := Settlement.new(new_sid, s.base_k, s.richness_sum)
	for stage in s.by_stage:
		var half: float = s.by_stage[stage] * 0.5
		s.by_stage[stage] -= half
		faction.by_stage[stage] = half
	for key in Enums.TRAIT_KEYS:
		faction.mean_traits[key] = s.mean_traits[key]
	faction.mood = s.mood
	for axis in s.belief:
		faction.belief[axis] = s.belief[axis]
	s.belief["faith"] = clampf(s.belief["faith"] + SPLIT_FAITH_SEPARATION, 0.0, 1.0)
	faction.belief["faith"] = clampf(faction.belief["faith"] - SPLIT_FAITH_SEPARATION, 0.0, 1.0)
	SettlementSim.trade(colony, s.sid, new_sid)
	return faction


## §17: war when rivalry + resource_pressure + religious_distance ≥ 1.5.
static func war_due(rivalry: float, resource_pressure: float, religious_distance: float) -> bool:
	return rivalry + resource_pressure + religious_distance >= WAR_THRESHOLD


## §14 war: outcome deterministic in relative war_strength =
## pop·(1+metallurgy)·(0.5+leadership); a major mortality & belief event.
static func war(colony: Colony, a: Settlement, b: Settlement) -> Dictionary:
	var strength_a := _strength(colony, a)
	var strength_b := _strength(colony, b)
	var winner := a if strength_a >= strength_b else b
	var loser := b if winner == a else a
	var ratio: float = minf(
		CASUALTY_RATIO_CAP, maxf(strength_a, strength_b) / maxf(0.001, minf(strength_a, strength_b))
	)
	var loser_losses := loser.pop() * LOSER_CASUALTY * ratio
	var winner_losses := winner.pop() * WINNER_CASUALTY
	_bleed(loser, loser_losses)
	_bleed(winner, winner_losses)
	loser.belief["fear"] = clampf(loser.belief["fear"] + WAR_FEAR_LOSER, 0.0, 1.0)
	winner.belief["fear"] = clampf(winner.belief["fear"] + WAR_FEAR_WINNER, 0.0, 1.0)
	return {
		"winner": winner,
		"loser": loser,
		"loser_losses": loser_losses,
		"winner_losses": winner_losses,
	}


## Main-settlement anointment & succession [user feature 2026-07-03]:
## sticky while the current seat lives (≥ ALIVE_EPSILON) — growth bias,
## not a crown that hops to whichever village is largest this season.
## When it dies off (or none was ever chosen) the LARGEST living
## settlement succeeds (tie → lowest sid, deterministic); with none left
## the seat empties to -1. Emits main_settlement_changed on every real
## change. The orchestrator/shell calls this each civilization season
## alongside the other §14 flows (same deferred-consumer pattern as
## schism_due). Returns the (possibly unchanged) main sid.
static func update_main_settlement(colony: Colony, settlements: Array) -> int:
	var largest: Settlement = null
	for s in settlements:
		if s.pop() < ALIVE_EPSILON:
			continue
		if s.sid == colony.main_settlement:
			return colony.main_settlement
		if (
			largest == null
			or s.pop() > largest.pop()
			or (s.pop() == largest.pop() and s.sid < largest.sid)
		):
			largest = s
	var previous := colony.main_settlement
	colony.main_settlement = largest.sid if largest != null else -1
	if colony.main_settlement != previous:
		EventBus.main_settlement_changed.emit({"sid": colony.main_settlement, "previous": previous})
	return colony.main_settlement


## §14 world's end: every settlement below one whole gnome AND no living
## individuals → world_ended fires exactly once; the run closes into the
## Chronicle (design §1.9). The latch lives ON the colony (no hidden
## static state — it must survive save/load and reset with a new run).
static func check_world_end(colony: Colony, settlements: Array) -> bool:
	for s in settlements:
		if s.pop() >= ALIVE_EPSILON:
			return false
	if colony.population() > 0:
		return false
	if not colony.world_over:
		colony.world_over = true
		EventBus.world_ended.emit({})
	return true


static func _strength(colony: Colony, s: Settlement) -> float:
	return TechEffects.war_strength(
		s.pop(), TechEffects.level(colony, s.sid, "metallurgy"), Leadership.quality(colony, s.sid)
	)


static func _bleed(s: Settlement, losses: float) -> void:
	var pop := s.pop()
	if pop <= 0.0:
		return
	var fraction := minf(1.0, losses / pop)
	for stage in s.by_stage:
		s.by_stage[stage] *= 1.0 - fraction
