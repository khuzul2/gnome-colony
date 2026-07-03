extends Node2D
## 🎮 Playtest Gate 1 — THROWAWAY vertical slice, not the real presentation
## layer (Phases 13–15). Run it with:
##   godot res://presentation/playtest/playtest_slice.tscn
## A top-down dot view of one band, buttons for the unlocked phenomena, and
## a mood/belief/devotion readout — just enough for a human to judge the
## nudge → response → belief → consequence loop. Extended for 🎮 Fun
## Check 2 with the Phase 9–10 systems: an ungated omen button seeds
## prophets, Prophet.tick preaches daily, research/magic advance each
## season/day, and the HUD reads prophets, creeds, tech, mu, and
## outliers. The sim stays pure: this
## scene only READS state and feeds legitimate inputs (seed, config,
## influence acts). Two slice-only pieces of glue, both documented below:
## day-trip staging (gnomes need locations before Phase 11/13 movement
## exists) and the daily belief/devotion composition (mirrors the
## integration tests until the real orchestrator lands in Phases 11–12).

const SEED := 8181
const HOLLOW := "the_hollow"
const RIDGE := "eastern_ridge"
const SITE_POS := {HOLLOW: Vector2(430, 340), RIDGE: Vector2(800, 170)}
const SITE_RADIUS := 105.0
## One act of each face, tier-gated live — plus an UNGATED omen (marked
## debug) so Fun Check 2 can play the prophet loop without grinding a
## 6-gnome band to the Tier-IV pop floor. Entry: [id, target, ungated].
const ACTS := [
	["still_air", HOLLOW, false],
	["standing_stones", HOLLOW, false],
	["landslide", RIDGE, false],
	["birds_silent", HOLLOW, true],
]
const SPEEDS := [["pause", 0.0], ["1 d/s", 1.0], ["7 d/s", 7.0], ["30 d/s", 30.0]]
const FEED_CAP := 8
const MAX_STEPS_PER_FRAME := 60

var runner: SimRunner
var world := WorldState.new()
var defs := Catalog.defs()
var handlers := Catalog.handlers()

var _days_per_sec := 1.0
var _accum := 0.0
var _day := 0
var _last_season := -1
## Slice-glue exposure signal for Magic.accrue: spikes to 1 on a cast,
## decays 2%/day (display-side shape, not a sim number).
var _exposure := 0.0
var _feed: Array = []
var _hud: Label
var _act_buttons := {}


func _ready() -> void:
	Rng.seed_with(SEED)
	var cfg := WorldConfig.new()
	cfg.seed = SEED
	cfg.band_size = 6
	cfg.temperament_leanings = ["devout", "social"]
	cfg.normalize()
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	# world passed so cfg.environmental_events = true above would bring
	# natural events to the slice; the default config keeps them off.
	runner = SimRunner.new(cfg, food, 60.0, null, null, world)
	world.sites[HOLLOW] = food
	world.sites[RIDGE] = ResourceNode.new("stone", 40.0, 40.0, 2.0, 0.8)
	world.hidden_resources[RIDGE] = [ResourceNode.new("iron", 30.0, 30.0, 0.0, 1.5)]
	world.affordances[RIDGE] = ["slope"]
	world.paths["%s_path" % RIDGE] = true
	_stage_locations()
	EventBus.belief_formed.connect(_on_belief_formed)
	EventBus.gnome_died.connect(_on_died)
	_build_ui()
	_refresh_hud()


func _exit_tree() -> void:
	EventBus.belief_formed.disconnect(_on_belief_formed)
	EventBus.gnome_died.disconnect(_on_died)
	runner.shutdown()


func _process(delta: float) -> void:
	if _days_per_sec <= 0.0 or runner.colony.population() == 0:
		return
	_accum += delta * _days_per_sec
	var steps := 0
	while _accum >= 1.0 and steps < MAX_STEPS_PER_FRAME:
		_accum -= 1.0
		steps += 1
		_advance_day()


func _advance_day() -> void:
	_day += 1
	_stage_locations()
	runner.tick()
	# Slice-only composition of the Phase 6/8/9/10 daily ticks (the sim's
	# real orchestrator arrives with Phases 11–12); numbers live in-system.
	Belief.propagate_tick(runner.colony, 1.0)
	Belief.decay_tick(runner.colony, 1.0)
	Belief.crystallize_tick(runner.colony, 1.0)
	Devotion.update_unlocks(runner.colony)
	Devotion.unrest_tick(runner.colony, 1.0)
	Prophet.tick(runner.colony, 1.0)
	Magic.accrue(
		runner.colony,
		0,
		runner.colony.vitals()["mean_traits"]["curious"],
		_exposure,
		_science(),
		1.0
	)
	_exposure *= 0.98
	if runner.time.season() != _last_season:
		_last_season = runner.time.season()
		_research_season()
	_ward_watch()
	_refresh_hud()
	queue_redraw()


