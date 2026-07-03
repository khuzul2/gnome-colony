class_name Tuning
extends RefCounted
## WorldConfig ingestion [plan T12.3, setup §3–§5]: resolve every
## player-facing option into the concrete parameter set the sim and
## world-gen honor. The setup spec names WHICH §17 parameters each
## slider scales and in which direction; the per-level MULTIPLIERS are
## interpretive (documented here + PROGRESS.md). Two hard rules:
##  · Defaults resolve to exactly the §17 baselines — every multiplier
##    1.0. Sliders bend spec numbers; they never replace them.
##  · The resolver is pure data: consumers multiply their own §17
##    constants by these factors (world-gen consumes the world block in
##    Phase 13; systems with existing hooks consume theirs at the
##    orchestrator, T13+/T16 wiring).
## Ticks/sec derive from setup §3.1's life-length targets (30/20/10 min
## at 1×) against §17's 8,640-tick life: 4.8 / 7.2 / 14.4.

const PACE_TICKS := {"languid": 4.8, "balanced": 7.2, "brisk": 14.4}
## Interpretive ladders (Normal ≡ 1.0 everywhere):
const MORTALITY_MULT := {"gentle": 0.75, "normal": 1.0, "harsh": 1.5, "brutal": 2.0}
const DISCOVERY_MULT := {"slow": 0.5, "normal": 1.0, "fast": 2.0}
const DIVINITY_THRESHOLD_MULT := {"humble": 1.25, "normal": 1.0, "ascendant": 0.8}
const DIVINITY_POWER_MULT := {"humble": 0.75, "normal": 1.0, "ascendant": 1.25}
const CHAOS_MULT := {"calm": 0.5, "normal": 1.0, "capricious": 2.0}
const CHAOS_RIPENESS_MULT := {"calm": 1.2, "normal": 1.0, "capricious": 0.8}
const SCALE_POP_CAP := {"intimate": 500, "kingdom": 5000, "civilization": 20000}
const FAITH_SECULARIZATION := {"coexist": 0.0, "mild_drift": 1.0, "secularizing": 2.0}
## Ward ceiling per faith mode (§13's 0.7 is the mild-drift default).
const FAITH_RESISTANCE_CEILING := {"coexist": 0.5, "mild_drift": 0.7, "secularizing": 0.85}
const ABUNDANCE_MULT := {"sparse": 0.6, "normal": 1.0, "lush": 1.5}
const HAZARD_MULT := {"calm": 0.5, "normal": 1.0, "volatile": 2.0}


static func resolve(cfg: WorldConfig) -> Dictionary:
	return {
		"pace":
		{
			"ticks_per_second": PACE_TICKS[cfg.generation_pace],
		},
		"mortality":
		# One ladder scales every §3.2 dial: age curve, hardship,
		{
			# accidents, tail lethality — and knowledge fragility.
			"age_curve_mult": MORTALITY_MULT[cfg.mortality],
			"hardship_mult": MORTALITY_MULT[cfg.mortality],
			"accident_mult": MORTALITY_MULT[cfg.mortality],
			"tail_lethality_mult": MORTALITY_MULT[cfg.mortality],
			"min_holders_mult": MORTALITY_MULT[cfg.mortality],
		},
		"discovery":
		{
			"base_rate_mult": DISCOVERY_MULT[cfg.discovery_pace],
			"magic_accrual_mult": DISCOVERY_MULT[cfg.discovery_pace],
		},
		"divinity":
		{
			"devotion_growth_mult": DIVINITY_POWER_MULT[cfg.divinity],
			"tier_threshold_mult": DIVINITY_THRESHOLD_MULT[cfg.divinity],
			"magnitude_k_mult": DIVINITY_POWER_MULT[cfg.divinity],
			"valence_delta_mult": DIVINITY_POWER_MULT[cfg.divinity],
		},
		"chaos":
		{
			"tail_risk_mult": CHAOS_MULT[cfg.chaos],
			"chain_prob_mult": CHAOS_MULT[cfg.chaos],
			"corruption_mult": CHAOS_MULT[cfg.chaos],
			"ripeness_mult": CHAOS_RIPENESS_MULT[cfg.chaos],
		},
		"scale":
		{
			"population_cap": SCALE_POP_CAP[cfg.civilization_scale],
			"individual_budget": Lod.DEFAULT_INDIVIDUAL_BUDGET,
			"quicken_budget": cfg.quicken_budget,
			"civ_tier_enabled": cfg.civilization_scale != "intimate",
		},
		"faith":
		{
			"secularization_mult": FAITH_SECULARIZATION[cfg.faith_enlightenment],
			"resistance_ceiling": FAITH_RESISTANCE_CEILING[cfg.faith_enlightenment],
		},
		"world":
		{
			"basin_count": cfg.basin_count(),
			"abundance_mult": ABUNDANCE_MULT[cfg.resource_abundance],
			"hazard_density_mult": HAZARD_MULT[cfg.hazard_frequency],
			"varied_biomes": cfg.biome_variety == "varied",
			"exploration_fog": cfg.exploration_fog,
		},
		"founding":
		{
			"band_size": cfg.band_size,
			"temperament_leanings": cfg.temperament_leanings.duplicate(),
		},
	}
