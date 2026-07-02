extends GutTest

## T4.5 — writing durability [algo §7]: where `writing` is held, known ids
## snapshot into durable records, exempt from extinction and re-teachable
## from the record.


func _scribe(id: int, settlement: int) -> GnomeData:
	var g := GnomeData.new(id)
	g.stage = Enums.LifeStage.ADULT
	g.home_settlement = settlement
	g.set_skill("writing", 0.5)
	g.add_knowledge("writing")
	g.set_skill("smithing", 0.5)
	g.add_knowledge("smithing")
	return g


func test_snapshot_requires_writing():
	var colony := Colony.new()
	var smith := GnomeData.new(0)
	smith.stage = Enums.LifeStage.ADULT
	smith.set_skill("smithing", 0.5)
	smith.add_knowledge("smithing")
	colony.add(smith)
	Knowledge.sync(colony)
	Knowledge.snapshot_records(colony)
	assert_false(colony.durable_records.get(0, {}).has("smithing"), "no writing, no records")


func test_writing_snapshots_all_known_ids():
	var colony := Colony.new()
	colony.add(_scribe(0, 0))
	Knowledge.sync(colony)
	Knowledge.snapshot_records(colony)
	assert_true(colony.durable_records[0].has("smithing"))
	assert_true(colony.durable_records[0].has("writing"))


func test_no_extinction_with_writing_present():
	var colony := Colony.new()
	var scribe := _scribe(0, 0)
	colony.add(scribe)
	Knowledge.sync(colony)
	Knowledge.snapshot_records(colony)

	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.knowledge_lost.connect(listener)
	scribe.stage = Enums.LifeStage.DEAD
	Knowledge.check_extinction(colony)
	EventBus.knowledge_lost.disconnect(listener)

	assert_eq(events.size(), 0, "written knowledge survives its holders")
	assert_true(colony.settlement_knowledge[0].has("smithing"))


func test_reteachable_from_record():
	var colony := Colony.new()
	var scribe := _scribe(0, 0)
	colony.add(scribe)
	Knowledge.sync(colony)
	Knowledge.snapshot_records(colony)
	scribe.stage = Enums.LifeStage.DEAD
	Knowledge.check_extinction(colony)

	var student := GnomeData.new(1)
	student.stage = Enums.LifeStage.ADOLESCENT
	student.home_settlement = 0
	colony.add(student)
	for day in 30:
		Skills.study_record(colony, student, "smithing", 1.0)
	assert_gt(student.skills.get("smithing", 0.0), 0.2, "the craft returns from the page")
	assert_true("smithing" in student.knowledge)


func test_study_requires_a_record():
	var colony := Colony.new()
	var student := GnomeData.new(0)
	student.stage = Enums.LifeStage.ADULT
	student.home_settlement = 0
	colony.add(student)
	Skills.study_record(colony, student, "smithing", 1.0)
	assert_eq(student.skills.get("smithing", 0.0), 0.0, "no record, no study")
