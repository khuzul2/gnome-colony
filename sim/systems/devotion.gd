class_name Devotion
extends RefCounted
## Devotion & social mass [plan T8.1, algo §10]. Per-gnome devotion is the
## faith-in-you feeling; colony devotion D = Σ faith (belief × population);
## depth d̄ = D/pop gates the toolbox (T8.2); flavor = mean(awe − fear)
## toward you — love-faith vs terror-faith. "You" lives in the substrate
## as the subject "unseen_will" [algo §9's attribution wording].

const YOU := "unseen_will"
const MAGNITUDE_K := 0.9
const VALENCE_DELTA := 0.4

# Attribution seed [algo §9/§17] (T8.5)
const ATTRIBUTION_ALPHA := 0.25
const ATTRIBUTION_BASE := 0.3
const ATTRIBUTION_DEVOUT := 0.7
const ATTRIBUTION_MAGIC := 0.8

# Terror instability [algo §10/§17] (T8.4)
const UNREST_RATE := 0.02
const UNREST_RELIEF_PER_DAY := 0.01
const FRACTURE_LINE := 0.8
const SCHISM_PRESSURE := 0.01
const SECULARIZATION_RATE := 0.0005

## Tier ladder [algo §10/§17] (T8.2): thresholds on d̄_peak, with
## population/era floors on the top tiers checked at unlock time.
const TIER_LADDER := [
	{"tier": 2, "dbar": 0.15},
	{"tier": 3, "dbar": 0.30},
	{"tier": 4, "dbar": 0.45, "pop": 50},
	{"tier": 5, "dbar": 0.60, "pop": 200},
	{"tier": 6, "dbar": 0.78, "pop": 1000, "gen": 5},
]


static func total(colony: Colony) -> float:
	var sum := 0.0
	for g in colony.living():
		sum += g.get_feeling(YOU, "faith")
	return sum


static func per_capita(colony: Colony) -> float:
	var pop := colony.population()
	return total(colony) / pop if pop > 0 else 0.0


## Ratcheting unlock pass: refresh d̄_peak, then climb every rung whose
## threshold + floor is met. A tier once earned never re-locks.
static func update_unlocks(colony: Colony) -> void:
	colony.devotion_peak = maxf(colony.devotion_peak, per_capita(colony))
	var pop := colony.population()
	# Lineage age counts dead ancestors too — an era floor, not a living
	# stat. And the ladder never SKIPS a gated rung: Wonders presuppose
	# Omens and Visions (interpretive reading of §10's tier table).
	var max_gen := 0
	for g in colony.gnomes.values():
		max_gen = maxi(max_gen, g.generation)
	for rung in TIER_LADDER:
		if rung["tier"] <= colony.unlocked_tier:
			continue
		if colony.devotion_peak < rung["dbar"]:
			break
		var pop_ok: bool = not rung.has("pop") or pop >= rung["pop"]
		var gen_ok: bool = rung.has("gen") and max_gen >= rung["gen"]
		if pop_ok or gen_ok:
			colony.unlocked_tier = rung["tier"]
		else:
			break


## Social-mass magnitude [algo §10/§17] (T8.3):
##   multiplier = 1 + 0.9·log10(1 + M), M = Σ faith.
## Log-scaled so power is FELT but never unbounded.
static func magnitude_multiplier(colony: Colony) -> float:
	return 1.0 + MAGNITUDE_K * (log(1.0 + total(colony)) / log(10.0))


## Valence potency [algo §11/§17] (T8.3): cruelty lands harder (×1+δ),
## kindness gentler (×1−δ), δ = 0.4 — the temptation that terror-faith's
## instability (T8.4) is priced against.
static func valence_potency(valence: String) -> float:
	match valence:
		"malevolent":
			return 1.0 + VALENCE_DELTA
		"benevolent":
			return 1.0 - VALENCE_DELTA
		_:
			return 1.0


static func flavor_balance(colony: Colony) -> float:
	var living := colony.living()
	if living.is_empty():
		return 0.0
	var sum := 0.0
	for g in living:
		sum += g.get_feeling(YOU, "awe") - g.get_feeling(YOU, "fear")
	return sum / living.size()


## The attribution seed [plan T8.5, algo §9]: a dramatic/inexplicable event
## writes a small faith toward "an unseen will" per witness:
##   faith += α·attribution·event_drama, α = 0.25 (the ramp dial)
##   attribution = clamp(0.3 + 0.7·devout − 0.8·magic_understanding)
## Primitive colonies invent you; magic-literate ones explain you away.
## Flavor rides along (interpretive: §9 says "awe/fear toward you"):
## malevolent drama seeds fear of you, everything else seeds awe.
static func attribute(
	colony: Colony,
	event_drama: float,
	magic_understanding: float,
	valence: String,
	witnesses: Variant = null,
) -> void:
	var present: Array = witnesses if witnesses != null else colony.living()
	var flavor_axis := "fear" if valence == "malevolent" else "awe"
	for g in present:
		var attribution: float = clampf(
			(
				ATTRIBUTION_BASE
				+ ATTRIBUTION_DEVOUT * g.traits["devout"]
				- ATTRIBUTION_MAGIC * magic_understanding
			),
			0.0,
			1.0
		)
		var delta := ATTRIBUTION_ALPHA * attribution * event_drama
		if delta <= 0.0:
			continue
		g.adjust_feeling(YOU, "faith", delta)
		g.adjust_feeling(YOU, flavor_axis, delta)


## The tyranny brake [plan T8.4, algo §10]: terror-flavored devotion levies
## a continuous instability tax — unrest += 0.02·max(0,−flavor)·log10 M per
## day — while quiet time relieves −0.01/day. Love-faith pays nothing.
static func unrest_tick(colony: Colony, dt_days: float) -> void:
	var terror := maxf(0.0, -flavor_balance(colony))
	var mass_log := log(1.0 + total(colony)) / log(10.0)
	var tax := UNREST_RATE * terror * mass_log
	# §10 relief ("benevolent acts, met needs, quiet time") applies when the
	# terror tax is silent — a boiling pot doesn't cool while the fire burns.
	var delta := tax if tax > 0.0 else -UNREST_RELIEF_PER_DAY
	colony.unrest = clampf(colony.unrest + delta * dt_days, 0.0, 1.0)


## At unrest ≥ 0.8 a fracture/revolt is due [algo §10] — the hard cap on
## how large a terror-state can grow. The event itself lands with the
## settlement tier (T11.x); this is the trigger.
static func fracture_due(colony: Colony) -> bool:
	return colony.unrest >= FRACTURE_LINE


## Extra schism probability per season contributed by unrest [algo §10];
## consumed by the civilization tier (T11.4).
static func schism_pressure_per_season(colony: Colony) -> float:
	return SCHISM_PRESSURE * colony.unrest


## Mild secularization [plan T8.4, algo §10]: faith drifts down by
## 0.0005·science_level/day — advanced colonies believe a little less,
## never catastrophically (devout mages stay possible).
static func secularize_tick(colony: Colony, science_level: float, dt_days: float) -> void:
	var drift := SECULARIZATION_RATE * science_level * dt_days
	if drift <= 0.0:
		return
	for g in colony.living():
		var faith: float = g.get_feeling(YOU, "faith")
		if faith > 0.0:
			g.set_feeling(YOU, "faith", maxf(0.0, faith - drift))
