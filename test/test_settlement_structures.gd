extends GutTest

## R2.1 [rav §R-build] — the settlement aggregate gains a `structures` stock
## (building-id → fractional count) and a `tier` (hamlet→city), both
## round-tripping through the serializer. Pure data; the flows come in R2.2/R2.3.


func test_new_settlement_has_no_structures_and_is_a_hamlet():
	var s := Settlement.new(0, 100.0, 2.0)
	assert_eq(s.structures, {}, "a fresh settlement has built nothing")
	assert_eq(s.tier, Enums.SettlementTier.HAMLET, "…and starts a hamlet")
	assert_eq(s.structure_count("farm"), 0.0, "absent structures count as zero")


func test_structure_count_reads_the_stock():
	var s := Settlement.new(1, 100.0, 2.0)
	s.structures["farm"] = 3.0
	s.structures["granary"] = 1.0
	assert_eq(s.structure_count("farm"), 3.0)
	assert_eq(s.structure_count("granary"), 1.0)
	assert_eq(s.structure_count("wall"), 0.0)


func test_tier_enum_is_stable():
	assert_eq(Enums.SettlementTier.HAMLET, 0)
	assert_eq(Enums.SettlementTier.VILLAGE, 1)
	assert_eq(Enums.SettlementTier.TOWN, 2)
	assert_eq(Enums.SettlementTier.CITY, 3)


func test_building_ids_cover_the_spec_catalog():
	# §R-build's nine structures, canonical order.
	assert_eq(
		Settlement.BUILDING_IDS,
		["dwelling", "farm", "well", "granary", "workshop", "shrine", "basilica", "wall", "market"]
	)


func test_structures_and_tier_round_trip():
	var s := Settlement.new(2, 120.0, 3.0)
	s.structures["dwelling"] = 5.0
	s.structures["farm"] = 2.0
	s.structures["basilica"] = 1.0
	s.tier = Enums.SettlementTier.TOWN
	var d := Serializer.settlement_to_dict(s)
	var back := Serializer.settlement_from_dict(d)
	assert_eq(back.structures, s.structures, "the built stock survives save/load")
	assert_eq(back.tier, Enums.SettlementTier.TOWN, "…and the tier")


func test_legacy_dict_without_structures_loads_as_empty_hamlet():
	# Pre-feature saves (no structures/tier keys) must still load.
	var s := Settlement.new(3, 100.0, 2.0)
	var d := Serializer.settlement_to_dict(s)
	d.erase("structures")
	d.erase("tier")
	var back := Serializer.settlement_from_dict(d)
	assert_eq(back.structures, {}, "missing structures → empty")
	assert_eq(back.tier, Enums.SettlementTier.HAMLET, "missing tier → hamlet")
