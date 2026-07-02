extends GutTest

## T9.4 — rivals & schism [algo §12]: rival prophets create competing
## belief-objects → schism when BOTH are strong; spamming prophets →
## fractured faith and unrest. §12 names the dynamics without numbers —
## the strength line (0.3) and the spam rates are interpretive,
## documented on the constants.


func _adults(n: int) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
	return c


func _anoint(g: GnomeData, charisma: float, flavor: String = "mercy") -> void:
	g.prophet = {
		"message": {"subject": "birds_silent", "flavor": flavor},
		"caught_age": g.age,
		"corrupted": false,
		"charisma": charisma,
		"doom_at": -1.0,
	}


func _creed(c: Colony, prophet_g: GnomeData, strength: float, holders: Array) -> void:
	var obj := BeliefObject.make("theology", Devotion.YOU, "faith", strength, holders)
	obj["flavor"] = prophet_g.prophet["message"]["flavor"]
	obj["prophet_id"] = prophet_g.id
	c.beliefs.append(obj)


func test_two_strong_rivals_produce_a_schism():
	var c := _adults(10)
	_anoint(c.gnomes[0], 0.8, "mercy")
	_anoint(c.gnomes[5], 0.8, "wrath")
	_creed(c, c.gnomes[0], 0.4, [0, 1, 2, 3, 4])
	_creed(c, c.gnomes[5], 0.35, [5, 6, 7, 8, 9])
	var verdict := Prophet.check_schism(c)
	assert_true(verdict["due"], "two strong creeds split the colony [§12]")
	assert_eq(verdict["factions"].size(), 2)
	assert_eq(verdict["factions"][0], [0, 1, 2, 3, 4])
	assert_eq(verdict["factions"][1], [5, 6, 7, 8, 9])


func test_one_creed_is_orthodoxy_not_schism():
	var c := _adults(10)
	_anoint(c.gnomes[0], 0.8)
	_creed(c, c.gnomes[0], 0.9, [0, 1, 2, 3, 4])
	assert_false(Prophet.check_schism(c)["due"])


func test_a_weak_rival_is_a_heresy_not_a_schism():
	var c := _adults(10)
	_anoint(c.gnomes[0], 0.8, "mercy")
	_anoint(c.gnomes[5], 0.8, "wrath")
	_creed(c, c.gnomes[0], 0.5, [0, 1, 2, 3, 4])
	_creed(c, c.gnomes[5], 0.1, [5, 6])
	assert_false(Prophet.check_schism(c)["due"], "both must be strong [§12]")


func test_a_dead_prophets_creed_cannot_rival():
	var c := _adults(10)
	_anoint(c.gnomes[0], 0.8, "mercy")
	_anoint(c.gnomes[5], 0.8, "wrath")
	_creed(c, c.gnomes[0], 0.4, [0, 1, 2, 3, 4])
	_creed(c, c.gnomes[5], 0.4, [5, 6, 7, 8, 9])
	c.gnomes[5].stage = Enums.LifeStage.DEAD
	assert_false(Prophet.check_schism(c)["due"], "a martyred creed is legend, not rebellion")


func test_prophet_spam_breeds_unrest():
	# Voiceless prophets (charisma 0) isolate the spam tax from preaching.
	var crowded := _adults(8)
	for i in 3:
		_anoint(crowded.gnomes[i], 0.0)
	var single := _adults(8)
	_anoint(single.gnomes[0], 0.0)
	for day in 10:
		Prophet.tick(crowded, 1.0)
		Prophet.tick(single, 1.0)
	assert_gt(crowded.unrest, 0.0, "three voices shouting is unrest [§12 spam]")
	assert_eq(single.unrest, 0.0, "one voice is order")


func test_prophet_spam_fractures_faith():
	var crowded := _adults(8)
	for i in 3:
		_anoint(crowded.gnomes[i], 0.0)
	for g in crowded.living():
		g.set_feeling(Devotion.YOU, "faith", 0.5)
	var single := _adults(8)
	_anoint(single.gnomes[0], 0.0)
	for g in single.living():
		g.set_feeling(Devotion.YOU, "faith", 0.5)
	for day in 10:
		Prophet.tick(crowded, 1.0)
		Prophet.tick(single, 1.0)
	assert_lt(
		Devotion.total(crowded), Devotion.total(single), "competing creeds erode shared faith"
	)
	assert_almost_eq(Devotion.total(single), 0.5 * 8, 0.0001, "orthodoxy holds steady")
