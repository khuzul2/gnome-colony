class_name GameShell
extends Node
## The game shell [PROGRESS T17.3, DONE.md handover note 3]: the single
## orchestrated scene that binds menu → wizard → run → chronicle into
## one executable flow — pure routing over the tested pieces, no sim
## surface, no gameplay. Screens are the setup-§6 entries verbatim
## (MainMenu already carries them); a run is a GameRun (T17.2); saves
## ride SaveStore, ended runs close into ChronicleStore via
## ChronicleScreen's hold-then-show beat, and the FaintCodex hears
## every witnessed phenomenon (session-lifetime, like every tested
## composition — persistence was never specified; disclosed in
## PROGRESS). Wall-clock (save timestamps, playtime) lives HERE only —
## presentation never feeds it to the sim. Exactly ONE GameRun is ever
## live (the EventBus is global; GameRun documents the constraint).
## Wizard pages beyond the preset cards and the settings screen stay
## logic-first, consistent with how T15.2/T15.4 shipped (their open
## minors note the missing chrome); the shell adds only Quick Start /
## Begin / Back buttons and read-only listings — playability chrome,
## not features. The in-run view itself is T17.4's RunView.

const SCREEN_FOR_ENTRY := {
	"new_game": "wizard",
	"load_game": "load",
	"settings": "settings",
	"codex": "codex",
	"chronicles": "chronicles",
	"credits": "credits",
}
const CREDITS_LINES := [
	"GNOME COLONY",
	"a god game about belief, not power",
	"design & simulation: the gnome-colony build loop",
]

## Injectable for tests — set before adding to the tree.
var save_dir := "user://saves"
var chronicle_dir := "user://chronicles"
var settings_path := "user://settings.cfg"

var settings: GameSettings
var store: SaveStore
var chronicle_store: ChronicleStore
var codex := FaintCodex.new()
var menu: MainMenu
var wizard: NewGameWizard
var wizard_view: WizardView
var settings_view: SettingsView
var load_menu: LoadMenu
var chronicle_screen: ChronicleScreen
var run: GameRun = null
var run_view: RunView = null
var screens := {}
var playtime_seconds := 0.0

var _auto_counter := 0

var _ui: CanvasLayer
var _lists := {}


func _ready() -> void:
	settings = GameSettings.load_from(settings_path)
	store = SaveStore.new(save_dir)
	chronicle_store = ChronicleStore.new(chronicle_dir)
	_build_screens()
	EventBus.phenomenon.connect(_on_phenomenon)
	menu.refresh(store.has_saves())
	show_screen("menu")


func _exit_tree() -> void:
	EventBus.phenomenon.disconnect(_on_phenomenon)
	if run != null:
		run.shutdown()
		run = null


## Wall-clock frame beat: playtime and the world's-end hold. Day
## pacing itself is the RunView's job (T17.4).
func _process(delta: float) -> void:
	if run == null:
		return
	playtime_seconds += delta
	chronicle_screen.update(delta)
	if chronicle_screen.showing:
		_close_into_chronicle()


func show_screen(name_key: String) -> void:
	for key in screens:
		screens[key].visible = key == name_key


func start_run(cfg: WorldConfig) -> void:
	_drop_run()
	run = GameRun.new_game(cfg)
	playtime_seconds = 0.0
	_arm_chronicle_watch()
	show_screen("run")
	_mount_run_view()


func quick_start() -> void:
	start_run(wizard.quick_start())


func begin() -> void:
	start_run(wizard.start())


func save_current(slot: String, kind: String = "manual") -> void:
	if run == null:
		return
	(
		store
		. save_game(
			slot,
			run.save(),
			{
				"kind": kind,
				"timestamp": Time.get_datetime_string_from_system(),
				"playtime": playtime_seconds,
			}
		)
	)
	menu.refresh(store.has_saves())


func close_run_to_menu() -> void:
	_drop_run()
	menu.refresh(store.has_saves())
	show_screen("menu")


