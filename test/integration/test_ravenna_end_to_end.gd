extends GutTest

## R4.1 [rav §R-set/§R-build/§R-infl] — the Ravenna settlement arc, END-TO-END
## and WORLD-DRIVEN. Every construction pressure is derived from the WORLD you
## shaped, through Construction.pressures_from — so this proves the influence
## loop itself (design §1.3, "legible only in hindsight"), not the priority
## math test_construction already pins.
##
## The per-beat tests are CONTROLLED experiments: two settlements identical but
## for one world signal, where the control's priority for the target structure
## is EXACTLY 0 without the signal (curious pinned to 0, fear 0, a tier short of
## devotion, no drought). So each assertion is load-bearing BY CONSTRUCTION —
## sever the routing and the "with-signal" build vanishes with nothing else to
## raise it. Then the integrated arc climbs hamlet→village→town→city in order,
## and a Long Dark regresses it. Sim-side only: no Node, no Rng, no render.

const PLACE := "the_hollow"
const SID := 3


func _colony(knowledge: Dictionary, unlocked_tier: int) -> Colony:
	var c := Colony.new()
	c.settlement_knowledge[SID] = knowledge.duplicate()
	c.unlocked_tier = unlocked_tier
	return c


## A settlement with pinned belief/traits so a control's target-structure
## priority is exactly what the tested signal contributes — nothing incidental.
func _settle(faith: float, fear: float, curious: float, adults: float) -> Settlement:
	var s := Settlement.new(SID, 200.0, 4.0)
	s.belief["faith"] = faith
	s.belief["fear"] = fear
	s.mean_traits["curious"] = curious
	s.by_stage[Enums.LifeStage.ADULT] = adults
	return s


## `iron` bared at the place — a landslide's revealed seam; the loop reads it as
## a workshop [§R-infl]. Mirrors WorldState.reveal_hidden's "<site>_<type>"
## naming so Construction._has_ore's begins_with(place) check finds it.
func _bare_ore(world: WorldState) -> void:
	world.sites["%s_iron" % PLACE] = ResourceNode.new("iron", 100.0, 100.0, 0.0, 1.0)


## Run `n` seasons whose pressures come FROM the world, never hand-fed — the
## real derivation _frontier_season uses.
func _seasons(c: Colony, s: Settlement, world: WorldState, food_factor: float, n: int) -> void:
	for _i in n:
		var pressures := Construction.pressures_from(c, world, PLACE, food_factor)
		Construction.season_tick(c, s, pressures)


func _distinct_promotions(s: Settlement) -> Array:
	var tos := []
	for i in get_signal_emit_count(EventBus, "settlement_tier_changed"):
		var p: Dictionary = get_signal_parameters(EventBus, "settlement_tier_changed", i)[0]
		if p["sid"] == s.sid and (tos.is_empty() or tos[-1] != p["to"]):
			tos.append(p["to"])
	return tos


# --- controlled per-beat routing: the world signal is load-bearing ----------


func test_drought_routes_to_a_well():
	# Well priority = water = drought; without drought it is exactly 0, so a well
	# only rises where the DROUGHT affordance drove it. (A farm rises either way —
	# it carries a +0.3 agricultural baseline — so the well is the clean witness.)
	var knowledge := {"agriculture": true}
	var parched := _settle(0.0, 0.0, 0.0, 30.0)
	var arid := WorldState.new()
	arid.affordances[PLACE] = ["drought"]
	_seasons(_colony(knowledge, 0), parched, arid, 1.0, 8)

	var watered := _settle(0.0, 0.0, 0.0, 30.0)
	_seasons(_colony(knowledge, 0), watered, WorldState.new(), 1.0, 8)

	assert_gte(parched.structure_count("farm"), 1.0, "scarcity drives the plough")
	assert_gte(parched.structure_count("well"), 1.0, "drought → a well [§R-infl]")
	assert_eq(
		watered.structure_count("well"), 0.0, "no drought, no well — the signal is load-bearing"
	)


func test_bared_ore_routes_to_a_workshop():
	# Workshop priority = has_ore + curious. With curious pinned to 0, only BARED
	# ORE can raise it — the reviewer's mutation caught the curious default masking
	# this, so the control proves the ore routing itself.
	var knowledge := {"smithing": true}
	var mined := _settle(0.0, 0.0, 0.0, 90.0)
	var seamed := WorldState.new()
	_bare_ore(seamed)
	_seasons(_colony(knowledge, 0), mined, seamed, 1.0, 10)

	var barren := _settle(0.0, 0.0, 0.0, 90.0)
	_seasons(_colony(knowledge, 0), barren, WorldState.new(), 1.0, 10)

	assert_gte(mined.structure_count("workshop"), 1.0, "bared ore → a workshop [§R-infl]")
	assert_eq(barren.structure_count("workshop"), 0.0, "no ore + incurious folk → no workshop")


