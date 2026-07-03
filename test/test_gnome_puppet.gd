extends GutTest

## T13.2 — GnomePuppet [plan Phase 13]: a scene that READS a GnomeData
## and renders it (scale by stage, tint by feeling, hidden when dead);
## pooled so ten thousand births don't churn nodes. And the structural
## invariant, enforced as a test: NO sim file references presentation —
## the sim must never know it is being watched.


func _gnome(stage: int) -> GnomeData:
	var g := GnomeData.new(0)
	g.stage = stage
	g.age = 30.0
	return g


func test_puppet_mirrors_data():
	var puppet := GnomePuppet.new()
	add_child_autofree(puppet)
	var adult := _gnome(Enums.LifeStage.ADULT)
	puppet.bind(adult)
	assert_true(puppet.visible)
	var adult_scale := puppet.scale.x
	var infant := _gnome(Enums.LifeStage.INFANT)
	puppet.bind(infant)
	assert_lt(puppet.scale.x, adult_scale, "an infant puppet is small")
	infant.stage = Enums.LifeStage.ADULT
	puppet.refresh()
	assert_almost_eq(puppet.scale.x, adult_scale, 0.0001, "refresh follows the data")


func test_the_dead_leave_the_stage():
	var puppet := GnomePuppet.new()
	add_child_autofree(puppet)
	var g := _gnome(Enums.LifeStage.ADULT)
	puppet.bind(g)
	g.stage = Enums.LifeStage.DEAD
	puppet.refresh()
	assert_false(puppet.visible)


func test_feelings_tint_the_body():
	var puppet := GnomePuppet.new()
	add_child_autofree(puppet)
	var calm := _gnome(Enums.LifeStage.ADULT)
	puppet.bind(calm)
	var calm_red: float = puppet.tint().r
	var afraid := _gnome(Enums.LifeStage.ADULT)
	afraid.set_feeling(Devotion.YOU, "fear", 0.9)
	puppet.bind(afraid)
	assert_gt(puppet.tint().r, calm_red, "dread reads at a glance (same mapping as the slice)")


func test_pool_reuses_released_puppets():
	var pool := PuppetPool.new()
	add_child_autofree(pool)
	var first := pool.acquire(_gnome(Enums.LifeStage.ADULT))
	pool.release(first)
	assert_false(first.visible, "released puppets vanish, not free()")
	var second := pool.acquire(_gnome(Enums.LifeStage.CHILD))
	assert_eq(second, first, "the pool hands the same node back — no churn")
	var third := pool.acquire(_gnome(Enums.LifeStage.ADULT))
	assert_ne(third, second, "an empty pool grows")


func test_no_sim_file_imports_presentation():
	var offenders := []
	var stack := ["res://sim"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		assert_not_null(dir, "sim/ must be readable")
		for sub in dir.get_directories():
			stack.append(dir_path + "/" + sub)
		for file in dir.get_files():
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir_path + "/" + file)
			for token in ["presentation/", "GnomePuppet", "PuppetPool", "WorldView", "CameraRig"]:
				if token in text:
					offenders.append("%s/%s → %s" % [dir_path, file, token])
	assert_eq(offenders, [], "the sim never knows it is being watched [design §2.3]")
