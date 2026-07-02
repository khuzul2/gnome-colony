class_name TimeService
extends RefCounted
## Sim calendar & clock [algo §0/§17]: 1 tick = 1 day, 24 days/season,
## 4 seasons/year = 96 days/year. Frame-rate independent — the renderer
## calls advance() with however much wall-time maps to sim-days at the
## chosen speed. (Plan T1.4 mentions "ticks/day=4"; that predates the
## review's calendar fix — §17 is the numeric truth.)

const DAYS_PER_SEASON := 24
const SEASONS_PER_YEAR := 4
const DAYS_PER_YEAR := DAYS_PER_SEASON * SEASONS_PER_YEAR

var total_days := 0.0
var speed := 1.0

var _speed_before_pause := 1.0


## Advance by `dt` sim-days scaled by the current speed.
## Returns the sim-days actually consumed (0 while paused).
func advance(dt: float) -> float:
	var consumed := dt * speed
	total_days += consumed
	return consumed


func day() -> int:
	return int(total_days)


func day_of_season() -> int:
	return day() % DAYS_PER_SEASON


func season() -> int:
	return (day() / DAYS_PER_SEASON) % SEASONS_PER_YEAR


func year() -> int:
	return day() / DAYS_PER_YEAR


func years_elapsed() -> float:
	return total_days / DAYS_PER_YEAR


func pause() -> void:
	if speed != 0.0:
		_speed_before_pause = speed
	speed = 0.0


func resume() -> void:
	speed = _speed_before_pause
