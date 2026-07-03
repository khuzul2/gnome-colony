extends GutTest

## T14.4 — diegetic ambience & act feedback [design §2.7c, locked]:
## ambience LAYERS read sim state — season, local mood, silence as the
## primary instrument (the uncanny arrives by subtraction: the Still
## Air is an audio phenomenon), "familiar, slightly wrong" for tainted
## beats, and music that is the colony's culture made audible. Act
## feedback is STRICTLY diegetic: no UI stingers, no confirmation
## fanfare — a button press changes nothing; only the landed
## phenomenon moves a layer. Audio reads the sim, never touches it.


func _audio_nodes_under(node: Node) -> Array:
	var found := []
	for child in node.get_children():
		if (
			child is AudioStreamPlayer
			or child is AudioStreamPlayer2D
			or child is AudioStreamPlayer3D
		):
			found.append(child)
		found.append_array(_audio_nodes_under(child))
	return found


func _director() -> AmbienceDirector:
	var director := AmbienceDirector.new()
	add_child_autofree(director)
	return director


func _colony_at(place: String, need_level: float) -> Colony:
	var colony := Colony.new()
	for i in 4:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = place
		for key in Enums.NEED_KEYS:
			g.needs[key] = need_level
	return colony


func test_season_and_local_mood_track_the_sim():
	var director := _director()
	var time := TimeService.new()
	var colony := _colony_at("the_hollow", 0.2)
	var params: Dictionary = director.params(colony, time, "the_hollow")
	assert_eq(params["season"], 0, "spring opens the world")
	assert_almost_eq(params["mood"], 0.8, 0.001, "the layer reads §5 mood, not its own guess")
	for i in 24:
		time.advance(1.0)
	for g in colony.living():
		for key in Enums.NEED_KEYS:
			g.needs[key] = 0.9
	params = director.params(colony, time, "the_hollow")
	assert_eq(params["season"], 1, "…a season later the bed changes")
	assert_almost_eq(params["mood"], 0.1, 0.001, "…and misery darkens the room tone")


func test_the_still_air_silences_by_subtraction():
	var director := _director()
	var colony := _colony_at("the_hollow", 0.2)
	var time := TimeService.new()
	assert_almost_eq(
		director.params(colony, time, "the_hollow")["silence"], 0.0, 0.001, "birdsong by default"
	)
	EventBus.phenomenon.emit(
		{
			"type": "still_air",
			"category": 1,
			"place": "the_hollow",
			"intensity": 0.8,
			"valence": "neutral",
			"effects": {}
		}
	)
	assert_almost_eq(
		director.params(colony, time, "the_hollow")["silence"],
		0.8,
		0.001,
		"the birdsong STOPS — silence is the instrument [§2.7c]"
	)
	assert_almost_eq(
		director.params(colony, time, "meadow")["silence"],
		0.0,
		0.001,
		"…only where the air went still"
	)
	director.update(AmbienceDirector.SILENCE_FADE_SECONDS)
	assert_almost_eq(
		director.params(colony, time, "the_hollow")["silence"],
		0.0,
		0.001,
		"the world breathes again after the fade (presentation seconds)"
	)


func test_tainted_beats_sound_familiar_but_wrong():
	var director := _director()
	var colony := _colony_at("the_hollow", 0.2)
	var time := TimeService.new()
	assert_almost_eq(director.params(colony, time, "the_hollow")["wrongness"], 0.0, 0.001)
	EventBus.phenomenon.emit(
		{
			"type": "weeping_sky",
			"category": 1,
			"place": "the_hollow",
			"intensity": 0.5,
			"valence": "benevolent",
			"taint": "tainted",
			"effects": {}
		}
	)
	assert_gt(
		director.params(colony, time, "the_hollow")["wrongness"],
		0.0,
		"rain that sounds almost like whispering [§2.7c]"
	)


func test_music_is_their_culture_audible():
	var director := _director()
	var colony := _colony_at("the_hollow", 0.2)
	var time := TimeService.new()
	assert_eq(
		director.params(colony, time, "the_hollow")["music"],
		"none",
		"no crystallized culture, no score [§2.7c]"
	)
	colony.beliefs.append(BeliefObject.make("rite", "harvest", "awe", 0.5, [0, 1]))
	assert_eq(
		director.params(colony, time, "the_hollow")["music"], "rite_melody", "a rite gains a melody"
	)
	var creed := BeliefObject.make("theology", Devotion.YOU, "faith", 0.5, [0, 1])
	colony.beliefs.append(creed)
	for g in colony.living():
		g.set_feeling(Devotion.YOU, "fear", 0.8)
		g.set_feeling(Devotion.YOU, "awe", 0.1)
	assert_eq(
		director.params(colony, time, "the_hollow")["music"],
		"hymn_urgent",
		"a terror-faith's hymns run thin and urgent"
	)
	for g in colony.living():
		g.set_feeling(Devotion.YOU, "fear", 0.0)
		g.set_feeling(Devotion.YOU, "awe", 0.6)
	assert_eq(
		director.params(colony, time, "the_hollow")["music"],
		"hymn_warm",
		"…a loved god's hymns sit warm"
	)


func test_casting_triggers_no_ui_audio_only_the_world_does():
	var director := _director()
	var colony := _colony_at("the_hollow", 0.2)
	var time := TimeService.new()
	var panel := InfluencePanel.new()
	add_child_autofree(panel)
	panel.build(Catalog.defs())
	colony.unlocked_tier = 6
	panel.refresh(colony)
	var before: Dictionary = director.params(colony, time, "the_hollow")
	panel.arm("still_air")
	panel.paint({"place": "the_hollow"})
	var after: Dictionary = director.params(colony, time, "the_hollow")
	assert_eq(before, after, "the button press is SILENT — no stinger, no fanfare [§2.7c]")
	# Reviewer catch: asserting absent dict keys was tautological. The
	# real claims: the UI owns no audio node anywhere in its subtree,
	# and the director never subscribed to the button's signal.
	assert_eq(_audio_nodes_under(panel).size(), 0, "the UI layer owns no speaker at all [§2.7c]")
	assert_false(
		panel.cast_requested.is_connected(director._on_phenomenon),
		"the director hears the world, never the button"
	)
	EventBus.phenomenon.emit(
		{
			"type": "still_air",
			"category": 1,
			"place": "the_hollow",
			"intensity": 0.6,
			"valence": "neutral",
			"effects": {}
		}
	)
	assert_gt(
		director.params(colony, time, "the_hollow")["silence"],
		0.0,
		"the world simply… stills — feedback is the phenomenon itself"
	)
