extends GutTest

## R6.4 [leg §L-hud] — the living chronicle feed: recent diegetic story beats so
## the player can FOLLOW the colony's evolution. The panel is a dumb renderer
## (push/cap/order); RunView subscribes to the story-beat EventBus signals and the
## landed phenomena and pushes formatted lines.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _feed() -> ChronicleFeed:
	var f := ChronicleFeed.new()
	add_child_autofree(f)
	return f


func _view(seed_value := 1811) -> RunView:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	add_child_autofree(view)
	return view


# --- the panel (dumb renderer) ----------------------------------------------


func test_push_keeps_arrival_order_newest_last():
	var f := _feed()
	f.push("first")
	f.push("second")
	assert_eq(f.lines, ["first", "second"] as Array[String], "arrival order, newest last")


func test_caps_at_max_lines_dropping_the_oldest():
	var f := _feed()
	for i in ChronicleFeed.MAX_LINES + 3:
		f.push("event %d" % i)
	assert_eq(f.lines.size(), ChronicleFeed.MAX_LINES, "capped at MAX_LINES")
	assert_eq(f.lines[0], "event 3", "the oldest scrolled off")
	assert_eq(f.lines[-1], "event %d" % (ChronicleFeed.MAX_LINES + 2), "the newest is kept")


# --- RunView feeds it from the world ----------------------------------------


func test_a_founding_reaches_the_feed_named():
	var view := _view()
	var before := view.chronicle_feed.lines.size()
	EventBus.settlement_founded.emit({"sid": 5, "place": "ochre_5", "day": 1})
	assert_eq(view.chronicle_feed.lines.size(), before + 1, "the founding is chronicled")
	assert_true("Ochre 5" in view.chronicle_feed.lines[-1], "…and names the place")


func test_a_tier_crossing_reaches_the_feed():
	var view := _view()
	EventBus.settlement_tier_changed.emit(
		{"sid": GameRun.HOME_SID, "from": 0, "to": Enums.SettlementTier.VILLAGE}
	)
	assert_true("village" in view.chronicle_feed.lines[-1], "the tier crossing is chronicled")


func test_a_landed_act_reaches_the_feed():
	# End-to-end: a real cast fires EventBus.phenomenon through the pipeline (valid
	# payloads), and the feed captures the landed omen.
	var view := _view()
	view.set_speed(0.0)
	var before := view.chronicle_feed.lines.size()
	assert_true(view.influence_panel.arm("still_air"))
	view.select_place(view.run.home)
	assert_gt(view.chronicle_feed.lines.size(), before, "a landed act is chronicled")


func test_teardown_drops_the_eventbus_wiring():
	# [R6.4 review] The feed subscribes to the global EventBus; tearing the run down
	# (menu-out / new game) must disconnect it, or a later event would push() onto a
	# freed feed. Removing the view from the tree fires _exit_tree on it AND its feed.
	var view := _view()
	var feed := view.chronicle_feed
	assert_true(
		EventBus.phenomenon.is_connected(feed._on_phenomenon), "the feed is wired while live"
	)
	assert_true(EventBus.settlement_founded.is_connected(feed._on_founded), "…all signals")
	remove_child(view)  # fires _exit_tree on the subtree; GUT still frees it at test end
	assert_false(
		EventBus.phenomenon.is_connected(feed._on_phenomenon), "the feed unwires on teardown"
	)
	assert_false(EventBus.settlement_founded.is_connected(feed._on_founded), "…all of them")
	assert_false(EventBus.born.is_connected(view._on_born), "the life-pulse wiring too")
