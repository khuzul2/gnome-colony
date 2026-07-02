extends GutTest

## Phase-Exit 1: build a Colony of 4, advance 100 ticks, assert
## time/calendar correct and state intact [plan Phase 1].


func test_colony_of_four_survives_100_ticks_with_calendar_intact():
	Rng.seed_with(1000)
	var colony := Colony.new()
	for i in 4:
		var g := colony.spawn()
		g.stage = Enums.LifeStage.ADULT
		g.age = 25.0
		g.set_trait("curious", Rng.randf())
	var snapshot := Serializer.colony_to_dict(colony)

	var t := TimeService.new()
	for i in 100:
		t.advance(1.0)

	# Calendar: day 100 = year 1 (96 days), season 0, day 4 of season.
	assert_eq(t.day(), 100)
	assert_eq(t.year(), 1)
	assert_eq(t.season(), 0)
	assert_eq(t.day_of_season(), 4)

	# State intact: no system ran, so the colony must be byte-identical.
	assert_eq(colony.population(), 4)
	assert_eq(Serializer.colony_to_dict(colony), snapshot, "ticking time alone never mutates state")
