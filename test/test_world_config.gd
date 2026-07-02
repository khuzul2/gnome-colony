extends GutTest


func test_defaults_match_setup_spec():
	var cfg := WorldConfig.new()
	# Tuning sheet [setup §3] — bold defaults
	assert_eq(cfg.generation_pace, "balanced")
	assert_eq(cfg.mortality, "normal")
	assert_eq(cfg.discovery_pace, "normal")
	assert_eq(cfg.divinity, "normal")
	assert_eq(cfg.chaos, "normal")
	assert_eq(cfg.civilization_scale, "kingdom")
	assert_eq(cfg.faith_enlightenment, "mild_drift")
	# World [setup §4]
	assert_eq(cfg.seed, 0)
	assert_eq(cfg.region_size, "medium")
	assert_eq(cfg.basin_count(), 6)
	assert_eq(cfg.resource_abundance, "normal")
	assert_eq(cfg.hazard_frequency, "normal")
	assert_eq(cfg.biome_variety, "varied")
	assert_true(cfg.exploration_fog)
	# Founding [setup §5]
	assert_eq(cfg.band_size, 4)
	assert_eq(cfg.temperament_leanings, ["curious"])
	assert_eq(cfg.culture_flavor, "")
	assert_eq(cfg.colony_name, "")
	# Gameplay constant, NOT a graphics setting [algo §14, setup §7.1]
	assert_eq(cfg.quicken_budget, 300)


func test_band_size_clamps_to_valid_range():
	var cfg := WorldConfig.new()
	cfg.band_size = 99
	cfg.normalize()
	assert_eq(cfg.band_size, 8, "band size caps at 8 (advanced max) [setup §5]")
	cfg.band_size = 1
	cfg.normalize()
	assert_eq(cfg.band_size, 3, "band size floors at 3 [setup §5]")


func test_invalid_level_strings_fall_back_to_defaults():
	var cfg := WorldConfig.new()
	cfg.mortality = "apocalyptic"
	cfg.region_size = "gigantic"
	cfg.normalize()
	assert_eq(cfg.mortality, "normal")
	assert_eq(cfg.region_size, "medium")


func test_valid_level_strings_survive_normalize():
	var cfg := WorldConfig.new()
	cfg.mortality = "brutal"
	cfg.region_size = "large"
	cfg.chaos = "capricious"
	cfg.normalize()
	assert_eq(cfg.mortality, "brutal")
	assert_eq(cfg.region_size, "large")
	assert_eq(cfg.basin_count(), 12)
	assert_eq(cfg.chaos, "capricious")


func test_temperament_leanings_validated():
	var cfg := WorldConfig.new()
	cfg.temperament_leanings = ["devout", "bloodthirsty", "hardy", "social"]
	cfg.normalize()
	assert_eq(
		cfg.temperament_leanings,
		["devout", "hardy"],
		"invalid entries dropped, then trimmed to the first 2 [setup §5]"
	)
	cfg.temperament_leanings = []
	cfg.normalize()
	assert_eq(cfg.temperament_leanings, ["curious"], "empty falls back to the default leaning")


func test_quicken_budget_clamps_to_positive():
	var cfg := WorldConfig.new()
	cfg.quicken_budget = -5
	cfg.normalize()
	assert_eq(cfg.quicken_budget, 1, "quicken budget must stay positive")
