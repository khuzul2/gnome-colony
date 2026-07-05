class_name ChronicleFeed
extends PanelContainer
## R6.4 [leg §L-hud] — the living chronicle: a small scrolling panel of the last
## few diegetic events so the player can FOLLOW the colony's story — settlements
## founded, structures raised, tiers crossed, discoveries, wars, schisms, and the
## acts/omens that land. Newest at the bottom; older lines fade. Births/deaths are
## the life pulse's job (R6.3), so they stay out of this feed to keep the story
## beats legible.
##
## The feed owns its EventBus subscription (connected in _ready, dropped in
## _exit_tree) so when the run is torn down it stops listening — the callables
## target THIS node, so there is no stale-push onto a freed feed. RunView only
## feeds it `place_of` (sid → place id) so events can name their settlement.

const MAX_LINES := 8  ## CHRONICLE_LINES [leg §L-hud]
const FADE_STEP := 0.11  ## each older line dims by this
const FADE_FLOOR := 0.35

## The lines shown, oldest first / newest last — the test-facing view.
var lines: Array[String] = []
## sid → place id, set by RunView so the feed can name settlements.
var place_of: Dictionary = {}

var _rows: VBoxContainer


func _init() -> void:
	name = "chronicle_feed"
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLORS[Palette.NIGHT_LAPIS]
	style.set_content_margin_all(8.0)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Chronicle"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Palette.COLORS[Palette.GOLD])
	box.add_child(title)
	_rows = VBoxContainer.new()
	_rows.name = "rows"
	box.add_child(_rows)


func _ready() -> void:
	for pair in _signals():
		pair[0].connect(pair[1])


func _exit_tree() -> void:
	for pair in _signals():
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


## The (signal, handler) pairs the feed listens on. Named handlers so _exit_tree
## can disconnect them by reference when the run is torn down.
func _signals() -> Array:
	return [
		[EventBus.settlement_founded, _on_founded],
		[EventBus.structure_built, _on_built],
		[EventBus.settlement_tier_changed, _on_tier],
		[EventBus.discovery_made, _on_discovery],
		[EventBus.war_waged, _on_war],
		[EventBus.schism_split, _on_schism],
		[EventBus.phenomenon, _on_phenomenon],
	]


## Append one diegetic line; the oldest scroll off past MAX_LINES.
func push(line: String) -> void:
	lines.append(line)
	while lines.size() > MAX_LINES:
		lines.pop_front()
	_render()


func _render() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	var count := lines.size()
	for i in count:
		var label := Label.new()
		label.text = lines[i]
		# Oldest (top) dimmest, newest (bottom) full — a gentle fade into memory.
		var tint: Color = Palette.COLORS[Palette.BONE_WHITE]
		tint.a = clampf(1.0 - FADE_STEP * (count - 1 - i), FADE_FLOOR, 1.0)
		label.add_theme_color_override("font_color", tint)
		label.add_theme_font_size_override("font_size", 14)
		_rows.add_child(label)


func _pretty(place_id: String) -> String:
	return place_id.capitalize()


func _place_name(sid: int) -> String:
	return _pretty(place_of.get(sid, "settlement_%d" % sid))


func _on_founded(p: Dictionary) -> void:
	push("a colony rises at %s" % _pretty(p.get("place", "the frontier")))


func _on_built(p: Dictionary) -> void:
	push("a %s rose at %s" % [p.get("building", "structure"), _place_name(p.get("sid", -1))])


func _on_tier(p: Dictionary) -> void:
	push(
		(
			"%s grew to a %s"
			% [
				_place_name(p.get("sid", -1)),
				SettlementRoster.TIER_NAMES.get(p.get("to", -1), "settlement")
			]
		)
	)


func _on_discovery(p: Dictionary) -> void:
	push("%s was discovered" % p.get("id", "a craft"))


func _on_war(p: Dictionary) -> void:
	push(
		"war — %s falls to %s" % [_place_name(p.get("loser", -1)), _place_name(p.get("winner", -1))]
	)


func _on_schism(p: Dictionary) -> void:
	push("a schism splinters %s" % _place_name(p.get("from", -1)))


func _on_phenomenon(p: Dictionary) -> void:
	push(
		"%s at %s" % [str(p.get("type", "an omen")).replace("_", " "), _pretty(p.get("place", ""))]
	)
