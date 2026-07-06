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
## Frontier fixtures [phase16 exit, promoted] + §14 wiring [T18.2]:
## aggregate basins carry the tested base_k/richness/food_factor; a
## fracture (unrest ≥ 0.8, §14 "splinter settlement") takes HALF the
## colony — Civilization.split's proven 0.5. Emigrants are the least
## notable adults (able-bodied leave, the noted stay — interpretive),
## folded out via Promotion.dematerialize. Player-authored malevolent
## stimuli at home accumulate into §14's your_phenomena input for the
## season (raw intensity sum, clamped by the formula — interpretive
## magnitude), then vent. Unrest resets after a fracture (the pressure
## has blown — interpretive; without it the line re-fires forever).
const FRONTIER_BASE_K := 200.0
const FRONTIER_RICHNESS := 2.0
const FRONTIER_FOOD_FACTOR := 1.0
const FRACTURE_FRACTION := 0.5
## Eye-quickening cap [T21.1]: dwelling on a populated frontier basin
## materializes at most this many of its souls — a small watchable knot,
## not a census. INTERPRETIVE presentation-side number (documented; no
## spec value maps a single basin's quickening); the GLOBAL LOD-0 cap
## stays WorldConfig.quicken_budget through Lod.assign as before.
const QUICKENED_PER_BASIN := 16

## Live frontier settlements [T18.2]: sid (= basin/region id) → the
## aggregate Settlement. Home stays individual-grain at HOME_SID.
var settlements := {}
## Eye-quickened frontier souls [T21.1]: sid → Array of the GnomeData
## this gaze materialized out of that basin's aggregate. Maintained
## daily by _quicken_frontier; rebuilt on resume from home_settlement;
## emptied at every civilization season boundary — _frontier_season
## folds the whole knot back before the conflict flows [T22.2].
var quickened := {}

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
var _phenomena_pressure := 0.0
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
	for s in loaded["settlements"]:
		run.settlements[s.sid] = s
	# T21.1: quickened frontier souls ride the colony envelope with
	# home_settlement pointing at their basin (their heads were drained
	# from the saved settlement at materialize-time — consistent, no
	# double count); regroup them so a later gaze-off dematerializes.
	for g in run.runner.colony.living():
		if g.home_settlement != HOME_SID:
			if not run.quickened.has(g.home_settlement):
				run.quickened[g.home_settlement] = []
			run.quickened[g.home_settlement].append(g)
	run.exposure = envelope.get("exposure", 0.0)
	run._phenomena_pressure = envelope.get("phenomena_pressure", 0.0)
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
	_quicken_frontier()
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
		_frontier_season()
	_ward_watch()
	if colony.population() == 0:
		Civilization.check_world_end(colony, settlements.values())
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
		# §14's your_phenomena input: your malevolence at home builds
		# this season's emigration pressure [T18.2].
		if stim.get("valence", "") == "malevolent" and stim.get("place", "") == home:
			_phenomena_pressure += stim.get("intensity", 0.0)
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
	var frontier := []
	var sids := settlements.keys()
	sids.sort()
	for sid in sids:
		frontier.append(settlements[sid])
	var envelope := Serializer.save_to_dict(
		runner.colony, world, frontier, config, runner.time, runner.chronicle
	)
	envelope["region_graph"] = Serializer.region_graph_to_dict(graph)
	envelope["home"] = home
	envelope["exposure"] = exposure
	envelope["phenomena_pressure"] = _phenomena_pressure
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
		if g.home_settlement != HOME_SID:
			continue  # quickened frontier folk keep their basin [T21.1]
		var trip: bool = (
			g.stage == Enums.LifeStage.ADULT
			and _trip_place != home
			and (g.id + day) % TRIP_ROTATION == 0
		)
		g.location = _trip_place if trip else home


