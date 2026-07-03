class_name LoadMenu
extends Control
## Load Game menu [plan T15.3, setup §6.1]: a card per save showing
## the store's metadata, a Load button per card reporting the chosen
## slot, and Manual/Autosave tabs that filter the same cards. Pure
## chrome over SaveStore — the menu restores nothing itself; the shell
## that hears `load_requested` calls Serializer.save_from_dict.

signal load_requested(slot: String)

var cards := {}

var _column: VBoxContainer


func build(store: SaveStore) -> void:
	_column = VBoxContainer.new()
	add_child(_column)
	for entry in store.list_saves():
		var slot: String = entry["slot"]
		var meta: Dictionary = entry["meta"]
		var card := HBoxContainer.new()
		card.name = slot
		var label := Label.new()
		label.name = "label"
		label.text = (
			"%s — gen %d · pop %d · day %d · seed %d · %s"
			% [
				meta.get("colony_name", "?"),
				meta.get("generation", 0),
				meta.get("population", 0),
				meta.get("day", 0),
				meta.get("seed", 0),
				meta.get("playtime", ""),
			]
		)
		card.add_child(label)
		var load_button := Button.new()
		load_button.name = "load"
		load_button.text = "Load"
		load_button.pressed.connect(func() -> void: load_requested.emit(slot))
		card.add_child(load_button)
		card.set_meta("kind", meta.get("kind", "manual"))
		_column.add_child(card)
		cards[slot] = card


## §6.1's tabs: "manual" / "auto" filter, "" shows everything.
func show_tab(kind: String) -> void:
	for slot in cards:
		cards[slot].visible = kind == "" or cards[slot].get_meta("kind") == kind
