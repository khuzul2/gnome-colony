class_name Outliers
extends RefCounted
## Outlier births — the divergence engine [plan T5.7, algo §8]. Each birth
## has p_outlier ≈ 0.01 of rolling an outlier; the type is drawn uniformly
## from the §8 table's rows (the spec lists types without weights —
## interpretive). Outlier trait values are CONSTITUTIONAL: exempt from
## plasticity and, for mutants, out-of-band and inherited unclamped.
##   genius     — curiosity pinned at the top of the band; leaps learning.
##   touched    — prophet_affinity 1.0 (prime prophet seed, consumed T9.1).
##   mutant     — one trait pushed outside [0,1] (band edge ± U(0.1, 0.5)
##                — magnitude interpretive, spec says only "outside band").
##   longlived  — lineage marker only for now (extensible flavour row).

const P_OUTLIER := 0.01
const TYPES := ["genius", "touched", "mutant", "longlived"]
const MUTANT_PUSH_MIN := 0.1
const MUTANT_PUSH_MAX := 0.5


## Roll and, on a hit, mark the newborn. Called once per birth.
static func maybe_mark(infant: GnomeData) -> void:
	if not Rng.chance(P_OUTLIER):
		return
	var type: String = TYPES[Rng.randi_range(0, TYPES.size() - 1)]
	infant.outlier_type = type
	match type:
		"genius":
			infant.traits["curious"] = 1.0
			infant.constitutional_traits.append("curious")
		"touched":
			infant.prophet_affinity = 1.0
		"mutant":
			var key: String = Enums.TRAIT_KEYS[Rng.randi_range(0, Enums.TRAIT_KEYS.size() - 1)]
			var push := Rng.randf_range(MUTANT_PUSH_MIN, MUTANT_PUSH_MAX)
			# Raw write on purpose: mutant values live OUTSIDE the clamped
			# band [algo §8], so set_trait() must not touch them.
			infant.traits[key] = 1.0 + push if Rng.chance(0.5) else -push
			infant.constitutional_traits.append(key)
		"longlived":
			pass
