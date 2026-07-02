class_name GnomeData
extends RefCounted
## Full per-gnome state & ranges [algo §1]. Plain data + clamp helpers only —
## behavior lives in sim/systems/. All scalars are [0,1] unless noted.

## Ring-buffer capacity for witnessed events. The spec says only "small"
## [algo §1 memory]; 16 is a structural implementation constant, not a
## gameplay number (noted in PROGRESS.md).
const MEMORY_CAP := 16

var id: int
var age := 0.0
var stage: int = Enums.LifeStage.INFANT
var sex := 0
var needs := {}
var traits := {}
var skills := {}
var knowledge: Array = []
var feelings := {}
var relationships := {}
var memory: Array = []
var notability := 0.0
## Crafts already credited with mastery notability [algo §14] (T8.6) — the
## guard that makes each craft worth fame at most once per lifetime.
var mastered_skills: Array = []
var partner_id := -1
var home_settlement := 0
## Abstract current place (site id, "" = unplaced) — prototype-spec
## location_id, string-keyed to match WorldState sites (T7.3).
var location := ""
## Extra death probability per day from sustained hardship [algo §3–§4].
## Written by the needs system (T3.5), consumed by Mortality (T2.3).
var hardship_rate := 0.0
## Consecutive days each hardship need has sat at ≥ 0.9 [algo §3] (T3.5).
var hardship_days := {"hunger": 0.0, "safety": 0.0}
## Active long-horizon project [algo §6] (T3.6): {} when none, else
## {kind, progress, duration} in days. Managed by Projects.
var project := {}
## Founder = 0; child = max(parent generations) + 1 (T5.3).
var generation := 0
## Trait names pinned by an outlier birth [algo §2/§8] (T5.7): exempt from
## plasticity, and (for mutants) inherited unclamped.
var constitutional_traits: Array = []
## "" for ordinary gnomes; else genius/touched/mutant/longlived (T5.7).
var outlier_type := ""
## 1.0 for the touched — prime prophet seed material [algo §8/§12] (T9.1).
var prophet_affinity := 0.0
## Per-phenomenon-type habituation counters [algo §9] (T6.1): repeats of
## the same act land weaker; recovers −0.02/day.
var habituation := {}


func _init(gnome_id: int = 0) -> void:
	id = gnome_id
	for key in Enums.NEED_KEYS:
		needs[key] = 0.0
	for key in Enums.TRAIT_KEYS:
		traits[key] = 0.5


func is_alive() -> bool:
	return stage != Enums.LifeStage.DEAD


func set_need(key: String, value: float) -> void:
	needs[key] = clampf(value, 0.0, 1.0)


func adjust_need(key: String, delta: float) -> void:
	set_need(key, needs.get(key, 0.0) + delta)


func set_trait(key: String, value: float) -> void:
	traits[key] = clampf(value, 0.0, 1.0)


func set_skill(key: String, value: float) -> void:
	skills[key] = clampf(value, 0.0, 1.0)


func set_feeling(subject: String, axis: String, value: float) -> void:
	if not feelings.has(subject):
		feelings[subject] = {}
	feelings[subject][axis] = clampf(value, 0.0, 1.0)


func adjust_feeling(subject: String, axis: String, delta: float) -> void:
	var current: float = feelings.get(subject, {}).get(axis, 0.0)
	set_feeling(subject, axis, current + delta)


func get_feeling(subject: String, axis: String) -> float:
	return feelings.get(subject, {}).get(axis, 0.0)


## `knowledge` is a SET of ids [algo §1] — always add through here so
## duplicates can never double-count teaching weight [algo §7].
func add_knowledge(knowledge_id: String) -> void:
	if not knowledge_id in knowledge:
		knowledge.append(knowledge_id)


func set_relationship(other_id: int, type: String, weight: float) -> void:
	relationships[other_id] = {"type": type, "weight": clampf(weight, -1.0, 1.0)}


func remember(event: Dictionary) -> void:
	memory.append(event)
	while memory.size() > MEMORY_CAP:
		memory.pop_front()
