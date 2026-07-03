extends GutTest

## T12.2 — determinism harness [plan Phase 12, design §2.4]: under a FIXED
## recorded input script (seed + config + influence acts + attention),
## the run-hash after N days is identical across independent runs — and a
## save→load→continue run lands on the same hash as an uninterrupted one.
## This test is also the tripwire that flags stray non-Rng randomness:
## any randi()/randf()/Time call in sim logic breaks the hash equality.
## Reproducibility is claimed ONLY from seed + recorded acts + attention
## (attention is a declared sim input by design — changing it changes
## the world, and the hash proves it).

const SEED := 12200
const DAYS := 60
## The recorded input script: day → influence act, day → attended places.
const ACT_SCRIPT := {10: ["still_air", "the_hollow"], 30: ["landslide", "eastern_ridge"]}
const ATTENTION_SCRIPT := {5: ["the_hollow"], 6: ["the_hollow"], 40: ["the_hollow"]}
## Hash checkpoint taken on an ATTENDED day, where the gaze is provably
## part of the world state (gnome LOD). Full fate-divergence under the
## Eye lands when the orchestrator promotes/demotes against aggregates
## (§14 — Phase 13+ wiring); the recorded input is load-bearing today.
const MID_HASH_DAY := 40


## Returns {final: hash after DAYS, mid: hash right after MID_HASH_DAY}.
func _scripted_run(acts: Dictionary, attention: Dictionary, break_at: int = -1) -> Dictionary:
	Rng.seed_with(SEED)
	var cfg := WorldConfig.new()
	cfg.band_size = 6
	var food := ResourceNode.new("food", 100.0, 100.0, 10.0, 1.0)
	var runner := SimRunner.new(cfg, food, 60.0)
	var world := WorldState.new()
	world.sites["the_hollow"] = food
	world.affordances["eastern_ridge"] = ["slope"]
	var settlements: Array = [Settlement.new(1, 50.0, 2.0)]
	settlements[0].by_stage[Enums.LifeStage.ADULT] = 30.0
	var defs := Catalog.defs()
	var handlers := Catalog.handlers()
	for g in runner.colony.living():
		g.location = "the_hollow"
	var mid_hash := ""
	for day in DAYS:
		Lod.assign(runner.colony, attention.get(day, []), cfg.quicken_budget)
		runner.tick()
		Belief.propagate_tick(runner.colony, 1.0)
		Belief.decay_tick(runner.colony, 1.0)
		Belief.crystallize_tick(runner.colony, 1.0)
		Devotion.update_unlocks(runner.colony)
		Devotion.unrest_tick(runner.colony, 1.0)
		Prophet.tick(runner.colony, 1.0)
		if acts.has(day):
			var act: Array = acts[day]
			var stimuli := Influence.cast_with_cascade(
				runner.colony, world, defs, act[0], act[1], 1.0, 1.0, handlers
			)
			for stim in stimuli:
				Influence.appraise_witnesses(runner.colony, stim)
				if stim.get("drama", 0.0) > 0.0:
					Devotion.attribute(
						runner.colony, stim["drama"], 0.0, stim["valence"], runner.colony.living()
					)
		if day == MID_HASH_DAY:
			var mid_save := Serializer.save_to_dict(
				runner.colony, world, settlements, cfg, runner.time, runner.chronicle
			)
			mid_hash = JSON.stringify(mid_save).md5_text()
		if day == break_at:
			# Save, wipe, load, continue — the resumed run must be
			# indistinguishable from the uninterrupted one.
			var save := Serializer.save_to_dict(
				runner.colony, world, settlements, cfg, runner.time, runner.chronicle
			)
			runner.shutdown()
			var loaded := Serializer.save_from_dict(save)
			world = loaded["world"]
			settlements = loaded["settlements"]
			food = world.sites["the_hollow"]
			runner = SimRunner.new(loaded["config"], food, 60.0, loaded["colony"], loaded["time"])
			runner.chronicle = loaded["chronicle"]
	var final_save := Serializer.save_to_dict(
		runner.colony, world, settlements, cfg, runner.time, runner.chronicle
	)
	runner.shutdown()
	return {"final": JSON.stringify(final_save).md5_text(), "mid": mid_hash}


func test_fixed_inputs_reproduce_the_hash():
	var first := _scripted_run(ACT_SCRIPT, ATTENTION_SCRIPT)
	var second := _scripted_run(ACT_SCRIPT, ATTENTION_SCRIPT)
	assert_eq(first["final"], second["final"], "seed + acts + attention fully determine the world")
	assert_eq(first["mid"], second["mid"])


func test_save_load_continue_equals_uninterrupted():
	var uninterrupted := _scripted_run(ACT_SCRIPT, ATTENTION_SCRIPT)
	var resumed := _scripted_run(ACT_SCRIPT, ATTENTION_SCRIPT, 25)
	assert_eq(resumed["final"], uninterrupted["final"], "a mid-run save/load leaves no fingerprint")


func test_different_acts_change_the_world():
	var baseline := _scripted_run(ACT_SCRIPT, ATTENTION_SCRIPT)
	var meddled := _scripted_run(
		{10: ["still_air", "the_hollow"], 30: ["still_air", "the_hollow"]}, ATTENTION_SCRIPT
	)
	assert_ne(baseline["final"], meddled["final"], "the recorded acts are load-bearing inputs")


func test_different_attention_changes_the_world():
	var baseline := _scripted_run(ACT_SCRIPT, ATTENTION_SCRIPT)
	var unwatched := _scripted_run(ACT_SCRIPT, {})
	assert_ne(
		baseline["mid"],
		unwatched["mid"],
		"the gaze is part of the recorded world while it rests there (LOD state)"
	)
