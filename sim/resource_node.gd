class_name ResourceNode
extends RefCounted
## Resource node [algo §15]: {type, capacity C, current c, regrowth r/day,
## richness}. Harvest draws `c`; `c += r·dt` up to `C`. Values come from
## world-gen (or tests) — the sim defines no defaults. Pulled forward from
## Phase 7/11 so the Phase-3 exit test has a food source (noted in
## PROGRESS.md).

var type: String
var capacity: float
var current: float
var regrowth: float
var richness: float


func _init(
	node_type: String,
	node_capacity: float,
	node_current: float,
	node_regrowth: float,
	node_richness: float,
) -> void:
	type = node_type
	capacity = node_capacity
	current = clampf(node_current, 0.0, node_capacity)
	regrowth = node_regrowth
	richness = node_richness


## Draw up to `amount`; returns what was actually taken.
func harvest(amount: float) -> float:
	var taken := minf(amount, current)
	current -= taken
	return taken


func regrow(dt_days: float) -> void:
	current = minf(current + regrowth * dt_days, capacity)
