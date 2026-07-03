class_name NewGameWizard
extends Control
## New Game wizard [plan T15.2, setup §1–§5]: five skippable pages —
## presets, the people, the world, the rules, summary — whose ONLY
## product is a valid WorldConfig. Presets are §1's curated bundles of
## every §3 slider plus world defaults; any slider can be nudged after.
## Quick Start launches Balanced Saga + a random world immediately.
## Blank seeds are rolled through Rng (never randi — the wizard runs
## before the sim, but the roll must still be reproducible); typed
## seeds are kept, shareable. A blank colony name gets a generated one
## (name parts are presentation strings). start() normalizes, so the
## config leaves legal no matter what the pages were fed.

## §1's preset table, verbatim: pace Slow/Normal/Brisk maps onto the
## §3.1 levels languid/balanced/brisk; world cells map onto §4 options.
const PRESETS := {
	"gentle_garden":
	{
		"generation_pace": "languid",
		"mortality": "gentle",
		"discovery_pace": "normal",
		"divinity": "humble",
		"chaos": "calm",
		"civilization_scale": "kingdom",
		"resource_abundance": "lush",
		"hazard_frequency": "calm",
	},
	"balanced_saga": {},  # the intended experience — WorldConfig defaults ARE the bundle
	"harsh_frontier":
	{
		"generation_pace": "balanced",
		"mortality": "brutal",
		"discovery_pace": "slow",
		"divinity": "normal",
		"chaos": "capricious",
		"civilization_scale": "kingdom",
		"resource_abundance": "sparse",
		"hazard_frequency": "volatile",
	},
	"epic_civilization":
	{
		"generation_pace": "brisk",
		"mortality": "normal",
		"discovery_pace": "fast",
		"divinity": "ascendant",
		"chaos": "normal",
		"civilization_scale": "civilization",
		"region_size": "large",
	},
	"custom": {},  # full control: defaults, everything exposed
}
const RULE_KEYS := [
	"generation_pace",
	"mortality",
	"discovery_pace",
	"divinity",
	"chaos",
	"civilization_scale",
	"faith_enlightenment",
]
const WORLD_KEYS := [
	"seed",
	"region_size",
	"resource_abundance",
	"hazard_frequency",
	"biome_variety",
	"exploration_fog",
	"environmental_events",
	"event_frequencies",
]
const FOUNDING_KEYS := ["band_size", "temperament_leanings", "culture_flavor", "colony_name"]
const PAGES := 5

## Generated-name parts (presentation strings, picked via Rng).
const NAME_HEADS := ["Moss", "Fern", "Root", "Burrow", "Thistle", "Alder", "Loam", "Bracken"]
const NAME_TAILS := ["bottom", "hollow", "reach", "stead", "warren", "fold", "brook", "den"]

var preset := "balanced_saga"
var page := 1

var _overrides := {}


func build() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	for id in PRESETS:
		var card := Button.new()
		card.name = id
		card.text = id.replace("_", " ")
		card.pressed.connect(set_preset.bind(id))
		column.add_child(card)


func set_preset(id: String) -> void:
	if PRESETS.has(id):
		preset = id


## Page 4 [§3]: nudge one rule slider; presets are starting positions.
func set_rule(key: String, level: Variant) -> void:
	if key in RULE_KEYS:
		_overrides[key] = level


## Page 3 [§4].
func set_world(key: String, value: Variant) -> void:
	if key in WORLD_KEYS:
		_overrides[key] = value


## Page 3 [user feature 2026-07-03]: dial one natural event's frequency —
## the per-event half of the environmental-events option. Levels are
## WorldConfig.EVENT_FREQUENCIES; ids the catalog doesn't know are
## dropped by normalize() on the way out, same as every other field.
func set_event_frequency(event_id: String, level: String) -> void:
	var frequencies: Dictionary = _overrides.get("event_frequencies", {})
	frequencies[event_id] = level
	_overrides["event_frequencies"] = frequencies


## Page 2 [§5].
func set_founding(key: String, value: Variant) -> void:
	if key in FOUNDING_KEYS:
		_overrides[key] = value


func next() -> void:
	page = mini(page + 1, PAGES)


func back() -> void:
	page = maxi(page - 1, 1)


## Page 5 [§2]: recap — the seed is shown copy/shareable.
func summary() -> Dictionary:
	var cfg := _compose()
	return {
		"preset": preset,
		"seed": cfg.seed,
		"colony_name": cfg.colony_name,
		"band_size": cfg.band_size,
		"region_size": cfg.region_size,
	}


## The wizard's product: preset bundle + nudges, rolled seed, generated
## name, normalized on the way out.
func start() -> WorldConfig:
	return _compose()


## §2's skip-ahead: Balanced Saga + random world, immediately.
func quick_start() -> WorldConfig:
	preset = "balanced_saga"
	_overrides.clear()
	return _compose()


func _compose() -> WorldConfig:
	var cfg := WorldConfig.new()
	var bundle: Dictionary = PRESETS[preset]
	for key in bundle:
		cfg.set(key, bundle[key])
	for key in _overrides:
		cfg.set(key, _overrides[key])
	# Rolls persist into the overrides: the seed the summary shows IS
	# the seed start() delivers — one roll per blank field, ever.
	if cfg.seed == 0:
		cfg.seed = Rng.randi_range(1, 2147483647)
		_overrides["seed"] = cfg.seed
	if cfg.colony_name == "":
		var head: String = NAME_HEADS[Rng.randi_range(0, NAME_HEADS.size() - 1)]
		var tail: String = NAME_TAILS[Rng.randi_range(0, NAME_TAILS.size() - 1)]
		cfg.colony_name = head + tail
		_overrides["colony_name"] = cfg.colony_name
	cfg.normalize()
	return cfg
