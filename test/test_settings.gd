extends GutTest

## T15.4 — global settings [setup §7]: presentation-only, persistent
## in user://settings.cfg, and constitutionally UNABLE to alter the
## sim. The load-bearing test: an identical seeded run under two
## Render Crowd Density values (with attention fixed) produces the
## SAME save hash — the density changes only what is drawn. The
## sim-affecting quicken budget deliberately lives in WorldConfig,
## never here.

const CFG_PATH := "user://test_settings_t154.cfg"


func after_all():
	if FileAccess.file_exists(CFG_PATH):
		DirAccess.remove_absolute(CFG_PATH)


func test_the_seven_dials_of_the_spec_are_present():
	var settings := GameSettings.new()
	for section in ["graphics", "audio", "controls", "gameplay", "accessibility"]:
		assert_true(settings.values.has(section), "§7 section: %s" % section)
	assert_true(
		settings.values["graphics"].has("render_crowd_density"),
		"Render Crowd Density is a graphics dial [§7.1]"
	)
	assert_true(settings.values["gameplay"].has("autosave"), "autosave frequency [§7.4]")
	assert_true(settings.values["accessibility"].has("colorblind"), "colorblind modes [§7.5]")
	for section in settings.values:
		for key in settings.values[section]:
			assert_false("quicken" in str(key), "the quicken budget NEVER lives here [§7.1 note]")


func test_settings_persist_to_cfg_and_back():
	var settings := GameSettings.new()
	settings.set_value("graphics", "render_crowd_density", 64)
	settings.set_value("audio", "music", 0.25)
	settings.set_value("accessibility", "colorblind", "deuteranopia")
	settings.save(CFG_PATH)
	var reloaded := GameSettings.load_from(CFG_PATH)
	assert_eq(reloaded.get_value("graphics", "render_crowd_density"), 64, "persisted [§7]")
	assert_eq(reloaded.get_value("audio", "music"), 0.25)
	assert_eq(reloaded.get_value("accessibility", "colorblind"), "deuteranopia")
	assert_eq(reloaded.get_value("gameplay", "autosave"), "season", "untouched keys keep defaults")


func test_unknown_keys_are_refused():
	var settings := GameSettings.new()
	assert_false(settings.set_value("graphics", "quicken_budget", 9999), "no smuggling [§7.1]")
	assert_false(settings.set_value("sim", "mortality", "brutal"), "no such section")
	assert_true(settings.set_value("graphics", "vsync", false), "real keys still work")


func _hash_of_run(density: int) -> String:
	Rng.seed_with(15400)
	var cfg := WorldConfig.new()
	cfg.seed = 15400
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	for g in runner.colony.living():
		g.location = "the_hollow"
	var settings := GameSettings.new()
	settings.set_value("graphics", "render_crowd_density", density)
	var pool := PuppetPool.new()
	add_child_autofree(pool)
	for day in 30:
		Lod.assign(runner.colony, [], cfg.quicken_budget)
		runner.tick()
		# The renderer draws at most `density` puppets — the ONLY thing
		# the dial may touch is this presentation-side count.
		var drawn := 0
		for g in runner.colony.living():
			if drawn >= settings.drawn_cap():
				break
			pool.acquire(g)
			drawn += 1
	var envelope := Serializer.save_to_dict(
		runner.colony, WorldState.new(), [], cfg, runner.time, []
	)
	return JSON.stringify(envelope, "", true).md5_text()


func test_render_crowd_density_changes_pixels_never_the_sim():
	var sparse := _hash_of_run(2)
	var dense := _hash_of_run(500)
	assert_eq(sparse, dense, "same seed, same attention, two densities, ONE sim [§7.1/§8]")


func test_drawn_cap_reads_the_dial():
	var settings := GameSettings.new()
	settings.set_value("graphics", "render_crowd_density", 7)
	assert_eq(settings.drawn_cap(), 7, "the renderer's budget is the dial")
