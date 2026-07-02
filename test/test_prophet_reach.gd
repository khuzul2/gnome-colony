extends GutTest

## T9.2 — charisma, reach, amplification [algo §12/§17]: charisma is a
## hidden N(0.6, 0.2) stat rolled at the catch; reach is a social-graph
## BFS whose depth scales with charisma; preaching writes the message
## across reach scaled by charisma, and FORCES crystallization of the
## message (no season wait) once enough of the flock holds it.


func _chain(n: int) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
	for i in n - 1:
		c.gnomes[i].set_relationship(i + 1, "friend", 0.5)
		c.gnomes[i + 1].set_relationship(i, "friend", 0.5)
	return c


func _anoint(g: GnomeData, charisma: float, flavor: String = "mercy") -> void:
	g.prophet = {
		"message": {"subject": "birds_silent", "flavor": flavor},
		"caught_age": g.age,
		"corrupted": false,
		"charisma": charisma,
	}


func test_charisma_is_rolled_at_the_catch():
	Rng.seed_with(9200)
	var c := _chain(6)
	for g in c.living():
		g.set_feeling(Devotion.YOU, "awe", 0.6)
	var stim := {"type": "birds_silent", "category": 5, "valence": "neutral"}
	var caught := Prophet.try_seed(c.living(), stim)
	assert_true(caught.prophet.has("charisma"), "the hidden stat exists")
	var first: float = caught.prophet["charisma"]
	assert_between(first, 0.0, 1.0)
	Rng.seed_with(9200)
	var c2 := _chain(6)
	for g in c2.living():
		g.set_feeling(Devotion.YOU, "awe", 0.6)
	var again := Prophet.try_seed(c2.living(), stim)
	assert_eq(again.prophet["charisma"], first, "same seed, same soul — reproducible")


func test_reach_scales_with_charisma():
	var c := _chain(8)
	var meek: GnomeData = c.gnomes[0]
	_anoint(meek, 0.2)
	assert_eq(Prophet.reach(c, meek).size(), 1, "charisma 0.2 carries one link down the chain")
	var magnetic := _chain(8)
	var voice: GnomeData = magnetic.gnomes[0]
	_anoint(voice, 1.0)
	var flock := Prophet.reach(magnetic, voice)
	assert_eq(flock.size(), 5, "charisma 1.0 carries five links [depth ∝ charisma]")
	for g in flock:
		assert_ne(g.id, 0, "the prophet is not their own convert")


func test_reach_ignores_hostile_edges():
	var c := _chain(3)
	c.gnomes[0].set_relationship(2, "rival", -0.6)
	c.gnomes[2].set_relationship(0, "rival", -0.6)
	var p: GnomeData = c.gnomes[0]
	_anoint(p, 0.2)
	var flock := Prophet.reach(c, p)
	assert_eq(flock.size(), 1, "enemies do not carry the gospel")
	assert_eq(flock[0].id, 1)


func test_the_dead_hear_nothing():
	var c := _chain(4)
	c.gnomes[1].stage = Enums.LifeStage.DEAD
	var p: GnomeData = c.gnomes[0]
	_anoint(p, 1.0)
	assert_eq(Prophet.reach(c, p).size(), 0, "the chain breaks at a grave")


func test_preaching_amplifies_with_charisma():
	var quiet := _chain(4)
	_anoint(quiet.gnomes[0], 0.3)
	var loud := _chain(4)
	_anoint(loud.gnomes[0], 0.9)
	for day in 5:
		Prophet.preach(quiet, quiet.gnomes[0], 1.0)
		Prophet.preach(loud, loud.gnomes[0], 1.0)
	var q: float = quiet.gnomes[1].get_feeling(Devotion.YOU, "faith")
	var l: float = loud.gnomes[1].get_feeling(Devotion.YOU, "faith")
	assert_gt(l, q, "the magnetic voice converts faster [influence = charisma]")
	assert_gt(q, 0.0, "even the meek voice moves the needle")


func test_wrath_message_writes_fear():
	var c := _chain(3)
	_anoint(c.gnomes[0], 0.8, "wrath")
	Prophet.preach(c, c.gnomes[0], 1.0)
	var convert: GnomeData = c.gnomes[1]
	assert_gt(convert.get_feeling(Devotion.YOU, "fear"), 0.0, "a hard creed seeds dread")
	assert_gt(convert.get_feeling(Devotion.YOU, "faith"), 0.0, "…and faith rides along")
	assert_eq(convert.get_feeling(Devotion.YOU, "awe"), 0.0)


func test_mass_crystallization_beats_the_season():
	# A star flock: everyone tied to the prophet. §9's organic path needs
	# 0.7 sustained for a WHOLE season (24 d); the prophet forces it fast.
	var c := Colony.new()
	for i in 10:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
	for i in range(1, 10):
		c.gnomes[0].set_relationship(i, "friend", 0.6)
		c.gnomes[i].set_relationship(0, "friend", 0.6)
	_anoint(c.gnomes[0], 1.0)
	var days := 0
	while c.beliefs.is_empty() and days < TimeService.DAYS_PER_SEASON:
		Prophet.preach(c, c.gnomes[0], 1.0)
		days += 1
	assert_false(c.beliefs.is_empty(), "the message crystallized")
	assert_lt(days, TimeService.DAYS_PER_SEASON, "…without waiting out a season [§12 'fast']")
	var creed: Dictionary = c.beliefs[0]
	assert_eq(creed["kind"], "theology")
	assert_eq(creed["subject"], Devotion.YOU)
	assert_eq(creed["flavor"], "mercy")
	assert_gte(creed["holders"].size(), 5, "a mass conversion, not a whisper")
	# Preaching on does not mint the same creed twice.
	Prophet.preach(c, c.gnomes[0], 1.0)
	assert_eq(c.beliefs.size(), 1, "one creed per prophet")
