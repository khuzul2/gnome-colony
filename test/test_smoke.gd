extends GutTest


func test_arithmetic_sanity():
	assert_eq(1 + 1, 2, "the harness itself must be sane")


func test_project_boots():
	# If this test is executing at all, the Godot project booted headless
	# and GUT discovered res://test — assert the engine agrees.
	assert_true(OS.has_feature("headless") or DisplayServer.get_name() != "", "engine is running")
