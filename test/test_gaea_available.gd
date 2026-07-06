extends GutTest

## G0.2 — the vendored Gaea addon (addons/gaea/, pinned in addons/gaea/SOURCES.md)
## must be usable HEADLESS: its runtime generation classes are registered, they
## instantiate with no editor/display/GPU, they compute a value, and that value is
## deterministic under a seed. This is the gate that Gaea actually loads on this
## Godot build before G1 builds TerrainField on top of it. It uses the LOW-LEVEL
## runtime noise node directly (a minimal availability smoke) — the fuller
## GaeaGenerator/graph API is exercised by G1's TerrainField.
##
## Gaea 2.0-beta6 registers class_names during `godot --headless --import` (the
## documented first-run step; the .godot cache is gitignored), so these class_name
## references resolve at test time.

const A_SEED := 12345
const A_CELL := Vector3i(3, 5, 0)


func _noise_value(node, seed_value: int, cell: Vector3i) -> float:
	var fnl := FastNoiseLite.new()
	fnl.seed = seed_value
	return node._get_noise_value(cell, fnl)


func test_gaea_runtime_noise_node_instantiates_headless():
	var noise := GaeaNodeNoise2D.new()
	assert_not_null(noise, "GaeaNodeNoise2D (Gaea runtime noise node) must instantiate headless")


func test_gaea_computes_a_finite_value_headless():
	var noise := GaeaNodeNoise2D.new()
	var v := _noise_value(noise, A_SEED, A_CELL)
	assert_true(is_finite(v), "Gaea noise node returns a finite value")
	assert_between(v, -1.0, 1.0, "FastNoiseLite noise value is in [-1, 1]")


func test_gaea_value_is_deterministic_under_seed():
	var noise := GaeaNodeNoise2D.new()
	var a := _noise_value(noise, 999, Vector3i(7, 2, 0))
	var b := _noise_value(noise, 999, Vector3i(7, 2, 0))
	assert_eq(a, b, "same seed + cell yields the same value (deterministic)")


func test_gaea_generator_node_instantiates_and_frees():
	var gen := GaeaGenerator.new()
	assert_not_null(gen, "GaeaGenerator (the runtime generator node) must instantiate headless")
	gen.free()
