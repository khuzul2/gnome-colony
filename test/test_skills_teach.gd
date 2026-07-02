extends GutTest

## T4.2 — teaching transfer [algo §7/§17]:
##   learner.prof += 0.03·(teacher.prof − learner.prof)·teacher_quality·dt
## Learner gains the knowledge id at prof ≥ 0.2 and can teach onward.
## teacher_quality has no spec-defined formula — explicit param, default 1.0.


func _master() -> GnomeData:
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.ELDER
	g.set_skill("smithing", 0.9)
	g.add_knowledge("smithing")
	return g


func _novice(id: int = 1) -> GnomeData:
	var g := GnomeData.new(id)
	g.stage = Enums.LifeStage.ADOLESCENT
	return g


func test_transfer_rate_matches_formula():
	var teacher := _master()
	var learner := _novice()
	Skills.teach(teacher, learner, "smithing", 1.0)
	assert_almost_eq(learner.skills["smithing"], 0.03 * 0.9, 0.000001)


func test_teacher_quality_scales_transfer():
	var teacher := _master()
	var learner := _novice()
	Skills.teach(teacher, learner, "smithing", 1.0, 0.5)
	assert_almost_eq(learner.skills["smithing"], 0.03 * 0.9 * 0.5, 0.000001)


func test_learner_converges_toward_teacher():
	var teacher := _master()
	var learner := _novice()
	for day in 400:
		Skills.teach(teacher, learner, "smithing", 1.0)
	assert_between(learner.skills["smithing"], 0.85, 0.9, "converges toward but never past teacher")


func test_learner_becomes_teachable_and_teaches_onward():
	var teacher := _master()
	var learner := _novice()
	while learner.skills.get("smithing", 0.0) < 0.2:
		Skills.teach(teacher, learner, "smithing", 1.0)
	assert_true("smithing" in learner.knowledge, "id gained at 0.2")
	var third := _novice(2)
	Skills.teach(learner, third, "smithing", 1.0)
	assert_gt(third.skills.get("smithing", 0.0), 0.0, "the chain continues")
	# §17 sanity: taught by a 0.9 master (0.03·0.9 = 0.027/day) beats
	# practicing alone from zero (0.01/day) — "teaching ~3× faster".
	assert_gt(Skills.TEACH_RATE * 0.9, 2.0 * Skills.PRACTICE_RATE)


func test_cannot_teach_without_the_id():
	var fraud := GnomeData.new(0)
	fraud.stage = Enums.LifeStage.ADULT
	fraud.set_skill("smithing", 0.9)
	fraud.knowledge.erase("smithing")
	var learner := _novice()
	Skills.teach(fraud, learner, "smithing", 1.0)
	assert_eq(learner.skills.get("smithing", 0.0), 0.0)


func test_no_reverse_transfer():
	var teacher := _master()
	var learner := _novice()
	learner.set_skill("smithing", 0.95)
	Skills.teach(teacher, learner, "smithing", 1.0)
	assert_eq(
		learner.skills["smithing"], 0.95, "a better learner gains nothing from a lesser teacher"
	)
