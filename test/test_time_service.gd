extends GutTest

## Calendar per algo §0/§17 (the numeric truth): 1 tick = 1 day,
## 24 days/season, 4 seasons/year = 96 days/year.
## (Plan T1.4's "ticks/day=4" is a pre-review fossil; §17 wins.)


func test_calendar_constants():
	assert_eq(TimeService.DAYS_PER_SEASON, 24)
	assert_eq(TimeService.SEASONS_PER_YEAR, 4)
	assert_eq(TimeService.DAYS_PER_YEAR, 96)


func test_rollovers_are_exact():
	var t := TimeService.new()
	assert_eq(t.day(), 0)
	t.advance(23.0)
	assert_eq(t.day(), 23)
	assert_eq(t.season(), 0)
	assert_eq(t.year(), 0)
	t.advance(1.0)
	assert_eq(t.day(), 24, "day 24 opens season 1")
	assert_eq(t.season(), 1)
	assert_eq(t.year(), 0)
	t.advance(71.0)
	assert_eq(t.day(), 95, "last day of year 0")
	assert_eq(t.season(), 3)
	assert_eq(t.year(), 0)
	t.advance(1.0)
	assert_eq(t.day(), 96)
	assert_eq(t.season(), 0, "year rollover resets season")
	assert_eq(t.year(), 1)
	assert_eq(t.day_of_season(), 0)


func test_years_elapsed_fraction():
	var t := TimeService.new()
	t.advance(48.0)
	assert_almost_eq(t.years_elapsed(), 0.5, 0.0001)


func test_speed_scales_advance():
	var t := TimeService.new()
	t.speed = 4.0
	var consumed := t.advance(1.0)
	assert_eq(consumed, 4.0, "advance returns the scaled sim-days consumed")
	assert_eq(t.day(), 4)


func test_pause_freezes_time():
	var t := TimeService.new()
	t.advance(5.0)
	t.pause()
	t.advance(100.0)
	assert_eq(t.day(), 5)
	t.resume()
	t.advance(1.0)
	assert_eq(t.day(), 6)
	assert_eq(t.speed, 1.0, "resume restores the previous speed")


func test_resume_restores_fast_forward_speed():
	var t := TimeService.new()
	t.speed = 8.0
	t.pause()
	t.resume()
	assert_eq(t.speed, 8.0)
