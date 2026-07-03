extends GutTest

## T16.3 — telemetry hooks [plan Phase 16, design §1.9]: an optional
## run-summary for balancing — generations, peak pop, techs, schisms,
## wars — accrued from the same event stream the Chronicle reads, plus
## day-by-day peaks. Plain data, exportable as JSON.


func test_the_summary_carries_the_balancing_fields():
	var telemetry := Telemetry.new()
	var colony := Colony.new()
	for i in 6:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.generation = i % 4
	colony.settlement_knowledge[0] = {"fire": true, "weaving": true, "iron": true}
	telemetry.track_day(colony)
	colony.remove(colony.gnomes.keys()[0])
	telemetry.track_day(colony)
	telemetry.record({"type": "war", "day": 300})
	telemetry.record({"type": "schism", "day": 200})
	telemetry.record({"type": "schism", "day": 260})
	telemetry.record({"type": "discovery", "day": 120, "id": "iron"})
	var summary: Dictionary = telemetry.summary(colony)
	for field in ["generations", "peak_pop", "techs", "schisms", "wars"]:
		assert_true(summary.has(field), "the balancing sheet has %s [T16.3]" % field)
	assert_eq(summary["generations"], 3, "furthest generation")
	assert_eq(summary["peak_pop"], 6, "the peak, not the survivor count")
	assert_eq(summary["techs"], 3, "distinct known ids")
	assert_eq(summary["schisms"], 2)
	assert_eq(summary["wars"], 1)


func test_the_export_travels_as_json():
	var telemetry := Telemetry.new()
	var colony := Colony.new()
	telemetry.record({"type": "war", "day": 1})
	var exported: String = telemetry.export_json(colony)
	var parsed: Variant = JSON.parse_string(exported)
	assert_not_null(parsed, "valid JSON")
	assert_eq(int(parsed["wars"]), 1, "…carrying the counts")


func test_the_chronicle_and_telemetry_read_one_stream():
	# The Chronicle composes from the same recorded events — no second
	# bookkeeping to drift out of sync.
	var telemetry := Telemetry.new()
	var colony := Colony.new()
	var events := [
		{"type": "war", "day": 300},
		{"type": "discovery", "day": 120, "id": "iron"},
		{"type": "settlement_founded", "day": 20, "sid": 1},
	]
	for event in events:
		telemetry.record(event)
	var screen := ChronicleScreen.new()
	add_child_autofree(screen)
	var record: Dictionary = screen.compose(colony, telemetry.events, {"colony_name": "x"})
	assert_eq(record["wars"], telemetry.summary(colony)["wars"], "one stream, two readers")
