class_name WorldState
extends RefCounted
## Minimal world container for the influence pipeline [plan T7.2, algo §15,
## prototype spec "World"]: abstract sites (resource nodes), hidden
## resources phenomena can reveal, and named paths that can be blocked.
## The full region-graph arrives with world-gen (Phase 11/13); this is the
## honest subset Phase 7 needs. Belief tags about places live on Colony.

var sites := {}
var hidden_resources := {}
## path name → passable (false = buried/blocked)
var paths := {}
## place → hazard affordance tags [algo §15] (slope, drought, farmland,
## built_up, crowded, wilds…) — phenomena need terrain to act on (T7.8).
var affordances := {}
## place → ward reduction [0,1] [algo §13] (T10.4): resistance-stage
## settlements blunt incoming phenomena on warded tiles.
var wards := {}


## Surface every hidden resource at `site_id` as a real site named
## "<site>_<type>" (numbered on collision so same-type finds never
## silently clobber each other). Returns the new site ids.
func reveal_hidden(site_id: String) -> Array:
	var revealed := []
	for node in hidden_resources.get(site_id, []):
		var new_id := "%s_%s" % [site_id, node.type]
		var n := 2
		while sites.has(new_id):
			new_id = "%s_%s_%d" % [site_id, node.type, n]
			n += 1
		sites[new_id] = node
		revealed.append(new_id)
	hidden_resources.erase(site_id)
	return revealed
