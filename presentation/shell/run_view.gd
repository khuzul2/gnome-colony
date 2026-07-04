class_name RunView
extends Node
## The in-run view [PROGRESS T17.4, DONE.md handover note 3]: binds the
## tested presentation pieces to one live GameRun — WorldView skins the
## region graph, PuppetPool mirrors up to Render-Crowd-Density gnomes
## (setup §7.1, draw cap only — the sim never notices), CameraRig +
## AttentionInput turn dwell into the Eye's attention input (T13.5) fed
## to Lod each day, the InfluencePanel's arm→paint gesture routes into
## GameRun.cast with the AftermathPanel's page opened on the act, the
## AmbienceDirector keeps its diegetic params, and the HUD carries the
## slice's readout, speed buttons, Save and Menu. Pacing numbers
## (speeds, steps/frame, feed cap) and the scatter angle/step are the
## slice's presentation numbers promoted verbatim; SCATTER_BASE/SCALE
## re-derive its pixel ring for 3D km-space (render-only placement).
## The readout also carries the run's civilization truth [T22.4]:
## frontier settlement count + aggregate souls + the main seat's place,
## the Eye's quickened knot, and a fracture-risk warning as unrest
## nears Devotion.FRACTURE_LINE. §7.4 autosave cadence
## (off/season/year) emits save_requested("auto"); the shell owns slots
## and rolling. Movement [T21.2/T22.5] is presentation-only: a NavWorld
## baked from the skin gates basin crossings — when a gnome's sim
## location moves to another basin, its puppet WALKS the baked route:
## NavWorld.path_between's polyline is fetched at walk start and the
## body advances along it piecewise at constant TOTAL duration
## WALK_SECONDS (wall-clock in _process, independent of sim pacing; the
## sim's location write stays the authoritative truth the whole time;
## degenerate/short routes fall back to the straight lerp), and a
## buried road (NavWorld.path_between empty, the sim's T7.3 verdict)
## refuses the walk — the puppet holds its old anchor and re-checks
## next day. First placement (no prior position) is instant; only a
## CHANGE walks. Set `run` and `settings` before entering the tree.

signal save_requested(kind: String)
signal menu_requested

## Slice presentation numbers, promoted verbatim.
const SPEEDS := [["pause", 0.0], ["1 d/s", 1.0], ["7 d/s", 7.0], ["30 d/s", 30.0]]
const MAX_STEPS_PER_FRAME := 60
const FEED_CAP := 8
const SCATTER_ANGLE := 2.399
## Scatter ring in world km (render-only placement around a basin).
const SCATTER_BASE := 0.15
const SCATTER_STEP := 75
const SCATTER_SCALE := 300.0
## Presentation walk time [T21.2]: wall-clock seconds a puppet spends
## crossing to a new basin — a render flourish, never a sim number (the
## sim already wrote the location; the body just catches up on screen).
const WALK_SECONDS := 2.0
## Below this distance a puppet already stands at its target — no walk.
const WALK_EPSILON := 0.001
## Fracture-risk warning thresholds [T22.4] — PRESENTATION numbers (the
## sim's break line is Devotion.FRACTURE_LINE, algo §10; the spec
## authors no warning band, so these only choose when the HUD speaks):
## the readout warns at UNREST_WARN and sharpens at UNREST_WARN_DIRE.
const UNREST_WARN := 0.6
const UNREST_WARN_DIRE := 0.75

var run: GameRun
var settings: GameSettings
## Optional music hook [T20.2]: the shell hands its director in.
var music: MusicDirector = null

var world_view: WorldView
var nav: NavWorld
var camera: CameraRig
var attention: AttentionInput
var pool: PuppetPool
var influence_panel: InfluencePanel
var aftermath: AftermathPanel
var heatmap_overlay: HeatmapOverlay
var ambience: AmbienceDirector
var hud: Control
var place_positions := {}
## sid → place id [T22.4]: RunView's own lookup over run.graph.regions
## (GameRun keeps its _place_of private; the view stays self-sufficient).
var sid_places := {}
var days_per_sec := 0.0

var _accum := 0.0
var _puppets := {}
## In-flight walks [T21.2/T22.5]: gnome id → {from, to, t, route (the
## raw path_between polyline), points (from + route + to), cum
## (cumulative segment lengths), length} — advanced in _process from
## delta alone (no Rng, no Time), t mapped onto the polyline.
var _walkers := {}
## Each puppet's last ACCEPTED place, to detect basin crossings; a
## refused crossing keeps the old place so next day re-checks the road.
var _last_place := {}
var _feed: Array = []
var _hud_label: Label


