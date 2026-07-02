class_name Devotion
extends RefCounted
## Devotion & social mass [plan T8.1, algo §10]. Per-gnome devotion is the
## faith-in-you feeling; colony devotion D = Σ faith (belief × population);
## depth d̄ = D/pop gates the toolbox (T8.2); flavor = mean(awe − fear)
## toward you — love-faith vs terror-faith. "You" lives in the substrate
## as the subject "unseen_will" [algo §9's attribution wording].

const YOU := "unseen_will"

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


static func flavor_balance(colony: Colony) -> float:
	var living := colony.living()
	if living.is_empty():
		return 0.0
	var sum := 0.0
	for g in living:
		sum += g.get_feeling(YOU, "awe") - g.get_feeling(YOU, "fear")
	return sum / living.size()
