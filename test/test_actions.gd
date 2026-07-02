extends GutTest

## T3.2 — action catalog [algo §6]: relief vectors (negative = reduces the
## need, small positives = side costs) + stage gates.


func _gnome_at_stage(stage: int) -> GnomeData:
	var g := GnomeData.new(0)
	g.stage = stage
	return g


func test_catalog_relief_vectors_match_algo_section_6():
	assert_eq(Actions.CATALOG.keys().size(), 7)
	assert_eq(Actions.relief("eat"), {"hunger": -0.9})
	assert_eq(Actions.relief("rest"), {"rest": -0.9})
	assert_eq(Actions.relief("socialize"), {"social": -0.7, "purpose": -0.1})
	assert_eq(Actions.relief("work"), {"rest": 0.05, "purpose": -0.6})
	assert_eq(Actions.relief("learn"), {"social": -0.05, "purpose": -0.4})
	assert_eq(Actions.relief("teach"), {"social": -0.2, "purpose": -0.5})
	assert_eq(Actions.relief("create"), {"purpose": -0.6})


func test_stage_gates():
	var infant := _gnome_at_stage(Enums.LifeStage.INFANT)
	var child := _gnome_at_stage(Enums.LifeStage.CHILD)
	var adolescent := _gnome_at_stage(Enums.LifeStage.ADOLESCENT)
	var adult := _gnome_at_stage(Enums.LifeStage.ADULT)
	var elder := _gnome_at_stage(Enums.LifeStage.ELDER)
	var ctx := {"teacher_available": true, "food_available": true, "caregiver_available": true}
	adult.add_knowledge("foraging")
	elder.add_knowledge("foraging")

	assert_eq(Actions.available(infant, ctx), ["eat", "rest"])
	assert_eq(Actions.available(child, ctx), ["eat", "rest", "socialize", "learn"])
	assert_eq(Actions.available(adolescent, ctx), ["eat", "rest", "socialize", "work", "learn"])
	assert_eq(
		Actions.available(adult, ctx),
		["eat", "rest", "socialize", "work", "learn", "teach", "create"]
	)
	assert_eq(
		Actions.available(elder, ctx),
		["eat", "rest", "socialize", "work", "learn", "teach"],
		"create is Adult-only per the §6 catalog"
	)


func test_teach_requires_knowledge():
	var adult := _gnome_at_stage(Enums.LifeStage.ADULT)
	assert_false("teach" in Actions.available(adult, {"teacher_available": true}))
	adult.add_knowledge("foraging")
	assert_true("teach" in Actions.available(adult, {}))


func test_learn_requires_teacher_or_source():
	var child := _gnome_at_stage(Enums.LifeStage.CHILD)
	assert_false("learn" in Actions.available(child, {"teacher_available": false}))
	assert_true("learn" in Actions.available(child, {"teacher_available": true}))


func test_eat_requires_food_and_infants_need_a_caregiver():
	var adult := _gnome_at_stage(Enums.LifeStage.ADULT)
	assert_false("eat" in Actions.available(adult, {"food_available": false}))
	assert_true("eat" in Actions.available(adult, {"food_available": true}))
	var infant := _gnome_at_stage(Enums.LifeStage.INFANT)
	assert_false(
		"eat" in Actions.available(infant, {"food_available": true, "caregiver_available": false}),
		"Infants eat only via a caregiver [algo §3/§6]"
	)


func test_dead_gnomes_have_no_actions():
	var dead := _gnome_at_stage(Enums.LifeStage.DEAD)
	assert_eq(Actions.available(dead, {}), [])
