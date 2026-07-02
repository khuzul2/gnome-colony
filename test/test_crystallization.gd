extends GutTest

## T6.3 — Layer B crystallization [algo §9]: a feeling held by
## ≥ max(5, 3% of settlement) gnomes at ≥ 0.7 for ≥ 1 season crystallizes
## into a named belief-object; strength = backing feeling × holder
## fraction; emits belief_formed. Axis→kind: fear→taboo, awe→rite,
## reverence→place_reverence, faith→theology (axis-primary reading of the
## §9 table, whose rows overlap). Taboo writes a cursed place-tag,
## place-reverence a blessed one.

const SEASON := 24


func _colony(n: int) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
	return c


func _feel_all(c: Colony, subject: String, axis: String, level: float, count: int = -1) -> void:
	var done := 0
	for g in c.living():
		if count >= 0 and done >= count:
			return
		g.set_feeling(subject, axis, level)
		done += 1


func _run_days(c: Colony, days: int) -> Array:
	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.belief_formed.connect(listener)
	for day in days:
		Belief.crystallize_tick(c, 1.0)
	EventBus.belief_formed.disconnect(listener)
	return events


func test_sustained_shared_fear_crystallizes_a_taboo():
	var c := _colony(8)
	_feel_all(c, "eastern_ridge", "fear", 0.8)
	var events := _run_days(c, SEASON)
	assert_eq(events.size(), 1)
	assert_eq(events[0]["kind"], "taboo")
	assert_eq(events[0]["subject"], "eastern_ridge")
	assert_eq(c.beliefs.size(), 1)
	assert_almost_eq(c.beliefs[0]["strength"], 0.8 * 1.0, 0.0001, "feeling × holder fraction")
	assert_almost_eq(c.place_tags["eastern_ridge"]["cursed"], 0.8, 0.0001)


func test_below_strength_never_crystallizes():
	var c := _colony(8)
	_feel_all(c, "ridge", "fear", 0.65)
	assert_eq(_run_days(c, SEASON * 3).size(), 0)


func test_too_few_holders_never_crystallizes():
	var c := _colony(8)
	_feel_all(c, "ridge", "fear", 0.9, 4)
	assert_eq(_run_days(c, SEASON * 3).size(), 0, "4 holders < min 5")


func test_duration_must_be_sustained():
	var c := _colony(8)
	_feel_all(c, "ridge", "fear", 0.8)
	assert_eq(_run_days(c, SEASON - 4).size(), 0, "20 days is not a season")
	_feel_all(c, "ridge", "fear", 0.2)
	_run_days(c, 2)
	_feel_all(c, "ridge", "fear", 0.8)
	assert_eq(_run_days(c, SEASON - 4).size(), 0, "the dip reset the clock")


func test_axis_kind_mapping_and_blessed_tag():
	var c := _colony(8)
	_feel_all(c, "spring", "reverence", 0.9)
	var events := _run_days(c, SEASON)
	assert_eq(events[0]["kind"], "place_reverence")
	assert_almost_eq(c.place_tags["spring"]["blessed"], 0.9, 0.0001)
	var c2 := _colony(8)
	_feel_all(c2, "harvest_feast", "awe", 0.8)
	assert_eq(_run_days(c2, SEASON)[0]["kind"], "rite")
	var c3 := _colony(8)
	_feel_all(c3, "unseen_will", "faith", 0.8)
	assert_eq(_run_days(c3, SEASON)[0]["kind"], "theology")


func test_no_duplicate_objects():
	var c := _colony(8)
	_feel_all(c, "ridge", "fear", 0.9)
	var events := _run_days(c, SEASON * 4)
	assert_eq(events.size(), 1, "the same taboo never crystallizes twice")
	assert_eq(c.beliefs.size(), 1)


func test_belief_objects_round_trip_through_serializer():
	var c := _colony(8)
	_feel_all(c, "ridge", "fear", 0.9)
	_run_days(c, SEASON)
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(c))
	assert_eq(restored.beliefs, c.beliefs)
	assert_eq(restored.place_tags, c.place_tags)
