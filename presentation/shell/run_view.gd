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
## (speeds, steps/frame) and the scatter angle/step are the
## slice's presentation numbers promoted verbatim; SCATTER_BASE/SCALE
## re-derive its pixel ring for 3D km-space (render-only placement).
## The readout also carries the run's civilization truth [T22.4]:
## frontier settlement count + aggregate souls + the main seat's place,
## the Eye's quickened knot, and a fracture-risk warning as unrest
## nears Devotion.FRACTURE_LINE. Input & render [T23]: RunView lights
## the world (a sun + ambient WorldEnvironment — without them lit
## materials render black), drives the CameraRig from the settings key
## bindings (pan/zoom) and the mouse (wheel-zoom, click-to-target,
## hover highlight) via _unhandled_input, so the HUD's armed act meets a
## world pick and casts — the game's core verb, finally reachable by a
## human. Colours/angles/speeds here are presentation numbers.
## §7.4 autosave cadence
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
## R7.2 [leg §L-acts] — a cast was refused (precondition unmet / wrong-or-no
## target); the shell plays the refused UI sound, and RunView shows the reason
## at the cursor. Emitted with a short player-facing reason.
signal cast_refused(reason: String)

## Slice presentation numbers, promoted verbatim.
const SPEEDS := [["pause", 0.0], ["1 d/s", 1.0], ["7 d/s", 7.0], ["30 d/s", 30.0]]
const MAX_STEPS_PER_FRAME := 60
const SCATTER_ANGLE := 2.399
## Scatter ring in world km (render-only placement around a basin).
const SCATTER_BASE := 0.15
const SCATTER_STEP := 75
const SCATTER_SCALE := 300.0
## R6.1 [leg §L-hud]: gnomes were ~6 px and invisible at the aggregate zooms. A
## per-zoom visibility multiplier scales the figures up so they read (calibrated
## by the projection test to clear PUPPET_MIN_PX). Hieratic oversizing over a
## miniature landscape is apt for the Ravenna register. Tuned at Gate A2.
const PUPPET_MIN_PX := 6.0
## Legibility floor holds at the two PLAY zooms (settlement, individual). The
## civilization view is the world map — settlements read via their locators /
## medallions (R6.2/R6.3), so gnome bodies stay modest there (scaling one to 6 px
## at map range would make it dwarf the whole map).
const PUPPET_ZOOM_SCALE := {
	CameraRig.Zoom.CIVILIZATION: 3.0,
	CameraRig.Zoom.SETTLEMENT: 2.2,
	CameraRig.Zoom.INDIVIDUAL: 1.0,
}
## R6.3 [leg §L-hud] — on-world settlement locators: a floating name-plate + tier
## glyph above each basin so colonies are findable on the map; alpha fades with
## distance from the focus so distant plates don't clutter. Presentation numbers,
## tuned at Gate A2.
const LOCATOR_HEIGHT := 4.0
const LOCATOR_PIXEL_SIZE := 0.05
const LOCATOR_FADE_NEAR := 6.0
const LOCATOR_FADE_FAR := 30.0
const LOCATOR_FADE_FLOOR := 0.15
const TIER_GLYPH := {"hamlet": "·", "village": "◦", "town": "◆", "city": "☩"}
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
## R7.2 [leg §L-acts] — how long the refusal message lingers at the cursor.
const REJECT_MSG_SECONDS := 2.0
## Camera control [T23.2] — presentation numbers: km/sec panned across
## the ground at sensitivity 1.
const PAN_SPEED := 12.0
## Lighting & mood [R1.4] live in StageLighting (Ravenna gold-on-lapis),
## replacing T23.1's plain daylight.

var run: GameRun
var settings: GameSettings
## Optional music hook [T20.2]: the shell hands its director in.
var music: MusicDirector = null

