class_name Lod
extends RefCounted
## LOD manager [plan T11.1, algo §14/§17]: who gets individual fidelity.
## Eligible for LOD-0/1: under the Eye of God OR notability ≥ 0.6. The
## quicken budget (WorldConfig gameplay constant, ~300) caps concurrent
## LOD-0; eligible overflow keeps individual fidelity at LOD-1. Everyone
## else is statistical (LOD-2) until the settlement's individual budget
## (~500, §17) folds the least notable into settlement stats (LOD-3).
## Attention is a SCRIPTED INPUT of place ids — dwell/hysteresis happen
## upstream in the presentation layer (design §2.4); the sim only sees
## the resolved gaze (CLAUDE.md: attention is a declared sim input).
## INTERPRETIVE (documented in PROGRESS.md): priority within budgets is
## (under-Eye, notability, id) — deterministic so replays agree; the
## fold-back of a demoted gnome's rich state is T11.3.

const QUICKENED := 0
const INDIVIDUAL := 1
const STATISTICAL := 2
const FOLDED := 3

const NOTABILITY_LINE := 0.6  # §14/§17: "Eye … OR notability ≥ 0.6"
const DEFAULT_INDIVIDUAL_BUDGET := 500  # §17: "settlement budget ~500"


## Recompute every living gnome's LOD from the current gaze + notability
## + budgets. Deterministic: same colony state and inputs → same fates.
static func assign(
	colony: Colony,
	attended_places: Array,
	quicken_budget: int,
	individual_budget: int = DEFAULT_INDIVIDUAL_BUDGET,
) -> void:
	var eligible := []
	var rest := []
	var watched := {}
	for g in colony.living():
		var under_eye: bool = g.location in attended_places
		if under_eye:
			watched[g.id] = true
		if under_eye or g.notability >= NOTABILITY_LINE:
			eligible.append(g)
		else:
			rest.append(g)
	eligible.sort_custom(_priority.bind(watched))
	for i in eligible.size():
		eligible[i].lod = QUICKENED if i < quicken_budget else INDIVIDUAL
	for g in rest:
		g.lod = STATISTICAL
	_fold_over_budget(colony, individual_budget)


## §14: beyond a settlement's individual budget the crowd folds into
## settlement-tier statistics — least notable first; the eligible
## (tracked lineage, prophets, the watched) never fold.
static func _fold_over_budget(colony: Colony, individual_budget: int) -> void:
	var by_settlement := {}
	for g in colony.living():
		if not by_settlement.has(g.home_settlement):
			by_settlement[g.home_settlement] = []
		by_settlement[g.home_settlement].append(g)
	for sid in by_settlement:
		var locals: Array = by_settlement[sid]
		if locals.size() <= individual_budget:
			continue
		locals.sort_custom(_fold_order)
		for i in range(individual_budget, locals.size()):
			locals[i].lod = FOLDED


## Budget priority: the watched first (the Eye changes fate, design
## §2.4), then fame, then id (stable).
static func _priority(a: GnomeData, b: GnomeData, watched: Dictionary) -> bool:
	var a_watched: bool = watched.has(a.id)
	var b_watched: bool = watched.has(b.id)
	if a_watched != b_watched:
		return a_watched
	if a.notability != b.notability:
		return a.notability > b.notability
	return a.id < b.id


## Fold order = keep priority: LOD level asc (eligible 0/1 kept first),
## then fame desc, then id.
static func _fold_order(a: GnomeData, b: GnomeData) -> bool:
	if a.lod != b.lod:
		return a.lod < b.lod
	if a.notability != b.notability:
		return a.notability > b.notability
	return a.id < b.id