func _on_menu_selected(entry: String) -> void:
	match entry:
		"continue":
			_load_newest()
		"quit":
			get_tree().quit()
		"new_game":
			_remint_wizard()
			show_screen("wizard")
		"load_game":
			load_menu.build(store)
			show_screen("load")
		"settings":
			_mount_settings_view()
			show_screen("settings")
		"codex":
			_fill_list("codex", codex.impressions(), "nothing observed yet")
			show_screen("codex")
		"chronicles":
			_fill_chronicles_list()
			show_screen("chronicles")
		"credits":
			show_screen("credits")


func _load_newest() -> void:
	var saves := store.list_saves()
	if saves.is_empty():
		return
	_load_slot(saves[0]["slot"])


func _load_slot(slot: String) -> void:
	_drop_run()
	run = GameRun.resume(store.load_game(slot))
	# Playtime is cumulative across loads [setup §6.1 card fact].
	playtime_seconds = 0.0
	for entry in store.list_saves():
		if entry["slot"] == slot:
			playtime_seconds = float(entry["meta"].get("playtime", 0.0))
			break
	_arm_chronicle_watch()
	show_screen("run")
	_mount_run_view()


func _drop_run() -> void:
	if run_view != null:
		run_view.run = null
		run_view.hud.queue_free()
		run_view.queue_free()
		run_view = null
	if run != null:
		run.shutdown()
		run = null


## The in-run binding (T17.4): the 3D/attention half lives under the
## shell root, the HUD reparents into the run screen so show_screen
## keeps governing visibility.
func _mount_run_view() -> void:
	run_view = RunView.new()
	run_view.run = run
	run_view.settings = settings
	run_view.save_requested.connect(_on_save_requested)
	run_view.menu_requested.connect(_on_menu_requested)
	add_child(run_view)
	run_view.remove_child(run_view.hud)
	screens["run"].add_child(run_view.hud)


## §7.4 autosaves roll over autosave_slots; manual saves name
## themselves after the colony and its day.
func _on_save_requested(kind: String) -> void:
	if run == null:
		return
	if kind == "auto":
		var slots: int = settings.get_value("gameplay", "autosave_slots")
		save_current("auto_%d" % (_auto_counter % maxi(1, slots)), "auto")
		_auto_counter += 1
	else:
		save_current("%s_day%d" % [run.config.colony_name, run.runner.time.day()], "manual")


## Leaving to the menu drops the live run — an exit autosave first, so
## a misclick never costs a world.
func _on_menu_requested() -> void:
	save_current("auto_exit", "auto")
	close_run_to_menu()


## A fresh NewGameWizard per New Game entry [T17.3 reviewer catch]: a
## wizard pins its rolled seed/name into its overrides BY DESIGN (one
## roll per blank field, per wizard — T15.2); reusing one instance
## across games would silently replay the first game's world and
## sliders. Same mint-fresh pattern as the chronicle watcher below.
## The Quick Start / Begin buttons live on the screen box and call
## shell methods, so they always reach the current instance.
func _remint_wizard() -> void:
	var box: Control = screens["wizard"]
	if wizard_view != null:
		box.remove_child(wizard_view)
		wizard_view.queue_free()
	wizard = NewGameWizard.new()
	wizard_view = WizardView.new()
	wizard_view.wizard = wizard
	box.add_child(wizard_view)
	box.move_child(wizard_view, 0)


## Settings chrome [T18.4]: the editable view mounts lazily, wrapping
## the shell's live GameSettings so edits persist immediately.
func _mount_settings_view() -> void:
	if settings_view != null:
		return
	settings_view = SettingsView.new()
	settings_view.settings = settings
	settings_view.settings_path = settings_path
	var box: Control = screens["settings"]
	box.add_child(settings_view)
	box.move_child(settings_view, 0)


## A fresh ChronicleScreen per run: its world_ended arm/hold state has
## no reset API by design (one screen per ended world) — minting a new
## one avoids touching its privates. Deliberately NOT a `screens`
## entry: it is the hold-then-compose watcher, not a UI screen — the
## visible history list is the "chronicles" screen.
func _arm_chronicle_watch() -> void:
	if chronicle_screen != null:
		chronicle_screen.queue_free()
	chronicle_screen = ChronicleScreen.new()
	_ui.add_child(chronicle_screen)
	chronicle_screen.visible = false


