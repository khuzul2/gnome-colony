extends GutTest

## T18.4 [PROGRESS T18.4] — settings chrome: SettingsView renders one
## editable widget per GameSettings.DEFAULTS key, chosen by the default
## value's type (bool → CheckBox, int/float → SpinBox, String →
## LineEdit). Every edit routes through the set_value whitelist and
## saves immediately, so GameSettings.load_from(path) sees it. The view
## can never smuggle a key the whitelist refuses — it builds only from
## DEFAULTS. Sim-hash invariance under these dials is already proven in
## test_settings.gd.

const CFG_PATH := "user://test_settings_view.cfg"


func before_each():
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func after_all():
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func _make_view(settings: GameSettings = GameSettings.new()) -> SettingsView:
	var view := SettingsView.new()
	view.settings = settings
	view.settings_path = CFG_PATH
	add_child_autofree(view)
	return view


func test_int_spinbox_edit_persists_to_cfg():
	var view := _make_view()
	var spin := view.widget_for("graphics", "render_crowd_density") as SpinBox
	assert_not_null(spin, "render_crowd_density (int default) renders as a SpinBox")
	spin.value = 64  # Range's value setter emits value_changed, like a user edit.
	var reloaded := GameSettings.load_from(CFG_PATH)
	assert_eq(reloaded.get_value("graphics", "render_crowd_density"), 64, "persisted on change")
	assert_eq(
		typeof(reloaded.get_value("graphics", "render_crowd_density")),
		TYPE_INT,
		"an int dial stays an int through the SpinBox's float signal"
	)


func test_checkbox_toggle_persists_to_cfg():
	var view := _make_view()
	var box := view.widget_for("audio", "mute_on_focus_loss") as CheckBox
	assert_not_null(box, "mute_on_focus_loss (bool default) renders as a CheckBox")
	assert_false(box.button_pressed, "initial state read from settings (default false)")
	box.button_pressed = true  # setter emits toggled, like a user click.
	var reloaded := GameSettings.load_from(CFG_PATH)
	assert_eq(reloaded.get_value("audio", "mute_on_focus_loss"), true, "persisted on toggle")


func test_string_edit_persists_to_cfg():
	var view := _make_view()
	var line := view.widget_for("gameplay", "locale") as LineEdit
	assert_not_null(line, "locale (String default) renders as a LineEdit")
	line.text = "de"
	line.text_changed.emit(line.text)  # LineEdit only signals on user input; simulate it.
	var reloaded := GameSettings.load_from(CFG_PATH)
	assert_eq(reloaded.get_value("gameplay", "locale"), "de", "persisted on edit")


func test_float_spinbox_edit_persists_as_float():
	var view := _make_view()
	var spin := view.widget_for("audio", "music") as SpinBox
	assert_not_null(spin, "music (float default) renders as a SpinBox")
	spin.value = 0.5
	var reloaded := GameSettings.load_from(CFG_PATH)
	assert_eq(reloaded.get_value("audio", "music"), 0.5, "persisted on change")
	assert_eq(typeof(reloaded.get_value("audio", "music")), TYPE_FLOAT, "float stays float")


func test_initial_values_come_from_the_injected_settings():
	var settings := GameSettings.new()
	# 0.4 is step-aligned: the float SpinBox snaps to its 0.1 step
	# (a presentation affordance), so only aligned values display as-is.
	settings.set_value("audio", "music", 0.4)
	settings.set_value("controls", "edge_scroll", false)
	settings.set_value("accessibility", "colorblind", "deuteranopia")
	var view := _make_view(settings)
	assert_eq((view.widget_for("audio", "music") as SpinBox).value, 0.4)
	assert_false((view.widget_for("controls", "edge_scroll") as CheckBox).button_pressed)
	assert_eq((view.widget_for("accessibility", "colorblind") as LineEdit).text, "deuteranopia")


func test_one_section_container_per_defaults_section():
	var view := _make_view()
	for section in GameSettings.DEFAULTS:
		var box := view.section_container(section)
		assert_not_null(box, "a VBoxContainer named after the section: %s" % section)
		assert_true(box is VBoxContainer, "%s groups its widgets in a VBoxContainer" % section)
		assert_eq(String(box.name), String(section), "container named after the section")


func test_every_widget_maps_to_a_defaults_key_and_is_named_after_it():
	var view := _make_view()
	for section in GameSettings.DEFAULTS:
		for widget in view.section_container(section).get_children():
			if not (widget is CheckBox or widget is SpinBox or widget is LineEdit):
				continue  # section header / row labels carry no key.
			assert_true(
				GameSettings.DEFAULTS[section].has(String(widget.name)),
				(
					"widget %s/%s exists in DEFAULTS — the view invents no keys"
					% [section, widget.name]
				)
			)


