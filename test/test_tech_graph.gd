extends GutTest

## T10.1 — knowledge graph & prereqs [algo §7/§13]: technologies are
## knowledge-objects (same lifecycle as crafts — teachable, losable,
## recordable, Phase 4) that list prereq ids; discovery can't fire until
## the prereqs are held somewhere in the settlement. §7's own example
## edge: smithing needs fire + stoneworking. The starter graph's other
## edges are interpretive data, documented in tech_graph.gd.


func test_the_spec_example_edge():
	# §7 verbatim: "smithing needs fire, stoneworking".
	assert_false(TechGraph.prereqs_met("smithing", []))
	assert_false(TechGraph.prereqs_met("smithing", ["fire"]), "half the prereqs is none of them")
	assert_true(TechGraph.prereqs_met("smithing", ["fire", "stoneworking"]))


func test_roots_are_always_open():
	var candidates := TechGraph.candidates([])
	assert_has(candidates, "fire")
	assert_has(candidates, "stoneworking")
	assert_has(candidates, "agriculture")
	assert_does_not_have(candidates, "smithing", "gated ids are not candidates")
	assert_does_not_have(candidates, "sail")


func test_discovery_opens_the_next_ring():
	var known := ["fire", "stoneworking"]
	var candidates := TechGraph.candidates(known)
	assert_has(candidates, "smithing", "prereqs held somewhere in the settlement [§7]")
	assert_does_not_have(candidates, "fire", "the known are no longer candidates")
	assert_does_not_have(candidates, "metallurgy", "smithing itself must come first")


func test_the_deep_chain():
	var known := ["fire", "stoneworking", "smithing"]
	assert_has(TechGraph.candidates(known), "metallurgy")
	assert_true(TechGraph.prereqs_met("construction", known))
	assert_false(TechGraph.prereqs_met("sail", known), "sail waits on construction")


func test_everything_known_leaves_nothing():
	assert_eq(TechGraph.candidates(TechGraph.defs().keys()), [])


func test_the_six_spec_techs_exist():
	# §13's effect table names these six; they must all be in the graph.
	var defs := TechGraph.defs()
	for id in ["agriculture", "writing", "metallurgy", "medicine", "construction", "sail"]:
		assert_true(defs.has(id), "%s is a §13 tech" % id)


func test_graph_is_well_formed():
	var defs := TechGraph.defs()
	for id in defs:
		assert_has(Enums.KNOWLEDGE_CATEGORIES, defs[id]["category"], "%s category" % id)
		for prereq in defs[id]["prereqs"]:
			assert_true(defs.has(prereq), "%s's prereq %s must exist" % [id, prereq])
	# Acyclic: repeatedly peeling ids whose prereqs are all peeled must
	# consume the whole graph (a cycle would never peel).
	var peeled := []
	var changed := true
	while changed:
		changed = false
		for id in defs:
			if id in peeled:
				continue
			if TechGraph.prereqs_met(id, peeled):
				peeled.append(id)
				changed = true
	assert_eq(peeled.size(), defs.size(), "no dependency cycles")
