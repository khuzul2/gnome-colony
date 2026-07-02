extends GutTest

## T4.4 — per-settlement extinction [algo §7]: when no living gnome in a
## settlement holds an id at prof ≥ 0.2, that settlement loses the id and
## `knowledge_lost` fires. Another settlement may still hold it — dark ages
## are regional. (Writing exemption is T4.5.)


func _crafter(id: int, settlement: int) -> GnomeData:
	var g := GnomeData.new(id)
	g.stage = Enums.LifeStage.ADULT
	g.home_settlement = settlement
	g.set_skill("smithing", 0.5)
	g.add_knowledge("smithing")
	return g


func test_sync_registers_held_ids_per_settlement():
	var colony := Colony.new()
	colony.add(_crafter(0, 0))
	colony.add(_crafter(1, 2))
	Knowledge.sync(colony)
	assert_true(colony.settlement_knowledge[0].has("smithing"))
	assert_true(colony.settlement_knowledge[2].has("smithing"))


func test_last_holder_death_causes_regional_extinction():
	var colony := Colony.new()
	var smith := _crafter(0, 0)
	colony.add(smith)
	colony.add(_crafter(1, 2))
	Knowledge.sync(colony)

	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.knowledge_lost.connect(listener)
	smith.stage = Enums.LifeStage.DEAD
	Knowledge.check_extinction(colony)
	EventBus.knowledge_lost.disconnect(listener)

	assert_eq(events.size(), 1)
	assert_eq(events[0]["id"], "smithing")
	assert_eq(events[0]["settlement"], 0)
	assert_false(colony.settlement_knowledge[0].has("smithing"), "lost in settlement 0")
	assert_true(colony.settlement_knowledge[2].has("smithing"), "still alive in settlement 2")


func test_low_proficiency_holder_does_not_prevent_extinction():
	var colony := Colony.new()
	var smith := _crafter(0, 0)
	colony.add(smith)
	Knowledge.sync(colony)
	smith.set_skill("smithing", 0.1)
	smith.knowledge.erase("smithing")

	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.knowledge_lost.connect(listener)
	Knowledge.check_extinction(colony)
	EventBus.knowledge_lost.disconnect(listener)
	assert_eq(events.size(), 1, "a sub-0.2 rememberer cannot keep a craft alive")


func test_no_event_while_a_holder_lives():
	var colony := Colony.new()
	colony.add(_crafter(0, 0))
	Knowledge.sync(colony)
	var events := []
	var listener := func(p: Dictionary) -> void: events.append(p)
	EventBus.knowledge_lost.connect(listener)
	Knowledge.check_extinction(colony)
	EventBus.knowledge_lost.disconnect(listener)
	assert_eq(events.size(), 0)


func test_settlement_knowledge_round_trips_through_serializer():
	var colony := Colony.new()
	colony.add(_crafter(0, 0))
	Knowledge.sync(colony)
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(colony))
	assert_eq(restored.settlement_knowledge, colony.settlement_knowledge)
