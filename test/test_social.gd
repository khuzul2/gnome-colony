extends GutTest

## T5.1 — relationship edges [algo §8/§17]: typed weights in [-1,1];
## interaction step w += 0.05·sign·compat; idle decay −0.001/day toward 0.
## compat rises with trait similarity (spec gives no closed formula —
## implemented as 1 − mean |Δtrait|, monotone in similarity, ∈[0,1]).


func _gnome_with_traits(id: int, value: float) -> GnomeData:
	var g := GnomeData.new(id)
	g.stage = Enums.LifeStage.ADULT
	for key in Enums.TRAIT_KEYS:
		g.set_trait(key, value)
	return g


func test_compat_rises_with_similarity():
	var a := _gnome_with_traits(0, 0.5)
	var twin := _gnome_with_traits(1, 0.5)
	var stranger := _gnome_with_traits(2, 1.0)
	assert_almost_eq(Social.compat(a, twin), 1.0, 0.0001)
	assert_almost_eq(Social.compat(a, stranger), 0.5, 0.0001)
	assert_true(Social.compat(a, twin) > Social.compat(a, stranger))


func test_positive_interaction_strengthens_symmetrically():
	var a := _gnome_with_traits(0, 0.5)
	var b := _gnome_with_traits(1, 0.5)
	Social.interact(a, b, "friend", 1.0)
	assert_almost_eq(a.relationships[1]["weight"], 0.05, 0.0001, "0.05·(+1)·compat(1.0)")
	assert_almost_eq(b.relationships[0]["weight"], 0.05, 0.0001, "edges update both ways")
	assert_eq(a.relationships[1]["type"], "friend")


func test_negative_interaction_weakens():
	var a := _gnome_with_traits(0, 0.5)
	var b := _gnome_with_traits(1, 0.5)
	Social.interact(a, b, "rival", -1.0)
	assert_almost_eq(a.relationships[1]["weight"], -0.05, 0.0001)


func test_repeated_interactions_accumulate_and_clamp():
	var a := _gnome_with_traits(0, 0.5)
	var b := _gnome_with_traits(1, 0.5)
	for i in 30:
		Social.interact(a, b, "mate", 1.0)
	assert_eq(a.relationships[1]["weight"], 1.0, "clamped at +1")


func test_idle_decay_moves_toward_zero_from_both_signs():
	var colony := Colony.new()
	var a := _gnome_with_traits(0, 0.5)
	var b := _gnome_with_traits(1, 0.5)
	colony.add(a)
	colony.add(b)
	a.set_relationship(1, "friend", 0.5)
	b.set_relationship(0, "rival", -0.5)
	Social.decay_tick(colony, 1.0)
	assert_almost_eq(a.relationships[1]["weight"], 0.499, 0.0001)
	assert_almost_eq(b.relationships[0]["weight"], -0.499, 0.0001)
	for i in 600:
		Social.decay_tick(colony, 1.0)
	assert_almost_eq(a.relationships[1]["weight"], 0.0, 0.001, "decays to 0, never overshoots")