## T21.1 — the Eye quickens the frontier: dwelling on a populated
## frontier basin materializes up to QUICKENED_PER_BASIN of its souls
## (Promotion.materialize — heads leave the buckets, bodies join the
## colony, standing at the basin's place); the gaze leaving (or the
## settlement vanishing) folds them back via Promotion.dematerialize —
## heads conserved by the proven T11.3 pair, the dead skipped there.
## The civilization season boundary ALSO folds them back — every
## boundary, gaze or no gaze — so the §14 conflict flows act on
## complete aggregates; a holding gaze simply re-materializes here the
## next day [T22.2].
## DISCLOSED DIVERGENCE [§14: "minor divergence is acceptable — and,
## under the Eye, intended"]: while quickened these souls live the
## individual day through SimRunner, so they share home's single larder
## (the sim has one food node) instead of their basin's food_factor
## economy, and their drained heads sit out SettlementSim.season_tick;
## the boundary fold [T22.2] means their identities churn across every
## conflict season (fresh bodies are sampled after each boundary).
func _quicken_frontier() -> void:
	var colony := runner.colony
	for sid in quickened.keys():
		var s: Settlement = settlements.get(sid)
		if s != null and _place_of(sid) in attention_places:
			continue
		# The s == null arm is future-proofing only [T22.6]: no code path
		# removes a settlements entry today (war bleeds to ~0, never
		# erases) — kept so a future reaper can't strand quickened souls.
		if s != null:
			Promotion.dematerialize(colony, s, quickened[sid])
		quickened.erase(sid)
	var sids := settlements.keys()
	sids.sort()
	for sid in sids:
		if quickened.has(sid):
			continue
		var s: Settlement = settlements[sid]
		if s.pop() < 1.0:
			continue
		var place := _place_of(sid)
		if place not in attention_places:
			continue
		var souls := Promotion.materialize(colony, s, mini(int(s.pop()), QUICKENED_PER_BASIN))
		for g in souls:
			g.home_settlement = sid
			g.location = place
		if not souls.is_empty():
			quickened[sid] = souls


