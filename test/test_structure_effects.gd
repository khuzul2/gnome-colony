extends GutTest

## R2.4 [rav §R-build] — built structures MODULATE existing flows, and every
## effect is INERT at zero structures (no double-count with the §14 tech terms,
## every pre-R2 test stays green). Each number is gated in isolation; the three
## directly-wired effects (farm→K, dwelling→crowding, wall→strength) are checked
## through their real call-sites.


func _settlement(pop: float = 100.0) -> Settlement:
	var s := Settlement.new(9, 50.0, 2.0)
	s.by_stage[Enums.LifeStage.ADULT] = pop
	return s


func test_every_effect_is_identity_at_zero_structures():
	var s := _settlement()
	assert_eq(StructureEffects.farm_k_bonus(s), 1.0, "no farms → K unchanged")
	assert_eq(StructureEffects.housing_capacity(s), 0.0, "no dwellings → no housing")
	assert_eq(StructureEffects.drought_mortality_mult(s), 1.0)
	assert_eq(StructureEffects.famine_mult(s), 1.0)
	assert_eq(StructureEffects.research_mult(s), 1.0)
	assert_eq(StructureEffects.unrest_growth_mult(s), 1.0)
	assert_eq(StructureEffects.devotion_mass_mult(s), 1.0)
	assert_eq(StructureEffects.war_strength_mult(s), 1.0)
	assert_eq(StructureEffects.trade_mood_mult(s), 1.0)


func test_isolated_effect_numbers_match_spec():
	var s := _settlement()
	s.structures = {
		"farm": 2.0,
		"well": 1.0,
		"granary": 1.0,
		"workshop": 1.0,
		"basilica": 1.0,
		"wall": 1.0,
		"market": 1.0,
	}
	assert_almost_eq(StructureEffects.farm_k_bonus(s), 1.30, 0.0001, "+0.15 per farm")
	assert_eq(StructureEffects.drought_mortality_mult(s), 0.8, "well −20%")
	assert_eq(StructureEffects.famine_mult(s), 0.7, "granary −30%")
	assert_eq(StructureEffects.research_mult(s), 1.2, "workshop ×1.2 craft research")
	assert_eq(StructureEffects.unrest_growth_mult(s), 0.8, "basilica ×0.8 terror-unrest")
	assert_eq(StructureEffects.devotion_mass_mult(s), 1.05, "basilica ×1.05 devotion mass")
	assert_eq(StructureEffects.war_strength_mult(s), 1.25, "wall ×1.25")
	assert_eq(StructureEffects.trade_mood_mult(s), 1.5, "market ×1.5 trade mood")


func test_farm_bonus_caps_at_the_agriculture_term():
	var s := _settlement()
	s.structures["farm"] = 10.0  # 10·0.15 = 1.5, capped to 0.5
	assert_almost_eq(
		StructureEffects.farm_k_bonus(s), 1.5, 0.0001, "farms can't exceed the ag term"
	)


func test_wall_multiplier_caps_at_double():
	var s := _settlement()
	s.structures["wall"] = 8.0  # 8·0.25 = 2.0, capped to +1.0
	assert_eq(StructureEffects.war_strength_mult(s), 2.0, "walls cap at ×2")


func test_farms_raise_carrying_capacity_through_k():
	var c := Colony.new()
	c.settlement_knowledge[9] = {}
	var s := _settlement()
	var bare := s.k(c)
	s.structures["farm"] = 2.0
	assert_almost_eq(s.k(c), bare * 1.30, 0.0001, "farms raise K at the call-site")


func test_dwellings_ease_crowding_through_crowding():
	var c := Colony.new()
	c.settlement_knowledge[9] = {}
	var s := _settlement()
	var bare := s.crowding(c)
	s.structures["dwelling"] = 5.0  # +20 housing capacity
	assert_lt(s.crowding(c), bare, "dwellings add housing and ease crowding")


func test_walls_raise_war_strength_through_civilization():
	var c := Colony.new()
	c.settlement_knowledge[9] = {}
	var a := _settlement(100.0)
	var b := _settlement(100.0)
	b.sid = 10
	c.settlement_knowledge[10] = {}
	# a walled town beats an unwalled twin of equal population.
	a.structures["wall"] = 2.0
	var outcome := Civilization.war(c, a, b)
	assert_eq(outcome["winner"], a, "walls decide a war between equals [R2.4]")
