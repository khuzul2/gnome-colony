extends GutTest

## T15.3 — Load Game [setup §6.1]: a SaveStore that lists saves as
## metadata cards (colony name, generation, population, seed, playtime,
## timestamp, kind) with Manual/Autosave tabs, and a LoadMenu that
## renders the cards and reports the chosen slot; loading restores the
## exact envelope. Timestamps are metadata fed BY THE CALLER (the shell
## clock never enters sim logic).

const DIR := "user://test_saves_t153"

var _store: SaveStore


func before_each():
	_store = SaveStore.new(DIR)
	_store.wipe()


func after_all():
	SaveStore.new(DIR).wipe()


func _rich_save() -> Dictionary:
	Rng.seed_with(15300)
	var colony := Colony.new()
	for i in 5:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.generation = i % 3
	colony.gnomes[0].set_feeling(Devotion.YOU, "fear", 0.6)
	colony.settlement_knowledge[0] = {"fire": true, "weaving": true}
	var cfg := WorldConfig.new()
	cfg.seed = 777
	cfg.colony_name = "Mossbottom"
	var time := TimeService.new()
	time.advance(40.0)
	return Serializer.save_to_dict(colony, WorldState.new(), [], cfg, time, [])


func test_a_save_becomes_a_metadata_card():
	var envelope := _rich_save()
	_store.save_game("first", envelope, {"kind": "manual", "playtime": "1h02m", "timestamp": "t1"})
	var cards: Array = _store.list_saves()
	assert_eq(cards.size(), 1, "one save, one card")
	var meta: Dictionary = cards[0]["meta"]
	assert_eq(meta["colony_name"], "Mossbottom", "the card names the colony [§6.1]")
	assert_eq(meta["population"], 5, "…its population")
	assert_eq(meta["generation"], 2, "…its current (max) generation")
	assert_eq(meta["seed"], 777, "…and the shareable seed")
	assert_eq(meta["playtime"], "1h02m")
	assert_eq(meta["kind"], "manual")
	assert_eq(meta["techs"], 2, "…the era/tech level [§6.1 card]")
	assert_eq(meta["faith"], "feared", "…and the dominant faith flavor [§6.1 card]")


func test_load_restores_the_exact_envelope():
	var envelope := _rich_save()
	_store.save_game("first", envelope, {"kind": "manual", "timestamp": "t1"})
	var loaded: Dictionary = _store.load_game("first")
	# JSON reads ints back as doubles (the T12.1-documented behavior the
	# serializer already survives) — canonicalize both sides through the
	# same round trip before comparing.
	var canonical: Variant = JSON.parse_string(JSON.stringify(envelope, "", true))
	assert_eq(
		JSON.stringify(loaded, "", true),
		JSON.stringify(canonical, "", true),
		"byte-identical envelope back [§6.1 Load]"
	)
	var restored: Dictionary = Serializer.save_from_dict(loaded)
	assert_eq(restored["colony"].population(), 5, "…and it restores to a living colony")


func test_manual_and_autosaves_sit_in_separate_tabs():
	var envelope := _rich_save()
	_store.save_game("manual_1", envelope, {"kind": "manual", "timestamp": "t1"})
	_store.save_game("auto_1", envelope, {"kind": "auto", "timestamp": "t2"})
	assert_eq(_store.list_saves("manual").size(), 1, "manual tab [§6.1]")
	assert_eq(_store.list_saves("auto").size(), 1, "autosave tab")
	assert_eq(_store.list_saves().size(), 2, "no filter, all saves")


func test_newest_first_delete_and_duplicate():
	var envelope := _rich_save()
	_store.save_game("old", envelope, {"kind": "manual", "timestamp": "2026-01-01T10:00:00"})
	_store.save_game("new", envelope, {"kind": "manual", "timestamp": "2026-01-02T10:00:00"})
	var cards: Array = _store.list_saves()
	assert_eq(cards[0]["slot"], "new", "most recent first")
	_store.duplicate_save("old", "old_copy")
	assert_eq(_store.list_saves().size(), 3, "Duplicate [§6.1 actions]")
	_store.delete_save("old")
	assert_eq(_store.list_saves().size(), 2, "Delete")
	assert_false(_store.has_save("old"))
	assert_true(_store.has_saves(), "the main menu's Continue feed")


func test_export_hands_over_the_raw_share():
	var envelope := _rich_save()
	_store.save_game("first", envelope, {"kind": "manual", "timestamp": "t1"})
	var exported: String = _store.export_save("first")
	assert_string_contains(exported, '"seed"', "the share carries the seed [§6.1 Export]")
	var parsed: Variant = JSON.parse_string(exported)
	assert_not_null(parsed, "…and is valid JSON")


func test_the_menu_renders_cards_and_reports_the_choice():
	var envelope := _rich_save()
	_store.save_game("first", envelope, {"kind": "manual", "timestamp": "t1"})
	_store.save_game("second", envelope, {"kind": "auto", "timestamp": "t2"})
	var menu := LoadMenu.new()
	add_child_autofree(menu)
	menu.build(_store)
	assert_eq(menu.cards.size(), 2, "a card per save")
	assert_string_contains(
		menu.cards["first"].get_node("label").text, "Mossbottom", "the card shows the metadata"
	)
	watch_signals(menu)
	menu.cards["first"].get_node("load").pressed.emit()
	assert_signal_emitted_with_parameters(menu, "load_requested", ["first"])
	menu.show_tab("auto")
	assert_false(menu.cards["first"].visible, "manual card hides on the autosave tab [§6.1]")
	assert_true(menu.cards["second"].visible)
