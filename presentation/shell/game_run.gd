class_name GameRun
extends RefCounted
## The run a player actually plays [PROGRESS T17.2, DONE.md handover
## note 3]: SimRunner + the PROVEN daily stack, composed exactly as the
## epochal harness and the Fun-Check slice ran it — this file is glue,
## every rule lives in its system. Per day, in order: staging → LOD ←
## attention → SimRunner.tick (life core + natural events) → Belief
## propagate/decay/crystallize → Devotion unlocks/unrest → Prophet.tick
## → Magic.accrue [slice glue] → seasonal §13 research [epochal
## derivations] → ward watch [slice] → world-end check. Casting is the
## slice's _on_cast composition, tier-gated (no playtest bypass).
## Promoted slice glue, unchanged and still pending real sim movement
## (Phases 11/13 never authored any): day-trip staging (a third of the
## adults rotate to the first ridge basin in region order), the
## exposure signal (1.0 on a cast, −2%/day), science = fraction of the
## TechGraph held. The colony lives at HOME_SID 0 at the individual
## grain — the civilization tier stays library+test-composed as the
## plan left it (Phase 17 header). Save/resume: the T12.1 envelope
## plus the shell's own keys (region_graph — the key T13.1 deferred to
## the orchestrator — home, exposure, and telemetry {events,
## peak_pop}); resume adopts colony+time+world into SimRunner and the
## Rng stream continues exactly (proven in tests).
## HARD CALL-SITE RULE [T17.2 reviewer]: exactly ONE GameRun may be
## live at a time — EventBus is global and SimRunner's death listener
## carries no per-colony guard, so a second live run would absorb the
## other's chronicle lines. Callers must shutdown() the old run before
## creating or resuming another (the shell does).

const HOME_SID := 0
const EXPOSURE_DECAY := 0.98
const TRIP_ROTATION := 3

var config: WorldConfig
var graph: RegionGraph
var world: WorldState
var food: ResourceNode
var capacity: float
var home := ""
var runner: SimRunner
var telemetry := Telemetry.new()
var exposure := 0.0
## The Eye's currently attended places — written by the HUD's
## AttentionInput each frame, read by the daily Lod.assign.
var attention_places: Array = []

var _individual_budget := 500
var _trip_place := ""
var _last_season := -1
var _defs := {}
var _handlers := {}


static func new_game(cfg: WorldConfig) -> GameRun:
	Rng.seed_with(cfg.seed)
	var run := GameRun.new()
	var built := WorldBootstrap.build(cfg)
	run.config = cfg
	run.graph = built["graph"]
	run.world = built["world"]
	run.food = built["food"]
	run.capacity = built["capacity"]
	run.home = built["home"]
	run.runner = SimRunner.new(cfg, run.food, run.capacity, null, null, run.world)
	run._finish_setup()
	run._stage_locations()
	return run


## Rebuild a live run from a saved envelope. Serializer.save_from_dict
## restores the Rng stream as a side effect — do NOT re-seed.
static func resume(envelope: Dictionary) -> GameRun:
	var loaded := Serializer.save_from_dict(envelope)
	var run := GameRun.new()
	run.config = loaded["config"]
	run.graph = Serializer.region_graph_from_dict(envelope["region_graph"])
	run.world = loaded["world"]
	run.home = envelope["home"]
	run.food = run.world.sites[run.home]
	run.capacity = (WorldBootstrap.COLONY_K * Tuning.resolve(run.config)["world"]["abundance_mult"])
	run.runner = SimRunner.new(
		run.config, run.food, run.capacity, loaded["colony"], loaded["time"], run.world
	)
	run.runner.chronicle = loaded["chronicle"]
	run.exposure = envelope.get("exposure", 0.0)
	var saved_telemetry: Dictionary = envelope.get("telemetry", {})
	for event in saved_telemetry.get("events", []):
		run.telemetry.record(event)
	run.telemetry.restore_peak(int(saved_telemetry.get("peak_pop", 0)))
	run._finish_setup()
	return run


func shutdown() -> void:
	runner.shutdown()


## One sim day, the proven order. Returns {day, season_changed,
## discovered} so the HUD can narrate without re-deriving.
func advance_day() -> Dictionary:
	var colony := runner.colony
	Terrain.refresh(colony, world, home, food, capacity, HOME_SID)
	_stage_locations()
	Lod.assign(colony, attention_places, config.quicken_budget, _individual_budget)
	runner.tick()
	Belief.propagate_tick(colony, 1.0)
	Belief.decay_tick(colony, 1.0)
	Belief.crystallize_tick(colony, 1.0)
	Devotion.update_unlocks(colony)
	Devotion.unrest_tick(colony, 1.0)
	Prophet.tick(colony, 1.0)
	Magic.accrue(
		colony, HOME_SID, colony.vitals()["mean_traits"]["curious"], exposure, science(), 1.0
	)
	exposure *= EXPOSURE_DECAY
	telemetry.track_day(colony)
	var discovered := []
	var season_changed := runner.time.season() != _last_season
	if season_changed:
		_last_season = runner.time.season()
		discovered = _research_season()
	_ward_watch()
	if colony.population() == 0:
		Civilization.check_world_end(colony, [])
	return {"day": runner.time.day(), "season_changed": season_changed, "discovered": discovered}


