extends GutTest

## T21.2/T22.5 — Movement [PROGRESS Phase 21/22]: presentation-only
## walking. RunView bakes a NavWorld from the skin, places every basin
## as a site, and turns a gnome's basin crossing into a walker that
## follows NavWorld.path_between's baked polyline over
## RunView.WALK_SECONDS in _process (wall-clock, no Rng/Time) — the
## sim's location writes stay the authoritative truth throughout. A
## buried road (WorldState.paths, T7.3) refuses the walk: the puppet
## holds its old anchor and re-checks next day. First placement is
## instant, so the existing RunView contract is untouched.
## (Probed layout, seed 1 @ default/medium: forest_0 home, the day
## trip rotates to ridge_1 — test_world_bootstrap.gd. GameRun stages
## locations BEFORE the tick advances the clock, so a staging CHANGE
## lands on the second advance_day: day-0's rotation trips ids 0/3,
## day-1's trips id 2 — probed.)

var _runs: Array = []


func after_each() -> void:
	for run in _runs:
		run.shutdown()
	_runs.clear()


func _view(seed_value: int, mutate: Callable = Callable()) -> RunView:
	Rng.seed_with(seed_value)
	var cfg := WorldConfig.new()
	cfg.seed = seed_value
	cfg.normalize()
	var run := GameRun.new_game(cfg)
	_runs.append(run)
	var view := RunView.new()
	view.run = run
	view.settings = GameSettings.new()
	if mutate.is_valid():
		mutate.call(view)
	add_child_autofree(view)
	return view


## Two days at speed 0: the second advance restages the rotation, so a
## founder who stood at home now day-trips (see header probe note).
func _rotate_the_trip(view: RunView) -> void:
	for i in 2:
		view.run.advance_day()


## The gnome whose sim location left home this staging.
func _tripper(view: RunView) -> GnomeData:
	for g in view.run.runner.colony.living():
		if g.location != view.run.home:
			return g
	return null


func test_ready_bakes_a_nav_world_with_every_basin_as_a_site():
	var view := _view(2121)
	assert_not_null(view.nav, "RunView raises a NavWorld [T21.2]")
	assert_gt(view.world_view.walkable_faces.size(), 0, "the skin fed real CPU faces")
	assert_not_null(view.nav.last_navigation_mesh, "…and the navmesh baked from them")
	for place in view.place_positions:
		assert_true(view.nav.site_positions.has(place), "%s placed as a site" % place)
		assert_eq(view.nav.site_positions[place], view.place_positions[place])


func test_a_day_trip_walks_instead_of_teleporting():
	var view := _view(1)
	view.set_speed(0.0)
	await wait_physics_frames(3)
	_rotate_the_trip(view)
	view._refresh_puppets()
	var tripper := _tripper(view)
	assert_not_null(tripper, "seed 1's rotation stages a day trip [probed]")
	var puppet: GnomePuppet = view._puppets[tripper.id]
	var target: Vector3 = view._stage_position(tripper)
	assert_true(view._walkers.has(tripper.id), "a walker carries the trip — no teleport")
	assert_gt(puppet.position.distance_to(target), 0.1, "…so the body is not there yet")
	view._process(RunView.WALK_SECONDS * 0.5)
	assert_gt(puppet.position.distance_to(target), 0.01, "half the walk: still en route")
	view._process(RunView.WALK_SECONDS)
	assert_lt(puppet.position.distance_to(target), 0.001, "the walk snaps onto the target")
	assert_false(view._walkers.has(tripper.id), "…and the walker retires")


## T22.5 — the walk follows the BAKED route, not the straight chord:
## the walker stores exactly path_between's polyline, and the half-time
## body stands ON that polyline at the constant-speed midpoint.
func test_the_walk_follows_the_baked_polyline():
	var view := _view(1)
	view.set_speed(0.0)
	await wait_physics_frames(3)
	_rotate_the_trip(view)
	view._refresh_puppets()
	var tripper := _tripper(view)
	assert_not_null(tripper, "seed 1's rotation stages a day trip [probed]")
	var walk: Dictionary = view._walkers[tripper.id]
	var route: PackedVector3Array = walk["route"]
	assert_gt(route.size(), 1, "the navmesh yielded a real route (home → ridge_1)")
	assert_eq(
		route,
		view.nav.path_between(view.run.home, tripper.location),
		"the walker stores exactly what path_between returned [T22.5]"
	)
	view._process(RunView.WALK_SECONDS * 0.5)
	var puppet: GnomePuppet = view._puppets[tripper.id]
	var points: PackedVector3Array = walk["points"]
	var nearest := INF
	for i in range(1, points.size()):
		var on_segment := Geometry3D.get_closest_point_to_segment(
			puppet.position, points[i - 1], points[i]
		)
		nearest = minf(nearest, puppet.position.distance_to(on_segment))
	assert_lt(nearest, 0.001, "mid-walk the body stands ON the polyline, not the chord")
	assert_eq(
		puppet.position,
		RunView._walk_position(walk, 0.5),
		"…at the constant-total-duration halfway point"
	)


func test_a_buried_road_refuses_the_walk():
	var view := _view(1)
	view.set_speed(0.0)
	await wait_physics_frames(3)
	var before := {}
	for id in view._puppets:
		before[id] = view._puppets[id].position
	view.run.world.paths["ridge_1_path"] = false
	_rotate_the_trip(view)
	view._refresh_puppets()
	var tripper := _tripper(view)
	assert_not_null(tripper, "the SIM still stages the trip — its truth is untouched")
	assert_eq(tripper.location, "ridge_1", "seed 1's trip place [probed]")
	var puppet: GnomePuppet = view._puppets[tripper.id]
	assert_false(view._walkers.has(tripper.id), "the world refuses — no walker starts")
	assert_eq(puppet.position, before[tripper.id], "the puppet holds its home anchor")
	view._process(RunView.WALK_SECONDS)
	assert_eq(puppet.position, before[tripper.id], "…and stays put through the day")


func test_the_refusal_lifts_when_the_road_reopens():
	var view := _view(1)
	view.set_speed(0.0)
	await wait_physics_frames(3)
	view.run.world.paths["ridge_1_path"] = false
	_rotate_the_trip(view)
	view._refresh_puppets()
	var tripper := _tripper(view)
	assert_false(view._walkers.has(tripper.id), "buried: refused")
	view.run.world.paths["ridge_1_path"] = true
	view._refresh_puppets()
	assert_true(view._walkers.has(tripper.id), "re-checked: the reopened road walks [T21.2]")
