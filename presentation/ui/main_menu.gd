class_name MainMenu
extends Control
## Main menu [plan T15.1, setup §6]: the eight top-level entries in
## spec order. Continue resumes the most recent save and hides when no
## save exists — refresh(has_save) is fed by the save store (T15.3
## owns discovery; the menu never touches the filesystem itself).
## Pure chrome: one `selected` signal, no game state.

signal selected(entry: String)

## §6's list, verbatim and ordered.
const ENTRIES := [
	"continue", "new_game", "load_game", "settings", "codex", "chronicles", "credits", "quit"
]
const LABELS := {
	"continue": "Continue",
	"new_game": "New Game",
	"load_game": "Load Game",
	"settings": "Settings",
	"codex": "Codex",
	"chronicles": "Chronicles",
	"credits": "Credits",
	"quit": "Quit",
}

var buttons := {}


func build() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	for entry in ENTRIES:
		var button := Button.new()
		button.name = entry
		button.text = LABELS[entry]
		button.pressed.connect(func() -> void: selected.emit(entry))
		column.add_child(button)
		buttons[entry] = button


## The save store tells the menu whether anything is resumable.
func refresh(has_save: bool) -> void:
	buttons["continue"].visible = has_save


func entry_names() -> Array:
	return ENTRIES.duplicate()
