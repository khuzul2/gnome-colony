extends GutTest

## T7.7 — valence & balance [algo §11 content rule, design §3.1]: the
## schema carries valence (T7.1); balance_report() enforces that every
## category with ≥2 entries offers both a kind and a cruel face, and that
## the overall set spans all three valences. The §18 seed set is
## deliberately dark-TILTED (4/7/4), so the rule is presence, not parity.


func _p(id: String, category: int, valence: String) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"valence": valence,
		"target": "area",
		"base_intensity": 0.5,
		"event_drama": 0.5,
		"tier": 1,
		"effects":
		{"material": 0.0, "population": 0.0, "discovery": 0.0, "belief": 0.3, "social": 0.0},
		"affordance_req": "any",
		"chain_hooks": [],
		"tail_risk": 0.03,
	}


func test_valence_spread_counts():
	var defs := [_p("a", 1, "benevolent"), _p("b", 1, "malevolent"), _p("c", 2, "neutral")]
	var spread := Phenomenon.valence_spread(defs)
	assert_eq(spread, {"benevolent": 1, "malevolent": 1, "neutral": 1})


func test_balanced_set_passes():
	var defs := [
		_p("rain", 1, "benevolent"),
		_p("drought", 1, "malevolent"),
		_p("fog", 1, "neutral"),
		_p("lone_omen", 5, "neutral"),
	]
	assert_eq(Phenomenon.balance_report(defs), [])


func test_cruel_only_category_fails():
	var defs := [
		_p("blight", 3, "malevolent"),
		_p("plague", 3, "malevolent"),
		_p("boon", 1, "benevolent"),
		_p("bane", 1, "malevolent"),
	]
	var errors := Phenomenon.balance_report(defs)
	assert_false(errors.is_empty(), "a shepherd-god must never be starved in a stocked category")


func test_missing_valence_overall_fails():
	var defs := [_p("a", 1, "malevolent"), _p("b", 1, "neutral"), _p("c", 2, "malevolent")]
	var errors := Phenomenon.balance_report(defs)
	assert_false(errors.is_empty(), "all three valences must exist somewhere in the arsenal")


func test_single_entry_categories_are_exempt():
	var defs := [
		_p("boon", 1, "benevolent"),
		_p("bane", 1, "malevolent"),
		_p("sign", 1, "neutral"),
		_p("wonder", 7, "malevolent"),
	]
	assert_eq(
		Phenomenon.balance_report(defs), [], "a category holding one act can't balance itself"
	)
