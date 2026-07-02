extends GutTest


func test_id_assignment():
	var g := GnomeData.new(7)
	assert_eq(g.id, 7)


func test_defaults_in_range():
	var g := GnomeData.new(0)
	assert_eq(g.age, 0.0)
	assert_eq(g.stage, Enums.LifeStage.INFANT)
	assert_true(g.sex in [0, 1])
	assert_true(g.is_alive())
	for key in Enums.NEED_KEYS:
		assert_true(g.needs.has(key), "need %s present" % key)
		assert_between(g.needs[key], 0.0, 1.0)
	for key in Enums.TRAIT_KEYS:
		assert_true(g.traits.has(key), "trait %s present" % key)
		assert_between(g.traits[key], 0.0, 1.0)
	assert_eq(g.skills, {})
	assert_eq(g.knowledge, [])
	assert_eq(g.feelings, {})
	assert_eq(g.relationships, {})
	assert_eq(g.memory, [])
	assert_eq(g.notability, 0.0)
	assert_eq(g.partner_id, -1)
	assert_eq(g.home_settlement, 0)


func test_need_and_trait_clamp():
	var g := GnomeData.new(0)
	g.set_need("hunger", 1.5)
	assert_eq(g.needs["hunger"], 1.0)
	g.set_need("hunger", -0.3)
	assert_eq(g.needs["hunger"], 0.0)
	g.set_trait("curious", 2.0)
	assert_eq(g.traits["curious"], 1.0)
	g.set_trait("curious", -1.0)
	assert_eq(g.traits["curious"], 0.0)


func test_skill_clamp():
	var g := GnomeData.new(0)
	g.set_skill("foraging", 1.7)
	assert_eq(g.skills["foraging"], 1.0)
	g.set_skill("foraging", -0.5)
	assert_eq(g.skills["foraging"], 0.0)


func test_feeling_clamp_and_shape():
	var g := GnomeData.new(0)
	g.set_feeling("eastern_ridge", "fear", 1.4)
	assert_eq(g.feelings["eastern_ridge"]["fear"], 1.0)
	g.adjust_feeling("eastern_ridge", "fear", -2.0)
	assert_eq(g.feelings["eastern_ridge"]["fear"], 0.0)
	g.adjust_feeling("spring", "awe", 0.3)
	assert_almost_eq(g.feelings["spring"]["awe"], 0.3, 0.0001)


func test_relationship_weight_clamps_to_signed_unit():
	var g := GnomeData.new(0)
	g.set_relationship(3, "friend", 2.0)
	assert_eq(g.relationships[3]["weight"], 1.0)
	g.set_relationship(3, "rival", -5.0)
	assert_eq(g.relationships[3]["weight"], -1.0)
	assert_eq(g.relationships[3]["type"], "rival")


func test_memory_is_a_capped_ring_buffer():
	var g := GnomeData.new(0)
	for i in GnomeData.MEMORY_CAP + 5:
		g.remember({"event": i})
	assert_eq(g.memory.size(), GnomeData.MEMORY_CAP, "oldest entries drop off")
	assert_eq(g.memory[0]["event"], 5, "front of buffer is the oldest KEPT entry")
	assert_eq(g.memory[-1]["event"], GnomeData.MEMORY_CAP + 4, "back is the newest")


func test_knowledge_behaves_as_a_set():
	var g := GnomeData.new(0)
	g.add_knowledge("foraging")
	g.add_knowledge("foraging")
	assert_eq(g.knowledge, ["foraging"], "duplicate ids must not accumulate")


func test_dead_gnome_is_not_alive():
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.DEAD
	assert_false(g.is_alive())
