class_name Birth
extends RefCounted
## Births [plan T2.4 scaffold + T5.3 fertility, algo §8/§17]:
## per-season chance per fertile pair = 0.15 · food_factor · (1 − crowding).
## Fertile pair: partnered, both Adult, opposite sexes, bearer aged 20–50.
## The "bearer" label is sex 0 — an arbitrary tag, only reproduction cares.
## Trait inheritance arrives in T5.4; children start with defaults for now.

const SEASON_BIRTH_CHANCE := 0.15
const BEARER_MIN_AGE := 20.0
const BEARER_MAX_AGE := 50.0
const BEARER_SEX := 0

# Inheritance [algo §8/§17] (T5.4), per trait:
#   child = clamp(0.5·(p1+p2) + N(0, 0.05)); 2% chance extra +N(0, 0.2).
const MUTATION_SD := 0.05
const LARGE_MUTATION_CHANCE := 0.02
const LARGE_MUTATION_SD := 0.2


## Placeholder direct spawn (T2.4) — also the shared tail of a fertile
## birth when parents are given.
static func spawn_infant(colony: Colony, p1: GnomeData = null, p2: GnomeData = null) -> GnomeData:
	var infant := colony.spawn()
	infant.stage = Enums.LifeStage.INFANT
	infant.age = 0.0
	infant.sex = Rng.randi_range(0, 1)
	if p1 != null and p2 != null:
		infant.generation = maxi(p1.generation, p2.generation) + 1
		infant.home_settlement = p1.home_settlement
		_inherit_traits(infant, p1, p2)
		Outliers.maybe_mark(infant)
		# Kin edges start at neutral 0 weight (no spec value; interactions
		# grow them) — the type marker is what matters for culture flow.
		infant.set_relationship(p1.id, "kin", 0.0)
		infant.set_relationship(p2.id, "kin", 0.0)
		p1.set_relationship(infant.id, "kin", 0.0)
		p2.set_relationship(infant.id, "kin", 0.0)
	EventBus.born.emit({"id": infant.id})
	return infant


## Roll every fertile pair once per season [algo §8].
static func season_tick(colony: Colony, food_factor: float, crowding: float) -> void:
	var chance := SEASON_BIRTH_CHANCE * food_factor * (1.0 - crowding)
	var ids := colony.gnomes.keys()
	ids.sort()
	for id in ids:
		var bearer: GnomeData = colony.gnomes[id]
		if not _is_fertile_bearer(bearer):
			continue
		var partner: GnomeData = colony.gnomes.get(bearer.partner_id)
		if partner == null or not _is_fertile_partner(partner):
			continue
		if Rng.chance(chance):
			spawn_infant(colony, bearer, partner)


## Per-trait blend + mutation [algo §8]. Skills/knowledge are NOT touched:
## they must be taught (that is why culture matters). A trait that is
## constitutional in either parent (mutant lineage) inherits UNCLAMPED and
## carries the constitutional marker onward. §8 says mutants are "partly
## heritable" without a probability — full heritability of the marked trait
## is the interpretive reading here (blending still dilutes the value).
static func _inherit_traits(infant: GnomeData, p1: GnomeData, p2: GnomeData) -> void:
	for key in Enums.TRAIT_KEYS:
		var value: float = 0.5 * (p1.traits[key] + p2.traits[key]) + Rng.gauss(0.0, MUTATION_SD)
		if Rng.chance(LARGE_MUTATION_CHANCE):
			value += Rng.gauss(0.0, LARGE_MUTATION_SD)
		if key in p1.constitutional_traits or key in p2.constitutional_traits:
			infant.traits[key] = value
			infant.constitutional_traits.append(key)
		else:
			infant.set_trait(key, value)


static func _is_fertile_bearer(g: GnomeData) -> bool:
	return (
		g.is_alive()
		and g.sex == BEARER_SEX
		and g.partner_id != -1
		and g.stage == Enums.LifeStage.ADULT
		and g.age >= BEARER_MIN_AGE
		and g.age <= BEARER_MAX_AGE
	)


static func _is_fertile_partner(g: GnomeData) -> bool:
	return g.is_alive() and g.sex != BEARER_SEX and g.stage == Enums.LifeStage.ADULT