## R1.2 — the mosaic pixel stage: the 3D world renders into stage.world (a
## low-res SubViewport) and this container upscales it; the mosaic shader
## (R1.3) rides on it. Window picking is scaled through stage.to_viewport.
var stage: PixelStage
var stage_world: SubViewport
var world_view: WorldView
var nav: NavWorld
var camera: CameraRig
var attention: AttentionInput
var pool: PuppetPool
var influence_panel: InfluencePanel
var aftermath: AftermathPanel
var heatmap_overlay: HeatmapOverlay
## R6.2 [leg §L-hud] — the settlement roster (how many colonies, where, what tier).
var settlement_roster: SettlementRoster
## R6.4 [leg §L-hud] — the living chronicle feed (recent story beats).
var chronicle_feed: ChronicleFeed
## R7.3 [leg §L-acts] — transient on-map markers for landed phenomena.
var cast_markers: CastMarkers
var ambience: AmbienceDirector
var hud: Control
var place_positions := {}
## sid → place id [T22.4]: RunView's own lookup over run.graph.regions
## (GameRun keeps its _place_of private; the view stays self-sufficient).
var sid_places := {}
var days_per_sec := 0.0
## The basin under the cursor while an act is armed [T23.4]; "" = none.
var hovered_place := ""

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
var _hud_label: Label
## R1.6 — place → its belief-tag medallion node (gold blessed / red cursed).
var _motifs := {}
var _motif_kinds := {}
## R6.3 [leg §L-hud] — sid → floating settlement locator (Label3D).
var _locators := {}
## R6.3 [leg §L-hud] — the life pulse: births/deaths since the season turned.
var _season_births := 0
var _season_deaths := 0
var _pulse_season := -1
## Input state [T23.2/T23.3/T23.4].
var _pan_keys := {}
var _zoom_keys := {}
var _pan_held := {}
var _pick_plane_y := 0.0
var _highlight: MeshInstance3D
## R7.2 [leg §L-acts] — the refusal banner + its fade countdown.
var _reject_label: Label
var _reject_timer := 0.0


func _ready() -> void:
	_build_stage()
	_build_environment()
	world_view = WorldView.new()
	stage_world.add_child(world_view)
	world_view.sync(run.graph)
	var y_sum := 0.0
	for region in run.graph.regions:
		var center: Vector2 = region["center"]
		var place := WorldBootstrap.place_id(region)
		place_positions[place] = Vector3(center.x, world_view.height_at(center), center.y)
		sid_places[region["id"]] = place
		y_sum += place_positions[place].y
	# The pick plane sits at the mean basin height so a click ray hits
	# near the true ground — minimal parallax when resolving the nearest
	# basin [T23.3].
	_pick_plane_y = y_sum / maxf(1.0, float(run.graph.regions.size()))
	nav = NavWorld.new()
	add_child(nav)
	nav.bake(world_view)
	nav.attach(run.world)
	for place in place_positions:
		nav.place_site(place, place_positions[place])
	camera = CameraRig.new()
	# R5.2 [leg §L-relief]: pixel-snap the presented camera so the mosaic grout
	# doesn't crawl on pan; the rig's logical position stays continuous.
	camera.snap_enabled = true
	# R6.1 [leg §L-hud]: rescale the figures for legibility whenever the zoom changes.
	camera.zoom_changed.connect(func(_level: int) -> void: _apply_puppet_view_scale())
	stage_world.add_child(camera)
	camera.focus(place_positions[run.home])
	attention = AttentionInput.new()
	add_child(attention)
	pool = PuppetPool.new()
	stage_world.add_child(pool)
	# R7.3 [leg §L-acts]: landed phenomena flash a medallion on the map. Inside the
	# stage so the markers render through the mosaic; it owns its own subscription.
	cast_markers = CastMarkers.new()
	cast_markers.place_positions = place_positions
	stage_world.add_child(cast_markers)
	ambience = AmbienceDirector.new()
	add_child(ambience)
	_build_hud()
	_build_controls()
	days_per_sec = settings.get_value("gameplay", "default_speed")
	influence_panel.refresh(run.runner.colony, _met_affordances())
	_refresh_puppets()
	_refresh_motifs()
	# R6.3 [leg §L-hud]: the life pulse counts births/deaths within a season.
	_pulse_season = run.runner.time.season()
	EventBus.born.connect(_on_born)
	EventBus.gnome_died.connect(_on_died)
	_refresh_locators()
	_refresh_hud()


## R6.3 [leg §L-hud] — roll the pulse to the current season BEFORE counting, so an
## event on the day the season turns opens the NEW season's tally instead of being
## added to the old one and then wiped (the reset must never race the count).
func _roll_season() -> void:
	var season := run.runner.time.season()
	if season != _pulse_season:
		_pulse_season = season
		_season_births = 0
		_season_deaths = 0


func _on_born(_payload: Dictionary) -> void:
	_roll_season()
	_season_births += 1


func _on_died(_payload: Dictionary) -> void:
	_roll_season()
	_season_deaths += 1