func test_dread_routes_to_a_wall():
	# Wall priority = fear + war_threat; pressures_from sets war_threat 0, so fear
	# is the sole driver — no dread, no wall.
	var knowledge := {"construction": true}
	var afraid := _settle(0.0, 0.9, 0.0, 90.0)
	_seasons(_colony(knowledge, 0), afraid, WorldState.new(), 1.0, 12)

	var calm := _settle(0.0, 0.0, 0.0, 90.0)
	_seasons(_colony(knowledge, 0), calm, WorldState.new(), 1.0, 12)

	assert_gte(afraid.structure_count("wall"), 1.0, "dread → a wall [§R-infl]")
	assert_eq(calm.structure_count("wall"), 0.0, "no dread, no wall")


func test_devotion_routes_to_a_basilica():
	# A basilica needs devotion Tier III (unlocked_tier >= 3) AND construction. A
	# colony one tier short can never seat one — the devotion prereq is the
	# load-bearing signal, not the faith weight.
	var knowledge := {"agriculture": true, "construction": true}
	var devout := _settle(0.9, 0.0, 0.0, 90.0)
	_seasons(_colony(knowledge, 3), devout, WorldState.new(), 1.0, 10)

	var shallow := _settle(0.9, 0.0, 0.0, 90.0)
	_seasons(_colony(knowledge, 2), shallow, WorldState.new(), 1.0, 10)

	assert_gte(devout.structure_count("basilica"), 1.0, "Tier III devotion → a basilica [§R-infl]")
	assert_eq(shallow.structure_count("basilica"), 0.0, "a tier short of devotion seats none")


# --- the integrated arc: growth in order, then a Long Dark ------------------


func test_the_world_you_shape_climbs_the_tiers_in_order():
	# The whole loop at once: the same settlement, its world changing season by
	# season, climbs hamlet→village→town→city — one crossing per tier, ascending.
	var c := _colony({"agriculture": true, "smithing": true, "construction": true}, 3)
	var s := _settle(0.9, 0.0, 0.5, 20.0)
	var world := WorldState.new()
	watch_signals(EventBus)
	assert_eq(s.tier, Enums.SettlementTier.HAMLET, "it starts a hamlet")

	world.affordances[PLACE] = ["drought"]  # scarcity → the plough → a village
	_seasons(c, s, world, 1.0, 8)
	assert_eq(s.tier, Enums.SettlementTier.VILLAGE, "pop + a farm → village")

	world.affordances.erase(PLACE)  # plenty → a granary → a town
	_bare_ore(world)
	s.by_stage[Enums.LifeStage.ADULT] = 90.0
	_seasons(c, s, world, 1.0, 10)
	assert_eq(s.tier, Enums.SettlementTier.TOWN, "pop + construction + a granary → town")

	s.belief["fear"] = 0.9  # dread + devotion → a wall + basilica → a city
	s.by_stage[Enums.LifeStage.ADULT] = 320.0
	_seasons(c, s, world, 1.0, 12)
	assert_eq(s.tier, Enums.SettlementTier.CITY, "pop + a basilica + a wall → city")

	assert_eq(
		_distinct_promotions(s),
		[
			Enums.SettlementTier.VILLAGE,
			Enums.SettlementTier.TOWN,
			Enums.SettlementTier.CITY,
		],
		"one crossing per tier, in order"
	)


func test_a_long_dark_loses_the_craft_and_regresses_the_tier():
	var c := _colony({"agriculture": true, "smithing": true, "construction": true}, 3)
	var s := _settle(0.9, 0.9, 0.5, 320.0)
	var world := WorldState.new()
	_bare_ore(world)
	_seasons(c, s, world, 1.0, 24)
	assert_gte(s.structure_count("workshop"), 1.0, "the grown settlement forged in a workshop")
	var peak_tier := s.tier
	assert_gte(peak_tier, Enums.SettlementTier.TOWN, "it grew to at least a town")

	# THE LONG DARK [§7]: the region loses smithing, so the workshop can no longer
	# stand; a hollowed labor force lets the rest of the stock fall to ruin.
	c.settlement_knowledge[SID].erase("smithing")
	s.by_stage[Enums.LifeStage.ADULT] = 1.0
	s.by_stage[Enums.LifeStage.CHILD] = 5.0
	for _i in 30:
		Construction.decay_tick(c, s)
	assert_eq(s.structure_count("workshop"), 0.0, "the lost craft strips the workshop [§7]")
	assert_lt(s.tier, peak_tier, "a dark age regresses the tier")
