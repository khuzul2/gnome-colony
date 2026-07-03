extends GutTest

## T16.5 — diversity & balance invariants [plan Phase 16, algo §2/§8,
## §10/§11, §17 "tyranny vs shepherd"]. Each claim is tested at the
## grain where the spec quantifies it:
##  (a) diversity floor — §8's mutation noise must keep trait variance
##      from collapsing over generations (floor is a structural
##      tripwire; the spec names no number — probes on this container
##      landed 60-year variances in [0.0003, 0.005]);
##  (b) tyrant = higher per-act potency AND higher instability — the
##      individual grain, where valence potency and the terror tax act
##      (§17: strong terror hits the 0.8 fracture line fast);
##  (c) shepherd = higher SUSTAINED devotion & stability — §17's own
##      note resolves this as "gentler acts on a stable, LARGER
##      civilization reach higher sustained magnitude": the size cap
##      binds at the settlement grain via the −0.3·unrest birth damp
##      (wired at T16.5), where K is not the binding constraint;
##  (d) both playstyles survive — neither strictly dominates.

const VARIANCE_FLOOR := 0.0001  # structural collapse tripwire, not §17


func _play(act: String, years: int) -> Dictionary:
	Rng.seed_with(16500)
	var cfg := WorldConfig.new()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var world := WorldState.new()
	world.affordances["the_hollow"] = ["farmland"]
	var defs := Catalog.defs()
	var handlers := Catalog.handlers()
	var last_season := runner.time.season()
	var intensities := []
	var days_to_fracture_line := -1
	for day in years * TimeService.DAYS_PER_YEAR:
		for g in runner.colony.living():
			g.location = "the_hollow"
		runner.tick()
		Belief.propagate_tick(runner.colony, 1.0)
		Belief.decay_tick(runner.colony, 1.0)
		Belief.crystallize_tick(runner.colony, 1.0)
		Devotion.update_unlocks(runner.colony)
		Devotion.unrest_tick(runner.colony, 1.0)
		Prophet.tick(runner.colony, 1.0)
		if days_to_fracture_line < 0 and Devotion.fracture_due(runner.colony):
			days_to_fracture_line = day
		if runner.time.season() != last_season:
			last_season = runner.time.season()
			var stimuli := Influence.cast_with_cascade(
				runner.colony,
				world,
				defs,
				act,
				"the_hollow",
				Devotion.magnitude_multiplier(runner.colony),
				Devotion.valence_potency(defs[act]["valence"]),
				handlers
			)
			for stim in stimuli:
				Influence.appraise_witnesses(runner.colony, stim)
				if stim.get("drama", 0.0) > 0.0:
					Devotion.attribute(
						runner.colony, stim["drama"], 0.0, stim["valence"], runner.colony.living()
					)
				if not stim.get("consequence", false) and not stim["type"].begins_with("tail:"):
					intensities.append(stim["intensity"])
	runner.shutdown()
	var mean_potency := 0.0
	for x in intensities:
		mean_potency += x
	mean_potency /= maxi(1, intensities.size())
	return {
		"pop": runner.colony.population(),
		"unrest": runner.colony.unrest,
		"potency": mean_potency,
		"fracture_day": days_to_fracture_line,
	}


func test_the_moral_tradeoff_is_mechanical_not_narrative():
	var tyrant := _play("the_blight", 20)
	var shepherd := _play("the_quickening", 20)
	gut.p("tyrant:   %s" % [tyrant])
	gut.p("shepherd: %s" % [shepherd])
	assert_gt(
		tyrant["potency"],
		shepherd["potency"] * 1.5,
		"cruelty lands harder per use [§11 valence potency]"
	)
	assert_gt(tyrant["unrest"], shepherd["unrest"] + 0.5, "…and pays for it in unrest [§10]")
	assert_gt(tyrant["fracture_day"], -1, "the terror-state reaches the fracture line [§17]")
	# (§17's "~30-40 days" figure presumes an ESTABLISHED strong terror
	# state — high mass, deeply negative flavor. This run boils from a
	# cold start, so only the destination is asserted, not that pace.)
	assert_eq(shepherd["fracture_day"], -1, "the shepherd never boils")
	assert_gt(tyrant["pop"], 0, "the tyrant's people survive [T16.5: both viable]")
	assert_gt(shepherd["pop"], 0, "…and the shepherd's flourish")


func test_the_shepherd_holds_more_sustained_devotion():
	# The settlement grain, where the terror-state's size cap binds:
	# same faith depth, ample K — the boiling colony's birth flow runs
	# at ×0.7 (§17 −0.3·unrest), so the stable civilization grows
	# LARGER, and total devotional weight D = faith·pop follows [§10].
	var results := {}
	for style in ["shepherd", "tyrant"]:
		Rng.seed_with(16501)
		var colony := Colony.new()
		colony.unrest = 1.0 if style == "tyrant" else 0.0
		var s := Settlement.new(0, 400.0, 1.0)
		s.by_stage[Enums.LifeStage.ADULT] = 20.0
		for season in 60:
			# Depth held constant (as sustained acts would): the leg
			# isolates §10's SIZE term of D = faith·pop.
			s.belief["faith"] = 0.5
			SettlementSim.season_tick(colony, s, 1.0)
		results[style] = {"pop": s.pop(), "d_total": s.belief["faith"] * s.pop()}
	gut.p("settlement century: %s" % [results])
	assert_gt(
		results["shepherd"]["pop"],
		results["tyrant"]["pop"],
		"the stable civilization grows larger [§17 unrest birth damp]"
	)
	# With depth held constant this restates the pop comparison through
	# §10's identity D = faith·pop — kept as the named claim the plan
	# asks for, but the independent evidence above is the SIZE gap
	# (reviewer note: not a second mechanism).
	assert_gt(
		results["shepherd"]["d_total"],
		results["tyrant"]["d_total"],
		"…and carries more sustained devotional weight [§10 D = Σfaith]"
	)


func test_trait_variance_never_collapses():
	Rng.seed_with(16510)
	var cfg := WorldConfig.new()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	runner.run_days(60 * TimeService.DAYS_PER_YEAR)
	var living := runner.colony.living()
	assert_gt(living.size(), 10, "a real population to measure")
	assert_gte(runner.max_generation, 3, "…generations deep")
	var floor_hit := ""
	for key in Enums.TRAIT_KEYS:
		var mean := 0.0
		for g in living:
			mean += g.traits[key]
		mean /= living.size()
		var variance := 0.0
		for g in living:
			variance += pow(g.traits[key] - mean, 2)
		variance /= living.size()
		gut.p("σ²(%s) = %.5f" % [key, variance])
		if variance < VARIANCE_FLOOR:
			floor_hit = key
	runner.shutdown()
	assert_eq(floor_hit, "", "no trait's variance collapsed below the floor [§2/§8 mutation noise]")