## The live civilization season [T18.2, algo §14]: fold a home mirror,
## compute §14's emigration (or the fracture splinter), fold whole
## adults out into the best-scoring basin, run every frontier basin's
## aggregate season, trade knowledge with home, fold every quickened
## soul back [T22.2], then the §14/§17 conflict flows [T21.3] — schism
## and war between the AGGREGATE settlements — keep the main settlement
## current, and let the world end only when EVERY basin — individual
## and aggregate — is empty. Every HOME count here is home-grain only
## [T22.1]: quickened frontier souls share the registry but belong to
## their basins — counting them as home people double-folds heads.
func _frontier_season() -> void:
	var colony := runner.colony
	var home_pop := _home_population()
	if home_pop > 0:
		var mirror := Settlement.from_colony(colony, HOME_SID, FRONTIER_BASE_K, FRONTIER_RICHNESS)
		var crowding := clampf(home_pop / capacity, 0.0, 1.0)
		var pressure := clampf(_phenomena_pressure, 0.0, 1.0)
		_phenomena_pressure = 0.0
		var count := 0
		if Devotion.fracture_due(colony):
			count = int(home_pop * FRACTURE_FRACTION)
			colony.unrest = 0.0
			EventBus.colony_fractured.emit({"day": runner.time.day()})
			runner.chronicle.append(
				"Year %d · the colony fractures — a splinter walks out" % runner.time.year()
			)
		else:
			count = int(SettlementSim.emigration(mirror, crowding, pressure))
		if count >= 1:
			_send_migrants(mirror, count)
	# T21.3: snapshot the belief state the season ENDS in, BEFORE the
	# ticks — the conflict triggers read the eve state (the documented
	# test_frontier convention: "the flows read the state the season ends
	# in"). Necessary, not stylistic: season_tick applies a whole season's
	# relax in one multiplicative step (×0.97²⁴ ≈ 0.48), which would put
	# §17's 0.5 schism line out of reach of ANY [0,1] belief pair.
	var eve_beliefs := {}
	for sid in settlements:
		eve_beliefs[sid] = settlements[sid].belief.duplicate()
	for sid in settlements:
		var s: Settlement = settlements[sid]
		if s.pop() >= Civilization.ALIVE_EPSILON:
			SettlementSim.season_tick(colony, s, FRONTIER_FOOD_FACTOR)
			SettlementSim.trade(colony, HOME_SID, sid)
			# R2.6 — the settlement builds & decays in response to the world you
			# shaped (drought→farms, ore→workshop, blessed→shrine); indirect only.
			var pressures := Construction.pressures_from(
				colony, world, _place_of(sid), FRONTIER_FOOD_FACTOR
			)
			# R3.4 — feed the civic story into telemetry so the end-of-run Chronicle
			# reads as development: what they built and the tier they crossed this
			# season (net of construction & decay). The live feed/aftermath already
			# hear the EventBus beats; this is the persisted end-of-run record.
			var tier_before: int = s.tier
			var built: String = Construction.season_tick(colony, s, pressures)
			Construction.decay_tick(colony, s)
			if built != "":
				(
					telemetry
					. record(
						{
							"type": "structure_built",
							"day": runner.time.day(),
							"sid": sid,
							"building": built,
						}
					)
				)
			if s.tier != tier_before:
				(
					telemetry
					. record(
						{
							"type": "settlement_tier_changed",
							"day": runner.time.day(),
							"sid": sid,
							"from": tier_before,
							"to": s.tier,
						}
					)
				)
	# T22.2 [RULED FIX] — fold EVERY quickened soul back BEFORE the
	# conflict flows: war casualties, schism splits and the war's
	# crowding reads all act on COMPLETE aggregates (one mechanism for
	# all three). The next day's _quicken_frontier re-materializes fresh
	# bodies under a holding gaze — the identity churn across a conflict
	# season is the disclosed §14 divergence ("minor divergence is
	# acceptable — and, under the Eye, intended").
	for sid in quickened:
		var basin: Settlement = settlements.get(sid)
		if basin != null:
			Promotion.dematerialize(colony, basin, quickened[sid])
	quickened.clear()
	var mirror_now := Settlement.from_colony(colony, HOME_SID, FRONTIER_BASE_K, FRONTIER_RICHNESS)
	_civ_conflicts(_season_settlements(mirror_now), eve_beliefs)
	var complete: Array = [mirror_now]
	complete.append_array(settlements.values())
	Civilization.update_main_settlement(colony, complete)


## T21.3 — the season's civilization list [§14]: the home fold plus
## every live aggregate basin (pop ≥ ALIVE_EPSILON), frontier sorted by
## sid so every pair scan below is deterministic.
func _season_settlements(mirror: Settlement) -> Array:
	var live := []
	if mirror.pop() >= Civilization.ALIVE_EPSILON:
		live.append(mirror)
	var sids := settlements.keys()
	sids.sort()
	for sid in sids:
		if settlements[sid].pop() >= Civilization.ALIVE_EPSILON:
			live.append(settlements[sid])
	return live


## T21.3 — §14's darkest flows, between AGGREGATES only: home (the
## mirror) joins the season list but fights and splits in NEITHER — its
## grain is individual (§14's civ flows are aggregate), and its people
## already carry their own break line (Devotion.fracture_due, above).
## Runs only after _frontier_season folded every quickened soul back
## [T22.2], so casualties and splits hit COMPLETE aggregates — the
## identity churn that fold costs a watched basin across a conflict
## season is the disclosed §14 divergence.
func _civ_conflicts(season_list: Array, eve_beliefs: Dictionary) -> void:
	var frontier := []
	for s in season_list:
		if s.sid != HOME_SID:
			frontier.append(s)
	_season_schism(frontier, eve_beliefs)
	_season_war(frontier, eve_beliefs)


