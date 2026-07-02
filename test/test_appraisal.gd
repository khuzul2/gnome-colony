extends GutTest

## T7.4 — per-witness appraisal [algo §11/§9]: each witness reads the
## stimulus through its traits. Fear writes to BOTH the place and the
## phenomenon-type (§9: "toward the relevant phenomenon-type and place"),
## sharing one habituation bump per event. Curious (>0.6) gnomes bank a
## discovery memory. Safety spikes by intensity·(0.3+timid) — the
## prototype-spec appraisal formula.

var _def := {
	"id": "landslide",
	"category": 2,
	"valence": "malevolent",
	"target": "point",
	"base_intensity": 0.6,
	"event_drama": 0.6,
	"tier": 2,
	"effects":
	{"material": -0.3, "population": -0.3, "discovery": 0.4, "belief": 0.5, "social": "=culture"},
	"affordance_req": "slope",
	"chain_hooks": [],
	"tail_risk": 0.03,
}


func _witness(id: int, timid: float, curious: float) -> GnomeData:
	var g := GnomeData.new(id)
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	g.location = "ridge"
	g.set_trait("timid", timid)
	g.set_trait("curious", curious)
	return g


func _stim() -> Dictionary:
	return {
		"type": "landslide",
		"place": "ridge",
		"intensity": 0.6,
		"drama": 0.6,
		"valence": "malevolent",
		"effects": _def["effects"],
	}


func test_timid_and_curious_diverge_on_the_same_event():
	var colony := Colony.new()
	var coward := _witness(0, 1.0, 0.2)
	var scholar := _witness(1, 0.0, 0.9)
	colony.add(coward)
	colony.add(scholar)
	Influence.appraise_witnesses(colony, _stim())
	assert_gt(
		coward.get_feeling("ridge", "fear"),
		scholar.get_feeling("ridge", "fear"),
		"the timid read wrath where the brave read rock"
	)
	var scholar_remembers := false
	for m in scholar.memory:
		if m.get("event", "") == "discovery_opportunity":
			scholar_remembers = true
	assert_true(scholar_remembers, "the curious eye the strange new ore")
	assert_eq(coward.memory.size(), 0, "no opportunity reading for the fearful")


func test_fear_written_to_place_and_phenomenon_type():
	var colony := Colony.new()
	var g := _witness(0, 1.0, 0.0)
	colony.add(g)
	Influence.appraise_witnesses(colony, _stim())
	var expected := 0.6 * 0.5 * 1.0  # intensity × belief axis × susceptibility(timid=1)
	assert_almost_eq(g.get_feeling("ridge", "fear"), expected, 0.0001)
	assert_almost_eq(g.get_feeling("landslide", "fear"), expected, 0.0001)
	assert_almost_eq(g.habituation["landslide"], 0.15, 0.0001, "ONE bump per event, not two")


func test_safety_need_spikes_with_timidity():
	var colony := Colony.new()
	var coward := _witness(0, 1.0, 0.0)
	colony.add(coward)
	Influence.appraise_witnesses(colony, _stim())
	assert_almost_eq(coward.needs["safety"], 0.6 * 1.3, 0.0001, "intensity·(0.3+timid)")


func test_only_those_present_witness():
	var colony := Colony.new()
	var away := _witness(0, 1.0, 0.0)
	away.location = "village"
	colony.add(away)
	Influence.appraise_witnesses(colony, _stim())
	assert_eq(away.get_feeling("ridge", "fear"), 0.0)
	assert_eq(away.needs["safety"], 0.0)


func test_explicit_witness_list_overrides_location():
	var colony := Colony.new()
	var pilgrim := _witness(0, 0.5, 0.0)
	pilgrim.location = "village"
	colony.add(pilgrim)
	Influence.appraise_witnesses(colony, _stim(), [pilgrim])
	assert_gt(pilgrim.get_feeling("ridge", "fear"), 0.0, "he saw it from the road")
