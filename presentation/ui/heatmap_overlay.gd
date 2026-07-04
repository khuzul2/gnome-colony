class_name HeatmapOverlay
extends Control
## Heatmap overlay [plan T21.4, design §2.7]: pure chrome over the
## Heatmap readers — one Label row per place, both grains merged into
## a single readout. Where a place has BOTH a quickened reading
## (Heatmap.from_gnomes) and a statistical one (from_settlements), the
## quickened grain wins: living gnomes are the finer instrument for a
## watched place (a presentation choice, not a sim number). Values
## print as fixed-point presentation strings; toggle() flips
## visibility; refresh() re-reads the same substrate and rebuilds.
## Standalone widget: the shell adds it to the HUD and calls build()
## with the run's colony/settlements/place_of, then refresh() on its
## own cadence.

const ROW_FORMAT := "%s — mood %.2f · faith %.2f · awe %.2f · fear %.2f"

## place → its Label row, rebuilt on every refresh.
var rows := {}

var _colony: Colony
var _settlements := {}
var _place_of := {}
var _column: VBoxContainer


## Point the overlay at the substrate and render it. The references
## are kept so refresh() can re-read them later.
func build(colony: Colony, settlements: Dictionary, place_of: Dictionary) -> void:
	_colony = colony
	_settlements = settlements
	_place_of = place_of
	refresh()


## The HUD's overlay switch: flip visibility, nothing else.
func toggle() -> void:
	visible = not visible


## Re-read the substrate and rebuild every row (places sort so the
## readout is stable run to run).
func refresh() -> void:
	if _column != null:
		_column.free()
	_column = VBoxContainer.new()
	_column.name = "places"
	add_child(_column)
	rows.clear()
	if _colony == null:
		return
	var merged := Heatmap.from_settlements(_settlements, _place_of)
	merged.merge(Heatmap.from_gnomes(_colony), true)
	var places := merged.keys()
	places.sort()
	for place in places:
		var r: Dictionary = merged[place]
		var row := Label.new()
		row.name = place
		row.text = ROW_FORMAT % [place, r["mood"], r["faith"], r["awe"], r["fear"]]
		_column.add_child(row)
		rows[place] = row
