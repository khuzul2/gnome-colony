class_name SettingsView
extends Control
## Settings chrome [PROGRESS T18.4, setup §7]: an editable widget per
## GameSettings.DEFAULTS key, chosen by the default value's type —
## bool → CheckBox, int/float → SpinBox, String → LineEdit. Non-scalar
## defaults (controls/bindings, a Dictionary) get no chrome here (a
## rebinding screen is its own feature). Every edit routes through
## settings.set_value — the whitelist; this view NEVER writes
## settings.values directly — then saves to settings_path immediately,
## so changes persist the moment they are made. Inject `settings` and
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


func _ready() -> void:
	_build()


## The editable widget for a DEFAULTS key, or null if none exists
## (unknown key, unknown section, or a non-scalar default).
func widget_for(section: String, key: String) -> Control:
	return _widgets.get(section, {}).get(key)


## The per-section VBoxContainer (named after the section), or null.
func section_container(section: String) -> VBoxContainer:
	return _sections.get(section)


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
			var widget := _make_widget(section, key, GameSettings.DEFAULTS[section][key])
			if widget == null:
				continue  # Non-scalar default (e.g. bindings {}): no chrome.
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


## The ONLY write path: through the whitelist, then persist at once.
func _apply(section: String, key: String, value: Variant) -> void:
	if settings.set_value(section, key, value):
		settings.save(settings_path)
