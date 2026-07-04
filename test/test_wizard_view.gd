extends GutTest

## T18.3 — Wizard chrome [PROGRESS T18.3, setup §1–§5]: WizardView
## renders the injected NewGameWizard's five pages as real widgets.
## Every widget routes through the wizard's whitelisted setters only,
## so the produced WorldConfig is the proof: poke a widget, start(),
## read the field. Navigation shows exactly one page at a time; the
## summary page shows the real seed. Also closes the T15.2 open minor:
## typo'd setter keys push_warning and stay no-ops.


func _view() -> WizardView:
	var view := WizardView.new()
	view.wizard = NewGameWizard.new()
	add_child_autofree(view)
	return view


func _widget(view: WizardView, path: String) -> Node:
	return view.get_node("column/" + path)


## Select an OptionButton entry by its text, the way a player would.
func _pick(option: OptionButton, level: String) -> void:
	for i in option.item_count:
		if option.get_item_text(i) == level:
			option.select(i)
			option.item_selected.emit(i)
			return
	fail_test("option '%s' offers no level '%s'" % [option.name, level])


func _visible_pages(view: WizardView) -> Array:
	var out := []
	for n in range(1, NewGameWizard.PAGES + 1):
		if _widget(view, "page_%d" % n).visible:
			out.append(n)
	return out


func test_the_view_builds_five_stable_pages():
	var view := _view()
	for n in range(1, NewGameWizard.PAGES + 1):
		assert_true(view.has_node("column/page_%d" % n), "page_%d exists, test-addressable" % n)
	assert_true(view.has_node("column/nav/next"), "nav buttons are stable nodes")
	assert_true(view.has_node("column/nav/back"))
	assert_true(view.wizard.is_inside_tree(), "the wizard node itself is the preset page")


func test_preset_buttons_reach_the_wizard():
	Rng.seed_with(18301)
	var view := _view()
	var card: Button = view.find_child("gentle_garden", true, false)
	assert_not_null(card, "wizard.build()'s preset cards live on page 1")
	card.pressed.emit()
	assert_eq(view.wizard.preset, "gentle_garden")
	assert_eq(view.wizard.start().mortality, "gentle", "…and land in the config [§1]")


func test_founding_widgets_reach_the_config():
	Rng.seed_with(18302)
	var view := _view()
	var band: SpinBox = _widget(view, "page_2/band_size")
	assert_eq(band.min_value, float(WorldConfig.BAND_SIZE_MIN), "spinner spans 3..8 [§5]")
	assert_eq(band.max_value, float(WorldConfig.BAND_SIZE_MAX))
	band.value = 6
	var colony: LineEdit = _widget(view, "page_2/colony_name")
	colony.text = "Mossbottom"
	colony.text_changed.emit(colony.text)
	var flavor: LineEdit = _widget(view, "page_2/culture_flavor")
	flavor.text = "stoic"
	flavor.text_changed.emit(flavor.text)
	var curious: CheckBox = _widget(view, "page_2/curious")
	assert_true(curious.button_pressed, "the default leaning starts checked [§5]")
	curious.button_pressed = false
	(_widget(view, "page_2/hardy") as CheckBox).button_pressed = true
	(_widget(view, "page_2/devout") as CheckBox).button_pressed = true
	var cfg := view.wizard.start()
	assert_eq(cfg.band_size, 6, "the spinner value IS the config value")
	assert_eq(cfg.colony_name, "Mossbottom")
	assert_eq(cfg.culture_flavor, "stoic")
	assert_eq(cfg.temperament_leanings, ["hardy", "devout"], "checkboxes → leanings")


func test_world_widgets_reach_the_config():
	Rng.seed_with(18303)
	var view := _view()
	var seed_edit: LineEdit = _widget(view, "page_3/seed")
	seed_edit.text = "424242"
	seed_edit.text_changed.emit(seed_edit.text)
	_pick(_widget(view, "page_3/region_size"), "large")
	_pick(_widget(view, "page_3/hazard_frequency"), "volatile")
	_pick(_widget(view, "page_3/biome_variety"), "uniform")
	var fog: CheckBox = _widget(view, "page_3/exploration_fog")
	assert_true(fog.button_pressed, "fog starts at the WorldConfig default [§4]")
	fog.button_pressed = false
	var cfg := view.wizard.start()
	assert_eq(cfg.seed, 424242, "a typed seed is kept, shareable [§4]")
	assert_eq(cfg.region_size, "large")
	assert_eq(cfg.hazard_frequency, "volatile")
	assert_eq(cfg.biome_variety, "uniform")
	assert_false(cfg.exploration_fog)


