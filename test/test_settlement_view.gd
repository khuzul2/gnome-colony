extends GutTest

## R3.2 [rav §R-build] — settlements on stage: for each live Settlement a cluster of
## mosaic building props reflecting its structure stock, placed deterministically
## (no Rng), nothing for a dead settlement, rebuilt only when the structures move.

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _settlement(sid: int, structures: Dictionary, adults := 20.0) -> Settlement:
	var s := Settlement.new(sid, 100.0, 1.0)
	s.by_stage[Enums.LifeStage.ADULT] = adults
	s.structures = structures.duplicate()
	return s


func _view() -> SettlementView:
	var v := SettlementView.new()
	add_child_autofree(v)
	return v


func _flat(_point: Vector2) -> float:
	return 0.0


func _rv(seed_value := 1901) -> RunView:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	add_child_autofree(view)
	return view


func test_prop_count_tracks_structure_count():
	var view := _view()
	var s := _settlement(2, {"dwelling": 3.0, "farm": 1.0, "basilica": 1.0})  # 5 structures
	view.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	assert_eq(view.cluster_prop_count(2), 5, "one prop per built structure")


func test_placement_is_deterministic_no_rng():
	var s := _settlement(2, {"dwelling": 2.0, "granary": 1.0})
	var a := _view()
	a.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	var b := _view()
	b.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	for i in a.cluster_prop_count(2):
		assert_eq(
			b._clusters[2].get_child(i).position,
			a._clusters[2].get_child(i).position,
			"same structures → same layout (a stable presentation function, no Rng)"
		)


func test_a_dead_settlement_renders_nothing():
	var view := _view()
	var s := _settlement(2, {"dwelling": 2.0}, 0.0)  # no souls
	view.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	assert_false(view.has_cluster(2), "no souls, no settlement on stage")


func test_unchanged_structures_reuse_the_cluster():
	var view := _view()
	var s := _settlement(2, {"dwelling": 2.0})
	view.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	var cluster: Node3D = view._clusters[2]
	view.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	assert_eq(view._clusters[2], cluster, "unchanged structures don't churn the nodes")


func test_runview_shows_a_settlements_buildings_on_stage():
	var view := _rv()
	var sid: int = -1
	for candidate in view.sid_places:
		if candidate != GameRun.HOME_SID:
			sid = candidate
			break
	assert_gt(sid, -1, "a frontier basin exists to settle")
	view.run.settlements[sid] = _settlement(sid, {"dwelling": 2.0, "shrine": 1.0})
	view._refresh_hud()
	assert_true(view.settlement_view.has_cluster(sid), "the settlement's buildings appear on stage")
	assert_eq(view.settlement_view.cluster_prop_count(sid), 3, "…one prop per structure")


# --- R3.3: growth & tier medallions ----------------------------------------


func test_a_new_structure_grows_in():
	var view := _view()
	var s := _settlement(2, {"dwelling": 1.0})
	view.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	var prop: Node3D = view._clusters[2].get_child(0)
	assert_lt(prop.scale.x, 1.0, "a raised building grows in, not popped full-size")
	view._process(SettlementView.GROW_SECONDS + 0.1)
	assert_almost_eq(prop.scale.x, 1.0, 0.01, "…and settles at full size")


func test_the_tier_medallion_swaps_on_a_tier_change():
	var view := _view()
	var s := _settlement(2, {"dwelling": 1.0})
	s.tier = Enums.SettlementTier.VILLAGE
	view.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	assert_true(view.has_medallion(2), "a village wears a civ-map medallion")
	assert_eq(
		view.medallion_glyph(2),
		SettlementView.TIER_MEDALLION[Enums.SettlementTier.VILLAGE],
		"…the rosette"
	)
	# Promote to city — the structure stock is UNCHANGED, but the medallion updates.
	s.tier = Enums.SettlementTier.CITY
	view.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	assert_eq(
		view.medallion_glyph(2),
		SettlementView.TIER_MEDALLION[Enums.SettlementTier.CITY],
		"the medallion swaps to the city monogram on the tier change"
	)


func test_a_hamlet_wears_no_medallion():
	var view := _view()
	var s := _settlement(2, {"dwelling": 1.0})  # tier defaults HAMLET
	view.refresh({2: s}, {2: "h"}, {"h": Vector3.ZERO}, Callable(self, "_flat"))
	assert_false(view.has_medallion(2), "a hamlet wears no medallion")
