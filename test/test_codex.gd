extends GutTest

## T14.3 (codex half) — the faint codex [design §3.8, locked: discover
## by trying]: no predicted effects, no odds, NO PRECISE ALMANAC. The
## codex accrues only faint, qualitative impressions ("the earth
## sometimes hides metal") from witnessed casts — frequency words, not
## counts; leanings, not numbers. Mastery stays a hunch, never a
## formula.

const DIGITS := "0123456789"
const CODEX_PATH := "user://test_codex_t214.json"


func after_all():
	if FileAccess.file_exists(CODEX_PATH):
		DirAccess.remove_absolute(CODEX_PATH)


func _stim(type: String, effects: Dictionary, intensity := 0.6) -> Dictionary:
	return {
		"type": type,
		"place": "the_hollow",
		"intensity": intensity,
		"drama": 0.6,
		"valence": "malevolent",
		"effects": effects,
	}


func _has_digit(text: String) -> bool:
	for ch in DIGITS:
		if ch in text:
			return true
	return false


func test_an_unobserved_act_is_pure_mystery():
	var codex := FaintCodex.new()
	assert_eq(codex.about("landslide"), [], "no almanac, no prediction [design §3.8]")
	assert_eq(codex.impressions(), [], "the book opens empty")


func test_a_witnessed_cast_leaves_a_faint_impression():
	var codex := FaintCodex.new()
	codex.observe(_stim("landslide", {"material": -0.3, "discovery": 0.4, "belief": 0.2}))
	var lines: Array = codex.about("landslide")
	assert_gt(lines.size(), 0, "the philosopher noted something")
	assert_string_contains(lines[0], "once", "a single sighting is only 'once'")


func test_impressions_hold_no_exact_data():
	var codex := FaintCodex.new()
	codex.observe(_stim("landslide", {"material": -0.3, "discovery": 0.4}, 0.6180339))
	codex.observe(_stim("still_air", {"belief": 0.3}, 0.25))
	for line in codex.impressions():
		assert_false(
			_has_digit(line), "no numbers ever: '%s' [design §3.8 no precise almanac]" % line
		)
		assert_false("0.6180339" in line, "the raw intensity never leaks")


func test_repetition_firms_the_hunch_without_counting():
	var codex := FaintCodex.new()
	for i in 6:
		codex.observe(_stim("landslide", {"discovery": 0.4}))
	var lines: Array = codex.about("landslide")
	assert_eq(lines.size(), 1, "the same lesson deepens, it does not repeat")
	assert_string_contains(lines[0], "often", "six sightings read as 'often' — a word, not a count")
	assert_false(_has_digit(lines[0]), "…and still no numbers")


func test_different_faces_of_one_act_accrue_separately():
	var codex := FaintCodex.new()
	codex.observe(_stim("landslide", {"discovery": 0.4}))
	codex.observe(_stim("landslide", {"population": -0.5}))
	var lines: Array = codex.about("landslide")
	assert_eq(lines.size(), 2, "two lessons: it uncovers, and it kills")


func test_an_unknown_effect_axis_stays_faceless_not_fatal():
	# Reviewer catch (T14.3): a future catalog entry with an axis the
	# phrase table doesn't know must degrade to mystery, not crash.
	var codex := FaintCodex.new()
	codex.observe(_stim("strange_act", {"weirdness": 0.9}))
	var lines: Array = codex.about("strange_act")
	assert_eq(lines.size(), 1, "the sighting is still recorded")
	assert_string_contains(lines[0], "without a trace", "…as a faceless impression")


func test_consequence_markers_teach_too():
	var codex := FaintCodex.new()
	var marker := {
		"type": "dam_flood",
		"place": "the_hollow",
		"intensity": 0.6,
		"valence": "neutral",
		"effects": {},
		"consequence": true,
	}
	codex.observe(marker)
	var lines: Array = codex.about("dam_flood")
	assert_gt(lines.size(), 0, "the domino is remembered as a thing that FOLLOWED")
	assert_string_contains(lines[0], "followed", "…in those words")


func test_the_book_survives_a_save_and_a_load():
	# T21.4 codex persistence: observe → save → load reads IDENTICALLY —
	# the reopened book is the same faint book, word for word.
	var codex := FaintCodex.new()
	for i in 3:
		codex.observe(_stim("landslide", {"discovery": 0.4}))
	codex.observe(_stim("landslide", {"population": -0.5}))
	codex.observe(_stim("still_air", {"belief": 0.3}))
	FaintCodex.save_file(CODEX_PATH, codex)
	var reopened := FaintCodex.load_file(CODEX_PATH)
	assert_eq(reopened.about("landslide"), codex.about("landslide"), "same impressions per act")
	assert_eq(reopened.impressions(), codex.impressions(), "…and the whole book reads the same")


func test_frequency_keeps_firming_after_a_reload():
	# The JSON trip must not corrupt the internal counts (doubles →
	# ints): four sightings saved + one more witnessed = "often" at 5.
	var codex := FaintCodex.new()
	for i in 4:
		codex.observe(_stim("landslide", {"discovery": 0.4}))
	FaintCodex.save_file(CODEX_PATH, codex)
	var reopened := FaintCodex.load_file(CODEX_PATH)
	reopened.observe(_stim("landslide", {"discovery": 0.4}))
	assert_string_contains(
		reopened.about("landslide")[0], "often", "the hunch firms across the session boundary"
	)


func test_a_missing_codex_file_opens_a_fresh_book():
	var codex := FaintCodex.load_file("user://no_such_codex_file.json")
	assert_eq(codex.impressions(), [], "no file → a fresh, empty codex — never a crash")


func test_to_dict_round_trips_as_plain_data():
	var codex := FaintCodex.new()
	codex.observe(_stim("landslide", {"discovery": 0.4}))
	var json := JSON.stringify(codex.to_dict(), "", true)
	var reparsed: Variant = JSON.parse_string(json)
	assert_not_null(reparsed, "the snapshot is pure plain data — it survives real JSON")
	var rebuilt := FaintCodex.from_dict(reparsed)
	assert_eq(rebuilt.impressions(), codex.impressions(), "dict → codex is lossless")
