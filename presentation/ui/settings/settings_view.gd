class_name SettingsView
extends Control
## Settings chrome [PROGRESS T18.4, setup §7]: an editable widget per
## GameSettings.DEFAULTS key, chosen by the default value's type —
## bool → CheckBox, int/float → SpinBox, String → LineEdit. A
## Dictionary default (controls/bindings) is the §7.3 rebinding
## surface [T21.4]: one single-char LineEdit per action, nested in its
## own container, each edit routing the WHOLE updated dict through
## set_value. Every edit routes through settings.set_value — the
## whitelist; this view NEVER writes settings.values directly — then
## saves to settings_path immediately, so changes persist the moment
## they are made. Inject `settings` and
## (optionally) `settings_path` before adding to the tree; the tree of
## widgets is built in _ready. Pure presentation: the sim never reads
## any of this (proven by test_settings.gd's sim-hash invariance).

## SpinBox ranges/steps are PRESENTATION numbers (widget affordances,
## not spec values): generous bounds so no legitimate dial is clamped.
const INT_MIN := 0
const INT_MAX := 100000
const INT_STEP := 1
const FLOAT_MIN := 0.0
const FLOAT_MAX := 100.0
const FLOAT_STEP := 0.1

var settings: GameSettings
var settings_path := "user://settings.cfg"

var _sections := {}
var _widgets := {}
var _binding_editors := {}


func _ready() -> void:
	_build()


## The editable widget for a DEFAULTS key, or null if none exists
## (unknown key, unknown section, or a non-scalar default).
func widget_for(section: String, key: String) -> Control:
	return _widgets.get(section, {}).get(key)


## The per-section VBoxContainer (named after the section), or null.
func section_container(section: String) -> VBoxContainer:
	return _sections.get(section)


## The single-char LineEdit for a §7.3 binding action, or null — an
## action outside the DEFAULTS bindings table has no editor at all.
func binding_editor(action: String) -> LineEdit:
	return _binding_editors.get(action)


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	for section: String in GameSettings.DEFAULTS:
		var box := VBoxContainer.new()
		box.name = section
		var header := Label.new()
		header.text = section.capitalize()
		box.add_child(header)
		_sections[section] = box
		_widgets[section] = {}
		for key: String in GameSettings.DEFAULTS[section]:
			var default: Variant = GameSettings.DEFAULTS[section][key]
			if default is Dictionary:
				# §7.3 rebinding surface: its editors nest in their own
				# container (NOT in _widgets — widget_for stays scalar-only).
				box.add_child(_bindings_box(section, key, default))
				continue
			var widget := _make_widget(section, key, default)
			if widget == null:
				continue  # Non-scalar default: no chrome.
			widget.name = key
			box.add_child(widget)
			_widgets[section][key] = widget
		column.add_child(box)


## One widget per key, typed by the DEFAULT value (the type contract);
## the INITIAL shown value comes from the live settings. State is set
## BEFORE signals connect, so building never triggers a save.
func _make_widget(section: String, key: String, default: Variant) -> Control:
	var current: Variant = settings.get_value(section, key)
	match typeof(default):
		TYPE_BOOL:
			var box := CheckBox.new()
			box.text = key.capitalize()
			box.button_pressed = bool(current)
			box.toggled.connect(func(on: bool) -> void: _apply(section, key, on))
			return box
		TYPE_INT:
			var spin := _spin_box(key, INT_MIN, INT_MAX, INT_STEP, float(current))
			spin.value_changed.connect(func(value: float) -> void: _apply(section, key, int(value)))
			return spin
		TYPE_FLOAT:
			var spin := _spin_box(key, FLOAT_MIN, FLOAT_MAX, FLOAT_STEP, float(current))
			spin.value_changed.connect(func(value: float) -> void: _apply(section, key, value))
			return spin
		TYPE_STRING:
			var line := LineEdit.new()
			line.text = String(current)
			line.tooltip_text = key.capitalize()
			line.text_changed.connect(func(text: String) -> void: _apply(section, key, text))
			return line
	return null


func _spin_box(key: String, low: float, high: float, step: float, current: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = current
	spin.tooltip_text = key.capitalize()
	return spin


## §7.3 [T21.4]: one LineEdit per DEFAULTS binding action, named after
## it, capped to a single character (key names like "W" — a
## presentation affordance). Editors exist ONLY for default actions,
## so the surface can never mint an unknown one.
func _bindings_box(section: String, key: String, defaults: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = key
	var current: Dictionary = settings.get_value(section, key)
	for action: String in defaults:
		var line := LineEdit.new()
		line.name = action
		line.max_length = 1
		line.text = String(current.get(action, defaults[action]))
		line.tooltip_text = action.capitalize()
		line.text_changed.connect(
			func(text: String) -> void: _apply_binding(section, key, action, text)
		)
		box.add_child(line)
		_binding_editors[action] = line
	return box


## A binding edit sends the WHOLE updated dict through set_value. The
## dict is rebuilt from the DEFAULTS action list — never from widget
## state at large — so an action the spec doesn't name is impossible
## by construction (the nested whitelist).
func _apply_binding(section: String, key: String, action: String, text: String) -> void:
	var defaults: Dictionary = GameSettings.DEFAULTS[section][key]
	var current: Dictionary = settings.get_value(section, key)
	var updated := {}
	for known: String in defaults:
		updated[known] = String(current.get(known, defaults[known]))
	updated[action] = text
	_apply(section, key, updated)


## The ONLY write path: through the whitelist, then persist at once.
func _apply(section: String, key: String, value: Variant) -> void:
	if settings.set_value(section, key, value):
		settings.save(settings_path)