func test_environmental_events_toggle_and_per_event_dials():
	# [user feature 2026-07-03]: opt in, then dial one event's clock.
	Rng.seed_with(18304)
	var view := _view()
	var frequencies: Node = _widget(view, "page_3/event_frequencies")
	assert_eq(frequencies.get_child_count(), Catalog.defs().size(), "one dial per catalog event")
	var events: CheckBox = _widget(view, "page_3/environmental_events")
	assert_false(events.button_pressed, "nature stays off by default [§1.8b]")
	events.button_pressed = true
	_pick(_widget(view, "page_3/event_frequencies/landslide"), "frequent")
	var cfg := view.wizard.start()
	assert_true(cfg.environmental_events, "the toggle reaches the config")
	assert_eq(cfg.event_frequencies["landslide"], "frequent", "…and so does the dial")


func test_rule_dials_reach_the_config():
	Rng.seed_with(18305)
	var view := _view()
	for key in NewGameWizard.RULE_KEYS:
		assert_true(view.has_node("column/page_4/" + key), "a dial per rule key: " + key)
	_pick(_widget(view, "page_4/mortality"), "brutal")
	_pick(_widget(view, "page_4/faith_enlightenment"), "secularizing")
	var cfg := view.wizard.start()
	assert_eq(cfg.mortality, "brutal", "picked levels land in the config [§3]")
	assert_eq(cfg.faith_enlightenment, "secularizing")


func test_navigation_shows_exactly_one_page():
	Rng.seed_with(18306)
	var view := _view()
	assert_eq(_visible_pages(view), [1], "the wizard opens on the preset cards [§2]")
	var back: Button = _widget(view, "nav/back")
	var next: Button = _widget(view, "nav/next")
	back.pressed.emit()
	assert_eq(_visible_pages(view), [1], "no page zero")
	next.pressed.emit()
	assert_eq(_visible_pages(view), [2])
	for i in 6:
		next.pressed.emit()
	assert_eq(_visible_pages(view), [5], "summary is the last page")
	back.pressed.emit()
	assert_eq(_visible_pages(view), [4])


func test_summary_labels_reflect_a_typed_seed():
	Rng.seed_with(18307)
	var view := _view()
	var seed_edit: LineEdit = _widget(view, "page_3/seed")
	seed_edit.text = "424242"
	seed_edit.text_changed.emit(seed_edit.text)
	var colony: LineEdit = _widget(view, "page_2/colony_name")
	colony.text = "Mossbottom"
	colony.text_changed.emit(colony.text)
	var next: Button = _widget(view, "nav/next")
	for i in 4:
		next.pressed.emit()
	var seed_label: Label = _widget(view, "page_5/seed")
	assert_string_contains(seed_label.text, "424242", "the summary shows the seed [§2]")
	var name_label: Label = _widget(view, "page_5/colony_name")
	assert_string_contains(name_label.text, "Mossbottom")


func test_unknown_setter_keys_warn_and_stay_no_ops():
	# T15.2 open minor closed: a typo'd key now push_warning-s (visible
	# in the run log) and still never reaches the config.
	Rng.seed_with(18308)
	var wizard := NewGameWizard.new()
	add_child_autofree(wizard)
	wizard.set_rule("mortalty", "brutal")
	wizard.set_world("regionsize", "large")
	wizard.set_founding("bandsize", 8)
	assert_engine_error("set_rule: unknown key 'mortalty'", "the typo is warned about")
	assert_engine_error("set_world: unknown key 'regionsize'")
	assert_engine_error("set_founding: unknown key 'bandsize'")
	var cfg := wizard.start()
	assert_eq(cfg.mortality, "normal", "a typo'd rule key never lands")
	assert_eq(cfg.region_size, "medium", "…nor a world key")
	assert_eq(cfg.band_size, 4, "…nor a founding key")