func _ready() -> void:
	world_view = WorldView.new()
	add_child(world_view)
	world_view.sync(run.graph)
	for region in run.graph.regions:
		var center: Vector2 = region["center"]
		var place := WorldBootstrap.place_id(region)
		place_positions[place] = Vector3(center.x, world_view.height_at(center), center.y)
		sid_places[region["id"]] = place
	nav = NavWorld.new()
	add_child(nav)
	nav.bake(world_view)
	nav.attach(run.world)
	for place in place_positions:
		nav.place_site(place, place_positions[place])
	camera = CameraRig.new()
	add_child(camera)
	camera.focus(place_positions[run.home])
	attention = AttentionInput.new()
	add_child(attention)
	pool = PuppetPool.new()
	add_child(pool)
	ambience = AmbienceDirector.new()
	add_child(ambience)
	_build_hud()
	days_per_sec = settings.get_value("gameplay", "default_speed")
	influence_panel.refresh(run.runner.colony)
	_refresh_puppets()
	_refresh_hud()


## Wall-clock frame beat: gaze → Eye → attention input, then the day
## accumulator (slice pacing), then ambience fades.
func _process(delta: float) -> void:
	if run == null:
		return
	attention.update(delta, _gazed_place(), camera.level)
	run.attention_places = attention.attended()
	_accum += delta * days_per_sec
	var steps := 0
	while _accum >= 1.0 and steps < MAX_STEPS_PER_FRAME:
		_accum -= 1.0
		steps += 1
		_advance_one_day()
	_advance_walkers(delta)
	ambience.update(delta)


func set_speed(value: float) -> void:
	days_per_sec = value


func puppet_count() -> int:
	return _puppets.size()


## The paint gesture, one click per target kind [T14.1]: places serve
## point/area/settlement/region directly (one shared id namespace);
## region-edge paints the place's edge id (no tested composition ever
## authored edge terrain — such acts fizzle at the affordance gate,
## disclosed in PROGRESS).
func select_place(place: String) -> void:
	if influence_panel.armed() == "":
		return
	match influence_panel.armed_target_kind():
		"region":
			influence_panel.paint({"region": place})
		"region-edge":
			influence_panel.paint({"edge": "%s_edge" % place})
		"individual":
			pass
		_:
			influence_panel.paint({"place": place})


## Individual-kind targets (Visions) land where the chosen gnome stands.
func select_gnome(gnome_id: int) -> void:
	if influence_panel.armed_target_kind() != "individual":
		return
	var g: GnomeData = run.runner.colony.gnomes.get(gnome_id)
	if g != null and g.is_alive():
		influence_panel.paint({"gnome": gnome_id, "place": g.location})


func _advance_one_day() -> void:
	var report := run.advance_day()
	if report["season_changed"] and music != null:
		var colony := run.runner.colony
		var state: String = ambience.params(colony, run.runner.time, run.home)["music"]
		music.play(music.track_for(state, run.runner.time.season()))
	if report["season_changed"]:
		var mode: String = settings.get_value("gameplay", "autosave")
		var year_wrapped: bool = run.runner.time.season() == 0
		if mode == "season" or (mode == "year" and year_wrapped):
			save_requested.emit("auto")
	for id in report["discovered"]:
		_push_feed("💡 discovered: %s" % id)
	influence_panel.refresh(run.runner.colony)
	_refresh_puppets()
	if heatmap_overlay.visible:
		heatmap_overlay.refresh()
	_refresh_hud()


func _on_cast_requested(act_id: String, target: String, _selection: Dictionary) -> void:
	aftermath.begin(act_id)
	var stimuli := run.cast(act_id, target)
	for stim in stimuli:
		_push_feed("· %s at %s (intensity %.2f)" % [stim["type"], stim["place"], stim["intensity"]])
	influence_panel.refresh(run.runner.colony)
	_refresh_hud()


func _gazed_place() -> String:
	var eye := Vector2(camera.position.x, camera.position.z)
	var best := run.home
	var best_distance := INF
	for place in place_positions:
		var pos: Vector3 = place_positions[place]
		var distance := eye.distance_to(Vector2(pos.x, pos.z))
		if distance < best_distance:
			best_distance = distance
			best = place
	return best


