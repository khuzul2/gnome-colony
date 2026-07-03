extends GutTest

## T13.5 — the Eye of God [design §2.4, algo §14/§17]: attention derives
## from the camera by DWELL — gaze must rest ≥ 2 s (⚙️) on a region to
## promote it, a promoted region releases only after ~10 s (⚙️) of the
## gaze being elsewhere, and civilization zoom never promotes (and
## counts as absence). Because release lags and dwell leads, an old and
## a new region can be attended AT ONCE — that overlap is the design,
## not a bug. Sparse [t_start, t_end, region, radius] segments record
## the stream so a run's attention replays identically (attention is a
## declared sim input). Radius-by-zoom values are presentation numbers.


func _eye() -> AttentionInput:
	var eye := AttentionInput.new()
	add_child_autofree(eye)
	return eye


func test_pan_past_never_promotes():
	var eye := _eye()
	for region in ["a", "b", "c", "d"]:
		eye.update(0.5, region, CameraRig.Zoom.SETTLEMENT)
	assert_eq(eye.attended(), [], "a passing glance is not the Eye [dwell ≥ 2 s]")


func test_dwell_promotes():
	var eye := _eye()
	eye.update(1.0, "the_hollow", CameraRig.Zoom.SETTLEMENT)
	assert_eq(eye.attended(), [], "1 s is not yet a gaze")
	eye.update(1.1, "the_hollow", CameraRig.Zoom.SETTLEMENT)
	assert_eq(eye.attended(), ["the_hollow"], "2.1 s of rest promotes [§17 dwell]")


func test_release_waits_out_the_hysteresis():
	var eye := _eye()
	eye.update(2.5, "the_hollow", CameraRig.Zoom.SETTLEMENT)
	eye.update(9.0, "elsewhere", CameraRig.Zoom.SETTLEMENT)
	assert_has(eye.attended(), "the_hollow", "9 s away — the old gaze lingers [~10 s hysteresis]")
	assert_has(eye.attended(), "elsewhere", "…while the new dwell already promoted (overlap)")
	eye.update(1.5, "elsewhere", CameraRig.Zoom.SETTLEMENT)
	assert_eq(eye.attended(), ["elsewhere"], "10.5 s away releases the hollow")


func test_returning_refreshes_the_gaze():
	var eye := _eye()
	eye.update(2.5, "the_hollow", CameraRig.Zoom.SETTLEMENT)
	eye.update(8.0, "elsewhere", CameraRig.Zoom.SETTLEMENT)
	eye.update(0.5, "the_hollow", CameraRig.Zoom.SETTLEMENT)
	eye.update(8.0, "elsewhere", CameraRig.Zoom.SETTLEMENT)
	assert_has(eye.attended(), "the_hollow", "coming back reset the hollow's release clock")


func test_civilization_zoom_never_promotes():
	var eye := _eye()
	eye.update(60.0, "the_hollow", CameraRig.Zoom.CIVILIZATION)
	assert_eq(eye.attended(), [], "never at civilization zoom [§14]")
	eye.update(2.5, "the_hollow", CameraRig.Zoom.SETTLEMENT)
	assert_eq(eye.attended(), ["the_hollow"])
	eye.update(11.0, "the_hollow", CameraRig.Zoom.CIVILIZATION)
	assert_eq(eye.attended(), [], "the god's-eye counts as absence; hysteresis ran out")


func test_radius_narrows_with_zoom():
	var eye := _eye()
	assert_gt(
		eye.radius_for(CameraRig.Zoom.SETTLEMENT),
		eye.radius_for(CameraRig.Zoom.INDIVIDUAL),
		"the closer the Eye, the tighter the circle"
	)
	assert_eq(
		eye.radius_for(CameraRig.Zoom.CIVILIZATION),
		0.0,
		"the god's-eye has no circle at all [reviewer minor]"
	)


func test_recording_replays_identically():
	var eye := _eye()
	var script := [
		[1.0, "a", CameraRig.Zoom.SETTLEMENT],
		[1.5, "a", CameraRig.Zoom.SETTLEMENT],
		[4.0, "b", CameraRig.Zoom.INDIVIDUAL],
		[3.0, "b", CameraRig.Zoom.INDIVIDUAL],
		[11.0, "c", CameraRig.Zoom.SETTLEMENT],
		[2.0, "c", CameraRig.Zoom.CIVILIZATION],
	]
	var live := []
	var t := 0.0
	for step in script:
		eye.update(step[0], step[1], step[2])
		t += step[0]
		live.append([t, eye.attended()])
	var segments := eye.recording()
	assert_gt(segments.size(), 0, "sparse segments were recorded")
	for segment in segments:
		assert_true(segment.has("radius"), "segments carry [t, region, radius] [design §2.4]")
	for sample in live:
		assert_eq(
			AttentionInput.attended_at(segments, sample[0]),
			sample[1],
			"the recorded stream replays the live gaze at t=%.1f [design §2.4]" % sample[0]
		)
