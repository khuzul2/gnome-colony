extends GutTest

## T2.2 — stage bands [algo §4/§17]: Infant 0–3 · Child 3–14 ·
## Adolescent 14–20 · Adult 20–65 · Elder 65+ (years).


func test_stage_bands_exact_thresholds():
	assert_eq(Aging.stage_for_age(0.0), Enums.LifeStage.INFANT)
	assert_eq(Aging.stage_for_age(2.999), Enums.LifeStage.INFANT)
	assert_eq(Aging.stage_for_age(3.0), Enums.LifeStage.CHILD)
	assert_eq(Aging.stage_for_age(13.999), Enums.LifeStage.CHILD)
	assert_eq(Aging.stage_for_age(14.0), Enums.LifeStage.ADOLESCENT)
	assert_eq(Aging.stage_for_age(19.999), Enums.LifeStage.ADOLESCENT)
	assert_eq(Aging.stage_for_age(20.0), Enums.LifeStage.ADULT)
	assert_eq(Aging.stage_for_age(64.999), Enums.LifeStage.ADULT)
	assert_eq(Aging.stage_for_age(65.0), Enums.LifeStage.ELDER)
	assert_eq(Aging.stage_for_age(110.0), Enums.LifeStage.ELDER)


func test_tick_ages_by_days_converted_to_years():
	var colony := Colony.new()
	var g := colony.spawn()
	Aging.tick(colony, 96.0)
	assert_almost_eq(g.age, 1.0, 0.0001, "96 days = 1 year")


func test_stage_transition_emits_event_on_crossing():
	var colony := Colony.new()
	var g := colony.spawn()
	g.age = 2.99
	watch_signals(EventBus)
	Aging.tick(colony, 1.0)
	assert_eq(g.stage, Enums.LifeStage.CHILD)
	assert_signal_emitted(EventBus, "stage_changed")
	var params: Array = get_signal_parameters(EventBus, "stage_changed")
	assert_eq(params[0]["id"], g.id)
	assert_eq(params[0]["from"], Enums.LifeStage.INFANT)
	assert_eq(params[0]["to"], Enums.LifeStage.CHILD)


func test_no_event_without_crossing():
	var colony := Colony.new()
	var g := colony.spawn()
	g.age = 5.0
	g.stage = Enums.LifeStage.CHILD
	watch_signals(EventBus)
	Aging.tick(colony, 1.0)
	assert_signal_not_emitted(EventBus, "stage_changed")


func test_dead_gnomes_do_not_age():
	var colony := Colony.new()
	var g := colony.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.DEAD
	Aging.tick(colony, 96.0)
	assert_eq(g.age, 30.0)
	assert_eq(g.stage, Enums.LifeStage.DEAD)