## The slice's cast composition, tier-gated for real play: cascade →
## per-stimulus witness appraisal (prediction-damped) → attribution on
## drama → prophet seeding — then the toolbox ladder refreshes.
func cast(act_id: String, target: String) -> Array:
	var def: Dictionary = _defs.get(act_id, {})
	if def.is_empty() or def["tier"] > runner.colony.unlocked_tier:
		return []
	var colony := runner.colony
	var mu := Magic.mu(colony, HOME_SID)
	var stimuli := Influence.cast_with_cascade(
		colony,
		world,
		_defs,
		act_id,
		target,
		Devotion.magnitude_multiplier(colony),
		Devotion.valence_potency(def["valence"]),
		_handlers
	)
	exposure = 1.0
	for stim in stimuli:
		var present := []
		for g in colony.living():
			if g.location == stim["place"]:
				present.append(g)
		Influence.appraise_witnesses(
			colony, stim, present, Magic.impact_mult_for(colony, HOME_SID, stim)
		)
		if stim.get("drama", 0.0) > 0.0:
			Devotion.attribute(colony, stim["drama"], mu, stim["valence"], present)
		Prophet.try_seed(present, stim)
	Devotion.update_unlocks(colony)
	return stimuli


## The T12.1 envelope plus the shell's keys — everything resume() needs.
func save() -> Dictionary:
	var envelope := Serializer.save_to_dict(
		runner.colony, world, [], config, runner.time, runner.chronicle
	)
	envelope["region_graph"] = Serializer.region_graph_to_dict(graph)
	envelope["home"] = home
	envelope["exposure"] = exposure
	envelope["telemetry"] = {
		"events": telemetry.events.duplicate(true),
		"peak_pop": telemetry.summary(runner.colony)["peak_pop"],
	}
	return envelope


## Display-side science level [slice glue]: fraction of the TechGraph
## the settlement holds.
func science() -> float:
	var known: Dictionary = runner.colony.settlement_knowledge.get(HOME_SID, {})
	var hits := 0
	for id in TechGraph.defs():
		if known.has(id):
			hits += 1
	return float(hits) / maxi(1, TechGraph.defs().size())


func _finish_setup() -> void:
	_defs = Catalog.defs()
	_handlers = Catalog.handlers()
	_last_season = runner.time.season()
	_individual_budget = Tuning.resolve(config)["scale"]["individual_budget"]
	_trip_place = home
	for region in graph.regions:
		var place := WorldBootstrap.place_id(region)
		if place != home and region["biome"] == "ridge":
			_trip_place = place
			break


## Slice-only staging, promoted verbatim [slice glue, NOT sim policy —
## movement never landed in the sim]: a third of the adults (by id
## rotation) day-trip to the nearest ridge, everyone else keeps home —
## so acts have honest on-site witnesses.
func _stage_locations() -> void:
	var day := runner.time.day()
	for g in runner.colony.living():
		var trip: bool = (
			g.stage == Enums.LifeStage.ADULT
			and _trip_place != home
			and (g.id + day) % TRIP_ROTATION == 0
		)
		g.location = _trip_place if trip else home


## Epochal derivations [test_epochal.gd]: a flat need of 1.0 on the
## whole discoverable frontier; surplus = a day's meals per head.
func _research_season() -> Array:
	var colony := runner.colony
	var known: Array = colony.settlement_knowledge.get(HOME_SID, {}).keys()
	var needs := {}
	for id in TechGraph.candidates(known):
		needs[id] = 1.0
	var pop := maxf(1.0, colony.population())
	var surplus: float = clampf(food.current / pop, 0.0, 1.0)
	var discovered := Research.season_tick(colony, HOME_SID, needs, surplus)
	for id in discovered:
		telemetry.record({"type": "discovery", "id": id, "day": runner.time.day()})
	return discovered


## At the resistance stage their first ward rises over home [slice] —
## visible proof the co-evolution turned.
func _ward_watch() -> void:
	if world.wards.has(home):
		return
	var mu := Magic.mu(runner.colony, HOME_SID)
	if Magic.stage(mu) == "resistance":
		Magic.place_ward(world, home, mu)
