class_name WizardView
extends Control
## Wizard chrome [PROGRESS T18.3, setup §1–§5]: real widgets for the
## New Game wizard's five pages. The view wraps an INJECTED
## NewGameWizard (set `wizard` before entering the tree) and routes
## EVERY write through its whitelisted setters — set_preset (via the
## wizard's own preset cards on page 1), set_founding, set_world,
## set_event_frequency, set_rule. The view owns ZERO config logic:
## widget lists come verbatim from WorldConfig's const tables, and
## normalize() at start() stays the sole gatekeeper (e.g. the max-2
## temperament rule is enforced there, never here). Next/Back drive
## wizard.next()/back(); exactly one page container is visible.

## Rule key → the WorldConfig level list its dial offers [setup §3].
const RULE_LEVELS := {
	"generation_pace": WorldConfig.GENERATION_PACES,
	"mortality": WorldConfig.MORTALITIES,
	"discovery_pace": WorldConfig.DISCOVERY_PACES,
	"divinity": WorldConfig.DIVINITIES,
	"chaos": WorldConfig.CHAOS_LEVELS,
	"civilization_scale": WorldConfig.CIVILIZATION_SCALES,
	"faith_enlightenment": WorldConfig.FAITH_MODES,
}
const SUMMARY_KEYS := ["preset", "seed", "colony_name", "band_size", "region_size"]
## Per-page heading so the raw widgets have context [R8.1 leg §L-ui].
const PAGE_TITLES := {
	1: "Choose a saga",
	2: "The founding band",
	3: "The world",
	4: "The rules",
	5: "Ready",
}

## Injected before entering the tree; _ready() builds around it.
var wizard: NewGameWizard

var _pages := {}
var _summary_labels := {}
var _temperament_boxes := {}


func _ready() -> void:
	assert(wizard != null, "inject a NewGameWizard before adding WizardView to the tree")
	# R8.1 [leg §L-ui]: fill the screen (was a 0-size Control that overflowed onto
	# the action buttons — the Gate-A overlap) on a night-lapis ground, Ravenna-
	# skinned. Structure (column → page_N + nav) is preserved for the wizard tests.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(RavennaUI.ground())
	var defaults := WorldConfig.new()
	var column := VBoxContainer.new()
	column.name = "column"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title := RavennaUI.heading("%s New Game" % RavennaUI.SEAT_MARK, RavennaUI.HEADING_FONT)
	title.name = "title"
	column.add_child(title)
	column.add_child(RavennaUI.meander_rule())
	for n in range(1, NewGameWizard.PAGES + 1):
		var page := VBoxContainer.new()
		page.name = "page_%d" % n
		page.add_theme_constant_override("separation", 4)
		column.add_child(page)
		_pages[n] = page
		page.add_child(RavennaUI.heading(PAGE_TITLES[n]))
	_build_presets()
	_build_founding(defaults)
	_build_world(defaults)
	_build_rules(defaults)
	_build_summary()
	_build_nav(column)
	_show_page(wizard.page)


## Page 1 [§2]: the wizard node IS the preset page — build() already
## makes the cards wired to set_preset; reuse them as-is.
func _build_presets() -> void:
	wizard.name = "wizard"
	if wizard.get_child_count() == 0:
		wizard.build()
	_pages[1].add_child(wizard)
	for card in wizard.find_children("*", "Button", true, false):
		RavennaUI.skin_button(card)


## Page 2 [§5]: founding — band size, names, temperament leanings.
func _build_founding(defaults: WorldConfig) -> void:
	var page: VBoxContainer = _pages[2]
	var band := SpinBox.new()
	band.name = "band_size"
	band.min_value = WorldConfig.BAND_SIZE_MIN
	band.max_value = WorldConfig.BAND_SIZE_MAX
	band.value = defaults.band_size
	band.value_changed.connect(
		func(value: float) -> void: wizard.set_founding("band_size", int(value))
	)
	page.add_child(band)
	for key in ["colony_name", "culture_flavor"]:
		var edit := LineEdit.new()
		edit.name = key
		edit.text_changed.connect(func(text: String) -> void: wizard.set_founding(key, text))
		page.add_child(edit)
	for temperament in WorldConfig.TEMPERAMENTS:
		var box := CheckBox.new()
		box.name = temperament
		box.text = temperament
		box.button_pressed = temperament in defaults.temperament_leanings
		box.toggled.connect(func(_on: bool) -> void: _write_leanings())
		page.add_child(box)
		_temperament_boxes[temperament] = box


