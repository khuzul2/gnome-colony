extends GutTest

## Phase-Exit 15 [plan]: the wizard emits a correct WorldConfig; Load
## lists saves; Settings persist and never alter the sim. One flow:
## menu → wizard → a lived fortnight → save → the menu's Continue
## wakes, the load list shows the truth, and the same days replay
## byte-identically under different machine settings.

const SAVE_DIR := "user://test_saves_p15exit"
const CFG_PATH := "user://test_settings_p15exit.cfg"


func after_all():
	SaveStore.new(SAVE_DIR).wipe()
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func _run_fortnight(cfg: WorldConfig) -> Dictionary:
	Rng.seed_with(cfg.seed)
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	for day in 14:
		Lod.assign(runner.colony, [], cfg.quicken_budget)
		runner.tick()
	return Serializer.save_to_dict(runner.colony, WorldState.new(), [], cfg, runner.time, [])


func test_the_front_end_holds_together():
	# The main menu with nothing to resume…
	var store := SaveStore.new(SAVE_DIR)
	store.wipe()
	var menu := MainMenu.new()
	add_child_autofree(menu)
	menu.build()
	menu.refresh(store.has_saves())
	assert_false(menu.buttons["continue"].visible, "an empty shelf hides Continue [§6]")
	# …a wizard emits a correct config…
	Rng.seed_with(15500)
	var wizard := NewGameWizard.new()
	add_child_autofree(wizard)
	wizard.build()
	wizard.set_preset("harsh_frontier")
	wizard.set_founding("colony_name", "Grimhollow")
	wizard.set_world("seed", 31337)
	var cfg := wizard.start()
	assert_eq(cfg.mortality, "brutal", "the wizard's config is the §1 bundle")
	assert_eq(cfg.seed, 31337, "…with the typed seed")
	var resolved := Tuning.resolve(cfg)
	assert_true(resolved.has("mortality"), "…and Tuning.resolve consumes it whole [T12.3]")
	# …a fortnight is lived and saved…
	var envelope := _run_fortnight(cfg)
	store.save_game("grimhollow", envelope, {"kind": "manual", "timestamp": "t1"})
	menu.refresh(store.has_saves())
	assert_true(menu.buttons["continue"].visible, "a save wakes Continue [exit: Load lists]")
	var cards: Array = store.list_saves()
	assert_eq(cards[0]["meta"]["colony_name"], "Grimhollow", "the list tells the truth")
	assert_eq(cards[0]["meta"]["day"], 14)
	# …and settings persist without ever touching the world.
	var settings := GameSettings.new()
	settings.set_value("graphics", "render_crowd_density", 3)
	settings.save(CFG_PATH)
	assert_eq(
		GameSettings.load_from(CFG_PATH).get_value("graphics", "render_crowd_density"),
		3,
		"settings persist [exit]"
	)
	var replay := _run_fortnight(cfg)
	assert_eq(
		JSON.stringify(replay, "", true).md5_text(),
		JSON.stringify(envelope, "", true).md5_text(),
		"the same fortnight, machine settings changed between runs — one world [exit: never alter sim]"
	)
	# The loaded save restores to the same living colony.
	var restored: Dictionary = Serializer.save_from_dict(store.load_game("grimhollow"))
	assert_eq(
		restored["colony"].population(),
		envelope["colony"]["gnomes"].size(),
		"…and Load brings them all back"
	)
