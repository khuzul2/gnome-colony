class_name Prophet
extends RefCounted
## Prophet entity & seeding [plan T9.1, algo §12/§17]: a prophet is a
## flagged gnome, seeded via an Omen (⑤) or Vision (⑥) stimulus, that only
## CATCHES where ripe — local mean(|awe−fear| toward the unseen will)
## ≥ 0.5. §17 fixes the ripeness line; the interpretive choices here, all
## documented in PROGRESS.md: the charge is measured toward YOU (prophets
## are theology, §12's "message derived from theology"); only adults and
## elders catch; the vessel is the witness with the highest
## prophet_affinity + devout (§8 calls the touched "prime prophet seed");
## and the message's flavor follows the flock's charge (love → mercy,
## terror → wrath) nudged by the vessel's own temperament.
## Charisma/reach arrive in T9.2, the life-arc & corruption in T9.3.

const RIPENESS_LINE := 0.5  # §17: "prophet catches: local mean(|awe−fear|) ≥ 0.5"
## §18 catalog categories that can seed a prophet [§12 "via an Omen/Vision"].
const SEED_CATEGORIES := [5, 6]

# Charisma [§17]: hidden, N(0.6, 0.2), rolled once at the catch (T9.2).
const CHARISMA_MEAN := 0.6
const CHARISMA_SD := 0.2

## Reach & amplification (T9.2). §12 gives shapes, not sizes — interpretive,
## documented in PROGRESS.md: BFS depth = round(charisma·5) so a peak voice
## carries five links; preaching writes 0.12·charisma/day (3× the §9 social
## propagation rate — a prophet is a megaphone, "fast"), along positive
## edges only.
const REACH_DEPTH_MAX := 5
const PREACH_RATE := 0.12


## Local emotional charge [§12]: mean per-witness |awe−fear| toward the
## unseen will. Polarization either way counts — terror is charge too.
static func ripeness(witnesses: Array) -> float:
	if witnesses.is_empty():
		return 0.0
	var sum := 0.0
	for g in witnesses:
		sum += absf(g.get_feeling(Devotion.YOU, "awe") - g.get_feeling(Devotion.YOU, "fear"))
	return sum / witnesses.size()


## Attempt to seed a prophet from an omen/vision stimulus landing on these
## witnesses. Returns the caught gnome, or null (wrong category, unripe
## flock, or no eligible vessel). Catching is a §14 deed (T8.6).
static func try_seed(witnesses: Array, stimulus: Dictionary) -> GnomeData:
	if not stimulus.get("category", 0) in SEED_CATEGORIES:
		return null
	if ripeness(witnesses) < RIPENESS_LINE:
		return null
	var vessel := _pick_vessel(witnesses)
	if vessel == null:
		return null
	vessel.prophet = {
		"message": _derive_message(vessel, witnesses, stimulus),
		"caught_age": vessel.age,
		"corrupted": false,
		"charisma": clampf(Rng.gauss(CHARISMA_MEAN, CHARISMA_SD), 0.0, 1.0),
	}
	Notability.award(vessel, Notability.PROPHET_LEADER)
	return vessel


static func is_prophet(g: GnomeData) -> bool:
	return g.is_alive() and not g.prophet.is_empty()


## Who the prophet converts [§12]: social-graph BFS from the prophet,
## depth ∝ charisma, along positive living edges only (enemies do not
## carry the gospel — interpretive). The prophet is not their own convert.
static func reach(colony: Colony, prophet_g: GnomeData) -> Array:
	var charisma: float = prophet_g.prophet.get("charisma", 0.0)
	var depth := maxi(1, roundi(charisma * REACH_DEPTH_MAX))
	var visited := {prophet_g.id: true}
	var frontier: Array = [prophet_g.id]
	var flock := []
	for level in depth:
		var next := []
		for id in frontier:
			var g: GnomeData = colony.gnomes.get(id)
			if g == null:
				continue
			for other_id in g.relationships:
				if visited.has(other_id):
					continue
				if g.relationships[other_id]["weight"] <= 0.0:
					continue
				var other: GnomeData = colony.gnomes.get(other_id)
				if other == null or not other.is_alive():
					continue
				visited[other_id] = true
				next.append(other_id)
				flock.append(other)
		frontier = next
	return flock


