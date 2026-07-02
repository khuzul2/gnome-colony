class_name Devotion
extends RefCounted
## Devotion & social mass [plan T8.1, algo §10]. Per-gnome devotion is the
## faith-in-you feeling; colony devotion D = Σ faith (belief × population);
## depth d̄ = D/pop gates the toolbox (T8.2); flavor = mean(awe − fear)
## toward you — love-faith vs terror-faith. "You" lives in the substrate
## as the subject "unseen_will" [algo §9's attribution wording].

const YOU := "unseen_will"


static func total(colony: Colony) -> float:
	var sum := 0.0
	for g in colony.living():
		sum += g.get_feeling(YOU, "faith")
	return sum


static func per_capita(colony: Colony) -> float:
	var pop := colony.population()
	return total(colony) / pop if pop > 0 else 0.0


static func flavor_balance(colony: Colony) -> float:
	var living := colony.living()
	if living.is_empty():
		return 0.0
	var sum := 0.0
	for g in living:
		sum += g.get_feeling(YOU, "awe") - g.get_feeling(YOU, "fear")
	return sum / living.size()
