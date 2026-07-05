extends GutTest

## R0.1 — the redesign spec must exist and carry its section anchors + the
## 16-entry palette. This guards the "numbers only from spec" invariant: the
## rest of the R-plan cites docs/redesign-ravenna.md, so its shape is a gate.

const SPEC_PATH := "res://docs/redesign-ravenna.md"
const ANCHORS := ["§R-art", "§R-set", "§R-build", "§R-infl"]


func _read_spec() -> String:
	assert_true(FileAccess.file_exists(SPEC_PATH), "redesign-ravenna.md must exist")
	var f := FileAccess.open(SPEC_PATH, FileAccess.READ)
	assert_not_null(f, "redesign-ravenna.md must open")
	return f.get_as_text() if f != null else ""


func test_spec_exists_and_has_all_anchors():
	var text := _read_spec()
	for anchor in ANCHORS:
		assert_true(text.contains(anchor), "spec must define section anchor %s" % anchor)


func test_palette_table_has_16_hex_entries():
	var text := _read_spec()
	# Count palette rows: a table row beginning "| <n> |" that carries a
	# 6-digit hex in backticks (the palette table in §R-art).
	var row := RegEx.new()
	row.compile("^\\|\\s*\\d+\\s*\\|.*`#[0-9a-fA-F]{6}`")
	var count := 0
	for line in text.split("\n"):
		if row.search(line) != null:
			count += 1
	assert_eq(count, 16, "the §R-art palette must list exactly 16 tesserae colors")
