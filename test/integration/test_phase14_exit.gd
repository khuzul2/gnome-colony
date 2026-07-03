extends GutTest

## Phase-Exit 14 [plan]: category controls appear/lock by devotion
## tier; an aftermath panel reflects a phenomenon's outcomes. One
## scene, one real cast: the panel gates by the LIVE Devotion ladder,
## the paint routes to Influence, the cascade lands on the EventBus,
## and the aftermath page shows the cause, the ground it touched, and
## what it did to their hearts.


func test_the_player_acts_and_reads_the_consequences():
	Rng.seed_with(14900)
	# A colony that barely believes…
	var colony := Colony.new()
	for i in 12:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = "the_hollow"
	Devotion.update_unlocks(colony)
	var world := WorldState.new()
	world.affordances["the_hollow"] = ["slope"]
	var panel := InfluencePanel.new()
	add_child_autofree(panel)
	var defs: Dictionary = Catalog.defs().duplicate(true)
	defs["landslide"]["chain_hooks"] = [{"phenom": "cursed_place", "prob": 1.0}]
	defs["landslide"]["tail_risk"] = 0.0
	panel.build(defs)
	panel.refresh(colony)
	assert_true(panel.category_boxes[1].visible, "the Elements greet a new god")
	assert_false(panel.category_boxes[7].visible, "Wonders locked away [exit: appear/lock by tier]")
	assert_false(panel.arm("landslide"), "tier 2 refuses a tier-1 myth")
	# …until their faith deepens…
	for g in colony.living():
		g.set_feeling(Devotion.YOU, "faith", 0.2)
	Devotion.update_unlocks(colony)
	panel.refresh(colony)
	assert_true(panel.category_boxes[2].visible, "Earth & Stone appears at tier II [§10]")
	assert_true(panel.arm("landslide"), "…and the landslide arms")
	# …then the cast flows panel → runner → EventBus → aftermath.
	var aftermath := AftermathPanel.new()
	add_child_autofree(aftermath)
	var routed := {}
	panel.cast_requested.connect(
		func(act_id: String, target: String, _selection: Dictionary) -> void:
			aftermath.begin(act_id)
			routed["stimuli"] = Influence.cast_with_cascade(
				colony,
				world,
				defs,
				act_id,
				target,
				Devotion.magnitude_multiplier(colony),
				Devotion.valence_potency(defs[act_id]["valence"]),
				Catalog.handlers()
			)
	)
	assert_true(panel.paint({"place": "the_hollow"}), "the paint releases the act")
	assert_eq(routed["stimuli"].size(), 2, "root + certain chain landed")
	assert_eq(
		aftermath.timeline.size(), 2, "the aftermath heard both beats [exit: reflects outcomes]"
	)
	assert_eq(aftermath.timeline[0]["type"], "landslide", "cause first")
	assert_eq(aftermath.timeline[1]["type"], "cursed_place", "…consequence after")
	assert_eq(aftermath.affected_places(), ["the_hollow"], "the touched ground is highlighted")
	assert_true(
		colony.place_tags.get("the_hollow", {}).has("cursed"),
		"the chain really marked the world (not a display fiction)"
	)


func test_the_aftermath_reads_their_hearts_after_the_blow():
	Rng.seed_with(14901)
	var colony := Colony.new()
	for i in 10:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = "the_hollow"
		g.set_feeling(Devotion.YOU, "faith", 0.3)
		g.set_feeling(Devotion.YOU, "fear", 0.5)
		g.set_feeling(Devotion.YOU, "awe", 0.1)
	Devotion.update_unlocks(colony)
	var aftermath := AftermathPanel.new()
	add_child_autofree(aftermath)
	var image: Dictionary = aftermath.who_they_think_you_are(colony)
	assert_eq(image["flavor"], "feared", "who they think you are: a thing to dread [§10]")
	assert_eq(image["tier"], colony.unlocked_tier, "the readout is the sim's ratchet")
