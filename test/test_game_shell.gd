extends GutTest

## T17.3 — GameShell [PROGRESS Phase 17]: the single orchestrated scene
## — setup-§6 menu entries route into real screens, the wizard founds a
## GameRun, saves restore through the Load flow, Continue wakes the
## newest save, a witnessed act reaches the codex, and an ended world
## closes into the ChronicleStore. Routing over tested pieces only.

const STORE_DIR := "user://test_shell_saves"
const CHRON_DIR := "user://test_shell_chronicles"
const SETTINGS_PATH := "user://test_shell_settings.cfg"
const CODEX_PATH := "user://test_shell_codex.json"


func before_each() -> void:
	SaveStore.new(STORE_DIR).wipe()
	ChronicleStore.new(CHRON_DIR).wipe()
	DirAccess.remove_absolute(CODEX_PATH)


func _shell() -> GameShell:
	var shell := GameShell.new()
	shell.save_dir = STORE_DIR
	shell.chronicle_dir = CHRON_DIR
	shell.settings_path = SETTINGS_PATH
	shell.codex_path = CODEX_PATH
	add_child_autofree(shell)
	return shell


func _cfg(seed_value: int) -> WorldConfig:
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.colony_name = "Shelltest"
	cfg.normalize()
	return cfg


func test_the_main_scene_is_the_shell():
	var scene: PackedScene = load("res://presentation/main.tscn")
	var root: Node = scene.instantiate()
	autofree(root)
	assert_true(root is GameShell, "main.tscn boots the game, not an empty node")


func test_boots_to_the_menu_with_continue_hidden():
	var shell := _shell()
	assert_true(shell.screens["menu"].visible, "the menu greets the player")
	assert_false(shell.menu.buttons["continue"].visible, "no saves yet [setup §6]")
	assert_null(shell.run)


func test_every_menu_entry_reaches_its_screen():
	var shell := _shell()
	for entry in ["new_game", "load_game", "settings", "codex", "chronicles", "credits"]:
		shell.menu.selected.emit(entry)
		var screen: String = GameShell.SCREEN_FOR_ENTRY[entry]
		assert_true(shell.screens[screen].visible, "%s shows %s" % [entry, screen])
	shell.menu.selected.emit("new_game")
	shell.screens["wizard"].get_node("back").pressed.emit()
	assert_true(shell.screens["menu"].visible, "Back returns to the menu")


func test_quick_start_founds_a_living_run():
	Rng.seed_with(17300)
	var shell := _shell()
	shell.menu.selected.emit("new_game")
	shell.screens["wizard"].get_node("quick_start").pressed.emit()
	assert_not_null(shell.run, "Quick Start launches immediately [setup §2]")
	assert_eq(shell.run.runner.colony.population(), 4, "the default band")
	assert_true(shell.screens["run"].visible)


func test_each_new_game_begins_a_fresh_world():
	# [T17.3 reviewer catch]: a wizard pins its rolled seed by design —
	# the shell must mint a fresh one per New Game entry, or every
	# later Begin replays the first game's world.
	Rng.seed_with(17307)
	var shell := _shell()
	shell.menu.selected.emit("new_game")
	shell.screens["wizard"].get_node("begin").pressed.emit()
	var first_seed: int = shell.run.config.seed
	var first_name: String = shell.run.config.colony_name
	shell.close_run_to_menu()
	shell.menu.selected.emit("new_game")
	shell.screens["wizard"].get_node("begin").pressed.emit()
	assert_ne(shell.run.config.seed, first_seed, "a new game rolls a new world")
	assert_ne(shell.run.config.colony_name, first_name, "…and a new name (blank fields re-roll)")


func test_save_then_continue_restores_the_exact_day():
	Rng.seed_with(17301)
	var shell := _shell()
	shell.start_run(_cfg(17301))
	for day in 10:
		shell.run.advance_day()
	var pop := shell.run.runner.colony.population()
	shell.save_current("holdfast")
	shell.close_run_to_menu()
	assert_null(shell.run)
	assert_true(shell.menu.buttons["continue"].visible, "a save wakes Continue")
	shell.menu.selected.emit("continue")
	assert_not_null(shell.run)
	assert_eq(shell.run.runner.time.day(), 10, "the run resumes where it stood")
	assert_eq(shell.run.runner.colony.population(), pop)


