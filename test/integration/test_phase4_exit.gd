extends GutTest

## Phase-Exit 4: the sole holder of a skill dies untaught ⇒ extinction
## event; with writing present ⇒ no extinction (and the craft is
## recoverable from the record).


func _sole_holder(colony: Colony, extra_knowledge: Array = []) -> GnomeData:
	var g := colony.spawn()
	g.stage = Enums.LifeStage.ELDER
	g.age = 80.0
	g.set_skill("bronzeworking", 0.8)
	g.add_knowledge("bronzeworking")
	for id in extra_knowledge:
		g.set_skill(id, 0.5)
		g.add_knowledge(id)
	return g


func test_untaught_death_extinguishes_the_craft():
	Rng.seed_with(4900)
	var colony := Colony.new()
	var elder := _sole_holder(colony)
	var apprentice := colony.spawn()
	apprentice.stage = Enums.LifeStage.ADOLESCENT
	Knowledge.sync(colony)

	var lost := []
	var listener := func(p: Dictionary) -> void: lost.append(p)
	EventBus.knowledge_lost.connect(listener)
	elder.stage = Enums.LifeStage.DEAD
	Knowledge.check_extinction(colony)
	EventBus.knowledge_lost.disconnect(listener)

	assert_eq(lost.size(), 1, "the craft dies with its last elder")
	assert_eq(lost[0]["id"], "bronzeworking")
	assert_eq(
		apprentice.skills.get("bronzeworking", 0.0), 0.0, "nobody was taught — nothing remains"
	)


func test_taught_apprentice_prevents_extinction():
	Rng.seed_with(4901)
	var colony := Colony.new()
	var elder := _sole_holder(colony)
	var apprentice := colony.spawn()
	apprentice.stage = Enums.LifeStage.ADOLESCENT
	while apprentice.skills.get("bronzeworking", 0.0) < Skills.TEACHABLE_AT:
		Skills.teach(elder, apprentice, "bronzeworking", 1.0)
	Knowledge.sync(colony)

	var lost := []
	var listener := func(p: Dictionary) -> void: lost.append(p)
	EventBus.knowledge_lost.connect(listener)
	elder.stage = Enums.LifeStage.DEAD
	Knowledge.check_extinction(colony)
	EventBus.knowledge_lost.disconnect(listener)
	assert_eq(lost.size(), 0, "the chain of teaching preserves the craft")


func test_writing_preserves_and_restores_the_craft():
	Rng.seed_with(4902)
	var colony := Colony.new()
	var elder := _sole_holder(colony, ["writing"])
	Knowledge.sync(colony)
	Knowledge.snapshot_records(colony)

	var lost := []
	var listener := func(p: Dictionary) -> void: lost.append(p)
	EventBus.knowledge_lost.connect(listener)
	elder.stage = Enums.LifeStage.DEAD
	Knowledge.check_extinction(colony)
	EventBus.knowledge_lost.disconnect(listener)
	assert_eq(lost.size(), 0, "written knowledge outlives every holder")

	var scholar := colony.spawn()
	scholar.stage = Enums.LifeStage.ADULT
	for day in 30:
		Skills.study_record(colony, scholar, "bronzeworking", 1.0)
	assert_true("bronzeworking" in scholar.knowledge, "the craft returns from the record")
