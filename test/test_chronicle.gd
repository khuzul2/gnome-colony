extends GutTest

## T15.5 — Chronicle & world's end [design §1.9 locked, setup §6]:
## when the last gnome dies the run CLOSES — world_ended fires exactly
## once, the camera holds on the empty world for a breath (presentation
## seconds), then the Chronicle: an auto-generated history (generations,
## settlements, faiths and their prophets, wars, discoveries, how it
## ended), exportable and kept for the main menu's Chronicles list. No
## new band arrives; what is gone is gone.

const DIR := "user://test_chronicles_t155"


func after_all():
	ChronicleStore.new(DIR).wipe()


func _fallen_colony() -> Colony:
	var colony := Colony.new()
	for i in 3:
		var g := colony.spawn()
		g.age = 60.0
		g.stage = Enums.LifeStage.DEAD
		g.generation = i + 4
	var creed := BeliefObject.make("theology", Devotion.YOU, "faith", 0.5, [0])
	creed["flavor"] = "wrathful"
	colony.beliefs.append(creed)
	colony.gnomes[1].prophet = {"message": {"flavor": "mercy"}, "charisma": 0.8}
	return colony


func _telemetry() -> Array:
	return [
		{"type": "war", "day": 300, "a": 0, "b": 1},
		{"type": "discovery", "day": 120, "id": "iron"},
		{"type": "discovery", "day": 340, "id": "writing"},
		{"type": "settlement_founded", "day": 20, "sid": 1},
	]


func test_extinction_emits_world_ended_exactly_once():
	var colony := _fallen_colony()
	watch_signals(EventBus)
	assert_true(Civilization.check_world_end(colony, []), "the last gnome is gone [§14]")
	assert_signal_emit_count(EventBus, "world_ended", 1)
	Civilization.check_world_end(colony, [])
	assert_signal_emit_count(EventBus, "world_ended", 1, "…and the latch holds: once")


func test_the_camera_holds_a_beat_before_the_chronicle():
	var screen := ChronicleScreen.new()
	add_child_autofree(screen)
	EventBus.world_ended.emit({})
	assert_false(screen.showing, "hearths cooling — not yet [§1.9]")
	screen.update(ChronicleScreen.HOLD_SECONDS)
	assert_true(screen.showing, "…then the Chronicle")


func test_the_chronicle_holds_the_required_history():
	var screen := ChronicleScreen.new()
	add_child_autofree(screen)
	var record: Dictionary = screen.compose(
		_fallen_colony(), _telemetry(), {"colony_name": "Mossbottom", "seed": 777, "days": 400}
	)
	assert_eq(record["generations"], 6, "generations reached [§1.9]")
	assert_eq(record["settlements"], 1, "settlements founded")
	assert_eq(record["faiths"], ["wrathful"], "faiths that named you")
	assert_eq(record["prophets"], 1, "…and their prophets")
	assert_eq(record["wars"], 1, "wars fought")
	assert_eq(record["discoveries"], ["iron", "writing"], "what they learned")
	assert_eq(record["how_it_ended"], "total extinction", "and how it ended")
	assert_eq(record["colony_name"], "Mossbottom")
	assert_eq(record["seed"], 777)
	assert_eq(record["days"], 400)


func test_chronicles_keep_and_list_for_the_main_menu():
	var screen := ChronicleScreen.new()
	add_child_autofree(screen)
	var store: ChronicleStore = screen.store(DIR)
	store.wipe()
	var record: Dictionary = screen.compose(
		_fallen_colony(), _telemetry(), {"colony_name": "Mossbottom", "seed": 777, "days": 400}
	)
	store.keep("mossbottom_777", record)
	var listed: Array = store.list_chronicles()
	assert_eq(listed.size(), 1, "the menu's Chronicles list [setup §6]")
	assert_eq(listed[0]["record"]["colony_name"], "Mossbottom")
	var exported: String = store.export_chronicle("mossbottom_777")
	assert_string_contains(exported, "wrathful", "exportable — the history travels [§1.9]")
