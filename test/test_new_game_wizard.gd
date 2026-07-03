extends GutTest

## T15.2 — New Game wizard [setup §1–§5]: presets are curated bundles
## of every §3 slider plus world/founding defaults; any slider can be
## nudged before starting; the wizard's only product is a valid
## WorldConfig. Quick Start launches Balanced Saga + a random world
## immediately. Seeds come from Rng (never randi) — typed seeds are
## kept, blank ones rolled; the colony name is generated when blank.


func _wizard() -> NewGameWizard:
	var wizard := NewGameWizard.new()
	add_child_autofree(wizard)
	wizard.build()
	return wizard


func test_balanced_saga_is_preselected_and_default():
	var wizard := _wizard()
	assert_eq(wizard.preset, "balanced_saga", "the default card [§2 page 1]")
	var cfg := wizard.start()
	assert_eq(cfg.generation_pace, "balanced")
	assert_eq(cfg.mortality, "normal")
	assert_eq(cfg.civilization_scale, "kingdom", "the intended experience, verbatim [§1]")


func test_each_preset_maps_to_the_spec_bundle():
	var wizard := _wizard()
	wizard.set_preset("gentle_garden")
	var cfg := wizard.start()
	assert_eq(cfg.generation_pace, "languid", "Gentle Garden: Slow pace [§1]")
	assert_eq(cfg.mortality, "gentle")
	assert_eq(cfg.divinity, "humble")
	assert_eq(cfg.chaos, "calm")
	assert_eq(cfg.resource_abundance, "lush", "…Lush / Calm world")
	assert_eq(cfg.hazard_frequency, "calm")
	wizard.set_preset("harsh_frontier")
	cfg = wizard.start()
	assert_eq(cfg.mortality, "brutal", "Harsh Frontier: Brutal [§1]")
	assert_eq(cfg.discovery_pace, "slow")
	assert_eq(cfg.chaos, "capricious")
	assert_eq(cfg.resource_abundance, "sparse", "…Sparse / Volatile world")
	assert_eq(cfg.hazard_frequency, "volatile")
	wizard.set_preset("epic_civilization")
	cfg = wizard.start()
	assert_eq(cfg.generation_pace, "brisk", "Epic Civilization: Brisk [§1]")
	assert_eq(cfg.discovery_pace, "fast")
	assert_eq(cfg.divinity, "ascendant")
	assert_eq(cfg.civilization_scale, "civilization")
	assert_eq(cfg.region_size, "large", "…Large / Normal world")


func test_any_slider_can_be_nudged_after_the_preset():
	var wizard := _wizard()
	wizard.set_preset("gentle_garden")
	wizard.set_rule("mortality", "harsh")
	wizard.set_world("biome_variety", "uniform")
	wizard.set_founding("band_size", 6)
	wizard.set_founding("temperament_leanings", ["hardy", "devout"])
	var cfg := wizard.start()
	assert_eq(cfg.mortality, "harsh", "presets are starting positions, not locks [§1]")
	assert_eq(cfg.chaos, "calm", "…untouched preset values remain")
	assert_eq(cfg.biome_variety, "uniform")
	assert_eq(cfg.band_size, 6)
	assert_eq(cfg.temperament_leanings, ["hardy", "devout"])


func test_the_config_leaves_valid_and_normalized():
	var wizard := _wizard()
	wizard.set_founding("band_size", 99)
	wizard.set_rule("mortality", "apocalyptic")
	var cfg := wizard.start()
	assert_eq(cfg.band_size, WorldConfig.BAND_SIZE_MAX, "normalize() clamps the exit [§5]")
	assert_eq(cfg.mortality, "normal", "an unknown level falls back to the default")


func test_seeds_typed_or_rolled_never_zero():
	Rng.seed_with(15200)
	var wizard := _wizard()
	wizard.set_world("seed", 424242)
	assert_eq(wizard.start().seed, 424242, "a typed seed is kept, shareable [§4]")
	var blank := _wizard()
	var cfg := blank.start()
	assert_ne(cfg.seed, 0, "a blank seed is rolled (via Rng, never randi)")
	# Replay the identical draw sequence: typed-seed start (name only),
	# then a blank start — the same rolls must fall out.
	Rng.seed_with(15200)
	var wizard_again := _wizard()
	wizard_again.set_world("seed", 424242)
	wizard_again.start()
	var blank_again := _wizard()
	assert_eq(blank_again.start().seed, cfg.seed, "…and the roll is Rng-reproducible")


func test_colony_name_generated_when_blank_kept_when_given():
	Rng.seed_with(15201)
	var wizard := _wizard()
	var cfg := wizard.start()
	assert_ne(cfg.colony_name, "", "a nameless colony gets a generated name [§5]")
	var named := _wizard()
	named.set_founding("colony_name", "Mossbottom")
	assert_eq(named.start().colony_name, "Mossbottom")


func test_quick_start_is_balanced_saga_plus_random_world():
	Rng.seed_with(15202)
	var wizard := _wizard()
	var cfg := wizard.quick_start()
	assert_eq(cfg.mortality, "normal", "Quick Start = Balanced Saga [§2]")
	assert_eq(cfg.civilization_scale, "kingdom")
	assert_ne(cfg.seed, 0, "…with a random world, immediately")
	assert_ne(cfg.colony_name, "", "…ready to play, no page 5")


func test_the_pages_walk_one_to_five():
	var wizard := _wizard()
	assert_eq(wizard.page, 1, "the wizard opens on the preset cards [§2]")
	wizard.back()
	assert_eq(wizard.page, 1, "no page zero")
	for i in 6:
		wizard.next()
	assert_eq(wizard.page, 5, "summary is the last page")
	var summary: Dictionary = wizard.summary()
	assert_true(summary.has("seed"), "the summary shows the seed, copy/shareable [§2]")
	assert_true(summary.has("preset"))
	var cfg := wizard.start()
	assert_eq(cfg.seed, summary["seed"], "the seed the summary promised IS the seed you get")
	assert_eq(cfg.colony_name, summary["colony_name"], "…and the name too")
