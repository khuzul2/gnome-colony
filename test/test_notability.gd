extends GutTest

## T8.6 — notability [algo §14/§17]: rises from deeds — surviving/causing
## a major phenomenon, mastering a craft (skill ≥ 0.9), reaching Elder,
## raising many children, prophet/leader status — and decays −0.001/day so
## the famous fade as new figures rise. §17 fixes only the decay; the
## award weights are interpretive, documented on the constants.


func _gnome() -> GnomeData:
	var g := GnomeData.new(0)
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	return g


func _colony_with(g: GnomeData) -> Colony:
	var c := Colony.new()
	c.add(g)
	return c


func test_a_deed_raises_notability():
	var g := _gnome()
	Notability.award(g, Notability.DEED)
	assert_almost_eq(g.notability, 0.3, 0.0001)


func test_notability_clamps_at_one():
	var g := _gnome()
	for i in 10:
		Notability.award(g, Notability.DEED)
	assert_eq(g.notability, 1.0)


func test_notability_decays_slowly():
	var g := _gnome()
	g.notability = 0.5
	var c := _colony_with(g)
	Notability.tick(c, 1.0)
	assert_almost_eq(g.notability, 0.499, 0.0001, "§17: −0.001/day")
	for day in 600:
		Notability.tick(c, 1.0)
	assert_almost_eq(g.notability, 0.0, 0.001, "the famous fade")


func test_mastery_awards_once_per_skill():
	var g := _gnome()
	g.set_skill("smithing", 0.95)
	Notability.on_mastery(g, "smithing")
	Notability.on_mastery(g, "smithing")
	assert_almost_eq(g.notability, Notability.MASTERY, 0.0001, "no double credit for one craft")


func test_mastery_requires_mastery():
	var g := _gnome()
	g.set_skill("smithing", 0.7)
	Notability.on_mastery(g, "smithing")
	assert_eq(g.notability, 0.0, "0.9 is the §14 mastery line")


func test_promotion_relevance():
	var g := _gnome()
	Notability.award(g, Notability.PROPHET_LEADER)
	Notability.award(g, Notability.DEED)
	assert_gte(g.notability, 0.6, "prophets and heroes cross the §14 LOD-promotion line")


func test_leader_score_weighs_fame_ambition_and_skill():
	# §14: leader_score = 0.5·notability + 0.3·ambitious + 0.2·relevant_skill
	var g := _gnome()
	g.notability = 0.6
	g.set_trait("ambitious", 0.5)
	g.set_skill("oratory", 0.8)
	g.set_skill("smithing", 1.0)
	assert_almost_eq(
		Notability.leader_score(g),
		0.5 * 0.6 + 0.3 * 0.5 + 0.2 * 0.8,
		0.0001,
		"oratory outranks a better smithing score — §14 prefers the leadership skill"
	)


func test_leader_score_falls_back_to_best_skill():
	var g := _gnome()
	g.notability = 0.4
	g.set_trait("ambitious", 1.0)
	g.set_skill("foraging", 0.3)
	g.set_skill("smithing", 0.9)
	assert_almost_eq(Notability.leader_score(g), 0.5 * 0.4 + 0.3 * 1.0 + 0.2 * 0.9, 0.0001)


func test_practicing_across_the_line_awards_mastery():
	# The live wiring (reviewer catch): crossing 0.9 through ordinary
	# practice must credit fame without anyone calling on_mastery by hand.
	var g := _gnome()
	g.set_skill("smithing", 0.899)
	Skills.practice(g, "smithing", 1.0)
	assert_gte(g.skills["smithing"], 0.9, "premise: this practice tick crosses the line")
	assert_almost_eq(g.notability, Notability.MASTERY, 0.0001, "the craft-master becomes known")
	Skills.practice(g, "smithing", 1.0)
	assert_almost_eq(g.notability, Notability.MASTERY, 0.0001, "still once per craft")


func test_mastery_credit_round_trips():
	var g := _gnome()
	g.set_skill("smithing", 0.95)
	Notability.on_mastery(g, "smithing")
	var restored := Serializer.gnome_from_dict(Serializer.gnome_to_dict(g))
	Notability.on_mastery(restored, "smithing")
	assert_almost_eq(restored.notability, Notability.MASTERY, 0.0001, "credit survives save/load")
