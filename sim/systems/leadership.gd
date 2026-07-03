class_name Leadership
extends RefCounted
## Emergent leadership [plan T11.6, algo §14]: each settlement's leader
## is its highest leader_score gnome (formula lives in Notability, T8.6:
## 0.5·notability + 0.3·ambitious + 0.2·relevant_skill), and
## leadership_quality = that score — feeding coordination, institutions,
## migration cohesion, and war (T11.4). No leader is ever appointed by
## the player. Becoming a leader is a §14 notability deed, awarded ONCE,
## when the leadership actually changes hands. INTERPRETIVE (PROGRESS.md):
## only adults/elders lead; a settlement with no living locals (folded)
## runs on a 0.5 baseline quality until the civ tier models aggregate
## leadership; ties break by id so replays agree.

const AGGREGATE_BASELINE_QUALITY := 0.5


## Recompute the settlement's leader; records it in colony.leaders and
## awards the §14 leader deed on a CHANGE. Returns the leader (null if
## no eligible local lives there).
static func elect(colony: Colony, sid: int) -> GnomeData:
	var best: GnomeData = null
	var best_score := -1.0
	for g in colony.living():
		if g.home_settlement != sid:
			continue
		if not g.stage in [Enums.LifeStage.ADULT, Enums.LifeStage.ELDER]:
			continue
		var score := Notability.leader_score(g)
		if score > best_score or (score == best_score and best != null and g.id < best.id):
			best_score = score
			best = g
	if best == null:
		colony.leaders.erase(sid)
		return null
	if colony.leaders.get(sid, -1) != best.id:
		colony.leaders[sid] = best.id
		Notability.award(best, Notability.PROPHET_LEADER)
	return best


## leadership_quality ∈ [0,1] [§14] — the current leader's score, or the
## aggregate baseline when nobody walks the settlement as an individual.
static func quality(colony: Colony, sid: int) -> float:
	var leader_id: int = colony.leaders.get(sid, -1)
	var leader: GnomeData = colony.gnomes.get(leader_id)
	if leader == null or not leader.is_alive():
		return AGGREGATE_BASELINE_QUALITY
	return clampf(Notability.leader_score(leader), 0.0, 1.0)
