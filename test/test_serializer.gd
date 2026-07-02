extends GutTest


func _populated_gnome(id: int) -> GnomeData:
	var g := GnomeData.new(id)
	g.age = 34.5
	g.stage = Enums.LifeStage.ADULT
	g.sex = 1
	g.set_need("hunger", 0.42)
	g.set_trait("curious", 0.9)
	g.set_skill("foraging", 0.55)
	g.add_knowledge("foraging")
	g.set_feeling("eastern_ridge", "fear", 0.7)
	g.set_relationship(99, "mate", 0.8)
	g.remember({"event": "landslide", "place": 3})
	g.notability = 0.25
	g.partner_id = 99
	g.home_settlement = 2
	g.hardship_rate = 0.15
	g.hardship_days = {"hunger": 3.0, "safety": 0.0}
	g.generation = 4
	g.constitutional_traits = ["curious"]
	g.outlier_type = "genius"
	g.prophet_affinity = 0.5
	g.habituation = {"landslide": 0.3}
	return g


func _populated_colony() -> Colony:
	var c := Colony.new()
	c.add(_populated_gnome(0))
	c.add(_populated_gnome(4))
	c.gnomes[4].stage = Enums.LifeStage.DEAD
	return c


func test_gnome_round_trip():
	var g := _populated_gnome(7)
	var restored := Serializer.gnome_from_dict(Serializer.gnome_to_dict(g))
	assert_eq(Serializer.gnome_to_dict(restored), Serializer.gnome_to_dict(g))
	assert_eq(restored.id, 7)
	assert_eq(restored.stage, Enums.LifeStage.ADULT)
	assert_eq(restored.relationships[99]["type"], "mate")
	assert_eq(restored.memory[0]["event"], "landslide")


func test_gnome_dict_is_a_deep_copy():
	var g := _populated_gnome(1)
	var d := Serializer.gnome_to_dict(g)
	g.set_need("hunger", 1.0)
	g.memory.append({"event": "later"})
	assert_almost_eq(d["needs"]["hunger"], 0.42, 0.0001, "snapshot must not alias live state")
	assert_eq(d["memory"].size(), 1)


func test_colony_round_trip_preserves_population_and_ids():
	var c := _populated_colony()
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(c))
	assert_eq(Serializer.colony_to_dict(restored), Serializer.colony_to_dict(c))
	assert_eq(restored.next_id, c.next_id)
	assert_eq(restored.gnomes.keys(), c.gnomes.keys())
	assert_eq(restored.population(), 1, "dead gnome stays dead after round-trip")
	assert_eq(restored.gnomes[4].stage, Enums.LifeStage.DEAD)


func test_world_config_round_trip():
	var cfg := WorldConfig.new()
	cfg.seed = 424242
	cfg.mortality = "brutal"
	cfg.region_size = "large"
	cfg.band_size = 5
	cfg.temperament_leanings = ["hardy", "devout"]
	cfg.exploration_fog = false
	var restored := Serializer.config_from_dict(Serializer.config_to_dict(cfg))
	assert_eq(Serializer.config_to_dict(restored), Serializer.config_to_dict(cfg))
	assert_eq(restored.seed, 424242)
	assert_eq(restored.mortality, "brutal")
	assert_eq(restored.basin_count(), 12)
	assert_eq(restored.temperament_leanings, ["hardy", "devout"])
	assert_false(restored.exploration_fog)
