class_name TechGraph
extends RefCounted
## Knowledge graph [plan T10.1, algo §7/§13]: technologies are knowledge-
## objects with prereq ids — the SAME lifecycle as crafts (teachable,
## decayable, extinguishable, recordable; Phase 4 owns all of that). §7
## fixes the rule ("each id lists prereq ids; discovery can't fire until
## prereqs are held somewhere in the settlement") and one example edge
## (smithing ← fire + stoneworking); §13 fixes the six tech ids. The other
## edges are INTERPRETIVE starter data (noted in PROGRESS.md), following
## design §4's hints: fire and stone before smithing; drought pushes
## irrigation; settled surplus precedes script; recorded knowledge
## precedes medicine. Effects (§13's parameter deltas) land in T10.3.

const GRAPH := {
	"fire": {"category": "tech", "prereqs": []},
	"stoneworking": {"category": "tech", "prereqs": []},
	"agriculture": {"category": "tech", "prereqs": []},
	"irrigation": {"category": "tech", "prereqs": ["agriculture"]},
	"smithing": {"category": "craft", "prereqs": ["fire", "stoneworking"]},  # §7's example
	"metallurgy": {"category": "tech", "prereqs": ["smithing"]},
	"writing": {"category": "tech", "prereqs": ["agriculture"]},
	"construction": {"category": "tech", "prereqs": ["stoneworking"]},
	"medicine": {"category": "tech", "prereqs": ["writing"]},
	"sail": {"category": "tech", "prereqs": ["construction"]},
}


static func defs() -> Dictionary:
	return GRAPH


## §7: prereqs must be held somewhere in the settlement — `known` is that
## settlement's id set (any container supporting `in`).
static func prereqs_met(id: String, known: Array) -> bool:
	for prereq in GRAPH[id]["prereqs"]:
		if not prereq in known:
			return false
	return true


## The discoverable frontier [§13]: catalog ids not yet known whose
## prereqs are all held. Deterministic order (the GRAPH literal's).
static func candidates(known: Array) -> Array:
	var out := []
	for id in GRAPH:
		if id in known:
			continue
		if prereqs_met(id, known):
			out.append(id)
	return out