func test_supported_defaults_keys_all_get_a_widget():
	var view := _make_view()
	for section in GameSettings.DEFAULTS:
		for key in GameSettings.DEFAULTS[section]:
			var default: Variant = GameSettings.DEFAULTS[section][key]
			var widget := view.widget_for(section, key)
			match typeof(default):
				TYPE_BOOL:
					assert_true(widget is CheckBox, "%s/%s bool → CheckBox" % [section, key])
				TYPE_INT, TYPE_FLOAT:
					assert_true(widget is SpinBox, "%s/%s number → SpinBox" % [section, key])
				TYPE_STRING:
					assert_true(widget is LineEdit, "%s/%s String → LineEdit" % [section, key])
				_:
					assert_null(
						widget,
						(
							"%s/%s has a non-scalar default (e.g. bindings {}) — no widget chrome"
							% [section, key]
						)
					)


func test_the_whitelist_still_refuses_unknown_keys_and_the_view_never_renders_one():
	var view := _make_view()
	assert_false(view.settings.set_value("graphics", "quicken_budget", 9999), "no smuggling [§7.1]")
	assert_false(view.settings.set_value("sim", "mortality", "brutal"), "no such section")
	assert_null(view.widget_for("graphics", "quicken_budget"), "no widget for a non-DEFAULTS key")
	assert_null(view.widget_for("sim", "mortality"), "no widget for a non-DEFAULTS section")
	var editable := 0
	for section in GameSettings.DEFAULTS:
		for widget in view.section_container(section).get_children():
			if widget is CheckBox or widget is SpinBox or widget is LineEdit:
				editable += 1
	var scalar_defaults := 0
	for section in GameSettings.DEFAULTS:
		for key in GameSettings.DEFAULTS[section]:
			if (
				typeof(GameSettings.DEFAULTS[section][key])
				in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]
			):
				scalar_defaults += 1
	assert_eq(editable, scalar_defaults, "exactly one widget per scalar DEFAULTS key, no extras")


func test_edits_go_through_set_value_never_raw_values():
	# The whitelist is the ONLY write path: a view wired straight into
	# settings.values would also accept this probe. widget_for returning
	# null for it (above) plus the source-level contract is the guard;
	# here we prove an edit lands via the whitelist by round-tripping a
	# real key and confirming values was mutated to the same thing.
	var view := _make_view()
	var spin := view.widget_for("gameplay", "autosave_slots") as SpinBox
	spin.value = 5
	assert_eq(view.settings.get_value("gameplay", "autosave_slots"), 5, "in-memory via set_value")
	var reloaded := GameSettings.load_from(CFG_PATH)
	assert_eq(reloaded.get_value("gameplay", "autosave_slots"), 5, "and saved immediately")


func test_every_binding_action_gets_a_single_char_editor_showing_its_default():
	# T21.4 [§7.3]: the controls/bindings dict finally gets chrome — one
	# LineEdit per action, capped to single-char key names.
	var view := _make_view()
	var defaults: Dictionary = GameSettings.DEFAULTS["controls"]["bindings"]
	assert_gt(defaults.size(), 0, "the §7.3 default table exists (pan/zoom actions)")
	for action in defaults:
		var line := view.binding_editor(action)
		assert_not_null(line, "an editor per action: %s" % action)
		assert_eq(line.text, defaults[action], "%s shows its default key" % action)
		assert_eq(line.max_length, 1, "single-char key names [§7.3 presentation affordance]")


func test_a_binding_edit_persists_the_whole_dict_through_load_from():
	var view := _make_view()
	var line := view.binding_editor("pan_up")
	line.text = "I"
	line.text_changed.emit(line.text)  # LineEdit only signals on user input; simulate it.
	var reloaded := GameSettings.load_from(CFG_PATH)
	var bindings: Dictionary = reloaded.get_value("controls", "bindings")
	assert_eq(bindings["pan_up"], "I", "the edited binding persisted [§7.3]")
	assert_eq(bindings["pan_down"], "S", "…while untouched actions keep their defaults")
	assert_eq(
		_sorted(bindings.keys()),
		_sorted(GameSettings.DEFAULTS["controls"]["bindings"].keys()),
		"the WHOLE dict rode through set_value — no action lost, none invented"
	)


func test_an_unknown_binding_action_is_impossible():
	var view := _make_view()
	assert_null(view.binding_editor("fly"), "no editor exists for an action outside DEFAULTS")
	var line := view.binding_editor("zoom_out")
	line.text = "Z"
	line.text_changed.emit(line.text)
	var reloaded := GameSettings.load_from(CFG_PATH)
	var bindings: Dictionary = reloaded.get_value("controls", "bindings")
	assert_false(bindings.has("fly"), "the saved dict holds only the spec's actions")
	assert_eq(bindings["zoom_out"], "Z", "…while a real action rebinds fine")
	assert_eq(
		_sorted(bindings.keys()),
		_sorted(GameSettings.DEFAULTS["controls"]["bindings"].keys()),
		"the dict is rebuilt from the DEFAULTS action list — the nested whitelist"
	)


## Key order through a ConfigFile round trip is the file's business,
## not the contract — compare as sorted sets.
func _sorted(keys: Array) -> Array:
	var out := keys.duplicate()
	out.sort()
	return out