## §14 schism at the civilization season [T21.3]: the FIRST qualifying
## ordered pair (sorted sids — deterministic) splits the LARGER
## settlement's faction into the first unsettled basin; then §14's
## unrest term (+0.01·unrest/season) is rolled ONCE against the LARGEST
## frontier settlement — this is exactly the deferred orchestrator roll
## civilization.gd's consumer note names for schism_pressure_per_season.
func _season_schism(frontier: Array, eve_beliefs: Dictionary) -> void:
	var colony := runner.colony
	for a in frontier:
		var split_done := false
		for b in frontier:
			if a == b:
				continue
			var eve_a := _eve_shadow(a, eve_beliefs)
			var eve_b := _eve_shadow(b, eve_beliefs)
			if Civilization.schism_due(colony, eve_a, eve_b):
				_schism_split(a if a.pop() >= b.pop() else b)
				split_done = true
				break
		if split_done:
			break
	if frontier.is_empty():
		return
	if Rng.chance(Devotion.schism_pressure_per_season(colony)):
		var largest: Settlement = frontier[0]
		for s in frontier:
			if s.pop() > largest.pop():
				largest = s
		_schism_split(largest)


## §17 war at the civilization season [T21.3]: at most ONE war a season
## — the first adjacent qualifying pair in sorted-sid order (adjacency =
## the basins neighbor each other in the region graph). §17 fixes the
## trigger sum ≥ 1.5; the spec is silent on the three inputs at this
## grain, so each derivation is INTERPRETIVE, documented here:
##  · religious_distance = mean |Δ| over the pair's belief axes at the
##    season's eve — the same metric Civilization.schism_due uses.
##  · resource_pressure = the pair's mean crowding, clamped to [0,1]
##    (war_due sums three NORMALIZED pressures against one threshold).
##  · rivalry = min(pop)/max(pop) — evenly-matched neighbors contest
##    hardest; a hamlet beside a city submits, near-equals collide.
func _season_war(frontier: Array, eve_beliefs: Dictionary) -> void:
	var colony := runner.colony
	for i in frontier.size():
		for j in range(i + 1, frontier.size()):
			var a: Settlement = frontier[i]
			var b: Settlement = frontier[j]
			if not _adjacent(a.sid, b.sid):
				continue
			var distance := _belief_distance(
				eve_beliefs.get(a.sid, a.belief), eve_beliefs.get(b.sid, b.belief)
			)
			var resource_pressure := clampf(
				0.5 * (a.crowding(colony) + b.crowding(colony)), 0.0, 1.0
			)
			var rivalry: float = minf(a.pop(), b.pop()) / maxf(maxf(a.pop(), b.pop()), 0.001)
			if not Civilization.war_due(rivalry, resource_pressure, distance):
				continue
			_wage_war(a, b)
			return


## Land a schism [§14]: the faction takes the first unsettled basin (no
## free ground → the break has nowhere to go — skip, interpretive), and
## the day enters telemetry + chronicle [§1.9].
func _schism_split(s: Settlement) -> void:
	var new_sid := _free_basin()
	if new_sid < 0:
		return
	var faction := Civilization.split(runner.colony, s, new_sid)
	settlements[new_sid] = faction
	telemetry.record({"type": "schism", "day": runner.time.day()})
	EventBus.schism_split.emit({"from": s.sid, "to": new_sid, "day": runner.time.day()})
	runner.chronicle.append(
		(
			"Year %d · schism — a faction of %s breaks away for %s"
			% [runner.time.year(), _place_of(s.sid), _place_of(new_sid)]
		)
	)


## §14 war lands [T21.3]: Civilization.war bleeds both sides and writes
## the fear; the day enters telemetry, winner/loser/losses the chronicle.
func _wage_war(a: Settlement, b: Settlement) -> void:
	var outcome := Civilization.war(runner.colony, a, b)
	var winner: Settlement = outcome["winner"]
	var loser: Settlement = outcome["loser"]
	telemetry.record({"type": "war", "day": runner.time.day()})
	EventBus.war_waged.emit({"winner": winner.sid, "loser": loser.sid, "day": runner.time.day()})
	(
		runner
		. chronicle
		. append(
			(
				"Year %d · war — %s breaks %s (%d fall against the victors' %d)"
				% [
					runner.time.year(),
					_place_of(winner.sid),
					_place_of(loser.sid),
					roundi(outcome["loser_losses"]),
					roundi(outcome["winner_losses"]),
				]
			)
		)
	)


