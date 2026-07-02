extends GutTest

## T7.1 — phenomenon schema [algo §11/§18]: data-driven definitions with
## category, valence, taint (benevolent only), target, intensities, tier,
## five-axis effects (social may be the literal "=culture"), affordance,
## chain hooks, tail risk. Target kinds are the union of §11's list and
## §18's index (which adds "region" — long_dark uses it).


func _valid() -> Dictionary:
	return {
		"id": "landslide",
		"category": 2,
		"valence": "malevolent",
		"target": "point",
		"base_intensity": 0.6,
		"event_drama": 0.6,
		"tier": 2,
		"effects":
		{
			"material": -0.3,
			"population": -0.3,
			"discovery": 0.4,
			"belief": 0.5,
			"social": "=culture"
		},
		"affordance_req": "slope",
		"chain_hooks":
		[{"phenom": "dam_flood", "prob": 0.15}, {"phenom": "cursed_place", "prob": 0.2}],
		"tail_risk": 0.03,
	}


func test_valid_definition_passes():
	assert_eq(Phenomenon.validate(_valid()), [], "a §18-shaped entry validates clean")


func test_missing_required_fields_fail():
	var d := _valid()
	d.erase("id")
	d.erase("effects")
	var errors := Phenomenon.validate(d)
	assert_false(errors.is_empty())


func test_category_range():
	var d := _valid()
	d["category"] = 8
	assert_false(Phenomenon.validate(d).is_empty(), "categories are 1–7")


func test_valence_values():
	var d := _valid()
	d["valence"] = "spiteful"
	assert_false(Phenomenon.validate(d).is_empty())


func test_taint_only_on_benevolent():
	var d := _valid()
	d["taint"] = "tainted"
	assert_false(Phenomenon.validate(d).is_empty(), "malevolent acts cannot carry boon taint")
	d["valence"] = "benevolent"
	assert_eq(Phenomenon.validate(d), [])
	d["taint"] = "murky"
	assert_false(Phenomenon.validate(d).is_empty())


func test_social_accepts_number_or_culture_literal():
	var d := _valid()
	d["effects"]["social"] = 0.4
	assert_eq(Phenomenon.validate(d), [])
	d["effects"]["social"] = "=culture"
	assert_eq(Phenomenon.validate(d), [])
	d["effects"]["social"] = "=vibes"
	assert_false(Phenomenon.validate(d).is_empty())


func test_target_kinds():
	for kind in ["point", "area", "settlement", "region", "region-edge", "individual"]:
		var d := _valid()
		d["target"] = kind
		assert_eq(Phenomenon.validate(d), [], "%s is a legal target" % kind)
	var bad := _valid()
	bad["target"] = "everyone"
	assert_false(Phenomenon.validate(bad).is_empty())


func test_chain_hook_shape():
	var d := _valid()
	d["chain_hooks"] = [{"phenom": "flood"}]
	assert_false(Phenomenon.validate(d).is_empty(), "hooks need prob")
	d["chain_hooks"] = [{"phenom": "flood", "prob": 1.5}]
	assert_false(Phenomenon.validate(d).is_empty(), "prob is a probability")


func test_effect_axes_complete_and_bounded():
	var d := _valid()
	d["effects"].erase("belief")
	assert_false(Phenomenon.validate(d).is_empty(), "all five axes required")
	var e := _valid()
	e["effects"]["material"] = -2.0
	assert_false(Phenomenon.validate(e).is_empty(), "effects ≈ [-1, 1]")