## Slice glue: a flat need of 1.0 on the whole discoverable frontier plus
## food surplus — enough to watch the tech arc move; the environment tier
## (T11.x) will author real per-need pressures.
func _research_season() -> void:
	var known: Array = runner.colony.settlement_knowledge.get(0, {}).keys()
	var needs := {}
	for id in TechGraph.candidates(known):
		needs[id] = 1.0
	var pop := maxf(1.0, runner.colony.population())
	var surplus: float = clampf(runner.food.current / pop, 0.0, 1.0)
	for id in Research.season_tick(runner.colony, 0, needs, surplus):
		_push_feed("💡 discovered: %s" % id)


## Display-side science level: fraction of the TechGraph the settlement
## holds (slice glue; T11.2 brings real aggregate levels).
func _science() -> float:
	var known: Dictionary = runner.colony.settlement_knowledge.get(0, {})
	var hits := 0
	for id in TechGraph.defs():
		if known.has(id):
			hits += 1
	return float(hits) / maxi(1, TechGraph.defs().size())


## At the resistance stage their first ward rises over the hollow —
## visible proof the co-evolution turned (mage behavior proper is later).
func _ward_watch() -> void:
	if world.wards.has(HOLLOW):
		return
	var mu := Magic.mu(runner.colony, 0)
	if Magic.stage(mu) == "resistance":
		Magic.place_ward(world, HOLLOW, mu)
		_push_feed("🛡 the hollow is warded — your acts land softer here")


## Slice-only staging: a third of the adults (by id rotation) day-trip to
## the ridge, everyone else keeps to the hollow — so acts have honest
## on-site witnesses. NOT sim policy; movement arrives in Phases 11/13.
func _stage_locations() -> void:
	for g in runner.colony.living():
		var trip: bool = g.stage == Enums.LifeStage.ADULT and (g.id + _day) % 3 == 0
		g.location = RIDGE if trip else HOLLOW


func _on_cast(act_id: String, target: String, ungated: bool = false) -> void:
	var def: Dictionary = defs[act_id]
	if not ungated and def["tier"] > runner.colony.unlocked_tier:
		return
	var mu := Magic.mu(runner.colony, 0)
	var stimuli := Influence.cast_with_cascade(
		runner.colony,
		world,
		defs,
		act_id,
		target,
		Devotion.magnitude_multiplier(runner.colony),
		Devotion.valence_potency(def["valence"]),
		handlers
	)
	_exposure = 1.0
	for stim in stimuli:
		var present := []
		for g in runner.colony.living():
			if g.location == stim["place"]:
				present.append(g)
		# Prediction dulls expected portents; literacy explains you away.
		Influence.appraise_witnesses(
			runner.colony, stim, present, Magic.impact_mult_for(runner.colony, 0, stim)
		)
		if stim.get("drama", 0.0) > 0.0:
			Devotion.attribute(runner.colony, stim["drama"], mu, stim["valence"], present)
		_push_feed("· %s at %s (intensity %.2f)" % [stim["type"], stim["place"], stim["intensity"]])
		var caught := Prophet.try_seed(present, stim)
		if caught != null:
			_push_feed(
				(
					"⚡ #%d caught the calling — a %s creed"
					% [caught.id, caught.prophet["message"]["flavor"]]
				)
			)
	Devotion.update_unlocks(runner.colony)
	_refresh_hud()
	queue_redraw()


func _set_speed(days_per_sec: float) -> void:
	_days_per_sec = days_per_sec


func _push_feed(line: String) -> void:
	_feed.append(line)
	while _feed.size() > FEED_CAP:
		_feed.pop_front()


func _on_belief_formed(payload: Dictionary) -> void:
	_push_feed("★ belief formed: %s of %s" % [payload["kind"], payload["subject"]])


func _on_died(payload: Dictionary) -> void:
	_push_feed("† #%d died (%s)" % [payload["id"], payload["cause"]])


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(370, 0)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "GNOME COLONY — playtest slice (throwaway)"
	vbox.add_child(title)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_hud)
	for act in ACTS:
		var def: Dictionary = defs[act[0]]
		var btn := Button.new()
		var gate_tag: String = " [ungated for playtest]" if act[2] else ""
		btn.text = (
			"%s (Tier %d, %s) → %s%s" % [act[0], def["tier"], def["valence"], act[1], gate_tag]
		)
		btn.pressed.connect(_on_cast.bind(act[0], act[1], act[2]))
		vbox.add_child(btn)
		if not act[2]:
			_act_buttons[act[0]] = btn
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	for entry in SPEEDS:
		var btn := Button.new()
		btn.text = entry[0]
		btn.pressed.connect(_set_speed.bind(entry[1]))
		hbox.add_child(btn)


