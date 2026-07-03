extends GutTest

## T14.2 — Feedback/hindsight [design §2.7]: outcomes are indirect and
## mysterious, so the player must trace cause→effect IN HINDSIGHT. The
## AftermathPanel listens to the EventBus (phenomenon, belief_formed)
## and renders: the cascade timeline (root first, consequences marked),
## the affected-area highlight (places touched), "what they now
## believe", and "who they think you are" (depth, tier, love/terror
## flavor, crystallized creeds). It READS the sim and mutates nothing.


func _panel() -> AftermathPanel:
	var panel := AftermathPanel.new()
	add_child_autofree(panel)
	return panel


func _colony(pop: int, faith: float, awe: float, fear: float) -> Colony:
	var colony := Colony.new()
	for i in pop:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = "the_hollow"
		g.set_feeling(Devotion.YOU, "faith", faith)
		g.set_feeling(Devotion.YOU, "awe", awe)
		g.set_feeling(Devotion.YOU, "fear", fear)
	Devotion.update_unlocks(colony)
	return colony


## A deterministic cascade fixture: the real landslide, chained to
## dam_flood at probability 1 with the tail silenced — schema-valid, so
## the panel watches a REAL cast, not hand-fed dicts.
func _certain_landslide() -> Dictionary:
	var defs: Dictionary = Catalog.defs().duplicate(true)
	defs["landslide"]["chain_hooks"] = [{"phenom": "dam_flood", "prob": 1.0}]
	defs["landslide"]["tail_risk"] = 0.0
	assert_eq(Phenomenon.validate(defs["landslide"]), [], "the fixture honors the §11 schema")
	return defs


func test_the_timeline_reflects_a_real_cascade():
	Rng.seed_with(14200)
	var panel := _panel()
	var colony := _colony(6, 0.2, 0.3, 0.1)
	var world := WorldState.new()
	world.affordances["the_hollow"] = ["slope"]
	panel.begin("landslide")
	Influence.cast_with_cascade(colony, world, _certain_landslide(), "landslide", "the_hollow")
	assert_eq(panel.timeline.size(), 2, "root + its chained consequence [design §2.7]")
	assert_eq(panel.timeline[0]["type"], "landslide", "the cause leads the timeline")
	assert_eq(panel.timeline[1]["type"], "dam_flood", "…the domino follows")
	assert_true(panel.timeline[1].get("consequence", false), "…marked as a consequence")
	assert_eq(panel.timeline_box.get_child_count(), 2, "a row per beat, rendered")


func test_the_affected_area_is_highlighted():
	Rng.seed_with(14201)
	var panel := _panel()
	var colony := _colony(6, 0.2, 0.3, 0.1)
	var world := WorldState.new()
	world.affordances["the_hollow"] = ["slope"]
	panel.begin("landslide")
	Influence.cast_with_cascade(colony, world, _certain_landslide(), "landslide", "the_hollow")
	assert_eq(panel.affected_places(), ["the_hollow"], "one place, highlighted once")
	EventBus.phenomenon.emit(
		{"type": "flood", "place": "meadow", "intensity": 0.3, "valence": "neutral"}
	)
	assert_eq(
		panel.affected_places(), ["the_hollow", "meadow"], "…a spreading event widens the highlight"
	)


func test_what_they_now_believe():
	var panel := _panel()
	panel.begin("the_swallowing")
	assert_eq(panel.new_beliefs.size(), 0, "no beliefs yet")
	EventBus.belief_formed.emit(
		{"kind": "taboo", "subject": "the_hollow", "axis": "fear", "strength": 0.4}
	)
	assert_eq(panel.new_beliefs.size(), 1, "a crystallized belief reaches the panel")
	assert_eq(panel.new_beliefs[0]["kind"], "taboo")
	assert_eq(panel.beliefs_box.get_child_count(), 1, "…and is rendered")


func test_who_they_think_you_are():
	var panel := _panel()
	var loved := _colony(10, 0.4, 0.5, 0.1)
	var image: Dictionary = panel.who_they_think_you_are(loved)
	assert_eq(image["flavor"], "loved", "awe above fear reads as love [algo §10 flavor]")
	assert_almost_eq(image["depth"], 0.4, 0.001, "depth is d̄ [algo §10]")
	assert_eq(image["tier"], loved.unlocked_tier, "tier is the sim's ratchet, not the panel's")
	var feared := _colony(10, 0.4, 0.1, 0.5)
	assert_eq(panel.who_they_think_you_are(feared)["flavor"], "feared", "fear above awe: terror")
	var unknown := Colony.new()
	assert_eq(
		panel.who_they_think_you_are(unknown)["flavor"],
		"unknown",
		"no feelings at all — they have no image of you yet"
	)


func test_creeds_name_who_you_have_become():
	var panel := _panel()
	var colony := _colony(10, 0.4, 0.1, 0.5)
	var creed := BeliefObject.make("theology", Devotion.YOU, "faith", 0.5, [0, 1, 2])
	creed["flavor"] = "wrathful"
	colony.beliefs.append(creed)
	var image: Dictionary = panel.who_they_think_you_are(colony)
	assert_eq(image["creeds"], ["wrathful"], "their theology names you [design §2.7/§3.7]")


func test_begin_opens_a_fresh_aftermath():
	var panel := _panel()
	panel.begin("landslide")
	EventBus.phenomenon.emit(
		{"type": "landslide", "place": "the_hollow", "intensity": 0.6, "valence": "malevolent"}
	)
	EventBus.belief_formed.emit(
		{"kind": "taboo", "subject": "the_hollow", "axis": "fear", "strength": 0.4}
	)
	panel.begin("still_air")
	assert_eq(panel.timeline.size(), 0, "a new act, a blank page")
	assert_eq(panel.new_beliefs.size(), 0)
	assert_eq(panel.affected_places(), [], "the old highlight is gone")
	assert_eq(panel.timeline_box.get_child_count(), 0, "…and the rendered rows with it")
