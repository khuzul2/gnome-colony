extends GutTest

## T12.1 — full save-game serializer [plan Phase 12, setup spec]: the
## whole run state — colony (with its belief/culture graph), world
## (sites/hidden/paths/affordances/wards), settlement aggregates, config,
## calendar, chronicle, and the RNG stream — round-trips to plain data
## and back with equality. A restored RNG must continue the SAME
## sequence an uninterrupted run would have produced.


func _rich_world() -> Dictionary:
	Rng.seed_with(12100)
	var colony := Colony.new()
	for i in 6:
		var g := colony.spawn()
		g.age = 30.0 + i
		g.stage = Enums.LifeStage.ADULT
		g.set_skill("smithing", 0.5 + 0.05 * i)
		g.add_knowledge("smithing")
		g.set_feeling(Devotion.YOU, "faith", 0.4)
	colony.gnomes[0].prophet = {
		"message": {"subject": "birds_silent", "flavor": "mercy"},
		"caught_age": 30.0,
		"corrupted": false,
		"charisma": 0.7,
		"doom_at": -1.0,
	}
	colony.beliefs.append(BeliefObject.make("taboo", "eastern_ridge", "fear", 0.5, [1, 2, 3]))
	colony.place_tags["eastern_ridge"] = {"cursed": 0.6}
	colony.belief_tracker["eastern_ridge|fear"] = 12.0
	colony.settlement_knowledge[0] = {"smithing": true, "writing": true}
	colony.durable_records[0] = {"smithing": true}
	colony.devotion_peak = 0.35
	colony.unlocked_tier = 3
	colony.unrest = 0.2
	colony.magic_understanding = {0: 0.55}
	colony.leaders = {0: 2}
	var world := WorldState.new()
	world.sites["the_hollow"] = ResourceNode.new("food", 100.0, 60.0, 10.0, 1.0)
	world.hidden_resources["eastern_ridge"] = [ResourceNode.new("iron", 30.0, 30.0, 0.0, 1.5)]
	world.paths["eastern_ridge_path"] = false
	world.affordances["eastern_ridge"] = ["slope"]
	world.wards["the_hollow"] = 0.7
	var s := Settlement.new(0, 50.0, 2.0)
	s.by_stage[Enums.LifeStage.ADULT] = 40.0
	s.mean_traits["curious"] = 0.7
	s.belief["faith"] = 0.5
	s.mood = 0.8
	var cfg := WorldConfig.new()
	cfg.seed = 12100
	cfg.band_size = 6
	var time := TimeService.new()
	time.advance(250.0)
	return {
		"colony": colony,
		"world": world,
		"settlements": [s],
		"config": cfg,
		"time": time,
		"chronicle": ["Year 0 · a band steps out", "Year 1 · born #6"],
	}


func test_world_state_round_trips():
	var state := _rich_world()
	var restored: WorldState = Serializer.world_from_dict(Serializer.world_to_dict(state["world"]))
	assert_eq(restored.sites["the_hollow"].type, "food")
	assert_almost_eq(restored.sites["the_hollow"].current, 60.0, 0.0001)
	assert_almost_eq(restored.sites["the_hollow"].regrowth, 10.0, 0.0001)
	assert_eq(restored.hidden_resources["eastern_ridge"][0].type, "iron")
	assert_eq(restored.paths["eastern_ridge_path"], false)
	assert_eq(restored.affordances["eastern_ridge"], ["slope"])
	assert_almost_eq(restored.wards["the_hollow"], 0.7, 0.0001)


func test_settlement_round_trips():
	var state := _rich_world()
	var s: Settlement = state["settlements"][0]
	var restored: Settlement = Serializer.settlement_from_dict(Serializer.settlement_to_dict(s))
	assert_eq(restored.sid, 0)
	assert_almost_eq(restored.by_stage[Enums.LifeStage.ADULT], 40.0, 0.0001)
	assert_almost_eq(restored.mean_traits["curious"], 0.7, 0.0001)
	assert_almost_eq(restored.belief["faith"], 0.5, 0.0001)
	assert_almost_eq(restored.mood, 0.8, 0.0001)
	assert_almost_eq(restored.base_k, 50.0, 0.0001)


func test_full_save_round_trips_with_equality():
	var state := _rich_world()
	var save := Serializer.save_to_dict(
		state["colony"],
		state["world"],
		state["settlements"],
		state["config"],
		state["time"],
		state["chronicle"]
	)
	var loaded := Serializer.save_from_dict(save)
	var resaved := Serializer.save_to_dict(
		loaded["colony"],
		loaded["world"],
		loaded["settlements"],
		loaded["config"],
		loaded["time"],
		loaded["chronicle"]
	)
	assert_eq(resaved, save, "save → load → save is byte-stable on a rich late-game state")
	assert_eq(loaded["time"].day(), 250)
	assert_eq(loaded["chronicle"].size(), 2)
	assert_eq(loaded["colony"].gnomes[0].prophet["message"]["flavor"], "mercy")