func _refresh_hud() -> void:
	var c := runner.colony
	var v := c.vitals()
	var flavor := Devotion.flavor_balance(c)
	var lines := []
	lines.append(
		"Year %d · season %d · pop %d" % [runner.time.year(), runner.time.season(), v["population"]]
	)
	lines.append(
		(
			"mood %.2f · hunger %.2f · safety %.2f · unrest %.2f"
			% [v["mean_mood"], v["mean_needs"]["hunger"], v["mean_needs"]["safety"], c.unrest]
		)
	)
	lines.append(
		(
			"devotion D %.2f · per-head %.3f (peak %.3f) · tier %d"
			% [Devotion.total(c), Devotion.per_capita(c), c.devotion_peak, c.unlocked_tier]
		)
	)
	lines.append("faith flavor %+.2f (%s)" % [flavor, "love" if flavor >= 0.0 else "terror"])
	if c.beliefs.is_empty():
		lines.append("beliefs: none yet")
	else:
		lines.append("beliefs:")
		for b in c.beliefs:
			lines.append("  %s of %s · strength %.2f" % [b["kind"], b["subject"], b["strength"]])
	for place in c.place_tags:
		lines.append("tags @ %s: %s" % [place, c.place_tags[place]])
	var prophet_lines := []
	for g in c.living():
		if g.prophet.is_empty():
			continue
		(
			prophet_lines
			. append(
				(
					"  #%d · %s creed · voice %.2f%s"
					% [
						g.id,
						g.prophet["message"]["flavor"],
						g.prophet.get("charisma", 0.0) * Prophet.arc(g),
						" · CORRUPTED" if g.prophet["corrupted"] else "",
					]
				)
			)
		)
	if not prophet_lines.is_empty():
		lines.append("prophets:")
		lines.append_array(prophet_lines)
		if Prophet.check_schism(c)["due"]:
			lines.append("  ⚠ SCHISM BREWING — two strong creeds")
	var known: Dictionary = c.settlement_knowledge.get(0, {})
	lines.append("tech: %s" % (", ".join(known.keys()) if not known.is_empty() else "none"))
	var mu := Magic.mu(c, 0)
	lines.append(
		(
			"magic: %.3f (%s)%s"
			% [mu, Magic.stage(mu), " · hollow warded" if world.wards.has(HOLLOW) else ""]
		)
	)
	var outliers := {}
	for g in c.living():
		if g.outlier_type != "":
			outliers[g.outlier_type] = outliers.get(g.outlier_type, 0) + 1
	if not outliers.is_empty():
		lines.append("outliers: %s" % outliers)
	if not _feed.is_empty():
		lines.append("— acts & signs —")
		lines.append_array(_feed)
	lines.append("— chronicle —")
	var tail: Array = runner.chronicle.slice(maxi(0, runner.chronicle.size() - 5))
	lines.append_array(tail)
	_hud.text = "\n".join(PackedStringArray(lines))
	for act_id in _act_buttons:
		var locked: bool = defs[act_id]["tier"] > c.unlocked_tier
		_act_buttons[act_id].disabled = locked


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for site in SITE_POS:
		var pos: Vector2 = SITE_POS[site]
		draw_circle(pos, SITE_RADIUS, Color(0.15, 0.19, 0.15))
		draw_arc(pos, SITE_RADIUS, 0.0, TAU, 48, Color(0.35, 0.4, 0.35), 2.0)
		var label_pos: Vector2 = pos + Vector2(-46.0, -SITE_RADIUS - 10.0)
		draw_string(font, label_pos, site, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.7))
		var tags: Dictionary = runner.colony.place_tags.get(site, {})
		if tags.has("cursed"):
			draw_arc(pos, SITE_RADIUS + 5.0, 0.0, TAU, 48, Color(0.8, 0.2, 0.2, 0.8), 3.0)
		if tags.has("blessed"):
			draw_arc(pos, SITE_RADIUS + 10.0, 0.0, TAU, 48, Color(0.9, 0.8, 0.3, 0.8), 3.0)
	for g in runner.colony.living():
		draw_circle(_dot_pos(g), _dot_radius(g), _dot_color(g))


## Display-only scatter (golden-angle by id) — never touches sim state.
func _dot_pos(g: GnomeData) -> Vector2:
	var center: Vector2 = SITE_POS.get(g.location, SITE_POS[HOLLOW])
	var angle: float = g.id * 2.399
	var radius: float = 18.0 + float((g.id * 29) % 75)
	return center + Vector2.from_angle(angle) * radius


func _dot_radius(g: GnomeData) -> float:
	match g.stage:
		Enums.LifeStage.INFANT:
			return 3.0
		Enums.LifeStage.CHILD:
			return 4.0
		Enums.LifeStage.ELDER:
			return 5.0
		_:
			return 6.0


## Red rises with fear (of the unseen will or of where they stand), warm
## gold with faith — so the colony's mood is readable at a glance.
func _dot_color(g: GnomeData) -> Color:
	var fear := maxf(g.get_feeling(Devotion.YOU, "fear"), g.get_feeling(g.location, "fear"))
	var faith: float = g.get_feeling(Devotion.YOU, "faith")
	return Color(0.5 + 0.5 * fear, 0.5 + 0.4 * faith - 0.2 * fear, 0.62 - 0.3 * fear)
