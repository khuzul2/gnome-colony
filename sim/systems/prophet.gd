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
	}
	Notability.award(vessel, Notability.PROPHET_LEADER)
	return vessel


static func is_prophet(g: GnomeData) -> bool:
	return g.is_alive() and not g.prophet.is_empty()


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
