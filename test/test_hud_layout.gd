extends GutTest

## HUD overhaul [user request 2026-07-06, leg §L-hud]: the flat origin-stacked HUD
## is replaced by an anchored Ravenna frame — a top-centre stats pane, a top-left
## column (roster + hindsight + heat), a collapsible/scrolling Historical Record on
## the right, and a bottom action bar (acts + speed/save/menu). The panes are
## translucent so the mosaic world shows through. These tests pin the STRUCTURE
## (anchoring, translucency, collapse, scroll, full-history cap) headlessly; the
## "does it look right" half belongs to a human playtest.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


# --- HudFrame: the anchored, translucent, mouse-through layout ----------------


func _frame() -> HudFrame:
	var frame := HudFrame.new()
	add_child_autofree(frame)
	return frame


func test_the_frame_fills_the_screen_and_passes_clicks_through():
	var frame := _frame()
	assert_eq(
		frame.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"the frame itself lets clicks on open ground reach the world picker"
	)
	assert_eq(frame.anchor_right, 1.0, "the frame is full-rect")
	assert_eq(frame.anchor_bottom, 1.0)


func test_the_four_panes_and_banner_exist():
	var frame := _frame()
	assert_not_null(frame.get_node("stats_panel"), "a top-centre stats pane")
	assert_not_null(frame.get_node("action_panel"), "a bottom action bar")
	assert_not_null(frame.get_node("left_column"), "a top-left column")
	assert_not_null(frame.history, "a right-side Historical Record")
	assert_not_null(frame.reject_label, "a refusal banner")


func test_bottom_and_right_panes_grow_on_screen():
	# Regression: the action bar and the record must grow INWARD from their edges,
	# not off-screen (the default GROW_DIRECTION_END pushed them out of view).
	var frame := _frame()
	var action := frame.get_node("action_panel")
	assert_eq(action.anchor_top, 1.0, "the action bar anchors to the bottom edge")
	assert_eq(
		action.grow_vertical,
		Control.GROW_DIRECTION_BEGIN,
		"…and grows UP into view, not down off-screen"
	)
	assert_eq(frame.history.anchor_right, 1.0, "the record anchors to the right edge")
	assert_eq(
		frame.history.grow_horizontal,
		Control.GROW_DIRECTION_BEGIN,
		"…and grows LEFT into view, not right off-screen"
	)
	assert_eq(
		frame.history.offset_left, -HistoryPanel.EXPANDED_WIDTH, "…at a bounded expanded width"
	)


func test_the_panes_are_translucent_ravenna():
	var frame := _frame()
	for pane_name in ["stats_panel", "action_panel"]:
		var style := frame.get_node(pane_name).get_theme_stylebox("panel") as StyleBoxFlat
		assert_not_null(style, "%s carries a stylebox" % pane_name)
		assert_almost_eq(
			style.bg_color.a, RavennaUI.HUD_ALPHA, 0.001, "%s floats translucent" % pane_name
		)


func test_mount_places_each_component_in_its_region():
	var frame := _frame()
	var roster := PanelContainer.new()
	var readout := Label.new()
	var influence := VBoxContainer.new()
	var controls := HBoxContainer.new()
	controls.name = "controls"
	var aftermath := PanelContainer.new()
	var heatmap := Control.new()
	(
		frame
		. mount(
			{
				"roster": roster,
				"readout": readout,
				"influence": influence,
				"controls": controls,
				"aftermath": aftermath,
				"heatmap": heatmap,
			}
		)
	)
	assert_eq(readout.get_parent().name, "stats_slot", "the readout fills the stats pane")
	assert_eq(frame.find_child("controls", true, false), controls, "the controls are on the bar")
	assert_true(
		influence.get_parent() is ScrollContainer, "the acts scroll horizontally on the bar"
	)
	assert_eq(roster.get_parent().name, "left_column", "the roster leads the left column")
	assert_eq(aftermath.get_parent().name, "left_column", "…with the act hindsight beneath it")


func test_mount_reskins_panel_components_translucent():
	var frame := _frame()
	var roster := PanelContainer.new()
	(
		frame
		. mount(
			{
				"roster": roster,
				"readout": Label.new(),
				"influence": VBoxContainer.new(),
				"controls": HBoxContainer.new(),
				"aftermath": PanelContainer.new(),
				"heatmap": Control.new(),
			}
		)
	)
	var style := roster.get_theme_stylebox("panel") as StyleBoxFlat
	assert_almost_eq(
		style.bg_color.a,
		RavennaUI.HUD_ALPHA,
		0.001,
		"a dropped panel joins the translucent register"
	)


# --- HistoryPanel: collapsible, scrolling, full history ----------------------


func _history() -> HistoryPanel:
	var panel := HistoryPanel.new()
	add_child_autofree(panel)
	return panel


func test_the_record_keeps_the_full_history_in_a_scroll():
	var panel := _history()
	assert_eq(
		panel.feed.max_lines, HistoryPanel.HISTORY_LINES, "the side panel keeps the whole story"
	)
	assert_true(panel.feed.get_parent() is ScrollContainer, "…inside a scroll container")


func test_the_record_collapses_and_expands():
	var panel := _history()
	assert_false(panel.collapsed, "open by default")
	assert_true(panel.get_node("column/body").visible, "the record shows")
	panel.toggle()
	assert_true(panel.collapsed, "the toggle folds it to a strip")
	assert_false(panel.get_node("column/body").visible, "…hiding the record")
	assert_eq(panel._toggle.text, HistoryPanel.UNFOLD_MARK, "the arrow flips to unfold")
	assert_eq(panel.offset_left, -HistoryPanel.COLLAPSED_WIDTH, "…and narrows to the gutter width")
	panel.toggle()
	assert_false(panel.collapsed, "…and back open")
	assert_true(panel.get_node("column/body").visible)
	assert_eq(panel.offset_left, -HistoryPanel.EXPANDED_WIDTH, "…restoring the full width")


func test_collapse_emits_its_signal():
	var panel := _history()
	watch_signals(panel)
	panel.toggle()
	assert_signal_emitted_with_parameters(panel, "collapsed_changed", [true])


# --- ChronicleFeed: the raised cap that feeds the record ---------------------


func test_the_feed_respects_a_raised_cap():
	var f := ChronicleFeed.new()
	add_child_autofree(f)
	f.max_lines = 50
	for i in 30:
		f.push("event %d" % i)
	assert_eq(f.lines.size(), 30, "under the raised cap the full run is kept")
	assert_eq(f.lines[0], "event 0", "…including the oldest, so nothing is lost")


func test_the_feed_signals_each_new_line():
	var f := ChronicleFeed.new()
	add_child_autofree(f)
	watch_signals(f)
	f.push("a beat")
	assert_signal_emitted(f, "line_added", "a hosting scroll can follow the newest line")


# --- Integration: RunView wires the feed into the record ---------------------


func test_run_view_routes_the_chronicle_into_the_record():
	Rng.seed_with(1906)
	var cfg := WorldConfig.new()
	cfg.seed = 1906
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	add_child_autofree(view)
	assert_eq(view.chronicle_feed, view.hud.history.feed, "the feed IS the record's feed")
	assert_eq(view.chronicle_feed.place_of, view.sid_places, "…fed the place names to name events")
