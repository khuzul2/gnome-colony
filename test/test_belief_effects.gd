extends GutTest

## T6.4 — behavioral effects [algo §6/§9]: a cursed place-tag drops the
## utility of acting there (avoidance); a blessed tag raises it. §6 bounds
## belief_mod to ~[0.5, 1.8]; the linear map (cursed: 1 − 0.5·s, blessed:
## 1 + 0.8·s) hits exactly that band at full strength — interpretive.


func _colony_with_tag(subject: String, tag: String, strength: float) -> Colony:
	var c := Colony.new()
	if not c.place_tags.has(subject):
		c.place_tags[subject] = {}
	c.place_tags[subject][tag] = strength
	return c


func test_cursed_place_penalizes():
	var c := _colony_with_tag("eastern_ridge", "cursed", 1.0)
	assert_almost_eq(Belief.place_mod(c, "eastern_ridge"), 0.5, 0.0001, "floor of the §6 band")
	var half := _colony_with_tag("ridge", "cursed", 0.5)
	assert_almost_eq(Belief.place_mod(half, "ridge"), 0.75, 0.0001)


func test_blessed_place_rewards():
	var c := _colony_with_tag("spring", "blessed", 1.0)
	assert_almost_eq(Belief.place_mod(c, "spring"), 1.8, 0.0001, "ceiling of the §6 band")


func test_untagged_place_is_neutral():
	var c := Colony.new()
	assert_eq(Belief.place_mod(c, "meadow"), 1.0)


func test_mixed_tags_multiply():
	var c := _colony_with_tag("shrine", "cursed", 0.5)
	c.place_tags["shrine"]["blessed"] = 0.5
	assert_almost_eq(Belief.place_mod(c, "shrine"), 0.75 * 1.4, 0.0001, "contested ground")


func test_taboo_object_and_tag_compound():
	var c := _colony_with_tag("ridge", "cursed", 1.0)
	c.beliefs.append(BeliefObject.make("taboo", "ridge", "fear", 1.0, [0]))
	assert_almost_eq(Belief.place_mod(c, "ridge"), 0.25, 0.0001, "object × tag multiply")


func test_cursed_tile_lowers_action_score_via_utility():
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.ADULT
	g.set_need("purpose", 0.8)
	var c := _colony_with_tag("eastern_ridge", "cursed", 1.0)
	var neutral := Utility.base_score(g, "work")
	var mod := Belief.place_mod(c, "eastern_ridge")
	var at_ridge := Utility.base_score(g, "work", {"belief_mods": {"work": mod}})
	assert_almost_eq(at_ridge, neutral * 0.5, 0.0001, "the iron can wait — the ridge is cursed")
	var blessed := _colony_with_tag("spring", "blessed", 1.0)
	var at_spring := Utility.base_score(
		g, "work", {"belief_mods": {"work": Belief.place_mod(blessed, "spring")}}
	)
	assert_gt(at_spring, neutral, "blessed ground invites work")
