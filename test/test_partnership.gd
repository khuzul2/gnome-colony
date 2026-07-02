extends GutTest

## T5.2 — partnership [algo §8]: two unpartnered Adults with mutual
## mate-weight ≥ 0.6 and culturally permitted pair up.


func _adult(id: int) -> GnomeData:
	var g := GnomeData.new(id)
	g.age = 25.0
	g.stage = Enums.LifeStage.ADULT
	return g


func _colony_pair(weight_ab: float, weight_ba: float) -> Colony:
	var c := Colony.new()
	var a := _adult(0)
	var b := _adult(1)
	a.set_relationship(1, "mate", weight_ab)
	b.set_relationship(0, "mate", weight_ba)
	c.add(a)
	c.add(b)
	return c


func test_mutual_mate_weight_pairs():
	var c := _colony_pair(0.7, 0.65)
	Social.form_partnerships(c)
	assert_eq(c.gnomes[0].partner_id, 1)
	assert_eq(c.gnomes[1].partner_id, 0)


func test_one_sided_affection_does_not_pair():
	var c := _colony_pair(0.9, 0.3)
	Social.form_partnerships(c)
	assert_eq(c.gnomes[0].partner_id, -1)
	assert_eq(c.gnomes[1].partner_id, -1)


func test_threshold_is_point_six():
	var c := _colony_pair(0.6, 0.6)
	Social.form_partnerships(c)
	assert_eq(c.gnomes[0].partner_id, 1, "exactly 0.6 qualifies (≥)")
	var c2 := _colony_pair(0.59, 0.6)
	Social.form_partnerships(c2)
	assert_eq(c2.gnomes[0].partner_id, -1)


func test_non_adults_do_not_pair():
	var c := _colony_pair(0.9, 0.9)
	c.gnomes[0].stage = Enums.LifeStage.ADOLESCENT
	Social.form_partnerships(c)
	assert_eq(c.gnomes[1].partner_id, -1)


func test_already_partnered_stay_loyal():
	var c := _colony_pair(0.9, 0.9)
	# A real, LIVING spouse — a dead or missing partner would (correctly)
	# free the slot via the widowhood sweep added with T5.6.
	var spouse := _adult(5)
	spouse.partner_id = 0
	c.add(spouse)
	c.gnomes[0].partner_id = 5
	Social.form_partnerships(c)
	assert_eq(c.gnomes[1].partner_id, -1, "no pairing with someone already partnered")
	assert_eq(c.gnomes[0].partner_id, 5, "the existing partnership is untouched")


func test_widowhood_frees_the_slot():
	var c := _colony_pair(0.9, 0.9)
	var late_spouse := _adult(5)
	late_spouse.partner_id = 0
	late_spouse.stage = Enums.LifeStage.DEAD
	c.add(late_spouse)
	c.gnomes[0].partner_id = 5
	Social.form_partnerships(c)
	assert_eq(c.gnomes[0].partner_id, 1, "a widowed adult may pair again")


func test_culture_veto_blocks_pairing():
	var c := _colony_pair(0.9, 0.9)
	var forbid := func(_a: GnomeData, _b: GnomeData) -> bool: return false
	Social.form_partnerships(c, forbid)
	assert_eq(c.gnomes[0].partner_id, -1, "culture norms gate partnership [algo §8/§9]")
	assert_eq(c.gnomes[1].partner_id, -1)
