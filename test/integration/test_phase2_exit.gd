extends GutTest

## Phase-Exit 2: seeded 50-year run; lifespans fall within [algo §4] bounds
## (target N(90,12), hard cap ~115) and every death emits exactly one event.

const COHORT := 100
const YEARS := 50


func test_fifty_year_run_lifespans_in_bounds_one_event_per_death():
	Rng.seed_with(2900)
	var colony := Colony.new()
	for i in COHORT:
		var g := colony.spawn()
		g.age = 65.0
		g.stage = Enums.LifeStage.ELDER

	var death_events := []
	var listener := func(p: Dictionary) -> void: death_events.append(p)
	EventBus.gnome_died.connect(listener)
	for day in YEARS * TimeService.DAYS_PER_YEAR:
		Aging.tick(colony, 1.0)
		Mortality.tick(colony, 1.0)
	EventBus.gnome_died.disconnect(listener)

	assert_eq(colony.population(), 0, "the 115-year cap guarantees no survivors at 65+50")
	assert_eq(death_events.size(), COHORT, "exactly one death event per gnome")

	var ids := {}
	var total_age := 0.0
	for e in death_events:
		ids[e["id"]] = true
		total_age += e["age"]
		assert_between(e["age"], 65.0, 115.1, "lifespan within §4 bounds")
	assert_eq(ids.size(), COHORT, "no id died twice")

	var mean_age := total_age / COHORT
	assert_between(
		mean_age, 85.0, 100.0, "mean lifespan consistent with N(90,12) given survival to 65"
	)
