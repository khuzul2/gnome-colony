extends GutTest

## T9.3 — life-arc & corruption [algo §12/§17]: influence = charisma ·
## arc(age) over a rise→peak→decline career, and a corruption roll — 0.10
## over the lifetime (§17) — that flips the message to madness (mercy →
## demands sacrifice). Arc shape numbers are interpretive (§12 names the
## shape only): fast rise (1 y), long peak (10 y), slow fade (15 y),
## floor 0.3.


func _flock(n: int, awe: float) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.set_feeling(Devotion.YOU, "awe", awe)
	return c


func _omen() -> Dictionary:
	return {"type": "birds_silent", "category": 5, "valence": "neutral"}


func _anoint(g: GnomeData, charisma: float, flavor: String = "mercy") -> void:
	g.prophet = {
		"message": {"subject": "birds_silent", "flavor": flavor},
		"caught_age": g.age,
		"corrupted": false,
		"charisma": charisma,
		"doom_at": -1.0,
	}


func test_arc_rises_peaks_and_declines():
	var g := GnomeData.new(0)
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	_anoint(g, 0.8)
	var at_catch := Prophet.arc(g)
	g.age = 30.5
	var rising := Prophet.arc(g)
	g.age = 33.0
	var at_peak := Prophet.arc(g)
	g.age = 50.0
	var fading := Prophet.arc(g)
	g.age = 80.0
	var spent := Prophet.arc(g)
	assert_gt(rising, at_catch, "the word spreads — rise")
	assert_eq(at_peak, 1.0, "peak influence")
	assert_lt(fading, at_peak, "…then the long fade")
	assert_almost_eq(spent, 0.3, 0.0001, "an old prophet keeps a remnant flock (floor)")


func test_influence_is_charisma_times_arc():
	# Same charisma, same flock — the peak prophet converts faster than
	# the freshly-caught one. [§12: influence = charisma · arc(age)]
	var fresh := _flock(3, 0.0)
	fresh.gnomes[0].set_relationship(1, "friend", 0.5)
	fresh.gnomes[1].set_relationship(0, "friend", 0.5)
	_anoint(fresh.gnomes[0], 0.8)
	var peaked := _flock(3, 0.0)
	peaked.gnomes[0].set_relationship(1, "friend", 0.5)
	peaked.gnomes[1].set_relationship(0, "friend", 0.5)
	_anoint(peaked.gnomes[0], 0.8)
	peaked.gnomes[0].age = 33.0
	Prophet.preach(fresh, fresh.gnomes[0], 1.0)
	Prophet.preach(peaked, peaked.gnomes[0], 1.0)
	var fresh_faith: float = fresh.gnomes[1].get_feeling(Devotion.YOU, "faith")
	var peak_faith: float = peaked.gnomes[1].get_feeling(Devotion.YOU, "faith")
	assert_gt(peak_faith, fresh_faith)
	assert_almost_eq(peak_faith, 0.12 * 0.8 * 1.0, 0.0001, "peak = full charisma")


func test_flip_frequency_is_about_ten_percent():
	Rng.seed_with(9300)
	var doomed := 0
	const TRIALS := 300
	for i in TRIALS:
		var c := _flock(6, 0.6)
		var caught := Prophet.try_seed(c.living(), _omen())
		if caught.prophet["doom_at"] >= 0.0:
			doomed += 1
	var rate := float(doomed) / TRIALS
	assert_between(rate, 0.05, 0.15, "§17: corruption 0.10 over the lifetime (got %.3f)" % rate)


func test_corruption_flips_mercy_to_madness():
	var c := _flock(4, 0.0)
	c.gnomes[0].set_relationship(1, "friend", 0.5)
	c.gnomes[1].set_relationship(0, "friend", 0.5)
	var p: GnomeData = c.gnomes[0]
	_anoint(p, 0.8)
	p.prophet["doom_at"] = 35.0
	Prophet.tick(c, 1.0)
	assert_false(p.prophet["corrupted"], "the doom sleeps until its hour")
	assert_eq(p.prophet["message"]["flavor"], "mercy")
	p.age = 36.0
	Prophet.tick(c, 1.0)
	assert_true(p.prophet["corrupted"], "mercy → madness [§12]")
	assert_eq(p.prophet["message"]["flavor"], "madness")
	var convert: GnomeData = c.gnomes[1]
	var fear_before: float = convert.get_feeling(Devotion.YOU, "fear")
	Prophet.tick(c, 1.0)
	assert_gt(
		convert.get_feeling(Devotion.YOU, "fear"),
		fear_before,
		"the mad creed demands dread, not wonder"
	)


func test_undoomed_prophets_never_flip():
	var c := _flock(4, 0.0)
	var p: GnomeData = c.gnomes[0]
	_anoint(p, 0.8)
	for year in 40:
		p.age += 1.0
		Prophet.tick(c, 1.0)
	assert_false(p.prophet["corrupted"], "90% of prophets die true")
	assert_eq(p.prophet["message"]["flavor"], "mercy")
