extends GutTest

## T2.1 — EventBus: autoload, signal-based [algo §16]. Systems react
## independently; payloads are Dictionaries.


func test_declares_all_core_signals():
	for signal_name in [
		"born", "gnome_died", "stage_changed", "knowledge_lost", "belief_formed", "phenomenon"
	]:
		assert_true(EventBus.has_signal(signal_name), "missing signal: %s" % signal_name)


func test_emit_and_receive_payload_intact():
	watch_signals(EventBus)
	var payload := {"id": 3, "cause": "hardship"}
	EventBus.gnome_died.emit(payload)
	assert_signal_emitted_with_parameters(EventBus, "gnome_died", [payload])


func test_stage_changed_payload_shape():
	watch_signals(EventBus)
	EventBus.stage_changed.emit(
		{"id": 1, "from": Enums.LifeStage.CHILD, "to": Enums.LifeStage.ADOLESCENT}
	)
	var params: Array = get_signal_parameters(EventBus, "stage_changed")
	assert_eq(params[0]["from"], Enums.LifeStage.CHILD)
	assert_eq(params[0]["to"], Enums.LifeStage.ADOLESCENT)


func test_multiple_subscribers_all_receive():
	var seen := []
	var sub_a := func(p: Dictionary) -> void: seen.append(["a", p["id"]])
	var sub_b := func(p: Dictionary) -> void: seen.append(["b", p["id"]])
	EventBus.born.connect(sub_a)
	EventBus.born.connect(sub_b)
	EventBus.born.emit({"id": 9})
	EventBus.born.disconnect(sub_a)
	EventBus.born.disconnect(sub_b)
	assert_eq(seen, [["a", 9], ["b", 9]])
