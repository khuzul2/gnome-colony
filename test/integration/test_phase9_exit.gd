extends GutTest

## Phase-Exit 9 [plan]: a prophet only catches when conditions are ripe;
## rival prophets produce a schism; spamming fractures faith. The ripeness
## leg runs the REAL pipeline: omen cast → witnessed attribution charges
## |awe−fear| → the same omen that fell flat on a cold flock catches on a
## charged one.


func _band(n: int, devout: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_trait("devout", devout)
	return c


func _anoint(g: GnomeData, charisma: float, flavor: String) -> void:
	g.prophet = {
		"message": {"subject": "birds_silent", "flavor": flavor},
		"caught_age": g.age,
		"corrupted": false,
		"charisma": charisma,
		"doom_at": -1.0,
	}


func test_a_prophet_only_catches_when_ripe():
	Rng.seed_with(9900)
	var colony := _band(10, 0.7)
	var world := WorldState.new()
	var omen: Dictionary = Catalog.defs()["birds_silent"]
	var stim := Influence.cast_act(colony, world, omen, "the_hollow")
	assert_null(Prophet.try_seed(colony.living(), stim), "a cold flock hears only birds")
	# Season after season of witnessed signs charges the flock with awe…
	var caught: GnomeData = null
	for i in 8:
		stim = Influence.cast_act(colony, world, omen, "the_hollow")
		Devotion.attribute(colony, stim["drama"], 0.0, stim["valence"])
		caught = Prophet.try_seed(colony.living(), stim)
		if caught != null:
			break
	assert_not_null(caught, "…until the same omen finds its vessel")
	assert_gte(
		Prophet.ripeness(colony.living()), Prophet.RIPENESS_LINE, "and only past the 0.5 line"
	)


func test_rival_prophets_produce_a_schism():
	Rng.seed_with(9901)
	var colony := _band(12, 0.5)
	# Two congregations: each prophet tied to their own half of the flock.
	for i in range(1, 6):
		colony.gnomes[0].set_relationship(i, "friend", 0.6)
		colony.gnomes[i].set_relationship(0, "friend", 0.6)
	for i in range(7, 12):
		colony.gnomes[6].set_relationship(i, "friend", 0.6)
		colony.gnomes[i].set_relationship(6, "friend", 0.6)
	_anoint(colony.gnomes[0], 1.0, "mercy")
	_anoint(colony.gnomes[6], 1.0, "wrath")
	# Premise: a prophet believes their own creed — their faith counts among
	# the holders, which is what lifts each creed past the 0.3 rivalry line.
	colony.gnomes[0].set_feeling(Devotion.YOU, "faith", 1.0)
	colony.gnomes[6].set_feeling(Devotion.YOU, "faith", 1.0)
	var days := 0
	while colony.beliefs.size() < 2 and days < 90:
		Prophet.tick(colony, 1.0)
		days += 1
	assert_eq(colony.beliefs.size(), 2, "two competing creeds crystallized")
	var verdict := Prophet.check_schism(colony)
	assert_true(verdict["due"], "…and both stand strong: schism [§12]")
	assert_eq(verdict["factions"].size(), 2)


func test_spamming_prophets_fractures_faith():
	Rng.seed_with(9902)
	var spammed := _band(10, 0.5)
	for i in 4:
		_anoint(spammed.gnomes[i], 0.0, "mercy")
	var orthodox := _band(10, 0.5)
	_anoint(orthodox.gnomes[0], 0.0, "mercy")
	for c in [spammed, orthodox]:
		for g in c.living():
			g.set_feeling(Devotion.YOU, "faith", 0.5)
	for day in 20:
		Prophet.tick(spammed, 1.0)
		Prophet.tick(orthodox, 1.0)
	assert_lt(Devotion.total(spammed), Devotion.total(orthodox), "four voices fracture the faith")
	assert_gt(spammed.unrest, 0.0, "…and breed unrest")
	assert_eq(orthodox.unrest, 0.0, "one voice costs nothing")
