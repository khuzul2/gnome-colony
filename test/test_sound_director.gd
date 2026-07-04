extends GutTest

## T19.2 — diegetic sound [PROGRESS Phase 19, design §2.7c]: the full
## manifest exists on disk; EventBus stimuli resolve to their wavs;
## and the T14.4 invariant holds — pressing an armed panel button
## reaches NO sound, only the world answering does.


func _director() -> SoundDirector:
	var director := SoundDirector.new()
	add_child_autofree(director)
	return director


func test_the_whole_manifest_exists():
	for id in Catalog.defs():
		assert_true(
			FileAccess.file_exists("res://assets/sounds/phenomenon_%s.wav" % id),
			"phenomenon_%s.wav" % id
		)
	for id in Catalog.CONSEQUENCES:
		assert_true(
			FileAccess.file_exists("res://assets/sounds/consequence_%s.wav" % id),
			"consequence_%s.wav" % id
		)
	var names := SoundDirector.AMBIENCE + SoundDirector.UI + SoundDirector.EXTRA_EVENTS
	for key in SoundDirector.CORE_EVENTS:
		names.append(SoundDirector.CORE_EVENTS[key])
	for name in names:
		assert_true(FileAccess.file_exists("res://assets/sounds/%s.wav" % name), "%s.wav" % name)


func test_stimuli_resolve_to_their_wavs():
	var director := _director()
	EventBus.phenomenon.emit({"type": "landslide", "place": "x", "intensity": 0.5})
	assert_eq(director.last_played, "res://assets/sounds/phenomenon_landslide.wav")
	EventBus.phenomenon.emit({"type": "famine", "place": "x", "consequence": true})
	assert_eq(director.last_played, "res://assets/sounds/consequence_famine.wav")
	EventBus.phenomenon.emit({"type": "tail:landslide", "place": "x"})
	assert_eq(director.last_played, "res://assets/sounds/phenomenon_landslide.wav")
	EventBus.born.emit({"id": 1})
	assert_eq(director.last_played, "res://assets/sounds/event_born.wav")
	director.ui("ui_click")
	assert_eq(director.last_played, "res://assets/sounds/ui_click.wav")


func test_pressing_a_panel_button_reaches_no_sound():
	var director := _director()
	var panel := InfluencePanel.new()
	add_child_autofree(panel)
	panel.build(Catalog.defs())
	director.last_played = ""
	panel.buttons["still_air"].pressed.emit()
	assert_eq(director.last_played, "", "arming is not the world answering [T14.4, §2.7c]")
