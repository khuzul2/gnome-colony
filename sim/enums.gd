class_name Enums
extends RefCounted
## Shared enums & key catalogs [plan T1.1]. Values are STABLE — serialization
## and tests depend on them; never reorder or renumber.

## Life stages [algo §4]; DEAD is terminal.
enum LifeStage { INFANT, CHILD, ADOLESCENT, ADULT, ELDER, DEAD }

## Settlement development tiers [rav §R-set]; ordered, ascending. Values are
## STABLE (serialized on Settlement.tier); never reorder.
enum SettlementTier { HAMLET, VILLAGE, TOWN, CITY }

## Personality trait keys [algo §2] — starting catalog, each in [0,1].
const TRAIT_KEYS := [
	"industrious",
	"curious",
	"timid",
	"social",
	"devout",
	"aggressive",
	"nurturing",
	"ambitious",
]

## Need keys [algo §3], each in [0,1]; 0 = satisfied, 1 = desperate.
const NEED_KEYS := ["hunger", "rest", "social", "safety", "purpose"]

## Feeling axes of the belief substrate [algo §9].
const BELIEF_AXES := ["fear", "awe", "faith", "reverence"]

## Knowledge-object categories [algo §1, §7]: crafts, technologies, magical
## insights — one lifecycle for all three.
const KNOWLEDGE_CATEGORIES := ["craft", "tech", "magic"]