## Mirror up to the render crowd cap [setup §7.1] — a DRAW budget; the
## colony itself is untouched (T15.4's invariant test is the proof).
## Position changes WALK [T21.2]: first placement is instant, a basin
## crossing whose road the sim buried is refused (the puppet holds its
## old anchor this day), everything else lerps via a walker.
func _refresh_puppets() -> void:
	var cap := settings.drawn_cap()
	var living := run.runner.colony.living()
	var wanted := {}
	for i in mini(cap, living.size()):
		wanted[living[i].id] = living[i]
	for id in _puppets.keys():
		if not wanted.has(id):
			pool.release(_puppets[id])
			_puppets.erase(id)
			_walkers.erase(id)
			_last_place.erase(id)
	for id in wanted:
		var g: GnomeData = wanted[id]
		if not _puppets.has(id):
			_puppets[id] = pool.acquire(g)
			_puppets[id].position = _stage_position(g)
			_last_place[id] = g.location
		var puppet: GnomePuppet = _puppets[id]
		puppet.refresh()
		_stage_walk(id, puppet, g)


## Decide how one puppet meets its target stage position [T21.2/T22.5]:
## a basin crossing fetches NavWorld.path_between's polyline ONCE, at
## walk start, and the walker carries it to arrival.
func _stage_walk(id: int, puppet: GnomePuppet, g: GnomeData) -> void:
	var target := _stage_position(g)
	if puppet.position.distance_to(target) <= WALK_EPSILON:
		puppet.position = target
		_walkers.erase(id)
		_last_place[id] = g.location
		return
	if _walkers.has(id) and _walkers[id]["to"].distance_to(target) <= WALK_EPSILON:
		return  # Already walking there — let the walker finish.
	var last: String = _last_place.get(id, g.location)
	var route := PackedVector3Array()
	if last != g.location:
		route = nav.path_between(last, g.location)
		if route.is_empty():
			# The world refuses [T7.3 buried road]: stay at the old anchor;
			# _last_place keeps the old basin so next day re-checks the road.
			_walkers.erase(id)
			return
	_walkers[id] = _make_walker(puppet.position, target, route)
	_last_place[id] = g.location


## Build one walker [T22.5]: the puppet's real (scattered) endpoints
## bracket the baked route, and cumulative segment lengths let t map
## onto the polyline at constant speed. A degenerate route (fewer than
## two waypoints, or ~zero length) falls back to the straight lerp.
func _make_walker(from: Vector3, to: Vector3, route: PackedVector3Array) -> Dictionary:
	var points := PackedVector3Array([from])
	if route.size() >= 2:
		points.append_array(route)
	points.append(to)
	var cum := PackedFloat32Array([0.0])
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		cum.append(total)
	if total <= WALK_EPSILON:
		points = PackedVector3Array([from, to])
		cum = PackedFloat32Array([0.0, from.distance_to(to)])
		total = cum[1]
	return {
		"from": from,
		"to": to,
		"t": 0.0,
		"route": route,
		"points": points,
		"cum": cum,
		"length": total
	}


## Advance in-flight walks — wall-clock, accumulated from delta only
## (deterministic under fixed frame deltas; independent of sim pacing).
## t ∈ [0,1] covers the WHOLE polyline in WALK_SECONDS [T22.5].
func _advance_walkers(delta: float) -> void:
	var arrived := []
	for id in _walkers:
		var walk: Dictionary = _walkers[id]
		walk["t"] = float(walk["t"]) + delta / WALK_SECONDS
		var puppet: GnomePuppet = _puppets.get(id)
		if puppet == null:
			arrived.append(id)
			continue
		if walk["t"] >= 1.0:
			puppet.position = walk["to"]
			arrived.append(id)
		else:
			puppet.position = _walk_position(walk, walk["t"])
	for id in arrived:
		_walkers.erase(id)


## Map t ∈ [0,1] onto the walker's polyline at constant total speed
## [T22.5]: find the segment holding t·length and lerp inside it.
static func _walk_position(walk: Dictionary, t: float) -> Vector3:
	var points: PackedVector3Array = walk["points"]
	var cum: PackedFloat32Array = walk["cum"]
	var total: float = walk["length"]
	if total <= 0.0 or points.size() < 2:
		return (walk["from"] as Vector3).lerp(walk["to"], t)
	var goal := t * total
	var i := 1
	while i < cum.size() - 1 and cum[i] < goal:
		i += 1
	var seg := cum[i] - cum[i - 1]
	if seg <= 0.0:
		return points[i]
	return points[i - 1].lerp(points[i], (goal - cum[i - 1]) / seg)


func _stage_position(g: GnomeData) -> Vector3:
	var anchor: Vector3 = place_positions.get(g.location, place_positions[run.home])
	var angle := g.id * SCATTER_ANGLE
	var radius := SCATTER_BASE + float((g.id * 29) % SCATTER_STEP) / SCATTER_SCALE
	return anchor + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _push_feed(line: String) -> void:
	_feed.append(line)
	while _feed.size() > FEED_CAP:
		_feed.pop_front()


