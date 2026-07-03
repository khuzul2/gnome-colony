extends GutTest

## T13.4 — camera & three-zoom lens [design §1.7c]: the world is read
## aggregate-first with frequent individual zooms — three discrete
## levels, civilization → settlement → individual, clamped at the ends,
## each with its own height (presentation numbers).


func _rig() -> CameraRig:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	return rig


func test_starts_at_settlement():
	assert_eq(_rig().level, CameraRig.Zoom.SETTLEMENT, "aggregate-primary [design §1.7c]")


func test_zoom_transitions_and_clamps():
	var rig := _rig()
	rig.zoom_in()
	assert_eq(rig.level, CameraRig.Zoom.INDIVIDUAL)
	rig.zoom_in()
	assert_eq(rig.level, CameraRig.Zoom.INDIVIDUAL, "clamped at the gnome's shoulder")
	rig.zoom_out()
	rig.zoom_out()
	assert_eq(rig.level, CameraRig.Zoom.CIVILIZATION)
	rig.zoom_out()
	assert_eq(rig.level, CameraRig.Zoom.CIVILIZATION, "clamped at the god's-eye")


func test_height_falls_as_the_eye_descends():
	var rig := _rig()
	rig.zoom_out()
	var civ_height := rig.camera.position.y
	rig.zoom_in()
	var settlement_height := rig.camera.position.y
	rig.zoom_in()
	var individual_height := rig.camera.position.y
	assert_gt(civ_height, settlement_height)
	assert_gt(settlement_height, individual_height)


func test_zoom_changed_fires_only_on_real_changes():
	var rig := _rig()
	var events := []
	rig.zoom_changed.connect(func(level: int) -> void: events.append(level))
	rig.zoom_in()
	rig.zoom_in()
	rig.zoom_out()
	assert_eq(events, [CameraRig.Zoom.INDIVIDUAL, CameraRig.Zoom.SETTLEMENT], "no clamp echoes")


func test_focus_moves_the_rig():
	var rig := _rig()
	rig.focus(Vector3(10, 0, -4))
	assert_eq(rig.position, Vector3(10, 0, -4))
