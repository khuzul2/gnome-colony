extends GutTest

## T2.3 — p_death/day = age_curve + hardship + accident [algo §4/§17]:
## Gompertz a=0.00005, b=0.085 (negligible pre-Elder), accident 0.00002/day,
## hard cap ~115 years.


func _cohort(n: int, age: float) -> Colony:
	var colony := Colony.new()
	for i in n:
		var g := colony.spawn()
		g.age = age
		g.stage = Aging.stage_for_age(age)
	return colony


func _run_days(colony: Colony, days: int) -> int:
	for i in days:
		Mortality.tick(colony, 1.0)
	return colony.gnomes.size() - colony.population()


func test_age_curve_matches_gompertz_constants():
	assert_almost_eq(Mortality.age_curve(65.0), 0.00005, 0.0000001, "at 65 the curve equals a")
	assert_almost_eq(Mortality.age_curve(30.0), 0.00005 * exp(0.085 * -35.0), 0.0000001)
	assert_true(Mortality.age_curve(90.0) > Mortality.age_curve(70.0), "monotonic after Elder")
	assert_true(Mortality.age_curve(90.0) > 20.0 * Mortality.age_curve(50.0), "steeply rising")


func test_deaths_negligible_pre_elder():
	Rng.seed_with(2300)
	var colony := _cohort(100, 30.0)
	var deaths := _run_days(colony, 96)
	assert_lte(deaths, 3, "~0.2 expected deaths in 100 adult-years worth of days")


func test_deaths_rise_sharply_after_elder():
	Rng.seed_with(2301)
	var colony := _cohort(100, 100.0)
	var deaths := _run_days(colony, 96)
	assert_between(deaths, 2, 25, "expected ≈9 deaths at age 100 over a year")
	Rng.seed_with(2301)
	var young := _cohort(100, 30.0)
	var young_deaths := _run_days(young, 96)
	assert_true(deaths > young_deaths, "elders die more than adults under the same seed")


func test_hardship_raises_mortality():
	Rng.seed_with(2302)
	var colony := _cohort(50, 30.0)
	for g in colony.living():
		g.hardship_rate = 0.15
	var deaths := _run_days(colony, 30)
	assert_gte(deaths, 45, "0.15/day hardship kills almost everyone within a month")


func test_hard_cap_is_certain_death():
	Rng.seed_with(2303)
	var colony := _cohort(5, 115.5)
	Mortality.tick(colony, 1.0)
	assert_eq(colony.population(), 0, "beyond the ~115 cap death is certain")


func test_death_emits_one_event_with_cause():
	Rng.seed_with(2304)
	var colony := _cohort(1, 116.0)
	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.gnome_died.connect(listener)
	Mortality.tick(colony, 1.0)
	Mortality.tick(colony, 1.0)
	EventBus.gnome_died.disconnect(listener)
	assert_eq(events.size(), 1, "a gnome dies exactly once")
	assert_eq(events[0]["id"], 0)
	assert_true(events[0]["cause"] in ["age", "hardship", "accident"])
	assert_almost_eq(events[0]["age"], 116.0, 0.1)
