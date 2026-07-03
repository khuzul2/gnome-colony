extends GutTest

## T15.1 — main menu [setup §6]: the eight top-level entries in spec
## order, each a button that reports its choice; Continue resumes the
## most recent save and is HIDDEN when none exists.

const ENTRIES := [
	"continue", "new_game", "load_game", "settings", "codex", "chronicles", "credits", "quit"
]


func _menu(has_save := false) -> MainMenu:
	var menu := MainMenu.new()
	add_child_autofree(menu)
	menu.build()
	menu.refresh(has_save)
	return menu


func test_the_spec_entries_in_spec_order():
	var menu := _menu()
	assert_eq(menu.entry_names(), ENTRIES, "the §6 list, verbatim and ordered")
	for entry in ENTRIES:
		assert_true(menu.buttons.has(entry), "a button per entry: %s" % entry)


func test_continue_hides_without_a_save():
	var menu := _menu(false)
	assert_false(menu.buttons["continue"].visible, "nothing to resume — Continue hidden [§6]")
	assert_true(menu.buttons["new_game"].visible, "…the rest remain")
	menu.refresh(true)
	assert_true(menu.buttons["continue"].visible, "a save appears, so does Continue")


func test_a_press_reports_the_choice():
	var menu := _menu(true)
	watch_signals(menu)
	menu.buttons["chronicles"].pressed.emit()
	assert_signal_emitted_with_parameters(menu, "selected", ["chronicles"])