func _close_into_chronicle() -> void:
	var record := (
		chronicle_screen
		. compose(
			run.runner.colony,
			run.telemetry.events,
			{
				"colony_name": run.config.colony_name,
				"seed": run.config.seed,
				"days": run.runner.time.day(),
			}
		)
	)
	chronicle_store.keep("%s_%d" % [run.config.colony_name, run.config.seed], record)
	_drop_run()
	menu.refresh(store.has_saves())
	_fill_chronicles_list()
	show_screen("chronicles")


func _on_phenomenon(payload: Dictionary) -> void:
	if run != null:
		codex.observe(payload)


func _build_screens() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	menu = MainMenu.new()
	menu.build()
	menu.selected.connect(_on_menu_selected)
	load_menu = LoadMenu.new()
	load_menu.load_requested.connect(func(slot: String) -> void: _load_slot(slot))
	screens = {
		"menu": menu,
		"wizard": _wizard_screen(),
		"load": _backed(load_menu, "load"),
		"settings": _list_screen("settings"),
		"codex": _list_screen("codex"),
		"chronicles": _list_screen("chronicles"),
		"credits": _credits_screen(),
		"run": Control.new(),
	}
	screens["run"].name = "run"
	for key in screens:
		if screens[key].get_parent() == null:
			_ui.add_child(screens[key])
		screens[key].visible = false
	_arm_chronicle_watch()
	_remint_wizard()


func _wizard_screen() -> Control:
	var box := VBoxContainer.new()
	box.name = "wizard_screen"
	var quick := Button.new()
	quick.name = "quick_start"
	quick.text = "Quick Start — Balanced Saga, random world"
	quick.pressed.connect(quick_start)
	box.add_child(quick)
	var begin_button := Button.new()
	begin_button.name = "begin"
	begin_button.text = "Begin"
	begin_button.pressed.connect(begin)
	box.add_child(begin_button)
	box.add_child(_back_button())
	return box


func _backed(inner: Control, screen_name: String) -> Control:
	var box := VBoxContainer.new()
	box.name = "%s_screen" % screen_name
	box.add_child(inner)
	box.add_child(_back_button())
	return box


func _list_screen(screen_name: String) -> Control:
	var box := VBoxContainer.new()
	box.name = "%s_screen" % screen_name
	var list := VBoxContainer.new()
	list.name = "list"
	box.add_child(list)
	box.add_child(_back_button())
	_lists[screen_name] = list
	return box


func _credits_screen() -> Control:
	var box := VBoxContainer.new()
	box.name = "credits_screen"
	for line in CREDITS_LINES:
		var label := Label.new()
		label.text = line
		box.add_child(label)
	box.add_child(_back_button())
	return box


func _back_button() -> Button:
	var back := Button.new()
	back.name = "back"
	back.text = "Back"
	back.pressed.connect(func() -> void: show_screen("menu"))
	return back


func _fill_list(screen_name: String, lines: Array, empty_line: String) -> void:
	var list: VBoxContainer = _lists[screen_name]
	for child in list.get_children():
		child.queue_free()
	var rows: Array = lines if not lines.is_empty() else [empty_line]
	for line in rows:
		var label := Label.new()
		label.text = str(line)
		list.add_child(label)


func _fill_chronicles_list() -> void:
	var lines := []
	for entry in chronicle_store.list_chronicles():
		var record: Dictionary = entry["record"]
		(
			lines
			. append(
				(
					"%s (seed %d) — %d days, %d generations, %s"
					% [
						record.get("colony_name", entry["slot"]),
						int(record.get("seed", 0)),
						int(record.get("days", 0)),
						int(record.get("generations", 0)),
						record.get("how_it_ended", ""),
					]
				)
			)
		)
	_fill_list("chronicles", lines, "no worlds have ended yet")