## A read-only stand-in carrying a settlement's season-eve beliefs so
## Civilization.schism_due (reused verbatim) judges the doctrine the
## season ended on — see the snapshot note in _frontier_season.
func _eve_shadow(s: Settlement, eve_beliefs: Dictionary) -> Settlement:
	if not eve_beliefs.has(s.sid):
		return s
	var shadow := Settlement.new(s.sid, s.base_k, s.richness_sum)
	shadow.belief = eve_beliefs[s.sid]
	return shadow


## The T6.5/§14 belief metric — mean |Δ| over the aggregate axes; the
## same computation Civilization.schism_due runs, reused for §17's
## religious_distance input.
func _belief_distance(a_belief: Dictionary, b_belief: Dictionary) -> float:
	var total := 0.0
	for axis in a_belief:
		total += absf(a_belief[axis] - b_belief[axis])
	return total / a_belief.size()


func _adjacent(a_sid: int, b_sid: int) -> bool:
	for region in graph.regions:
		if region["id"] == a_sid:
			return b_sid in region["neighbors"]
	return false


func _free_basin() -> int:
	for region in graph.regions:
		if region["id"] != HOME_SID and not settlements.has(region["id"]):
			return region["id"]
	return -1


func _send_migrants(mirror: Settlement, count: int) -> void:
	var colony := runner.colony
	var candidates := []
	for region in graph.regions:
		if region["id"] == HOME_SID:
			continue
		candidates.append(
			settlements.get(
				region["id"], Settlement.new(region["id"], FRONTIER_BASE_K, FRONTIER_RICHNESS)
			)
		)
	if candidates.is_empty():
		return
	var target: Settlement = Civilization.choose_basin(colony, mirror, candidates)
	var adults := []
	for g in colony.living():
		if g.home_settlement != HOME_SID:
			continue  # quickened frontier souls are never HOME migrants [T22.1]
		if g.stage == Enums.LifeStage.ADULT:
			adults.append(g)
	adults.sort_custom(
		func(a: GnomeData, b: GnomeData) -> bool:
			return a.notability < b.notability if a.notability != b.notability else a.id < b.id
	)
	var leaving := adults.slice(0, mini(count, adults.size()))
	if leaving.is_empty():
		return
	if not settlements.has(target.sid):
		settlements[target.sid] = target
		telemetry.record({"type": "settlement_founded", "day": runner.time.day()})
		EventBus.settlement_founded.emit(
			{"sid": target.sid, "place": _place_of(target.sid), "day": runner.time.day()}
		)
	Promotion.dematerialize(colony, target, leaving)
	runner.chronicle.append(
		(
			"Year %d · %d souls strike out for %s"
			% [runner.time.year(), leaving.size(), _place_of(target.sid)]
		)
	)


## T22.1 — the colony's HOME-grain head-count. Quickened frontier souls
## [T21.1] share the registry but belong to their basins: any count or
## selection of HOME people that includes them double-folds heads (their
## bucket seats are already drained). Every _frontier_season read of
## "the colony's people" goes through this.
func _home_population() -> int:
	var count := 0
	for g in runner.colony.living():
		if g.home_settlement == HOME_SID:
			count += 1
	return count


func _place_of(sid: int) -> String:
	for region in graph.regions:
		if region["id"] == sid:
			return WorldBootstrap.place_id(region)
	return "settlement_%d" % sid


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
		EventBus.discovery_made.emit({"id": id, "day": runner.time.day()})
	return discovered


## At the resistance stage their first ward rises over home [slice] —
## visible proof the co-evolution turned.
func _ward_watch() -> void:
	if world.wards.has(home):
		return
	var mu := Magic.mu(runner.colony, HOME_SID)
	if Magic.stage(mu) == "resistance":
		Magic.place_ward(world, home, mu)
