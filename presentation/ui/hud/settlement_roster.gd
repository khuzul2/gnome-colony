class_name SettlementRoster
extends PanelContainer
## R6.2 [leg §L-hud] — the settlement roster: one row per settlement
## (name · tier · pop, the sacred monogram on the seat), so the player can see
## how many colonies exist and where. Reads the sim fold READ-ONLY; clicking a row
## asks RunView to focus the camera there. Ravenna skin: night-lapis ground, gold
## heading, bone-white body. Presentation-only.

signal focus_settlement(sid: int)

const MAX_ROWS := 8  ## ROSTER_ROWS [leg §L-hud]
const SEAT_MARK := "☩"  ## the sacred monogram marks the main settlement (seat)
const TIER_NAMES := {
	Enums.SettlementTier.HAMLET: "hamlet",
	Enums.SettlementTier.VILLAGE: "village",
	Enums.SettlementTier.TOWN: "town",
	Enums.SettlementTier.CITY: "city",
}

## Row models for the rows shown, in display order — the test-facing view of the
## panel: [{sid, name, tier, pop, seat}]. Never more than MAX_ROWS.
var entries: Array = []
## How many settlements were hidden beyond MAX_ROWS (drives the "+N more" line).
var overflow := 0

var _rows: VBoxContainer


func _init() -> void:
	name = "settlement_roster"
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLORS[Palette.NIGHT_LAPIS]
	style.set_content_margin_all(8.0)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "%s Settlements" % SEAT_MARK
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Palette.COLORS[Palette.GOLD])
	box.add_child(title)
	_rows = VBoxContainer.new()
	_rows.name = "rows"
	box.add_child(_rows)


## Rebuild the rows from pre-built models (RunView assembles them from the home
## colony + the frontier fold, so the seat leads and nothing is omitted). Each
## model is {sid, name, tier, pop, seat}; the panel just renders — a disagreeing
## roster lies, so the caller reads sim state verbatim.
func refresh(rows: Array) -> void:
	entries.clear()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	overflow = maxi(0, rows.size() - MAX_ROWS)
	for i in mini(rows.size(), MAX_ROWS):
		var model: Dictionary = rows[i]
		entries.append(model)
		_rows.add_child(_make_row(model))
	if overflow > 0:
		var more := Label.new()
		more.name = "more"
		more.text = "+%d more" % overflow
		more.add_theme_color_override("font_color", Palette.COLORS[Palette.BONE_WHITE])
		_rows.add_child(more)


func _make_row(model: Dictionary) -> Button:
	var row := Button.new()
	# The seat leads with the monogram; plain rows start at the name (no fragile
	# space-padding — proportional fonts wouldn't align it anyway).
	var mark: String = "%s " % SEAT_MARK if model["seat"] else ""
	row.text = "%s%s · %s · %d" % [mark, model["name"], model["tier"], model["pop"]]
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.flat = true
	row.add_theme_color_override(
		"font_color", Palette.COLORS[Palette.GOLD_LIT if model["seat"] else Palette.BONE_WHITE]
	)
	var sid: int = model["sid"]
	row.pressed.connect(func() -> void: focus_settlement.emit(sid))
	return row
