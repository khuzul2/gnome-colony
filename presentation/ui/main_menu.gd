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
	# R8.1 [leg §L-ui]: a night-lapis ground with a centred, Ravenna-skinned column
	# (title + monogram + meander rule + the entries) — no more raw buttons jammed
	# at the origin.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ground := RavennaUI.ground()
	add_child(ground)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.add_child(center)
	var column := VBoxContainer.new()
	column.name = "column"
	column.add_theme_constant_override("separation", 6)
	center.add_child(column)
	var title := RavennaUI.heading("%s Gnome Colony" % RavennaUI.SEAT_MARK, RavennaUI.TITLE_FONT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(RavennaUI.meander_rule())
	for entry in ENTRIES:
		var button := Button.new()
		button.name = entry
		button.text = LABELS[entry]
		RavennaUI.skin_button(button)
		button.pressed.connect(func() -> void: selected.emit(entry))
		column.add_child(button)
		buttons[entry] = button


## The save store tells the menu whether anything is resumable.
func refresh(has_save: bool) -> void:
	buttons["continue"].visible = has_save


func entry_names() -> Array:
	return ENTRIES.duplicate()
