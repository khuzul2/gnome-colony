extends GutTest

## T11.2 — settlement tier [algo §14/§7]: aggregate stage-buckets + the
## per-season flow equations (births/deaths/aging/migration/research/
## belief relax), K = base_K·Σrichness·(1+0.5·ag+0.3·constr) with
## crowding = pop/K, and per-settlement knowledge with regional loss and
## re-spread via trade. §14 gives the flow SHAPES; closed forms it leaves
## open (migration pressure weights, stage-representative mortality ages,
## the fertile-pair calibration) are interpretive, documented in
## settlement_sim.gd.


func _hamlet(adults: float, base_k: float = 50.0, richness: float = 2.0) -> Settlement:
	var s := Settlement.new(0, base_k, richness)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	return s


func test_aggregation_from_individuals():
	var c := Colony.new()
	for i in 5:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("curious", 0.8)
		g.set_feeling(Devotion.YOU, "faith", 0.4)
	var child := c.spawn()
	child.age = 8.0
	child.stage = Enums.LifeStage.CHILD
	var s := Settlement.from_colony(c, 0, 50.0, 2.0)
	assert_eq(s.by_stage[Enums.LifeStage.ADULT], 5.0)
	assert_eq(s.by_stage[Enums.LifeStage.CHILD], 1.0)
	assert_almost_eq(s.pop(), 6.0, 0.0001)
	assert_almost_eq(s.mean_traits["curious"], 0.75, 0.0001, "5×0.8 + 1×0.5 default")
	assert_almost_eq(s.belief["faith"], 0.4 * 5.0 / 6.0, 0.0001)


func test_crowding_comes_from_the_spec_k():
	var c := Colony.new()
	var s := _hamlet(100.0)
	assert_almost_eq(s.k(c), 100.0, 0.0001, "base 50 · richness 2")
	assert_almost_eq(s.crowding(c), 1.0, 0.0001)
	var g := c.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	g.add_knowledge("agriculture")
	Knowledge.sync(c)
	assert_almost_eq(s.k(c), 150.0, 0.0001, "agriculture raises K [§17]")
	assert_almost_eq(s.crowding(c), 100.0 / 150.0, 0.0001, "…and crowding falls")


func test_flows_conserve_population_accounting():
	Rng.seed_with(11200)
	var c := Colony.new()
	var s := _hamlet(40.0, 50.0, 2.0)
	var before := s.pop()
	var report := SettlementSim.season_tick(c, s, 1.0)
	var expected: float = before + report["births"] - report["deaths"] - report["migration_out"]
	assert_almost_eq(s.pop(), expected, 0.0001, "no gnome appears or vanishes unaccounted [§14]")
	assert_gt(report["births"], 0.0, "well-fed uncrowded adults bear children")


func test_crowding_chokes_births_and_pushes_migration():
	Rng.seed_with(11201)
	var c := Colony.new()
	var packed := _hamlet(99.0)
	var packed_report := SettlementSim.season_tick(c, packed, 1.0)
	var roomy := _hamlet(30.0)
	var roomy_report := SettlementSim.season_tick(c, roomy, 1.0)
	assert_lt(
		packed_report["births"] / 99.0,
		roomy_report["births"] / 30.0,
		"births scale with (1 − crowding) [§14]"
	)
	assert_gt(packed_report["migration_out"], 0.0, "a packed basin pushes people out")
	assert_eq(roomy_report["migration_out"], 0.0, "a roomy, content one holds them")


func test_elders_die_faster_than_adults():
	Rng.seed_with(11202)
	var c := Colony.new()
	var old := Settlement.new(0, 50.0, 2.0)
	old.by_stage[Enums.LifeStage.ELDER] = 50.0
	var young := _hamlet(50.0)
	var old_report := SettlementSim.season_tick(c, old, 1.0)
	var young_report := SettlementSim.season_tick(c, young, 1.0)
	assert_gt(old_report["deaths"], young_report["deaths"], "Σ mortality(stage)·N_stage [§14]")


