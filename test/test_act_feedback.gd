extends GutTest

## R7.2 [leg §L-acts] — reject-with-feedback: a cast that lands nothing (its
## precondition unmet at that place, or no/wrong target) now SAYS why at the cursor
## and emits cast_refused (the shell rings the refused UI cue), instead of the
## Gate-A silent no-op ("weeping sky does nothing").

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _view(seed_value := 1821) -> RunView:
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


func test_an_unmet_precondition_is_refused_with_a_reason():
	var view := _view()
	view.set_speed(0.0)
	# Premise: weeping sky needs a drought, and a fresh colony's home has none.
	assert_false(
		"drought" in view.run.world.affordances.get(view.run.home, []), "no drought at home yet"
	)
	watch_signals(view)
	assert_true(view.influence_panel.arm("weeping_sky"), "the act is unlocked at tier I")
	view.select_place(view.run.home)
	assert_signal_emitted(view, "cast_refused", "a landed-nothing cast is refused, not silent")
	assert_true(view._reject_label.visible, "the reason shows")
	assert_true("drought" in view._reject_label.text, "…and names the missing precondition")
	# It must ride the HUD (which the shell reparents into the run screen), not
	# RunView itself — else it renders nowhere in the real game [R7.2 review].
	assert_eq(view._reject_label.get_parent(), view.hud, "the banner is mounted in the HUD")


func test_a_valid_cast_is_not_refused():
	var view := _view()
	view.set_speed(0.0)
	watch_signals(view)
	assert_true(view.influence_panel.arm("still_air"), "still air needs nothing")
	view.select_place(view.run.home)
	assert_signal_emit_count(view, "cast_refused", 0, "a landed act is not refused")
	assert_false(view._reject_label.visible, "…and no refusal message shows")


func test_the_refusal_message_fades_after_its_time():
	var view := _view()
	view.set_speed(0.0)
	view._show_reject("test")
	assert_true(view._reject_label.visible, "the message shows")
	view._process(RunView.REJECT_MSG_SECONDS + 0.1)
	assert_false(view._reject_label.visible, "…and clears after REJECT_MSG_SECONDS")
