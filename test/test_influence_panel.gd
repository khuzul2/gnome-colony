extends GutTest

## T14.1 — Phenomenon controls [design §3.1/§3.1b, algo §10/§11]: buttons
## per category, gated by d̄_peak tier (the REAL Devotion ladder, not a
## copy); act targeting — the panel arms an act, demands the selection
## kind its `target` field declares (point/area/settlement/region/
## region-edge/individual), and routes the correct selection to the
## runner via cast_requested. Choose the act, paint the where, release —
## no preview, no undo (§3.8): a paint disarms.


func _panel() -> InfluencePanel:
	var panel := InfluencePanel.new()
	add_child_autofree(panel)
	panel.build(Catalog.defs())
	return panel


func _colony_at_dbar(dbar: float, pop: int) -> Colony:
	var colony := Colony.new()
	for i in pop:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_feeling(Devotion.YOU, "faith", dbar)
	Devotion.update_unlocks(colony)
	return colony


func test_a_button_per_act_under_seven_category_roofs():
	var panel := _panel()
	var defs := Catalog.defs()
	for id in defs:
		assert_true(panel.buttons.has(id), "an act, a button: %s" % id)
		var category: int = defs[id]["category"]
		assert_true(
			panel.category_boxes.has(category),
			"…under its category roof (%d) [design §3.1]" % category
		)


func test_gating_matches_the_devotion_ladder():
	var panel := _panel()
	# A colony that barely believes: tier I — the gentle Elements only.
	panel.refresh(_colony_at_dbar(0.0, 10))
	assert_false(panel.buttons["still_air"].disabled, "tier-1 acts open at the start [§10 table]")
	assert_true(panel.buttons["long_dark"].disabled, "tier-2 stays locked below d̄ 0.15")
	assert_true(panel.buttons["day_twice"].disabled, "Wonders unthinkable at tier I")
	# Deep faith but a small camp: d̄ 0.5 crosses 0.30 (tier III) yet the
	# pop-50 floor holds tier IV shut [§10].
	panel.refresh(_colony_at_dbar(0.5, 10))
	assert_false(panel.buttons["the_blight"].disabled, "tier-3 opens at d̄ ≥ 0.30")
	assert_true(panel.buttons["birds_silent"].disabled, "Omens wait for pop ≥ 50 [§10 floor]")
	# The same depth in a town of 60: the floor lifts.
	panel.refresh(_colony_at_dbar(0.5, 60))
	assert_false(panel.buttons["birds_silent"].disabled, "…and lifts at pop 60")


func test_locked_categories_appear_only_when_earned():
	var panel := _panel()
	panel.refresh(_colony_at_dbar(0.0, 10))
	assert_true(panel.category_boxes[1].visible, "the Elements greet a new god")
	assert_false(
		panel.category_boxes[2].visible,
		"Earth & Stone (all tier-2 acts) is not even a rumor at tier I [design §3.1/§3.8]"
	)
	assert_false(panel.category_boxes[5].visible, "Omens neither [design §3.1]")
	assert_false(panel.category_boxes[7].visible, "Wonders neither")
	panel.refresh(_colony_at_dbar(0.5, 60))
	assert_true(panel.category_boxes[5].visible, "Omens appear when tier IV is earned")
	assert_false(panel.category_boxes[7].visible, "Wonders still wait")


func test_arming_respects_the_gate():
	var panel := _panel()
	panel.refresh(_colony_at_dbar(0.0, 10))
	assert_false(panel.arm("day_twice"), "a locked act will not arm")
	assert_eq(panel.armed(), "", "…nothing armed")
	assert_true(panel.arm("still_air"), "an open act arms")
	assert_eq(panel.armed(), "still_air")
	assert_eq(panel.armed_target_kind(), "area", "…and declares the paint it wants [§11]")


func test_each_target_kind_routes_the_correct_selection():
	var panel := _panel()
	panel.refresh(_colony_at_dbar(0.9, 1200))
	watch_signals(panel)
	var legs := [
		["landslide", {"place": "the_hollow"}, "the_hollow"],
		["still_air", {"place": "meadow", "radius": 3.0}, "meadow"],
		["birds_silent", {"place": "the_hollow", "settlement": 0}, "the_hollow"],
		["long_dark", {"region": "basin_2"}, "basin_2"],
		["coming_herd", {"edge": "eastern_pass"}, "eastern_pass"],
	]
	var casts := 0
	for leg in legs:
		assert_true(panel.arm(leg[0]), "%s arms at tier VI" % leg[0])
		assert_true(panel.paint(leg[1]), "%s accepts its selection kind" % leg[0])
		casts += 1
		assert_signal_emit_count(panel, "cast_requested", casts)
		var got: Array = get_signal_parameters(panel, "cast_requested", casts - 1)
		assert_eq(got[0], leg[0], "the act reaches the runner")
		assert_eq(got[1], leg[2], "…aimed at the painted where [§11 targeting]")
		assert_eq(got[2], leg[1], "…with the full selection riding along")


func test_individual_target_addresses_a_single_gnome():
	# The seed 15 hold no individual-target act (§18) — Visions may
	# address one gnome (§11), so the panel must route it; a synthetic
	# schema-valid definition proves the path.
	var vision := {
		"id": "apparition",
		"category": 6,
		"valence": "neutral",
		"target": "individual",
		"base_intensity": 0.3,
		"event_drama": 0.5,
		"tier": 5,
		"effects":
		{"material": 0.0, "population": 0.0, "discovery": 0.2, "belief": 0.5, "social": 0.0},
		"affordance_req": "any",
		"chain_hooks": [],
		"tail_risk": 0.03,
		"mundane": "only a dream",
	}
	assert_eq(Phenomenon.validate(vision), [], "the synthetic vision honors the §11 schema")
	var panel := InfluencePanel.new()
	add_child_autofree(panel)
	var defs := Catalog.defs()
	defs["apparition"] = vision
	panel.build(defs)
	panel.refresh(_colony_at_dbar(0.9, 1200))
	watch_signals(panel)
	assert_true(panel.arm("apparition"))
	assert_false(panel.paint({"place": "the_hollow"}), "a place is not a gnome — refused")
	assert_true(panel.paint({"gnome": 7, "place": "the_hollow"}), "one chosen gnome routes")
	var got: Array = get_signal_parameters(panel, "cast_requested", 0)
	assert_eq(got[1], "the_hollow", "the vision lands where the chosen one stands")
	assert_eq(got[2]["gnome"], 7, "…addressed to gnome 7 [design §3.1 Visions]")


func test_a_paint_of_the_wrong_kind_is_refused():
	var panel := _panel()
	panel.refresh(_colony_at_dbar(0.9, 1200))
	watch_signals(panel)
	panel.arm("landslide")
	assert_false(panel.paint({"region": "basin_2"}), "a point act refuses a region paint")
	assert_signal_emit_count(panel, "cast_requested", 0, "nothing reached the runner")
	assert_eq(panel.armed(), "landslide", "a refused paint keeps the act armed")


func test_release_disarms_no_preview_no_undo():
	var panel := _panel()
	panel.refresh(_colony_at_dbar(0.9, 1200))
	panel.arm("landslide")
	panel.paint({"place": "the_hollow"})
	assert_eq(panel.armed(), "", "released — the act must be armed anew [design §3.8]")
	assert_false(panel.paint({"place": "the_hollow"}), "…so a second paint casts nothing")
