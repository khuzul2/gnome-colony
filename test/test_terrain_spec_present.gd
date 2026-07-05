extends GutTest

## G0.1 — the Gaea terrain spec must exist and carry its section anchors + the
## constant summary. This guards the "numbers only from spec" invariant: the rest
## of the G-plan (docs/terrain-gaea-plan.md) cites docs/terrain-gaea.md as
## [gaea §X], so the spec's shape is a gate — same role test_rav_spec_present.gd
## plays for the Ravenna redesign.

const SPEC_PATH := "res://docs/terrain-gaea.md"
const ANCHORS := ["§gaea-gen", "§gaea-anchor", "§gaea-det", "§gaea-invariants"]
## Every constant the plan references must be pinned in the spec, so a task can
## never cite a value the source of truth doesn't fix.
const CONSTANTS := [
	"DETAIL_OCTAVES",
	"DETAIL_FREQ_PER_KM",
	"DETAIL_AMPLITUDE_T",
	"ANCHOR_RADIUS_KM",
	"ANCHOR_TOL",
	"GRID",
	"BAKE_BUDGET_MS",
]


func _read_spec() -> String:
	assert_true(FileAccess.file_exists(SPEC_PATH), "terrain-gaea.md must exist")
	var f := FileAccess.open(SPEC_PATH, FileAccess.READ)
	assert_not_null(f, "terrain-gaea.md must open")
	return f.get_as_text() if f != null else ""


func test_spec_exists_and_has_all_anchors():
	var text := _read_spec()
	for anchor in ANCHORS:
		assert_true(text.contains(anchor), "spec must define section anchor %s" % anchor)


func test_spec_pins_every_referenced_constant():
	var text := _read_spec()
	for c in CONSTANTS:
		assert_true(text.contains(c), "spec must pin the constant %s" % c)


func test_spec_marks_the_rng_independence_invariant():
	# The crux determinism rule: terrain noise is seeded from WorldConfig.seed and
	# NEVER draws from the Rng singleton. The spec must state it in words, since the
	# whole plan (and G1.1's tripwire test) rest on it.
	var text := _read_spec()
	assert_true(text.contains("WorldConfig.seed"), "spec must name the seed source")
	assert_true(text.contains("Rng"), "spec must state terrain never touches the Rng singleton")
