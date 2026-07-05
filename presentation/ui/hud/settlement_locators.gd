class_name SettlementLocators
extends Node3D
## R6.3 [leg §L-hud] — floating name-plates above each colony's basin (home +
## frontier) so settlements are findable on the map. Billboarded and depth-test-off
## so they read over the relief; alpha fades with distance from the focus so distant
## plates don't clutter. RunView feeds the roster models + place maps each refresh.
## Presentation-only. (Extracted from RunView to keep that file under the line cap.)

const LOCATOR_HEIGHT := 4.0
const LOCATOR_PIXEL_SIZE := 0.05
const LOCATOR_FADE_NEAR := 6.0
const LOCATOR_FADE_FAR := 30.0
const LOCATOR_FADE_FLOOR := 0.15
const TIER_GLYPH := {"hamlet": "·", "village": "◦", "town": "◆", "city": "☩"}

var _locators := {}  ## sid → Label3D


## Rebuild/reposition the plates from the roster models. rows: [{sid, name, tier,
## seat}]; place_of: sid → place id; positions: place → world Vector3; focus: the
## camera aim (for the distance fade); home: the fallback place.
func refresh(
	rows: Array, place_of: Dictionary, positions: Dictionary, focus: Vector3, home: String
) -> void:
	var wanted := {}
	for model in rows:
		wanted[model["sid"]] = model
	for sid in _locators.keys():
		if not wanted.has(sid):
			_locators[sid].queue_free()
			_locators.erase(sid)
	for sid in wanted:
		var model: Dictionary = wanted[sid]
		var place: String = place_of.get(sid, home)
		if not positions.has(place):
			continue
		var label: Label3D = _locators.get(sid)
		if label == null:
			label = Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.pixel_size = LOCATOR_PIXEL_SIZE
			label.outline_size = 8
			label.outline_modulate = Palette.COLORS[Palette.NIGHT_LAPIS]
			add_child(label)
			_locators[sid] = label
		var glyph: String = TIER_GLYPH.get(model["tier"], "·")
		label.text = "%s %s" % [glyph, model["name"]]
		var pos: Vector3 = positions[place] + Vector3(0.0, LOCATOR_HEIGHT, 0.0)
		label.position = pos
		var tint: Color = Palette.COLORS[Palette.GOLD_LIT if model["seat"] else Palette.GOLD]
		var d := focus.distance_to(pos)
		tint.a = clampf(
			1.0 - (d - LOCATOR_FADE_NEAR) / (LOCATOR_FADE_FAR - LOCATOR_FADE_NEAR),
			LOCATOR_FADE_FLOOR,
			1.0
		)
		label.modulate = tint


func count() -> int:
	return _locators.size()


func has_locator(sid: int) -> bool:
	return _locators.has(sid)


func locator(sid: int) -> Label3D:
	return _locators.get(sid)
