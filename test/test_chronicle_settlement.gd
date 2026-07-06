extends GutTest

## R3.4 [rav §R-build] — the settlement chronicle & aftermath vocabulary. Two
## readers of the SAME civic story, at two ranges:
##  · the end-of-run Chronicle reads as CIVIC DEVELOPMENT — what they built
##    (a tally of raised structures) and the height they reached (peak tier);
##  · the per-cast Aftermath surfaces "what they built, and why" — a structure
##    raised in the wake of a phenomenon is attributed to it, so the
##    [rav §R-infl] loop (your act → their response) is legible in hindsight
##    (design §2.7). The Aftermath mutates no sim state.

# --- the end-of-run Chronicle: civic development -----------------------------


func _telemetry() -> Array:
	return [
		{"type": "settlement_founded", "day": 20, "sid": 1},
		{"type": "structure_built", "day": 40, "sid": 1, "building": "farm"},
		{"type": "structure_built", "day": 55, "sid": 1, "building": "farm"},
		{"type": "structure_built", "day": 90, "sid": 1, "building": "basilica"},
		{"type": "settlement_tier_changed", "day": 60, "sid": 1, "from": 0, "to": 1},
		{"type": "settlement_tier_changed", "day": 200, "sid": 1, "from": 1, "to": 2},
	]


func test_the_chronicle_reads_as_civic_development():
	var screen := ChronicleScreen.new()
	add_child_autofree(screen)
	var record: Dictionary = screen.compose(Colony.new(), _telemetry(), {})
	assert_eq(
		record["structures"], {"farm": 2, "basilica": 1}, "what they built, tallied [§R-build]"
	)
	assert_eq(record["peak_tier"], "town", "…and the height they reached — the top tier crossed")


func test_a_run_that_never_grew_reads_as_a_hamlet():
	var screen := ChronicleScreen.new()
	add_child_autofree(screen)
	var record: Dictionary = screen.compose(Colony.new(), [], {})
	assert_eq(record["structures"], {}, "nothing built")
	assert_eq(record["peak_tier"], "hamlet", "a colony that never crossed a tier stayed a hamlet")


# --- the per-cast Aftermath: what they built, and why ------------------------


func _panel() -> AftermathPanel:
	var panel := AftermathPanel.new()
	add_child_autofree(panel)
	return panel


func test_the_aftermath_attributes_a_build_to_its_phenomenon():
	var panel := _panel()
	panel.begin("the_withering")
	EventBus.phenomenon.emit(
		{"type": "drought", "place": "the_hollow", "intensity": 0.6, "valence": "malevolent"}
	)
	EventBus.structure_built.emit({"sid": 1, "building": "farm", "tier": 1})
	assert_eq(panel.built.size(), 1, "the raised structure reaches the hindsight page")
	assert_eq(panel.built[0]["building"], "farm", "…named")
	assert_eq(
		panel.built[0]["after"], "drought", "…and tied to the phenomenon that drove it [§R-infl]"
	)
	assert_eq(panel.works_box.get_child_count(), 1, "…and rendered as a line of works")


func test_a_build_with_no_phenomenon_stands_unattributed():
	var panel := _panel()
	panel.begin("still_air")
	EventBus.structure_built.emit({"sid": 1, "building": "well", "tier": 0})
	assert_eq(panel.built.size(), 1, "a spontaneous work still shows")
	assert_eq(panel.built[0]["after"], "", "no phenomenon this cast — no false attribution")


func test_the_root_phenomenon_earns_the_attribution():
	# A cascade: the ROOT (the act's manifestation) is credited, not a late domino.
	var panel := _panel()
	panel.begin("landslide")
	EventBus.phenomenon.emit(
		{"type": "landslide", "place": "the_hollow", "intensity": 0.6, "valence": "malevolent"}
	)
	EventBus.phenomenon.emit(
		{"type": "dam_flood", "place": "the_hollow", "intensity": 0.4, "consequence": true}
	)
	EventBus.structure_built.emit({"sid": 1, "building": "wall", "tier": 1})
	assert_eq(panel.built[0]["after"], "landslide", "the root cause of the cast earns the credit")


func test_begin_clears_the_ledger_of_works():
	var panel := _panel()
	panel.begin("landslide")
	EventBus.phenomenon.emit(
		{"type": "landslide", "place": "the_hollow", "intensity": 0.6, "valence": "malevolent"}
	)
	EventBus.structure_built.emit({"sid": 1, "building": "wall", "tier": 1})
	panel.begin("still_air")
	assert_eq(panel.built.size(), 0, "a new act, a blank ledger of works")
	assert_eq(panel.works_box.get_child_count(), 0, "…and the rendered rows with it")
	# …and the cleared root no longer credits a fresh build.
	EventBus.structure_built.emit({"sid": 1, "building": "farm", "tier": 1})
	assert_eq(panel.built[0]["after"], "", "the new cast starts with no phenomenon to attribute to")
