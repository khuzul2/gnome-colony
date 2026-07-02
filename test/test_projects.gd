extends GutTest

## T3.6 — multi-tick projects [algo §6, review C4]: a long-horizon goal
## persists across ticks (not re-decided) until done or abandoned. The
## urgency override reuses the spec's 0.9 desperate-need line — mild spikes
## never drop a project.


func _adult() -> GnomeData:
	var g := GnomeData.new(0)
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	return g


func _colony_with(g: GnomeData) -> Colony:
	var c := Colony.new()
	c.add(g)
	return c


func test_started_project_persists_and_completes():
	var g := _adult()
	var c := _colony_with(g)
	# 0.8, not 0.9 — at 0.9 the need is desperate and would abandon the
	# project via the urgency override.
	g.set_need("purpose", 0.8)
	Projects.start(g, "explore", 3.0)
	Projects.tick(c, 1.0)
	Projects.tick(c, 1.0)
	assert_false(g.project.is_empty(), "project persists mid-way")
	Projects.tick(c, 1.0)
	assert_true(g.project.is_empty(), "project completes after its duration")
	assert_almost_eq(g.needs["purpose"], 0.2, 0.0001, "completion applies the §6 create relief")


func test_mild_need_spike_does_not_drop_project():
	var g := _adult()
	var c := _colony_with(g)
	Projects.start(g, "build", 10.0)
	g.set_need("hunger", 0.6)
	Projects.tick(c, 1.0)
	assert_false(g.project.is_empty(), "0.6 hunger is uncomfortable, not desperate")


func test_desperate_need_abandons_project():
	var g := _adult()
	var c := _colony_with(g)
	Projects.start(g, "master", 10.0)
	g.set_need("hunger", 0.95)
	Projects.tick(c, 1.0)
	assert_true(g.project.is_empty(), "a desperate need (≥0.9) overrides the project")


func test_decide_returns_project_action_while_active():
	Rng.seed_with(3600)
	var g := _adult()
	g.set_need("social", 0.5)
	Projects.start(g, "explore", 5.0)
	assert_eq(Decide.choose(g, {}), "project:explore")


func test_decide_overrides_project_when_desperate():
	Rng.seed_with(3601)
	var g := _adult()
	g.set_need("hunger", 1.0)
	Projects.start(g, "explore", 5.0)
	assert_eq(Decide.choose(g, {"food_available": true}), "eat")


func test_project_round_trips_through_serializer():
	var g := _adult()
	Projects.start(g, "build", 7.0)
	g.project["progress"] = 2.0
	var restored := Serializer.gnome_from_dict(Serializer.gnome_to_dict(g))
	assert_eq(restored.project, g.project)