func test_save_is_plain_data():
	var state := _rich_world()
	var save := Serializer.save_to_dict(
		state["colony"],
		state["world"],
		state["settlements"],
		state["config"],
		state["time"],
		state["chronicle"]
	)
	var json := JSON.stringify(save)
	assert_true(json.length() > 100, "the whole save survives JSON — no objects leaked in")
	# The REAL disk trip: parse it back and continue the run from it.
	# (Reviewer catch: a raw int64 rng_state silently corrupts through
	# JSON's doubles — hence the string encoding.)
	var reparsed: Dictionary = JSON.parse_string(json)
	var reloaded := Serializer.save_from_dict(reparsed)
	assert_eq(
		reloaded["colony"].population(),
		state["colony"].population(),
		"a save that crossed a real JSON boundary still loads"
	)
	assert_eq(
		str(reparsed["rng_state"]),
		str(save["rng_state"]),
		"the 64-bit stream position survives JSON exactly"
	)


func test_rng_stream_continues_across_a_save():
	Rng.seed_with(4242)
	Rng.randf()
	Rng.gauss(0.0, 1.0)
	var saved_state := Rng.get_state()
	var uninterrupted := [Rng.randf(), Rng.randf(), Rng.randi_range(0, 100)]
	Rng.seed_with(999)
	Rng.randf()
	Rng.set_state(saved_state)
	var resumed := [Rng.randf(), Rng.randf(), Rng.randi_range(0, 100)]
	assert_eq(resumed, uninterrupted, "a loaded game continues the exact stream [Phase 12 goal]")


## A deliberately id-shuffled two-basin graph dict (the serializer's
## region_graph shape) for the §6.1 thumbnail tests [T21.4].
func _region_graph_dict() -> Dictionary:
	return {
		"regions":
		[
			{"id": 1, "center": [1.0, 0.0], "elevation": 1.4, "biome": "forest", "neighbors": [0]},
			{"id": 0, "center": [0.0, 0.0], "elevation": 2.6, "biome": "ridge", "neighbors": [1]},
		],
		"version": 0,
	}


func test_meta_carries_a_deterministic_thumbnail_when_the_envelope_has_a_region_graph():
	var state := _rich_world()
	var envelope := Serializer.save_to_dict(
		state["colony"],
		state["world"],
		state["settlements"],
		state["config"],
		state["time"],
		state["chronicle"]
	)
	envelope["region_graph"] = _region_graph_dict()
	var meta := SaveStore.derive_meta(envelope)
	assert_eq(
		meta["thumbnail"],
		[[2, 3], [1, 1]],
		"id-sorted cells of [biome index (ridge=2, forest=1), rounded elevation] [§6.1 card]"
	)
	assert_eq(
		SaveStore.derive_meta(envelope)["thumbnail"],
		meta["thumbnail"],
		"same envelope, same thumbnail — deterministic"
	)
	var reparsed: Variant = JSON.parse_string(JSON.stringify(meta["thumbnail"]))
	assert_not_null(reparsed, "the grid is JSON-safe — it rides the card to disk")


func test_an_envelope_without_a_region_graph_thumbnails_to_empty():
	var envelope := Serializer.save_to_dict(
		Colony.new(), WorldState.new(), [], WorldConfig.new(), TimeService.new(), []
	)
	var meta := SaveStore.derive_meta(envelope)
	assert_eq(meta["thumbnail"], [], "old saves stay loadable — an empty grid, not a crash")


func test_the_load_card_renders_the_thumbnail_as_biome_glyphs():
	var store := SaveStore.new("user://test_thumbnail_saves")
	store.wipe()
	var envelope := Serializer.save_to_dict(
		Colony.new(), WorldState.new(), [], WorldConfig.new(), TimeService.new(), []
	)
	envelope["region_graph"] = _region_graph_dict()
	store.save_game("thumbed", envelope, {"kind": "manual", "timestamp": "t1"})
	var menu := LoadMenu.new()
	add_child_autofree(menu)
	menu.build(store)
	var text: String = menu.cards["thumbed"].get_node("label").text
	assert_string_contains(text, "▲♣", "id-sorted glyphs: ridge then forest [presentation]")
	assert_eq(LoadMenu.glyphs([[0, 1], [3, 2], [9, 1]]), ".~?", "meadow, marsh, unknown biome")
	store.wipe()


func test_newest_is_robust_under_tied_timestamps():
	# [T18.5] whole-second stamps tie under rapid saves; the monotonic
	# sequence breaks the tie by write order, by construction.
	var store := SaveStore.new("user://test_sequence_saves")
	store.wipe()
	var envelope := Serializer.save_to_dict(
		Colony.new(), WorldState.new(), [], WorldConfig.new(), TimeService.new(), []
	)
	for slot in ["zzz_first", "aaa_second", "mmm_third"]:
		store.save_game(slot, envelope, {"kind": "manual", "timestamp": "same_second"})
	assert_eq(store.list_saves()[0]["slot"], "mmm_third", "the LAST write is the newest")
	store.wipe()