func _exit_tree() -> void:
	# Drop the life-pulse subscriptions when the run is torn down so a rebuilt
	# RunView never double-counts (the chronicle feed disconnects its own wiring).
	for pair in [[EventBus.born, _on_born], [EventBus.gnome_died, _on_died]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


## The mosaic pixel stage [R1.2]: a low-res SubViewport (its own World3D)
## that the 3D world renders into, upscaled to the window with nearest-
## neighbor filtering. In real play the stage fills the window and tracks
## resize; headless leaves it at size 0 (nothing to display) so the analytic
## picking round-trip stays identity.
func _build_stage() -> void:
	stage = PixelStage.new()
	stage.name = "pixel_stage"
	add_child(stage)
	stage_world = stage.world
	# The mosaic post-process rides on the stage's screen [R1.3].
	stage.set_screen_material(Mosaic.make_material())
	if DisplayServer.get_name() != "headless":
		var vp := get_viewport()
		stage.fit_to(vp.get_visible_rect().size)
		vp.size_changed.connect(
			func() -> void: stage.fit_to(get_viewport().get_visible_rect().size)
		)


## Light the world [T23.1] in the Ravenna register [R1.4]: a low gold key
## light + deep-lapis ambient (StageLighting), inside the pixel stage's world
## [R1.2]. Without them the lit puppet/heightmap materials render black.
func _build_environment() -> void:
	stage_world.add_child(StageLighting.build_sun())
	var world_env := WorldEnvironment.new()
	world_env.name = "environment"
	world_env.environment = StageLighting.build_environment()
	stage_world.add_child(world_env)
	# A faint unshaded ring under the cursor while an act is armed [T23.4].
	_highlight = MeshInstance3D.new()
	_highlight.name = "target_highlight"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 0.9
	_highlight.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	_highlight.material_override = mat
	_highlight.visible = false
	stage_world.add_child(_highlight)


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
	_apply_pan(delta)
	ambience.update(delta)
	if _reject_timer > 0.0:
		_reject_timer -= delta
		_reject_label.modulate.a = clampf(_reject_timer / REJECT_MSG_SECONDS, 0.0, 1.0)
		if _reject_timer <= 0.0:
			_reject_label.visible = false


## Resolve the settings key bindings (T21.4) into keycode → action maps
## once [T23.2] — rebinding in Settings is honored on the next run.
func _build_controls() -> void:
	var bindings: Dictionary = settings.get_value("controls", "bindings")
	_pan_keys = {
		_keycode(bindings.get("pan_up", "W")): Vector2(0.0, -1.0),
		_keycode(bindings.get("pan_down", "S")): Vector2(0.0, 1.0),
		_keycode(bindings.get("pan_left", "A")): Vector2(-1.0, 0.0),
		_keycode(bindings.get("pan_right", "D")): Vector2(1.0, 0.0),
	}
	_zoom_keys = {
		_keycode(bindings.get("zoom_in", "E")): 1,
		_keycode(bindings.get("zoom_out", "Q")): -1,
	}


func _keycode(name: String) -> int:
	return OS.find_keycode_from_string(name)


## The world's input [T23.2/T23.3/T23.4]: only events the HUD didn't
## consume reach here, so a click on a panel button arms the act while a
## click on open ground targets it. Held pan keys accumulate; discrete
## zoom fires on press; a left click paints the armed act's target;
## motion moves the hover highlight.
func _unhandled_input(event: InputEvent) -> void:
	if run == null:
		return
	if event is InputEventKey:
		var code: int = event.keycode
		if _pan_keys.has(code):
			if event.pressed:
				_pan_held[code] = true
			else:
				_pan_held.erase(code)
		elif event.pressed and not event.echo and _zoom_keys.has(code):
			_zoom(_zoom_keys[code])
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(-1)
			MOUSE_BUTTON_LEFT:
				_pick(event.position)
	elif event is InputEventMouseMotion:
		_hover(event.position)


## Discrete zoom, honoring the invert-zoom setting [T23.2].
func _zoom(direction: int) -> void:
	if settings.get_value("controls", "invert_zoom"):
		direction = -direction
	if direction > 0:
		camera.zoom_in()
	else:
		camera.zoom_out()


## Slide the rig across the ground by the held pan keys [T23.2] — screen
## up (W) is world −Z, matching the downward camera's facing.
func _apply_pan(delta: float) -> void:
	if _pan_held.is_empty():
		return
	var dir := Vector2.ZERO
	for code in _pan_held:
		dir += _pan_keys.get(code, Vector2.ZERO)
	if dir == Vector2.ZERO:
		return
	# Normalize so a diagonal (W+D) doesn't pan ~1.41× faster than an axis
	# [T23 review]; the rig rides the terrain height at its new spot so the
	# camera keeps its per-zoom clearance over uneven ground.
	dir = dir.normalized()
	var sensitivity: float = settings.get_value("controls", "pan_sensitivity")
	var step := PAN_SPEED * sensitivity * delta
	var target := camera.position + Vector3(dir.x * step, 0.0, dir.y * step)
	target.y = world_view.height_at(Vector2(target.x, target.z))
	camera.focus(target)


## Cast the armed act where the cursor points [T23.3]: a ray to the pick
## plane resolves the nearest basin (or the nearest gnome for an
## individual-kind Vision — no stock catalog act targets one, same as
## T14.1's disclosure, but the routing is here for when one exists).
func _pick(screen_pos: Vector2) -> void:
	if influence_panel.armed() == "":
		return
	var point := _ground_point(screen_pos)
	if point.x == INF:
		return
	if influence_panel.armed_target_kind() == "individual":
		var g := _nearest_gnome(point)
		if g != null:
			select_gnome(g.id)
		else:
			_show_reject("No soul stands there to touch.")
	else:
		select_place(_nearest_place(point))


## Move the hover ring to the basin under the cursor while an act is
## armed; clear it when nothing is armed [T23.4].
func _hover(screen_pos: Vector2) -> void:
	if influence_panel.armed() == "":
		if hovered_place != "":
			hovered_place = ""
			_highlight.visible = false
		return
	var point := _ground_point(screen_pos)
	if point.x == INF:
		# The cursor strayed off the pickable ground — drop the ring
		# rather than leave it glued to the last valid spot [T23 review].
		hovered_place = ""
		_highlight.visible = false
		return
	hovered_place = _nearest_place(point)
	_highlight.position = place_positions[hovered_place] + Vector3(0.0, 0.05, 0.0)
	_highlight.visible = true


## Project a screen point onto the mean-height ground plane [T23.3];
## returns Vector3(INF,…) when the ray never meets it.
func _ground_point(screen_pos: Vector2) -> Vector3:
	var cam := camera.camera
	# The camera renders into the low-res stage, so a window-space click must
	# be scaled to viewport space before the ray [R1.2]; identity in headless.
	var viewport_pos := stage.to_viewport(screen_pos)
	# Target from the PRE-snap (continuous) camera pose [R5.2, leg §L-ui]: the
	# presented camera is pixel-quantized for anti-shimmer, but the pixel grid is
	# metres wide, so picking must read the true aim or a click could resolve to the
	# wrong basin. The snap is a pure planar translation the rig exposes — undo it
	# on the ray origin (the direction, and the framing offset, are unaffected).
	var origin := cam.project_ray_origin(viewport_pos) - camera.snap_offset
	var normal := cam.project_ray_normal(viewport_pos)
	var hit: Variant = Plane(Vector3.UP, _pick_plane_y).intersects_ray(origin, normal)
	if hit == null:
		return Vector3(INF, INF, INF)
	return hit


func _nearest_place(point: Vector3) -> String:
	var best := run.home
	var best_distance := INF
	var flat := Vector2(point.x, point.z)
	for place in place_positions:
		var pos: Vector3 = place_positions[place]
		var distance := flat.distance_to(Vector2(pos.x, pos.z))
		if distance < best_distance:
			best_distance = distance
			best = place
	return best


func _nearest_gnome(point: Vector3) -> GnomeData:
	var best: GnomeData = null
	var best_distance := INF
	for id in _puppets:
		var puppet: GnomePuppet = _puppets[id]
		if puppet.data == null or not puppet.data.is_alive():
			continue
		var distance := puppet.position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = puppet.data
	return best


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
			_show_reject("Choose a gnome — this vision needs a soul.")
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
	# Discoveries reach the chronicle feed via EventBus.discovery_made (R6.4).
	influence_panel.refresh(run.runner.colony, _met_affordances())
	_refresh_puppets()
	_refresh_motifs()
	if heatmap_overlay.visible:
		heatmap_overlay.refresh()
	_refresh_hud()


## R1.6 — mark each basin's blessed/cursed belief tag with its Ravenna
## medallion (gold monogram / red ring), inside the pixel stage. Only rebuilds
## a marker when a place's tag KIND changes (cheap; no per-day churn).
func _refresh_motifs() -> void:
	for place in place_positions:
		var tags: Dictionary = run.runner.colony.place_tags.get(place, {})
		var kind := Motifs.kind_for(tags)
		if _motif_kinds.get(place, "") == kind:
			continue
		_motif_kinds[place] = kind
		if _motifs.has(place):
			_motifs[place].queue_free()
			_motifs.erase(place)
		var marker := Motifs.build_place_medallion(kind)
		if marker != null:
			marker.position = place_positions[place]
			stage_world.add_child(marker)
			_motifs[place] = marker


## R6.3 [leg §L-hud] — a floating name-plate + tier glyph above each colony's
## basin (home + frontier), so the player can find settlements on the map. Reads
## the roster models; billboarded and depth-test-off so it reads over the relief,
## and fades with distance from the focus. Presentation-only.
func _refresh_locators() -> void:
	var wanted := {}
	for model in _roster_rows():
		wanted[model["sid"]] = model
	for sid in _locators.keys():
		if not wanted.has(sid):
			_locators[sid].queue_free()
			_locators.erase(sid)
	for sid in wanted:
		var model: Dictionary = wanted[sid]
		var place: String = sid_places.get(sid, run.home)
		if not place_positions.has(place):
			continue
		var label: Label3D = _locators.get(sid)
		if label == null:
			label = Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.pixel_size = LOCATOR_PIXEL_SIZE
			label.outline_size = 8
			label.outline_modulate = Palette.COLORS[Palette.NIGHT_LAPIS]
			stage_world.add_child(label)
			_locators[sid] = label
		var glyph: String = TIER_GLYPH.get(model["tier"], "·")
		label.text = "%s %s" % [glyph, model["name"]]
		var pos: Vector3 = place_positions[place] + Vector3(0.0, LOCATOR_HEIGHT, 0.0)
		label.position = pos
		var tint: Color = Palette.COLORS[Palette.GOLD_LIT if model["seat"] else Palette.GOLD]
		var span := LOCATOR_FADE_FAR - LOCATOR_FADE_NEAR
		var d := camera.position.distance_to(pos)
		tint.a = clampf(1.0 - (d - LOCATOR_FADE_NEAR) / span, LOCATOR_FADE_FLOOR, 1.0)
		label.modulate = tint


func _on_cast_requested(act_id: String, target: String, _selection: Dictionary) -> void:
	aftermath.begin(act_id)
	# The landed stimuli reach the chronicle feed via EventBus.phenomenon (R6.4);
	# the diegetic story-beat channel, not a re-summary of the request (T14.4).
	var stimuli := run.cast(act_id, target)
	# R7.2 [leg §L-acts]: a cast that lands nothing was refused — the precondition
	# wasn't met at that place (or the ground was warded). Say so, don't sit silent.
	# (arm() already refuses tier-locked acts, so an empty result here is always a
	# precondition/target miss, never a tier gate — safe to name the affordance.)
	if stimuli.is_empty():
		var req: String = Catalog.defs()[act_id].get("affordance_req", "any")
		if req != "any":
			_show_reject("%s needs %s here." % [act_id.replace("_", " "), req.replace("_", " ")])
		else:
			_show_reject("The omen found no purchase here.")
	influence_panel.refresh(run.runner.colony, _met_affordances())
	_refresh_hud()


## R7.2 [leg §L-acts] — flash a refusal at the cursor and ring the refused UI sound
## (the shell wires cast_refused → SoundDirector). A UI cue, not a diegetic stinger.
func _show_reject(reason: String) -> void:
	_reject_label.text = "✕ %s" % reason
	_reject_label.modulate.a = 1.0
	_reject_label.visible = true
	_reject_timer = REJECT_MSG_SECONDS
	cast_refused.emit(reason)


## R6.2 [leg §L-hud] — a roster row click pans the camera to that settlement's
## basin (read-only: it moves the Eye, it never commands the settlement).
func _on_focus_settlement(sid: int) -> void:
	var place: String = sid_places.get(sid, run.home)
	if place_positions.has(place):
		camera.focus(place_positions[place])


## R6.2 [leg §L-hud] — the roster row models: the home colony first (it lives at
## the individual grain, absent from run.settlements) then the frontier fold, so
## the player sees EVERY colony. Home has no structure-tier (development is a
## frontier mechanic), so its tier is a population display heuristic; frontier
## rows carry their real §R-set tier. Seat = colony.main_settlement (home when
## none is elected yet, main_settlement < 0).
func _roster_rows() -> Array:
	var colony := run.runner.colony
	var seat: int = colony.main_settlement
	var rows: Array = [
		{
			"sid": GameRun.HOME_SID,
			"name": _pretty_place(run.home),
			"tier": _display_tier(colony.population()),
			"pop": colony.population(),
			"seat": seat == GameRun.HOME_SID or seat < 0,
		}
	]
	var sids := run.settlements.keys()
	sids.sort()
	for sid in sids:
		var s: Settlement = run.settlements[sid]
		(
			rows
			. append(
				{
					"sid": sid,
					"name": _pretty_place(sid_places.get(sid, "settlement_%d" % sid)),
					"tier": SettlementRoster.TIER_NAMES.get(s.tier, "hamlet"),
					"pop": int(round(s.pop())),
					"seat": sid == seat,
				}
			)
		)
	return rows


func _pretty_place(place_id: String) -> String:
	return place_id.capitalize()


## R7.1 [leg §L-acts] — the world affordance requirements currently satisfiable
## somewhere (any place's lived tags), so the influence panel can show which acts'
## preconditions are met and mute the rest. Read-only over WorldState.
func _met_affordances() -> Array:
	var met := {}
	for place in run.world.affordances:
		for tag in run.world.affordances[place]:
			met[tag] = true
	return met.keys()


## Population-only display tier for the home row (the §R-set pop thresholds).
func _display_tier(population: int) -> String:
	if population >= 250:
		return "city"
	if population >= 60:
		return "town"
	if population >= 12:
		return "village"
	return "hamlet"


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
		puppet.view_scale = PUPPET_ZOOM_SCALE[camera.level]
		puppet.refresh()
		_stage_walk(id, puppet, g)


## R6.1 [leg §L-hud] — rescale every live puppet for the current zoom so gnomes
## stay legible figures at the aggregate views (not ~6 px specks).
func _apply_puppet_view_scale() -> void:
	for id in _puppets:
		var puppet: GnomePuppet = _puppets[id]
		puppet.view_scale = PUPPET_ZOOM_SCALE[camera.level]
		puppet.refresh()


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
	var spot := anchor + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	# R6.1: sit the figure on the LOCAL relief surface, not the basin-centre
	# height — so amplified terrain (R5.1) neither buries nor floats it.
	spot.y = world_view.height_at(Vector2(spot.x, spot.z))
	return spot


func _build_hud() -> void:
	hud = VBoxContainer.new()
	hud.name = "run_hud"
	add_child(hud)
	# R7.2 [leg §L-acts]: the refusal banner leads the HUD so it's always on-screen
	# (the HUD is a tall VBox reparented into the run screen, so a cursor-float would
	# need a separate overlay layer — a Gate-A2 polish; a top banner reads fine).
	_reject_label = Label.new()
	_reject_label.name = "reject"
	_reject_label.add_theme_color_override("font_color", Palette.COLORS[Palette.TERRACOTTA])
	_reject_label.add_theme_font_size_override("font_size", 16)
	_reject_label.visible = false
	hud.add_child(_reject_label)
	# R6.2 [leg §L-hud]: the roster leads the HUD — colonies, where, what tier.
	settlement_roster = SettlementRoster.new()
	settlement_roster.focus_settlement.connect(_on_focus_settlement)
	hud.add_child(settlement_roster)
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
	# R6.4 [leg §L-hud]: the living chronicle closes the HUD (recent story beats).
	# It owns its EventBus subscription and disconnects itself on teardown; we only
	# feed it the sid → place names so events can name their settlement.
	chronicle_feed = ChronicleFeed.new()
	chronicle_feed.place_of = sid_places
	hud.add_child(chronicle_feed)


## The slice's readout, promoted: the state a god actually watches.
func _refresh_hud() -> void:
	var colony := run.runner.colony
	# R6.3 [leg §L-hud]: keep the pulse anchored to the current season (no-op when a
	# born/died on the crossing tick already rolled it — see _roll_season).
	_roll_season()
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
		# R6.3 [leg §L-hud] — the life pulse: is the colony growing or dying?
		"this season · +%d born · −%d died" % [_season_births, _season_deaths],
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
	_hud_label.text = "\n".join(PackedStringArray(lines))
	# R6.2/R6.3 [leg §L-hud]: keep the roster + locators in step with the fold. The
	# recent story beats (acts, buildings, tiers, wars) live in the chronicle feed
	# (R6.4), which subscribes to the events directly — no longer dumped here.
	settlement_roster.refresh(_roster_rows())
	_refresh_locators()
