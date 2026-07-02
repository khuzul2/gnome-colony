extends GutTest

## T2.4 — birth scaffold: placeholder spawn (full logic in Phase 5).


func test_spawn_infant_emits_born_and_is_in_range():
	Rng.seed_with(2400)
	var colony := Colony.new()
	watch_signals(EventBus)
	var infant := Birth.spawn_infant(colony)
	assert_signal_emitted(EventBus, "born")
	var params: Array = get_signal_parameters(EventBus, "born")
	assert_eq(params[0]["id"], infant.id)
	assert_eq(infant.stage, Enums.LifeStage.INFANT)
	assert_eq(infant.age, 0.0)
	assert_true(infant.sex in [0, 1])
	assert_true(colony.gnomes.has(infant.id))
	for key in Enums.TRAIT_KEYS:
		assert_between(infant.traits[key], 0.0, 1.0)
	for key in Enums.NEED_KEYS:
		assert_between(infant.needs[key], 0.0, 1.0)


func test_sex_is_rolled_through_rng():
	Rng.seed_with(2401)
	var colony := Colony.new()
	var seen := {}
	for i in 40:
		seen[Birth.spawn_infant(colony).sex] = true
	assert_eq(seen.size(), 2, "both sexes occur across 40 seeded births")
