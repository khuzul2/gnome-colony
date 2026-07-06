class_name HistoryPanel
extends PanelContainer
## The Historical Record [user request 2026-07-06, leg §L-hud]: a translucent
## side panel, anchored to the right of the run HUD, that shows the FULL story of
## the colony — every founding, structure, tier crossing, discovery, war, schism
## and landed omen — newest at the bottom. It wraps a ChronicleFeed inside a
## ScrollContainer so a long history scrolls with the wheel or the bar, and a
## header toggle COLLAPSES it to a thin gutter strip when the player wants the
## world unobscured. Presentation-only: the feed owns its own EventBus wiring, the
## panel is pure chrome (skin + scroll + collapse). Ravenna skin: a night-lapis
## pane seen through gauze (HUD_ALPHA), gold heading, a thin gold edge.

signal collapsed_changed(collapsed: bool)

## The full-history cap the side panel keeps (far above the compact feed's 8) so
## the record reads as the whole story, bounded only so it can't grow unbounded.
const HISTORY_LINES := 400
## Arrows for the collapse toggle: « folds the open panel, » unfolds the strip.
const FOLD_MARK := "«"
const UNFOLD_MARK := "»"
## The panel's on-screen width, open vs folded [user request 2026-07-06]. The HUD
## frame anchors the RIGHT edge; the panel spans leftward by one of these widths,
## so collapsing genuinely narrows it to a gutter strip. Presentation numbers.
const EXPANDED_WIDTH := 340.0
const COLLAPSED_WIDTH := 44.0

## The wrapped feed — the test-facing renderer; RunView feeds it `place_of`.
var feed: ChronicleFeed
var collapsed := false

var _body: VBoxContainer
var _scroll: ScrollContainer
var _heading: Label
var _toggle: Button


func _init() -> void:
	name = "history_panel"
	RavennaUI.skin_hud_panel(self)
	# Clip so long chronicle lines can't force the pane wider than its fixed width.
	clip_contents = true
	var column := VBoxContainer.new()
	column.name = "column"
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(column)
	# Header: the gold title and the collapse toggle, on one row.
	var header := HBoxContainer.new()
	header.name = "header"
	column.add_child(header)
	_heading = RavennaUI.hud_heading("Historical Record")
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	_toggle = Button.new()
	_toggle.name = "toggle"
	_toggle.text = FOLD_MARK
	_toggle.tooltip_text = "Collapse the record"
	_toggle.flat = true
	_toggle.add_theme_color_override("font_color", Palette.COLORS[Palette.GOLD_LIT])
	_toggle.pressed.connect(toggle)
	header.add_child(_toggle)
	# Body: the scrolling record. The feed keeps the full history and renders
	# newest-last; the scroll follows it down as events land.
	_body = VBoxContainer.new()
	_body.name = "body"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_scroll = ScrollContainer.new()
	_scroll.name = "scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_scroll)
	feed = ChronicleFeed.new()
	feed.max_lines = HISTORY_LINES
	feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The feed's own solid ground would double the pane's opacity, and its inline
	# "Chronicle" title would double this panel's heading — clear both.
	feed.add_theme_stylebox_override("panel", RavennaUI.clear_style())
	# The panel carries its own "Historical Record" heading, so drop the feed's
	# inline "Chronicle" title to avoid a double heading.
	var inner_title: Node = feed.find_child("title", true, false)
	if inner_title != null:
		(inner_title as CanvasItem).visible = false
	_scroll.add_child(feed)
	feed.line_added.connect(_follow_to_newest)


## Collapse to a thin strip (only the toggle shows) or expand back to the record.
## The HUD frame anchors the panel's RIGHT edge; narrowing offset_left folds it to
## a gutter strip (grow_horizontal BEGIN keeps it hugging the right edge).
func set_collapsed(value: bool) -> void:
	collapsed = value
	_heading.visible = not value
	_body.visible = not value
	offset_left = -(COLLAPSED_WIDTH if value else EXPANDED_WIDTH)
	_toggle.text = UNFOLD_MARK if value else FOLD_MARK
	_toggle.tooltip_text = "Show the record" if value else "Collapse the record"
	collapsed_changed.emit(collapsed)


func toggle() -> void:
	set_collapsed(not collapsed)


## Keep the newest line in view as the story grows (deferred: the scroll range is
## only known after the new label lays out).
func _follow_to_newest() -> void:
	if not collapsed:
		_scroll.set_deferred("scroll_vertical", 1_000_000)
