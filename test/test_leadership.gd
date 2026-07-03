extends GutTest

## T11.6 — emergent leadership [algo §14]: each settlement's leader is
## its highest leader_score = 0.5·notability + 0.3·ambitious +
## 0.2·relevant_skill (T8.6 owns the formula); leadership_quality = that
## score, feeding coordination/institutions/migration/war. No leader is
## ever appointed by the player. Becoming a leader is a §14 notability
## deed (awarded once, on the CHANGE of leader). Interpretive, documented:
## only adults/elders lead; a settlement with no living locals runs on a
## 0.5 baseline quality until the civ tier models aggregate leadership.


func _folk(c: Colony, notability: float, ambitious: float, oratory: float = 0.0) -> GnomeData:
	var g := c.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	g.notability = notability
	g.set_trait("ambitious", ambitious)
	if oratory > 0.0:
		g.set_skill("oratory", oratory)
	return g


func test_the_top_scorer_leads():
	var c := Colony.new()
	var quiet := _folk(c, 0.2, 0.3)
	var voice := _folk(c, 0.6, 0.8, 0.9)
	var famous := _folk(c, 0.7, 0.2)
	var leader := Leadership.elect(c, 0)
	assert_eq(leader, voice, "0.5·0.6+0.3·0.8+0.2·0.9 = 0.72 beats fame alone")
	assert_gt(Notability.leader_score(voice), Notability.leader_score(famous))
	assert_gt(Notability.leader_score(famous), Notability.leader_score(quiet))


func test_children_do_not_rule():
	var c := Colony.new()
	var prodigy := c.spawn()
	prodigy.age = 8.0
	prodigy.stage = Enums.LifeStage.CHILD
	prodigy.notability = 1.0
	prodigy.set_trait("ambitious", 1.0)
	var elder := _folk(c, 0.1, 0.1)
	assert_eq(Leadership.elect(c, 0), elder, "adults/elders only (interpretive, documented)")


func test_becoming_leader_is_a_deed_awarded_once():
	var c := Colony.new()
	var chief := _folk(c, 0.3, 0.9)
	Leadership.elect(c, 0)
	var after_first: float = chief.notability
	assert_almost_eq(
		after_first, 0.3 + Notability.PROPHET_LEADER, 0.0001, "§14: becoming a leader raises fame"
	)
	Leadership.elect(c, 0)
	assert_almost_eq(chief.notability, after_first, 0.0001, "re-election is not a new deed")


func test_a_usurper_earns_the_deed_on_the_change():
	var c := Colony.new()
	var old_guard := _folk(c, 0.3, 0.9)
	Leadership.elect(c, 0)
	var usurper := _folk(c, 0.9, 1.0, 1.0)
	var leader := Leadership.elect(c, 0)
	assert_eq(leader, usurper, "the crown follows the score")
	assert_gte(usurper.notability, 0.9, "the change is the deed")
	assert_eq(c.leaders[0], usurper.id, "the settlement remembers its leader")
	assert_true(old_guard.is_alive(), "no purge — just eclipse")


func test_quality_is_the_leaders_score():
	var c := Colony.new()
	var chief := _folk(c, 0.4, 0.5, 0.8)
	Leadership.elect(c, 0)
	assert_almost_eq(
		Leadership.quality(c, 0),
		Notability.leader_score(chief),
		0.0001,
		"leadership_quality = leader_score [§14]"
	)


func test_empty_settlements_run_on_the_baseline():
	var c := Colony.new()
	assert_eq(Leadership.elect(c, 5), null)
	assert_almost_eq(Leadership.quality(c, 5), 0.5, 0.0001, "aggregate baseline (interpretive)")


func test_quality_feeds_war_strength():
	var strong := TechEffects.war_strength(100.0, 0.5, 0.9)
	var weak := TechEffects.war_strength(100.0, 0.5, 0.2)
	assert_gt(strong, weak, "§14: leadership_quality feeds war")
	assert_almost_eq(strong, 100.0 * 1.5 * 1.4, 0.0001)


func test_leaders_round_trip():
	var c := Colony.new()
	var chief := _folk(c, 0.5, 0.9)
	Leadership.elect(c, 0)
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(c))
	assert_eq(restored.leaders[0], chief.id)
