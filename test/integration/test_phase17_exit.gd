extends GutTest

## Phase-Exit 17 [PROGRESS Phase 17]: the game is PLAYABLE, end to end,
## through the real shell — boot → menu → Quick Start → a season lived
## at speed with the autosave cadence firing → an armed act painted and
## witnessed → save → menu → Continue → the same world wakes → total
## extinction closes into a kept Chronicle. And the CLAUDE.md
## reproducibility contract holds through the shell: two identically
## scripted shell runs (same seed, same scripted frames, same act, same
## gaze) produce byte-identical save envelopes. The manual "does it
## FEEL right" half belongs to the human — every fun gate was waived,
## and DONE.md's handover keeps that door open.

const STORE_DIR := "user://test_exit17_saves"
const CHRON_DIR := "user://test_exit17_chronicles"
const SETTINGS_PATH := "user://test_exit17_settings.cfg"


func before_each() -> void:
	SaveStore.new(STORE_DIR).wipe()
	ChronicleStore.new(CHRON_DIR).wipe()


func _shell() -> GameShell:
	var shell := GameShell.new()
	shell.save_dir = STORE_DIR
	shell.chronicle_dir = CHRON_DIR
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	return shell


func test_the_whole_game_flows_from_boot_to_chronicle():
	# 1 · main.tscn IS the game: instantiated, entered, at the menu
	# (test dirs injected before _ready so the boot stays isolated).
	var scene: PackedScene = load("res://presentation/main.tscn")
	var booted: Node = scene.instantiate()
	assert_true(booted is GameShell, "the project boots the shell")
	booted.save_dir = STORE_DIR
	booted.chronicle_dir = CHRON_DIR
	booted.settings_path = SETTINGS_PATH
	add_child_autofree(booted)
	assert_true(booted.screens["menu"].visible, "…and it opens on the menu")
	# 2 · the menu greets; New Game → Quick Start founds a world
	Rng.seed_with(17999)
	var shell := _shell()
	assert_true(shell.screens["menu"].visible)
	shell.menu.selected.emit("new_game")
	shell.screens["wizard"].get_node("quick_start").pressed.emit()
	assert_eq(shell.run.runner.colony.population(), 4, "the band steps out [setup §2]")
	var colony_name: String = shell.run.config.colony_name
	# 3 · a season lived through the real pacing loop at 30 d/s
	shell.run_view.set_speed(30.0)
	shell.run_view._process(1.0)
	assert_gte(shell.run.runner.time.day(), TimeService.DAYS_PER_SEASON, "a season passed")
	assert_gt(shell.store.list_saves("auto").size(), 0, "§7.4 cadence autosaved the turn")
	# 4 · the god acts: arm → paint → witnessed consequences
	shell.run_view.set_speed(0.0)
	assert_true(shell.run_view.influence_panel.arm("still_air"))
	shell.run_view.select_place(shell.run.home)
	assert_gt(Devotion.total(shell.run.runner.colony), 0.0, "the act was witnessed")
	assert_gt(shell.run_view.aftermath.timeline.size(), 0, "the aftermath page tells it")
	assert_gt(shell.codex.impressions().size(), 0, "the codex remembers, faintly")
	# 5 · save, leave, Continue — the same world wakes
	var day: int = shell.run.runner.time.day()
	var pop: int = shell.run.runner.colony.population()
	# Controls now live in the bottom action bar [user request 2026-07-06]; find them
	# by name (layout-independent) — the behaviour (buttons emit save/menu) is unchanged.
	shell.run_view.hud.find_child("save", true, false).pressed.emit()
	shell.run_view.hud.find_child("menu", true, false).pressed.emit()
	assert_true(shell.screens["menu"].visible)
	assert_null(shell.run)
	shell.menu.selected.emit("continue")
	assert_eq(shell.run.runner.time.day(), day, "Continue wakes the same day")
	assert_eq(shell.run.runner.colony.population(), pop)
	# 6 · the world ends; the history keeps
	for g in shell.run.runner.colony.living():
		g.stage = Enums.LifeStage.DEAD
	shell.run.advance_day()
	shell._process(ChronicleScreen.HOLD_SECONDS + 0.1)
	assert_null(shell.run, "no re-founding [design §1.9]")
	var kept := shell.chronicle_store.list_chronicles()
	assert_eq(kept.size(), 1, "one world, one chronicle")
	assert_eq(kept[0]["record"]["colony_name"], colony_name)
	assert_eq(kept[0]["record"]["how_it_ended"], "total extinction")
	assert_true(shell.screens["chronicles"].visible, "the run closes into history")


func test_the_shell_reproduces_a_scripted_run_exactly():
	var envelopes := []
	for attempt in 2:
		Rng.seed_with(18000)
		var shell := _shell()
		shell.menu.selected.emit("new_game")
		shell.screens["wizard"].get_node("quick_start").pressed.emit()
		var view := shell.run_view
		view.set_speed(1.0)
		for frame in 10:
			view._process(1.0)
		view.influence_panel.arm("still_air")
		view.select_place(shell.run.home)
		for frame in 5:
			view._process(1.0)
		envelopes.append(JSON.stringify(shell.run.save()))
		shell.close_run_to_menu()
	assert_eq(
		envelopes[0],
		envelopes[1],
		"seed + config + scripted acts + scripted gaze reproduce the run [CLAUDE.md]"
	)