func _build_hud() -> void:
	hud = VBoxContainer.new()
	hud.name = "run_hud"
	add_child(hud)
	_hud_label = Label.new()
	_hud_label.name = "readout"
	_hud_label.add_theme_font_size_override("font_size", 12)
	hud.add_child(_hud_label)
	influence_panel = InfluencePanel.new()
	influence_panel.build(Catalog.defs())
	influence_panel.cast_requested.connect(_on_cast_requested)
	hud.add_child(influence_panel)
	aftermath = AftermathPanel.new()
	hud.add_child(aftermath)
	heatmap_overlay = HeatmapOverlay.new()
	heatmap_overlay.build(run.runner.colony, run.settlements, sid_places)
	heatmap_overlay.visible = false
	hud.add_child(heatmap_overlay)
	var controls := HBoxContainer.new()
	controls.name = "controls"
	hud.add_child(controls)
	for entry in SPEEDS:
		var speed_button := Button.new()
		speed_button.text = entry[0]
		speed_button.pressed.connect(set_speed.bind(entry[1]))
		controls.add_child(speed_button)
	var heat_button := Button.new()
	heat_button.name = "heatmap"
	heat_button.text = "Heat"
	heat_button.pressed.connect(func() -> void: heatmap_overlay.toggle())
	controls.add_child(heat_button)
	var save_button := Button.new()
	save_button.name = "save"
	save_button.text = "Save"
	save_button.pressed.connect(func() -> void: save_requested.emit("manual"))
	controls.add_child(save_button)
	var menu_button := Button.new()
	menu_button.name = "menu"
	menu_button.text = "Menu"
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	controls.add_child(menu_button)


## The slice's readout, promoted: the state a god actually watches.
func _refresh_hud() -> void:
	var colony := run.runner.colony
	var vitals := colony.vitals()
	var flavor := Devotion.flavor_balance(colony)
	var mu := Magic.mu(colony, GameRun.HOME_SID)
	var lines := [
		(
			"%s · year %d · season %d · pop %d"
			% [
				run.config.colony_name,
				run.runner.time.year(),
				run.runner.time.season(),
				vitals["population"],
			]
		),
		(
			"mood %.2f · hunger %.2f · safety %.2f · unrest %.2f"
			% [
				vitals["mean_mood"],
				vitals["mean_needs"]["hunger"],
				vitals["mean_needs"]["safety"],
				colony.unrest,
			]
		),
		(
			"devotion %.2f · per-head %.3f · tier %d · %s"
			% [
				Devotion.total(colony),
				Devotion.per_capita(colony),
				colony.unlocked_tier,
				"love" if flavor >= 0.0 else "terror",
			]
		),
		"tech: %s" % ", ".join(colony.settlement_knowledge.get(GameRun.HOME_SID, {}).keys()),
		(
			"magic: %.3f (%s)%s"
			% [mu, Magic.stage(mu), " · home warded" if run.world.wards.has(run.home) else ""]
		),
	]
	# T22.4 — the run's civilization truth, no longer bare numbers.
	if not run.settlements.is_empty():
		var souls := 0.0
		for sid in run.settlements:
			souls += run.settlements[sid].pop()
		var seat := ""
		if sid_places.has(colony.main_settlement):
			seat = " · seat %s" % sid_places[colony.main_settlement]
		var plural := "" if run.settlements.size() == 1 else "s"
		lines.append(
			(
				"frontier: %d settlement%s · %.0f souls%s"
				% [run.settlements.size(), plural, souls, seat]
			)
		)
	if not run.quickened.is_empty():
		var held := 0
		var basins := PackedStringArray()
		var quickened_sids := run.quickened.keys()
		quickened_sids.sort()
		for sid in quickened_sids:
			held += run.quickened[sid].size()
			basins.append(sid_places.get(sid, "settlement_%d" % sid))
		lines.append("the Eye holds %d souls at %s" % [held, ", ".join(basins)])
	if colony.unrest >= UNREST_WARN_DIRE:
		lines.append(
			"⚠ unrest brushes the fracture line (%.1f) — a splinter looms" % Devotion.FRACTURE_LINE
		)
	elif colony.unrest >= UNREST_WARN:
		lines.append("⚠ unrest nears the fracture line (%.1f)" % Devotion.FRACTURE_LINE)
	if not _feed.is_empty():
		lines.append("— acts & signs —")
		lines.append_array(_feed)
	lines.append("— chronicle —")
	var chronicle := run.runner.chronicle
	lines.append_array(chronicle.slice(maxi(0, chronicle.size() - 5)))
	_hud_label.text = "\n".join(PackedStringArray(lines))
