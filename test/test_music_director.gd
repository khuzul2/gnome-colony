extends GutTest

## T20.2 — music resolution [PROGRESS Phase 20]: every music state and
## screen moment resolves to a track whose placeholder AND Suno brief
## exist; empty placeholders play as silence, never a crash.


func test_every_track_has_a_placeholder_and_a_brief():
	var names := MusicDirector.SEASON_TRACKS.duplicate()
	for key in MusicDirector.STATE_TRACKS:
		names.append(MusicDirector.STATE_TRACKS[key])
	for key in MusicDirector.SCREEN_TRACKS:
		names.append(MusicDirector.SCREEN_TRACKS[key])
	for key in MusicDirector.EVENT_TRACKS:
		names.append(MusicDirector.EVENT_TRACKS[key])
	for name in names:
		assert_true(
			FileAccess.file_exists("res://assets/music/%s.mp3" % name), "%s.mp3 exists" % name
		)
		assert_true(
			FileAccess.file_exists("res://assets/music/%s.md" % name),
			"%s.md carries the Suno brief" % name
		)


func test_states_and_seasons_resolve():
	var director := MusicDirector.new()
	add_child_autofree(director)
	assert_eq(director.track_for("hymn_urgent", 0), "res://assets/music/hymn_urgent.mp3")
	assert_eq(director.track_for("rite_melody", 2), "res://assets/music/rite_melody.mp3")
	assert_eq(
		director.track_for("none", 2),
		"res://assets/music/season_autumn.mp3",
		"no culture music yet — the season carries the bed"
	)
	assert_eq(director.screen_track("menu"), "res://assets/music/menu_theme.mp3")
	assert_eq(director.screen_track("chronicles"), "res://assets/music/world_end_lament.mp3")


## T22.3 — EVENT_TRACKS goes live: a frontier founding interrupts the
## bed with its track (the next season boundary restores the bed).
func test_a_founding_interrupts_the_bed():
	var director := MusicDirector.new()
	add_child_autofree(director)
	EventBus.settlement_founded.emit({"sid": 1, "place": "x", "day": 0})
	assert_eq(
		director.last_track,
		"res://assets/music/frontier_founding.mp3",
		"the founding cue resolves off the EventBus wiring [T22.3]"
	)


func test_empty_placeholders_play_as_silence():
	var director := MusicDirector.new()
	add_child_autofree(director)
	director.play(director.track_for("hymn_warm", 0))
	assert_eq(director.last_track, "res://assets/music/hymn_warm.mp3", "resolved, skipped, alive")
