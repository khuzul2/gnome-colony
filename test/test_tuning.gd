extends GutTest

## T12.3 — WorldConfig ingestion [setup §3–§5]: every option/preset
## resolves to a concrete parameter set the sim and world-gen honor.
## The setup spec names WHICH §17 parameters each slider scales and the
## direction; the per-level multipliers are interpretive, documented in
## tuning.gd. Defaults must resolve to exactly the §17 baselines (all
## multipliers 1.0) — sliders bend the spec numbers, never replace them.


func _defaults() -> Dictionary:
	return Tuning.resolve(WorldConfig.new())


func test_defaults_are_the_spec_baseline():
	var p := _defaults()
	assert_almost_eq(p["mortality"]["age_curve_mult"], 1.0, 0.0001, "Normal bends nothing")
	assert_almost_eq(p["discovery"]["base_rate_mult"], 1.0, 0.0001)
	assert_almost_eq(p["divinity"]["tier_threshold_mult"], 1.0, 0.0001)
	assert_almost_eq(p["chaos"]["tail_risk_mult"], 1.0, 0.0001)
	assert_almost_eq(p["faith"]["secularization_mult"], 1.0, 0.0001)
	assert_almost_eq(p["world"]["abundance_mult"], 1.0, 0.0001)
	assert_eq(p["scale"]["civ_tier_enabled"], true, "Kingdom default enables the civ tier")
	assert_eq(p["world"]["basin_count"], 6, "Medium = 6 basins [setup §4]")


func test_generation_pace_sets_the_clock():
	# setup §3.1: a life ≈ 30/20/10 min at 1× — 8,640 ticks per life [§17]
	# gives 4.8 / 7.2 / 14.4 ticks per second.
	var languid := _make("generation_pace", "languid")
	var brisk := _make("generation_pace", "brisk")
	assert_almost_eq(_defaults()["pace"]["ticks_per_second"], 7.2, 0.0001)
	assert_almost_eq(languid["pace"]["ticks_per_second"], 4.8, 0.0001)
	assert_almost_eq(brisk["pace"]["ticks_per_second"], 14.4, 0.0001)


func test_mortality_ladder_is_monotone():
	var gentle := _make("mortality", "gentle")
	var harsh := _make("mortality", "harsh")
	var brutal := _make("mortality", "brutal")
	assert_lt(gentle["mortality"]["age_curve_mult"], 1.0)
	assert_lt(1.0, harsh["mortality"]["age_curve_mult"])
	assert_lt(harsh["mortality"]["age_curve_mult"], brutal["mortality"]["age_curve_mult"])
	assert_lt(
		gentle["mortality"]["min_holders_mult"],
		brutal["mortality"]["min_holders_mult"],
		"Brutal makes knowledge precious [setup §3.2]"
	)


func test_discovery_and_divinity_and_chaos_bend_their_dials():
	var fast := _make("discovery_pace", "fast")
	assert_gt(fast["discovery"]["base_rate_mult"], 1.0)
	assert_gt(fast["discovery"]["magic_accrual_mult"], 1.0)
	var ascendant := _make("divinity", "ascendant")
	assert_lt(ascendant["divinity"]["tier_threshold_mult"], 1.0, "rapid godhood unlocks sooner")
	assert_gt(ascendant["divinity"]["magnitude_k_mult"], 1.0)
	var capricious := _make("chaos", "capricious")
	assert_gt(capricious["chaos"]["tail_risk_mult"], 1.0)
	assert_gt(capricious["chaos"]["corruption_mult"], 1.0, "mad prophets [setup §3.5]")
	assert_lt(capricious["chaos"]["ripeness_mult"], 1.0, "…that catch more easily")


func test_civilization_scale_gates_the_civ_tier():
	var intimate := _make("civilization_scale", "intimate")
	var civilization := _make("civilization_scale", "civilization")
	assert_eq(intimate["scale"]["civ_tier_enabled"], false, "Intimate keeps it personal")
	assert_eq(civilization["scale"]["civ_tier_enabled"], true)
	assert_lt(intimate["scale"]["population_cap"], civilization["scale"]["population_cap"])
	assert_lt(
		intimate["scale"]["individual_budget"],
		civilization["scale"]["individual_budget"],
		"§3.6 names individual_budget as a scale target (reviewer catch)"
	)
	assert_eq(
		_defaults()["scale"]["individual_budget"],
		Lod.DEFAULT_INDIVIDUAL_BUDGET,
		"Kingdom default = the §17 ~500 mark"
	)


func test_faith_slider_spans_coexist_to_secularizing():
	var coexist := _make("faith_enlightenment", "coexist")
	var secular := _make("faith_enlightenment", "secularizing")
	assert_eq(coexist["faith"]["secularization_mult"], 0.0, "Coexist: science never erodes faith")
	assert_gt(secular["faith"]["secularization_mult"], 1.0)
	assert_lt(
		coexist["faith"]["resistance_ceiling"],
		secular["faith"]["resistance_ceiling"],
		"sharper tension, stronger wards [setup §3.7]"
	)


func test_world_options_resolve():
	var lush := _make("resource_abundance", "lush")
	var sparse := _make("resource_abundance", "sparse")
	assert_gt(lush["world"]["abundance_mult"], 1.0)
	assert_lt(sparse["world"]["abundance_mult"], 1.0)
	var volatile := _make("hazard_frequency", "volatile")
	assert_gt(volatile["world"]["hazard_density_mult"], 1.0)
	var small := _make("region_size", "small")
	assert_eq(small["world"]["basin_count"], 3)
	var uniform := _make("biome_variety", "uniform")
	assert_eq(uniform["world"]["varied_biomes"], false)
	var no_fog := WorldConfig.new()
	no_fog.exploration_fog = false
	assert_eq(Tuning.resolve(no_fog)["world"]["exploration_fog"], false)


func test_every_gameplay_option_is_honored():
	# The §3–§5 contract in one sweep: flipping ANY enumerated option away
	# from its default must change the resolved parameter set. (Seed feeds
	# Rng directly; colony_name/culture_flavor are cosmetic labels.)
	var baseline := JSON.stringify(_defaults())
	var flips := {
		"generation_pace": "brisk",
		"mortality": "brutal",
		"discovery_pace": "fast",
		"divinity": "ascendant",
		"chaos": "capricious",
		"civilization_scale": "intimate",
		"faith_enlightenment": "secularizing",
		"region_size": "large",
		"resource_abundance": "lush",
		"hazard_frequency": "volatile",
		"biome_variety": "uniform",
	}
	for option in flips:
		var flipped := _make(option, flips[option])
		assert_ne(JSON.stringify(flipped), baseline, "%s must reach the parameter set" % option)
	var fogless := WorldConfig.new()
	fogless.exploration_fog = false
	assert_ne(JSON.stringify(Tuning.resolve(fogless)), baseline, "exploration_fog too")
	var big_band := WorldConfig.new()
	big_band.band_size = 8
	assert_eq(Tuning.resolve(big_band)["founding"]["band_size"], 8, "band size passes through [§5]")


func _make(option: String, level: String) -> Dictionary:
	var cfg := WorldConfig.new()
	cfg.set(option, level)
	return Tuning.resolve(cfg)