## One day of preaching [§12]: the message lands on everyone in reach —
## faith toward the unseen will always, plus the flavor axis (mercy → awe,
## wrath → fear) — scaled by charisma (life-arc joins in T9.3). Then the
## forced-crystallization check: a prophet does not wait out a season.
static func preach(colony: Colony, prophet_g: GnomeData, dt_days: float) -> void:
	if not is_prophet(prophet_g):
		return
	var message: Dictionary = prophet_g.prophet["message"]
	var influence: float = prophet_g.prophet.get("charisma", 0.0)
	var flavor_axis: String = "awe" if message["flavor"] == "mercy" else "fear"
	var flock := reach(colony, prophet_g)
	for g in flock:
		g.adjust_feeling(Devotion.YOU, "faith", PREACH_RATE * influence * dt_days)
		g.adjust_feeling(Devotion.YOU, flavor_axis, PREACH_RATE * influence * dt_days)
	_force_crystallize(colony, prophet_g, flock)


## Forced crystallization [§12: "forces crystallization of their message
## across reach, fast"]: same holder floor and strength formula as the
## organic §9 path (T6.3), but NO season timer — the moment enough of the
## flock holds the faith, the creed is real. One creed per prophet; it
## carries the message flavor and the prophet's id for T9.4's rivalries.
static func _force_crystallize(colony: Colony, prophet_g: GnomeData, flock: Array) -> void:
	var pop := colony.population()
	if pop == 0:
		return
	for b in colony.beliefs:
		if b.get("prophet_id", -1) == prophet_g.id:
			return
	var min_holders := maxi(Belief.MIN_HOLDERS_FLOOR, ceili(Belief.MIN_HOLDERS_FRACTION * pop))
	var holders := []
	var total := 0.0
	for g in flock + [prophet_g]:
		var faith: float = g.get_feeling(Devotion.YOU, "faith")
		if faith >= Belief.CRYSTALLIZE_STRENGTH:
			holders.append(g.id)
			total += faith
	if holders.size() < min_holders:
		return
	var message: Dictionary = prophet_g.prophet["message"]
	var strength: float = (total / holders.size()) * (float(holders.size()) / pop)
	var creed := BeliefObject.make("theology", Devotion.YOU, "faith", strength, holders)
	creed["flavor"] = message["flavor"]
	creed["prophet_id"] = prophet_g.id
	colony.beliefs.append(creed)
	EventBus.belief_formed.emit(
		{"kind": "theology", "subject": Devotion.YOU, "axis": "faith", "strength": strength}
	)


## The omen picks its vessel: the most receptive adult/elder witness,
## scored prophet_affinity + devout (deterministic; ties break by id so
## replays agree). Existing prophets are passed over — one calling each.
static func _pick_vessel(witnesses: Array) -> GnomeData:
	var best: GnomeData = null
	var best_score := -1.0
	for g in witnesses:
		if not g.stage in [Enums.LifeStage.ADULT, Enums.LifeStage.ELDER]:
			continue
		if not g.prophet.is_empty():
			continue
		var score: float = g.prophet_affinity + g.traits["devout"]
		if score > best_score or (score == best_score and best != null and g.id < best.id):
			best_score = score
			best = g
	return best


## The message [§12: "derived from theology + triggering event + traits"]:
## subject = the triggering act; flavor = the flock's charge direction
## (mean awe−fear toward you) nudged by the vessel's nurturing−aggressive.
static func _derive_message(
	vessel: GnomeData, witnesses: Array, stimulus: Dictionary
) -> Dictionary:
	var lean := 0.0
	for g in witnesses:
		lean += g.get_feeling(Devotion.YOU, "awe") - g.get_feeling(Devotion.YOU, "fear")
	lean /= witnesses.size()
	lean += vessel.traits["nurturing"] - vessel.traits["aggressive"]
	return {
		"subject": stimulus["type"],
		"flavor": "mercy" if lean >= 0.0 else "wrath",
	}