func test_infants_graduate_toward_adulthood():
	Rng.seed_with(11203)
	var c := Colony.new()
	var s := Settlement.new(0, 50.0, 2.0)
	s.by_stage[Enums.LifeStage.INFANT] = 12.0
	SettlementSim.season_tick(c, s, 1.0)
	assert_lt(s.by_stage[Enums.LifeStage.INFANT], 12.0, "a season moves 1/12 of the infant band")
	assert_gt(s.by_stage[Enums.LifeStage.CHILD], 0.0)


func test_aggregate_research_discovers():
	Rng.seed_with(11204)
	var c := Colony.new()
	var s := _hamlet(60.0)
	s.mean_traits["curious"] = 0.9
	var found := []
	for season in 80:
		found += SettlementSim.season_tick(c, s, 1.0, 0.0, {"fire": 6.0})["discovered"]
		if not found.is_empty():
			break
	assert_has(found, "fire", "folded settlements research without individual gnomes [§14]")
	assert_true(c.settlement_knowledge[0].has("fire"))


func test_regional_loss_and_trade_respread():
	var c := Colony.new()
	c.settlement_knowledge[0] = {"smithing": true}
	c.settlement_knowledge[1] = {"smithing": true, "writing": true}
	c.settlement_knowledge[0].erase("smithing")
	assert_true(
		c.settlement_knowledge[1].has("smithing"),
		"a craft lost in one settlement survives in another [§7]"
	)
	var spread := SettlementSim.trade(c, 0, 1)
	assert_has(spread, "smithing", "trade re-spreads the lost craft [§14]")
	assert_has(spread, "writing")
	assert_true(c.settlement_knowledge[0].has("smithing"))
	assert_true(c.settlement_knowledge[0].has("writing"))


func test_extinction_sweep_spares_folded_settlements():
	# Reviewer catch: a folded settlement holds knowledge without gnome
	# objects BY DESIGN — the caller names it and the T4.4 sweep skips it.
	# A settlement emptied by death is NOT folded and still goes dark.
	var c := Colony.new()
	c.settlement_knowledge[7] = {"smithing": true}
	c.settlement_knowledge[3] = {"pottery": true}
	Knowledge.check_extinction(c, [7])
	assert_true(
		c.settlement_knowledge[7].has("smithing"), "aggregate-held knowledge survives the sweep"
	)
	assert_false(
		c.settlement_knowledge[3].has("pottery"),
		"an UN-folded settlement with no living holders still goes dark [T4.4]"
	)


func test_aggregate_tracks_individual_control_loosely():
	# T11.2's tolerance check (T11.5's exit test is the strict one): the
	# same founding band, one simulated individually and one as flows,
	# lands in the same demographic neighborhood after 2 years.
	Rng.seed_with(11205)
	var cfg := WorldConfig.new()
	cfg.band_size = 8
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var aggregate := Settlement.from_colony(runner.colony, 0, 30.0, 2.0)
	var mirror := Colony.new()
	for season in 8:
		runner.run_days(TimeService.DAYS_PER_SEASON)
		SettlementSim.season_tick(mirror, aggregate, 1.0)
	runner.shutdown()
	var individual := float(runner.colony.population())
	var flows := aggregate.pop()
	assert_almost_eq(
		flows, individual, maxf(3.0, 0.5 * individual), "within tolerance (±50%, documented)"
	)


func test_belief_scalars_relax_like_individuals():
	Rng.seed_with(11206)
	var c := Colony.new()
	var s := _hamlet(10.0)
	s.belief["fear"] = 0.8
	SettlementSim.season_tick(c, s, 1.0)
	var expected := 0.8 * pow(1.0 - Belief.RELAX_PER_DAY, TimeService.DAYS_PER_SEASON)
	assert_almost_eq(s.belief["fear"], expected, 0.001, "aggregate mirrors §9's daily relaxation")