func test_load_menu_restores_a_chosen_slot():
	Rng.seed_with(17302)
	var shell := _shell()
	shell.start_run(_cfg(17302))
	for day in 5:
		shell.run.advance_day()
	shell.save_current("early")
	shell.close_run_to_menu()
	shell.menu.selected.emit("load_game")
	assert_true(shell.screens["load"].visible)
	shell.load_menu.load_requested.emit("early")
	assert_not_null(shell.run)
	assert_eq(shell.run.runner.time.day(), 5)
	assert_true(shell.screens["run"].visible)


func test_a_witnessed_act_reaches_the_codex():
	Rng.seed_with(17303)
	var shell := _shell()
	shell.start_run(_cfg(17303))
	assert_eq(shell.codex.impressions(), [], "nothing observed yet [design §3.8]")
	shell.run.cast("still_air", shell.run.home)
	assert_gt(shell.codex.impressions().size(), 0, "the shell files what the player saw")


func test_extinction_closes_the_run_into_a_chronicle():
	Rng.seed_with(17304)
	var shell := _shell()
	shell.start_run(_cfg(17304))
	for g in shell.run.runner.colony.living():
		g.stage = Enums.LifeStage.DEAD
	shell.run.advance_day()
	shell._process(ChronicleScreen.HOLD_SECONDS + 0.1)
	assert_null(shell.run, "the ended run closed — no re-founding [design §1.9]")
	var kept := shell.chronicle_store.list_chronicles()
	assert_eq(kept.size(), 1, "the history keeps")
	assert_eq(kept[0]["record"]["how_it_ended"], "total extinction")
	assert_eq(kept[0]["record"]["colony_name"], "Shelltest")
	assert_true(shell.screens["chronicles"].visible, "…and is shown")


func test_the_run_view_mounts_with_the_run():
	Rng.seed_with(17308)
	var shell := _shell()
	shell.start_run(_cfg(17308))
	assert_not_null(shell.run_view, "starting a run raises its view [T17.4]")
	assert_eq(shell.run_view.run, shell.run)
	assert_eq(
		shell.run_view.hud.get_parent(),
		shell.screens["run"],
		"the HUD lives in the run screen so show_screen governs it"
	)
	assert_eq(shell.run_view.puppet_count(), 4, "the band is on stage")
	shell.close_run_to_menu()
	assert_null(shell.run_view, "leaving the run drops its view")


func test_manual_save_button_writes_a_named_slot():
	Rng.seed_with(17309)
	var shell := _shell()
	shell.start_run(_cfg(17309))
	for day in 3:
		shell.run.advance_day()
	shell.run_view.hud.get_node("controls/save").pressed.emit()
	var saves := shell.store.list_saves("manual")
	assert_eq(saves.size(), 1, "the Save button writes one manual slot")
	assert_eq(saves[0]["slot"], "Shelltest_day3", "…named after the colony and its day")


func test_autosaves_roll_over_their_slots():
	Rng.seed_with(17310)
	var shell := _shell()
	shell.start_run(_cfg(17310))
	shell.run.advance_day()
	for i in 4:
		shell.run_view.save_requested.emit("auto")
	assert_eq(
		shell.store.list_saves("auto").size(),
		shell.settings.get_value("gameplay", "autosave_slots"),
		"§7.4: rolling autosaves never exceed the slot count"
	)


func test_menu_button_exit_autosaves_and_returns():
	Rng.seed_with(17311)
	var shell := _shell()
	shell.start_run(_cfg(17311))
	shell.run.advance_day()
	shell.run_view.hud.get_node("controls/menu").pressed.emit()
	assert_null(shell.run, "back at the menu, no live run")
	assert_true(shell.screens["menu"].visible)
	var kinds := []
	for entry in shell.store.list_saves("auto"):
		kinds.append(entry["slot"])
	assert_has(kinds, "auto_exit", "a misclick never costs a world")


func test_a_new_run_after_an_ended_world_stays_open():
	Rng.seed_with(17305)
	var shell := _shell()
	shell.start_run(_cfg(17305))
	for g in shell.run.runner.colony.living():
		g.stage = Enums.LifeStage.DEAD
	shell.run.advance_day()
	shell._process(ChronicleScreen.HOLD_SECONDS + 0.1)
	assert_null(shell.run)
	shell.start_run(_cfg(17306))
	shell._process(ChronicleScreen.HOLD_SECONDS + 0.1)
	assert_not_null(shell.run, "a fresh world is not haunted by the last one's end")
	assert_eq(shell.run.runner.colony.population(), 4)
