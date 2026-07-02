extends GutTest

## T8.2 — toolbox tiers [algo §10/§17]: unlock on PEAK per-capita devotion
## d̄_peak (II .15 · III .30 · IV .45 pop≥50 · V .60 pop≥200 · VI .78
## pop≥1000 or gen≥5), ratcheting — a baby boom dilutes d̄ but never strips
## an earned power. Floors are checked when the unlock happens.


func _flock(colony: Colony, n: int, faith: float, generation: int = 0) -> void:
	for i in n:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.generation = generation
		g.set_feeling(Devotion.YOU, "faith", faith)


func test_tiers_unlock_at_exact_thresholds():
	var c := Colony.new()
	_flock(c, 4, 0.14)
	Devotion.update_unlocks(c)
	assert_eq(c.unlocked_tier, 1, "0.14 is short of Tier II")
	for g in c.living():
		g.set_feeling(Devotion.YOU, "faith", 0.15)
	Devotion.update_unlocks(c)
	assert_eq(c.unlocked_tier, 2, "exactly 0.15 opens Tier II")
	for g in c.living():
		g.set_feeling(Devotion.YOU, "faith", 0.30)
	Devotion.update_unlocks(c)
	assert_eq(c.unlocked_tier, 3)


func test_population_floors_gate_the_high_tiers():
	var cult := Colony.new()
	_flock(cult, 10, 0.9)
	Devotion.update_unlocks(cult)
	assert_eq(cult.unlocked_tier, 3, "ten fanatics cannot wield Omens — pop floor 50")
	var town := Colony.new()
	_flock(town, 50, 0.9)
	Devotion.update_unlocks(town)
	assert_eq(town.unlocked_tier, 4, "pop 50 admits Tier IV, 200 still gates V")


func test_generation_alternative_for_tier_six():
	var old_line := Colony.new()
	_flock(old_line, 250, 0.9, 6)
	Devotion.update_unlocks(old_line)
	assert_eq(old_line.unlocked_tier, 6, "gen ≥ 5 stands in for the pop-1000 floor")


func test_ladder_never_skips_a_gated_rung():
	# Pins the interpretation: a tiny, ancient, fanatic line cannot leap
	# past the pop-gated middle tiers to Wonders — VI's gen alternative
	# only matters once IV and V are honestly earned.
	var hermits := Colony.new()
	_flock(hermits, 10, 0.9, 8)
	Devotion.update_unlocks(hermits)
	assert_eq(hermits.unlocked_tier, 3, "gen 8 alone cannot skip the pop-50 rung")


func test_baby_boom_never_strips_a_power():
	var c := Colony.new()
	_flock(c, 8, 0.35)
	Devotion.update_unlocks(c)
	assert_eq(c.unlocked_tier, 3)
	_flock(c, 80, 0.0)
	assert_lt(Devotion.per_capita(c), 0.15, "newborns diluted the mean below even Tier II")
	Devotion.update_unlocks(c)
	assert_eq(c.unlocked_tier, 3, "the ratchet holds — you earned it")
	assert_almost_eq(c.devotion_peak, 0.35, 0.0001, "peak remembers")


func test_unlock_state_round_trips():
	var c := Colony.new()
	_flock(c, 8, 0.35)
	Devotion.update_unlocks(c)
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(c))
	assert_eq(restored.unlocked_tier, 3)
	assert_almost_eq(restored.devotion_peak, 0.35, 0.0001)
