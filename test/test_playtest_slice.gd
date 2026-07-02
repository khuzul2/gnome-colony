extends GutTest

## 🎮 Gate-1 slice smoke [plan Playtest Gate 1]: the throwaway scene must
## boot headless, advance sim days, and turn a button-cast into witnessed
## faith — otherwise the human has nothing to play. Fun itself is judged
## by the human (AWAIT_PLAYTEST.md), not here.


func _slice() -> Node2D:
	var scene: PackedScene = load("res://presentation/playtest/playtest_slice.tscn")
	var slice: Node2D = scene.instantiate()
	add_child_autofree(slice)
	return slice


func test_slice_boots_with_a_living_band():
	var slice := _slice()
	assert_gt(slice.runner.colony.population(), 0, "founders spawned")
	for g in slice.runner.colony.living():
		assert_true(g.location != "", "staging gave everyone a place to stand")


func test_slice_advances_days():
	var slice := _slice()
	for i in 5:
		slice._advance_day()
	assert_eq(slice.runner.time.day(), 5)
	assert_gt(slice.runner.colony.population(), 0, "five quiet days kill nobody")


func test_casting_seeds_witnessed_faith():
	var slice := _slice()
	assert_eq(Devotion.total(slice.runner.colony), 0.0)
	slice._on_cast("still_air", slice.HOLLOW)
	assert_gt(Devotion.total(slice.runner.colony), 0.0, "a witnessed act writes faith toward you")


func test_locked_act_does_nothing():
	var slice := _slice()
	assert_eq(slice.runner.colony.unlocked_tier, 1, "fresh colony holds Tier I only")
	slice._on_cast("landslide", slice.RIDGE)
	var still_there: ResourceNode = slice.world.sites[slice.RIDGE]
	assert_eq(still_there.current, 40.0, "a Tier-II act must not fire at Tier I")
