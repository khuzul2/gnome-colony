class_name HudFrame
extends Control
## The run HUD frame [user request 2026-07-06, leg §L-hud]: the anchored, non-
## overlapping chrome that floats over the live mosaic world, replacing the old
## single flat VBox that stacked everything at the origin and overlapped the game.
## Four regions, each a translucent Ravenna pane (RavennaUI.HUD_ALPHA):
##   • top-center  — the colony STATS pane (vitals, devotion, warnings)
##   • top-left    — the left column: settlement roster, then act hindsight + heat
##   • right       — the Historical Record (collapsible, scrolling; HistoryPanel)
##   • bottom      — the ACTION BAR (the phenomenon acts + speed/save/menu)
## HudFrame owns the anchoring + skinning; RunView builds the live components (they
## need run data) and hands them to mount(). The frame itself passes mouse through
## (MOUSE_FILTER_IGNORE) so clicks on open ground still reach the world picker —
## only the actual panes consume input. Presentation-only.

## Gap between the panes and the screen edge.
const MARGIN := 8.0
## Vertical clearance the right panel leaves for the bottom action bar, so the
## Historical Record doesn't run under it. A presentation estimate (the bar's
## height is dynamic); the panes are translucent so a small overlap is harmless.
const ACTION_CLEAR := 168.0

## The collapsible Historical Record — the frame owns it; RunView reads .feed.
var history: HistoryPanel
## R7.2 [leg §L-acts] — the refusal banner, anchored top-centre over the stats pane;
## RunView flashes it and fades it. Owned here so it's a child of the frame (which
## the shell reparents into the run screen) and always renders.
var reject_label: Label

var _stats_slot: VBoxContainer
var _left_slot: VBoxContainer
var _action_slot: HBoxContainer


func _init() -> void:
	name = "run_hud"
	# Let clicks on open ground fall through to the world picker; the panes below
	# (PanelContainers) still consume clicks that land on them.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_left_column()
	_build_stats_pane()
	_build_history()
	_build_action_bar()
	_build_reject_banner()


func _build_left_column() -> void:
	_left_slot = VBoxContainer.new()
	_left_slot.name = "left_column"
	_left_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_left_slot.offset_left = MARGIN
	_left_slot.offset_top = MARGIN
	_left_slot.add_theme_constant_override("separation", int(MARGIN))
	add_child(_left_slot)


func _build_stats_pane() -> void:
	var pane := PanelContainer.new()
	pane.name = "stats_panel"
	RavennaUI.skin_hud_panel(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pane.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pane.offset_top = MARGIN
	_stats_slot = VBoxContainer.new()
	_stats_slot.name = "stats_slot"
	pane.add_child(_stats_slot)
	add_child(pane)


func _build_history() -> void:
	history = HistoryPanel.new()
	history.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	history.offset_right = -MARGIN
	history.offset_top = MARGIN
	history.offset_bottom = -ACTION_CLEAR
	add_child(history)


func _build_action_bar() -> void:
	var pane := PanelContainer.new()
	pane.name = "action_panel"
	RavennaUI.skin_hud_panel(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pane.offset_left = MARGIN
	pane.offset_right = -MARGIN
	pane.offset_bottom = -MARGIN
	_action_slot = HBoxContainer.new()
	_action_slot.name = "action_slot"
	_action_slot.add_theme_constant_override("separation", int(MARGIN))
	pane.add_child(_action_slot)
	add_child(pane)


func _build_reject_banner() -> void:
	reject_label = Label.new()
	reject_label.name = "reject"
	reject_label.add_theme_color_override("font_color", Palette.COLORS[Palette.TERRACOTTA])
	reject_label.add_theme_font_size_override("font_size", 16)
	reject_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reject_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	reject_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	reject_label.offset_top = 4.0
	reject_label.visible = false
	add_child(reject_label)


## Place RunView's live components into the regions and skin them into the pane
## register. `parts` keys: roster, readout, influence, controls, aftermath, heatmap.
func mount(parts: Dictionary) -> void:
	var roster: Control = parts["roster"]
	_translucent(roster)
	_left_slot.add_child(roster)
	var aftermath: Control = parts["aftermath"]
	_translucent(aftermath)
	_left_slot.add_child(aftermath)
	# The heat overlay is toggled (hidden by default), so it takes no column space
	# until shown; it reads directly over the mosaic.
	_left_slot.add_child(parts["heatmap"])
	_stats_slot.add_child(parts["readout"])
	# The action bar: the acts scroll horizontally in the middle (the toolbox widens
	# as tiers unlock), the speed/save/menu controls stay pinned to the right. The
	# InfluencePanel is itself a PanelContainer INSIDE this translucent pane, so its
	# own ground is cleared (else it would double the opacity) — same as the feed.
	var influence: Control = parts["influence"]
	if influence is PanelContainer:
		influence.add_theme_stylebox_override("panel", RavennaUI.clear_style())
	var scroll := ScrollContainer.new()
	scroll.name = "act_scroll"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(influence)
	_action_slot.add_child(scroll)
	_action_slot.add_child(parts["controls"])


## Re-skin a HUD component into the translucent pane register so its own opaque
## ground doesn't clash with the floating chrome.
func _translucent(component: Control) -> void:
	if component is PanelContainer:
		RavennaUI.skin_hud_panel(component)
