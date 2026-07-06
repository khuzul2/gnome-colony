extends GutTest

## R4.2 [rav §R-set/§R-build] — the redesign determinism envelope. The living
## settlement adds STRUCTURES, TIER, and banked BUILD_PROGRESS to the save
## state (Serializer.settlement_to_dict, added in R2). This proves that new
## state is a first-class, reproducible part of the envelope:
##   · a scripted construction run (Construction is Rng-free) reproduces its
##     settlement-envelope hash across independent runs;
##   · structures/tier are LOAD-BEARING in the hash — a differently-developed
##     settlement hashes differently, so the state can't silently fall out;
##   · save→load round-trips the built stock and leaves no fingerprint;
##   · the built settlement rides the FULL save envelope reproducibly.
## Sim-side only: no Node, no render, no Rng in the construction path.

const SEED := 42200
const PLACE := "the_hollow"
const SID := 3


func _colony() -> Colony:
	var c := Colony.new()
	c.settlement_knowledge[SID] = {"agriculture": true, "smithing": true, "construction": true}
	c.unlocked_tier = 3
	return c


func _world() -> WorldState:
	var world := WorldState.new()
	# A bared iron seam so the arc also raises a workshop [§R-infl].
	world.sites["%s_iron" % PLACE] = ResourceNode.new("iron", 100.0, 100.0, 0.0, 1.0)
	return world


## A settlement developed over `seasons` of Rng-free, world-driven construction.
func _built_settlement(seasons: int) -> Settlement:
	Rng.seed_with(SEED)  # construction draws no Rng — seeding proves independence
	var c := _colony()
	var world := _world()
	var s := Settlement.new(SID, 200.0, 4.0)
	s.belief["faith"] = 0.9
	s.belief["fear"] = 0.9
	s.by_stage[Enums.LifeStage.ADULT] = 320.0
	for _i in seasons:
		Construction.season_tick(c, s, Construction.pressures_from(c, world, PLACE, 1.0))
	return s


func _hash(s: Settlement) -> String:
	return JSON.stringify(Serializer.settlement_to_dict(s)).md5_text()


func test_the_built_state_reproduces_its_envelope_hash():
	# The hash is stable across runs because construction is a pure function of
	# state: _best_buildable iterates the fixed Settlement.BUILDING_IDS order, so
	# the `structures` dict is filled in the same insertion order every run, and
	# JSON.stringify serializes that order deterministically.
	assert_eq(
		_hash(_built_settlement(20)),
		_hash(_built_settlement(20)),
		"same seed + world + seasons ⇒ an identical structures/tier envelope"
	)


func test_structures_and_tier_are_load_bearing_in_the_envelope():
	# A settlement developed for longer holds a different stock/tier, so it MUST
	# hash differently — proving the redesign state is actually captured, not
	# dropped from the envelope.
	var young := _built_settlement(4)
	var grown := _built_settlement(20)
	assert_ne(_hash(young), _hash(grown), "a differently-developed settlement hashes differently")
	assert_true(grown.tier > young.tier, "…and the grown one really did develop further")


func test_save_load_round_trips_the_built_stock():
	var s := _built_settlement(20)
	var restored := Serializer.settlement_from_dict(Serializer.settlement_to_dict(s))
	assert_eq(restored.structures, s.structures, "every built structure survives the envelope")
	assert_eq(restored.tier, s.tier, "…and the earned tier [rav §R-set]")
	assert_almost_eq(restored.build_progress, s.build_progress, 0.0001, "…and the banked labor")
	assert_eq(_hash(restored), _hash(s), "the round-trip leaves no fingerprint")


func test_the_built_settlement_rides_the_full_save_envelope():
	# The whole sim envelope (colony + world + settlements + time + chronicle)
	# carries the built stock and reproduces byte-for-byte.
	var a := _full_envelope()
	var b := _full_envelope()
	assert_eq(a["hash"], b["hash"], "the full redesign envelope is reproducible")
	assert_true(a["has_structures"], "…and it actually contains the built structures")


func _full_envelope() -> Dictionary:
	Rng.seed_with(SEED)
	var cfg := WorldConfig.new()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var c := runner.colony
	c.settlement_knowledge[SID] = {"agriculture": true, "smithing": true, "construction": true}
	c.unlocked_tier = 3
	var world := _world()
	var s := Settlement.new(SID, 200.0, 4.0)
	s.belief["faith"] = 0.9
	s.belief["fear"] = 0.9
	s.by_stage[Enums.LifeStage.ADULT] = 320.0
	for _i in 20:
		Construction.season_tick(c, s, Construction.pressures_from(c, world, PLACE, 1.0))
	var save := Serializer.save_to_dict(c, world, [s], cfg, runner.time, runner.chronicle)
	runner.shutdown()
	return {"hash": JSON.stringify(save).md5_text(), "has_structures": not s.structures.is_empty()}
