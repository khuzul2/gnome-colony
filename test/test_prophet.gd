extends GutTest

## T9.1 — prophet entity & seeding [algo §12/§17]: a prophet is a flagged
## gnome, seeded via an Omen/Vision stimulus, and only CATCHES where ripe —
## local mean(|awe−fear| toward the unseen will) ≥ 0.5. Charisma/reach are
## T9.2; this task is the entity, the gate, and the message's birth.


func _flock(n: int, awe: float, fear: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_feeling(Devotion.YOU, "awe", awe)
		g.set_feeling(Devotion.YOU, "fear", fear)
	return c


func _omen() -> Dictionary:
	return {
		"type": "birds_silent",
		"category": 5,
		"place": "the_hollow",
		"intensity": 0.3,
		"drama": 0.5,
		"valence": "neutral",
		"effects": {"belief": 0.6},
	}


func test_catches_when_ripe():
	var c := _flock(6, 0.6, 0.0)
	var vessel: GnomeData = c.living()[2]
	vessel.prophet_affinity = 1.0
	var caught := Prophet.try_seed(c.living(), _omen())
	assert_eq(caught, vessel, "the omen finds its vessel")
	assert_false(caught.prophet.is_empty(), "the gnome is flagged")
	assert_gte(
		caught.notability,
		Notability.PROPHET_LEADER,
		"becoming a prophet is a §14 deed (T8.6 deferred hook)"
	)


func test_does_not_catch_when_unripe():
	var c := _flock(6, 0.3, 0.0)
	c.living()[0].prophet_affinity = 1.0
	assert_null(Prophet.try_seed(c.living(), _omen()), "0.3 charge is short of the 0.5 line")


func test_terror_charge_is_also_ripe():
	# |awe−fear| measures POLARIZATION, not love: a terrorized flock births
	# prophets just as an awed one does [§12 — the charge, either way].
	var c := _flock(6, 0.0, 0.7)
	c.living()[0].prophet_affinity = 1.0
	assert_not_null(Prophet.try_seed(c.living(), _omen()))


func test_mixed_feelings_cancel_the_charge():
	# awe 0.6 AND fear 0.6 → |awe−fear| = 0 per head: confusion, not charge.
	var c := _flock(6, 0.6, 0.6)
	c.living()[0].prophet_affinity = 1.0
	assert_null(Prophet.try_seed(c.living(), _omen()))


func test_only_omens_and_visions_seed():
	var c := _flock(6, 0.8, 0.0)
	c.living()[0].prophet_affinity = 1.0
	var quake := _omen()
	quake["type"] = "landslide"
	quake["category"] = 2
	assert_null(Prophet.try_seed(c.living(), quake), "earthworks are not portents")
	var vision := _omen()
	vision["type"] = "shared_dream"
	vision["category"] = 6
	assert_not_null(Prophet.try_seed(c.living(), vision), "visions seed too [§12]")


func test_the_touched_are_prime_vessels():
	# §8: the touched are "prime prophet seed" — affinity outranks piety.
	var c := _flock(4, 0.6, 0.0)
	var pious: GnomeData = c.living()[0]
	pious.set_trait("devout", 1.0)
	var touched: GnomeData = c.living()[3]
	touched.set_trait("devout", 0.2)
	touched.prophet_affinity = 1.0
	assert_eq(Prophet.try_seed(c.living(), _omen()), touched)


func test_children_do_not_catch():
	var c := _flock(5, 0.7, 0.0)
	var child: GnomeData = c.living()[1]
	child.age = 6.0
	child.stage = Enums.LifeStage.CHILD
	child.prophet_affinity = 1.0
	var caught := Prophet.try_seed(c.living(), _omen())
	assert_not_null(caught, "the flock is ripe — someone catches")
	assert_ne(caught, child, "but not the child (interpretive: adults/elders only)")


func test_message_flavor_follows_the_flock():
	var awed := _flock(6, 0.7, 0.0)
	var mercy := Prophet.try_seed(awed.living(), _omen())
	assert_eq(mercy.prophet["message"]["flavor"], "mercy", "love-charge births a gentle creed")
	assert_eq(mercy.prophet["message"]["subject"], "birds_silent", "born of its trigger [§12]")
	var terrorized := _flock(6, 0.0, 0.7)
	var wrath := Prophet.try_seed(terrorized.living(), _omen())
	assert_eq(wrath.prophet["message"]["flavor"], "wrath", "terror-charge births a hard creed")


func test_prophet_flag_round_trips():
	var c := _flock(6, 0.7, 0.0)
	var caught := Prophet.try_seed(c.living(), _omen())
	var restored := Serializer.gnome_from_dict(Serializer.gnome_to_dict(caught))
	assert_eq(restored.prophet["message"]["flavor"], caught.prophet["message"]["flavor"])


func test_cast_stimuli_carry_their_category():
	# The seeding gate reads the stimulus itself, so casts must carry the
	# §18 category (public-API addition to Influence.cast, PROGRESS.md).
	var c := _flock(3, 0.0, 0.0)
	var stim := Influence.cast(c, WorldState.new(), Catalog.defs()["birds_silent"], "anywhere")
	assert_eq(stim["category"], 5)
