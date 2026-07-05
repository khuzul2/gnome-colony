extends GutTest

## R2.5 [rav §R-set] — regression & abandonment: an under-tended settlement's
## structures decay and its tier can fall; a dark age that loses the enabling
## craft strips the workshop; a well-labored settlement holds everything.


func _settlement(adults: float, children: float = 0.0) -> Settlement:
	var s := Settlement.new(5, 100.0, 3.0)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	s.by_stage[Enums.LifeStage.CHILD] = children
	return s


func _colony(techs: Array = []) -> Colony:
	var c := Colony.new()
	var known := {}
	for t in techs:
		known[t] = true
	c.settlement_knowledge[5] = known
	return c


func test_under_labored_structures_decay():
	var s := _settlement(1.0, 20.0)  # 1 adult, pop 21 → labor 0
	s.structures = {"dwelling": 2.0, "farm": 1.0}
	Construction.decay_tick(_colony(["agriculture"]), s)
	assert_lt(s.structure_count("dwelling"), 2.0, "neglected dwellings crumble")
	assert_lt(s.structure_count("farm"), 1.0, "…and the farm goes fallow")


func test_well_labored_settlement_holds_its_buildings():
	var s := _settlement(40.0)  # plenty of hands
	s.structures = {"dwelling": 3.0, "farm": 2.0, "granary": 1.0}
	Construction.decay_tick(_colony(["agriculture"]), s)
	assert_eq(s.structure_count("dwelling"), 3.0, "a tended settlement loses nothing")
	assert_eq(s.structure_count("farm"), 2.0)


func test_decay_can_drop_the_tier():
	var c := _colony(["agriculture"])
	var s := _settlement(0.5, 5.0)  # a dwindling remnant
	s.structures = {"farm": 0.03}  # a hair of a farm left
	s.tier = Enums.SettlementTier.VILLAGE
	Construction.decay_tick(c, s)
	assert_eq(s.structure_count("farm"), 0.0, "the last farm is gone")
	assert_eq(s.tier, Enums.SettlementTier.HAMLET, "a village without a farm is a hamlet again")


func test_a_dark_age_strips_the_workshop():
	var c := _colony(["smithing"])
	var s := _settlement(40.0)
	s.structures = {"workshop": 1.0}
	Construction.decay_tick(c, s)
	assert_eq(s.structure_count("workshop"), 1.0, "with the craft alive the workshop stands")
	# The craft goes extinct in this settlement (a regional dark age, §7).
	c.settlement_knowledge[5].erase("smithing")
	Construction.decay_tick(c, s)
	assert_eq(s.structure_count("workshop"), 0.0, "losing the craft strips the workshop")


func test_recovery_rebuilds_after_a_dark_age():
	var c := _colony(["stoneworking"])
	var s := _settlement(40.0)
	s.build_progress = 20.0
	# The craft returns (trade/migration re-spread) and there is ore + curiosity.
	var built := Construction.season_tick(c, s, {"has_ore": 1.0})
	assert_eq(built, "workshop", "with the craft back, the workshop rises again")


func test_counts_never_go_negative():
	var s := _settlement(0.0, 10.0)  # no labor at all
	s.structures = {"shrine": 0.02}
	Construction.decay_tick(_colony(), s)
	assert_eq(s.structure_count("shrine"), 0.0, "decay floors at zero, never negative")
