extends GutTest

## T1.1 — enum values must be STABLE: serialization (T1.5) and tests depend
## on these exact ints/orders. Changing one is a breaking change.


func test_life_stage_values_stable():
	assert_eq(Enums.LifeStage.INFANT, 0)
	assert_eq(Enums.LifeStage.CHILD, 1)
	assert_eq(Enums.LifeStage.ADOLESCENT, 2)
	assert_eq(Enums.LifeStage.ADULT, 3)
	assert_eq(Enums.LifeStage.ELDER, 4)
	assert_eq(Enums.LifeStage.DEAD, 5)


func test_trait_keys_match_algo_section_2():
	assert_eq(
		Enums.TRAIT_KEYS,
		[
			"industrious",
			"curious",
			"timid",
			"social",
			"devout",
			"aggressive",
			"nurturing",
			"ambitious",
		]
	)


func test_need_keys_match_algo_section_3():
	assert_eq(Enums.NEED_KEYS, ["hunger", "rest", "social", "safety", "purpose"])


func test_belief_axes_match_algo_section_9():
	assert_eq(Enums.BELIEF_AXES, ["fear", "awe", "faith", "reverence"])


func test_knowledge_categories_match_algo_section_1():
	assert_eq(Enums.KNOWLEDGE_CATEGORIES, ["craft", "tech", "magic"])
