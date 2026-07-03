class_name Culture
extends RefCounted
## Culture system stub [plan T5.5]; grows into the full belief machinery in
## Phase 6. For now: trait plasticity [algo §2/§17] — the young drift toward
## their culture's trait means:
##   trait += plasticity · (env_mean − trait) · dt
## plasticity = 0.02/day through Infant/Child, tapering linearly to 0 across
## Adolescence (14→20) — the spec gives "0.02/day while young → ~0 by
## Adult" without a curve; the linear taper is interpretive (PROGRESS.md).
## Constitutional (outlier-born) traits are EXEMPT so the divergence engine
## isn't washed out [algo §2].

const PLASTICITY_PER_DAY := 0.02


static func plasticity_for(g: GnomeData) -> float:
	match g.stage:
		Enums.LifeStage.INFANT, Enums.LifeStage.CHILD:
			return PLASTICITY_PER_DAY
		Enums.LifeStage.ADOLESCENT:
			var fade := (
				(Aging.ADOLESCENT_UNTIL - g.age) / (Aging.ADOLESCENT_UNTIL - Aging.CHILD_UNTIL)
			)
			return PLASTICITY_PER_DAY * clampf(fade, 0.0, 1.0)
		_:
			return 0.0


static func plasticity_tick(colony: Colony, dt_days: float) -> void:
	var living := colony.living()
	# Lazy: trait means are only computed once someone plastic exists —
	# an all-adult colony pays nothing (T11.5 perf, behavior identical).
	var env_mean := {}
	for g in living:
		var rate := plasticity_for(g)
		if rate == 0.0:
			continue
		if env_mean.is_empty():
			env_mean = _trait_means(living)
		for key in Enums.TRAIT_KEYS:
			if key in g.constitutional_traits:
				continue
			var drift: float = rate * (env_mean[key] - g.traits[key]) * dt_days
			g.set_trait(key, g.traits[key] + drift)


## Mean traits over the living — the slice of §5 vitals plasticity needs
## (identical numbers to colony.vitals()["mean_traits"], without paying
## for needs/stages/mood every day).
static func _trait_means(living: Array) -> Dictionary:
	var means := {}
	for key in Enums.TRAIT_KEYS:
		means[key] = 0.0
	for g in living:
		for key in Enums.TRAIT_KEYS:
			means[key] += g.traits[key]
	for key in Enums.TRAIT_KEYS:
		means[key] /= living.size()
	return means