## Page 3 [§4 + user feature 2026-07-03]: the world, fog, and nature.
func _build_world(defaults: WorldConfig) -> void:
	var page: VBoxContainer = _pages[3]
	var seed_edit := LineEdit.new()
	seed_edit.name = "seed"
	seed_edit.text_changed.connect(func(text: String) -> void: wizard.set_world("seed", int(text)))
	page.add_child(seed_edit)
	var world_levels := {
		"region_size": WorldConfig.REGION_SIZES.keys(),
		"resource_abundance": WorldConfig.RESOURCE_ABUNDANCES,
		"hazard_frequency": WorldConfig.HAZARD_FREQUENCIES,
		"biome_variety": WorldConfig.BIOME_VARIETIES,
	}
	for key in world_levels:
		_add_option(
			page,
			key,
			world_levels[key],
			defaults.get(key),
			func(level: String) -> void: wizard.set_world(key, level)
		)
	for key in ["exploration_fog", "environmental_events"]:
		var box := CheckBox.new()
		box.name = key
		box.text = key
		box.button_pressed = defaults.get(key)
		box.toggled.connect(func(on: bool) -> void: wizard.set_world(key, on))
		page.add_child(box)
	var frequencies := VBoxContainer.new()
	frequencies.name = "event_frequencies"
	page.add_child(frequencies)
	var ids: Array = Catalog.defs().keys()
	ids.sort()
	for event_id in ids:
		_add_option(
			frequencies,
			event_id,
			WorldConfig.EVENT_FREQUENCIES,
			WorldConfig.DEFAULT_EVENT_FREQUENCY,
			func(level: String) -> void: wizard.set_event_frequency(event_id, level)
		)


## Page 4 [§3]: one dial per rule slider, levels verbatim from WorldConfig.
func _build_rules(defaults: WorldConfig) -> void:
	for key in NewGameWizard.RULE_KEYS:
		_add_option(
			_pages[4],
			key,
			RULE_LEVELS[key],
			defaults.get(key),
			func(level: String) -> void: wizard.set_rule(key, level)
		)


## Page 5 [§2]: recap labels, filled from wizard.summary() on entry.
func _build_summary() -> void:
	for key in SUMMARY_KEYS:
		var label := Label.new()
		label.name = key
		_pages[5].add_child(label)
		_summary_labels[key] = label


func _build_nav(column: VBoxContainer) -> void:
	var nav := HBoxContainer.new()
	nav.name = "nav"
	column.add_child(nav)
	nav.add_theme_constant_override("separation", int(RavennaUI.GUTTER))
	var back := Button.new()
	back.name = "back"
	back.text = "Back"
	RavennaUI.skin_button(back)
	back.pressed.connect(_go_back)
	nav.add_child(back)
	var next := Button.new()
	next.name = "next"
	next.text = "Next"
	RavennaUI.skin_button(next)
	next.pressed.connect(_go_next)
	nav.add_child(next)


func _add_option(
	parent: Node, key: String, levels: Array, current: String, write: Callable
) -> void:
	var option := OptionButton.new()
	option.name = key
	for i in levels.size():
		option.add_item(levels[i])
		if levels[i] == current:
			option.select(i)
	option.item_selected.connect(func(index: int) -> void: write.call(option.get_item_text(index)))
	parent.add_child(option)


## Every toggle rewrites the full checked list (in TEMPERAMENTS order);
## normalize() — not the view — trims it to MAX_LEANINGS on the way out.
func _write_leanings() -> void:
	var checked := []
	for temperament in WorldConfig.TEMPERAMENTS:
		if _temperament_boxes[temperament].button_pressed:
			checked.append(temperament)
	wizard.set_founding("temperament_leanings", checked)


func _go_next() -> void:
	wizard.next()
	_show_page(wizard.page)


func _go_back() -> void:
	wizard.back()
	_show_page(wizard.page)


func _show_page(n: int) -> void:
	for i in _pages:
		_pages[i].visible = i == n
	if n == NewGameWizard.PAGES:
		_refresh_summary()


## summary() is only composed when page 5 is actually shown, so blank
## seed/name rolls happen exactly when the player sees them — and the
## rolled values persist into start() (wizard behavior, unchanged).
func _refresh_summary() -> void:
	var recap := wizard.summary()
	for key in SUMMARY_KEYS:
		_summary_labels[key].text = "%s: %s" % [key, recap[key]]
