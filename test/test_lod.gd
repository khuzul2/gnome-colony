extends GutTest

## T11.1 — LOD manager [algo §14/§17]: individual fidelity (LOD-0/1) goes
## to gnomes under the Eye of God OR at notability ≥ 0.6; the quicken
## budget (WorldConfig, ~300) caps concurrent LOD-0; everyone else runs
## statistical (LOD-2) until the settlement's individual budget (~500)
## folds the overflow into settlement stats (LOD-3). Attention arrives as
## a SCRIPTED input of place ids — dwell/hysteresis are applied upstream
## (design §2.4); the sim only ever sees the resolved gaze.


func _band(n: int) -> Colony:
	var c := Colony.new()
	for i in n:
		var g := c.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = "the_hollow"
	return c


func test_notability_promotes_at_the_lod_line():
	var c := _band(3)
	c.gnomes[0].notability = 0.6
	c.gnomes[1].notability = 0.59
	Lod.assign(c, [], 300)
	assert_eq(c.gnomes[0].lod, Lod.QUICKENED, "0.6 crosses §14's promotion line")
	assert_eq(c.gnomes[1].lod, Lod.STATISTICAL, "0.59 does not")
	assert_eq(c.gnomes[2].lod, Lod.STATISTICAL)


func test_the_eye_promotes_whole_places():
	var c := _band(4)
	c.gnomes[2].location = "eastern_ridge"
	Lod.assign(c, ["eastern_ridge"], 300)
	assert_eq(c.gnomes[2].lod, Lod.QUICKENED, "under the dwelled gaze")
	assert_eq(c.gnomes[0].lod, Lod.STATISTICAL, "the unwatched stay statistical")


func test_quicken_budget_caps_lod0():
	var c := _band(6)
	for i in 6:
		c.gnomes[i].notability = 0.6 + 0.01 * i
	Lod.assign(c, [], 3)
	var quickened := []
	var individual := []
	for g in c.living():
		if g.lod == Lod.QUICKENED:
			quickened.append(g.id)
		elif g.lod == Lod.INDIVIDUAL:
			individual.append(g.id)
	assert_eq(quickened.size(), 3, "the quicken budget is a hard gameplay cap [§14]")
	assert_eq(
		quickened, [3, 4, 5], "the three MOST notable claim the budget (collected in id order)"
	)
	assert_eq(individual.size(), 3, "eligible overflow keeps individual fidelity at LOD-1")


func test_attention_leaving_demotes():
	var c := _band(2)
	Lod.assign(c, ["the_hollow"], 300)
	assert_eq(c.gnomes[0].lod, Lod.QUICKENED)
	Lod.assign(c, [], 300)
	assert_eq(c.gnomes[0].lod, Lod.STATISTICAL, "the Eye moves on; fate rejoins the statistics")


func test_settlement_budget_folds_the_crowd():
	var c := _band(8)
	for i in 8:
		c.gnomes[i].notability = 0.1 + 0.01 * i
	Lod.assign(c, [], 300, 5)
	var folded := []
	for g in c.living():
		if g.lod == Lod.FOLDED:
			folded.append(g.id)
	assert_eq(folded, [0, 1, 2], "beyond the individual budget the LEAST notable fold [§14]")


func test_eligible_gnomes_never_fold():
	var c := _band(8)
	c.gnomes[0].notability = 0.9
	Lod.assign(c, [], 300, 3)
	assert_eq(c.gnomes[0].lod, Lod.QUICKENED, "a prophet is tracked even in a crowd")
	var individual_count := 0
	for g in c.living():
		if g.lod != Lod.FOLDED:
			individual_count += 1
	assert_eq(individual_count, 3, "the budget still holds overall")


func test_assignment_is_deterministic():
	var a := _band(10)
	var b := _band(10)
	for i in 10:
		a.gnomes[i].notability = 0.55 + 0.01 * i
		b.gnomes[i].notability = 0.55 + 0.01 * i
	Lod.assign(a, ["the_hollow"], 4, 6)
	Lod.assign(b, ["the_hollow"], 4, 6)
	for i in 10:
		assert_eq(a.gnomes[i].lod, b.gnomes[i].lod, "same inputs, same fates (replay-safe)")


func test_lod_round_trips():
	var c := _band(2)
	c.gnomes[0].notability = 0.7
	Lod.assign(c, [], 300)
	var restored := Serializer.colony_from_dict(Serializer.colony_to_dict(c))
	assert_eq(restored.gnomes[0].lod, Lod.QUICKENED)
	assert_eq(restored.gnomes[1].lod, Lod.STATISTICAL)
