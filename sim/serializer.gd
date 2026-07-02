class_name Serializer
extends RefCounted
## Data-only serialization [plan T1.5]: GnomeData, Colony, WorldConfig
## ↔ plain Dictionaries (deep-copied, no aliasing). The full save-game
## serializer (belief graph, world, RNG state) arrives in T12.1 on top
## of these primitives.


static func gnome_to_dict(g: GnomeData) -> Dictionary:
	return {
		"id": g.id,
		"age": g.age,
		"stage": g.stage,
		"sex": g.sex,
		"needs": g.needs.duplicate(true),
		"traits": g.traits.duplicate(true),
		"skills": g.skills.duplicate(true),
		"knowledge": g.knowledge.duplicate(true),
		"feelings": g.feelings.duplicate(true),
		"relationships": g.relationships.duplicate(true),
		"memory": g.memory.duplicate(true),
		"notability": g.notability,
		"partner_id": g.partner_id,
		"home_settlement": g.home_settlement,
		"hardship_rate": g.hardship_rate,
		"hardship_days": g.hardship_days.duplicate(true),
		"project": g.project.duplicate(true),
		"generation": g.generation,
	}


static func gnome_from_dict(d: Dictionary) -> GnomeData:
	var g := GnomeData.new(d["id"])
	g.age = d["age"]
	g.stage = d["stage"]
	g.sex = d["sex"]
	g.needs = d["needs"].duplicate(true)
	g.traits = d["traits"].duplicate(true)
	g.skills = d["skills"].duplicate(true)
	g.knowledge = d["knowledge"].duplicate(true)
	g.feelings = d["feelings"].duplicate(true)
	g.relationships = d["relationships"].duplicate(true)
	g.memory = d["memory"].duplicate(true)
	g.notability = d["notability"]
	g.partner_id = d["partner_id"]
	g.home_settlement = d["home_settlement"]
	g.hardship_rate = d["hardship_rate"]
	g.hardship_days = d["hardship_days"].duplicate(true)
	g.project = d["project"].duplicate(true)
	g.generation = d["generation"]
	return g


static func colony_to_dict(c: Colony) -> Dictionary:
	var gnome_dicts := {}
	for gnome_id in c.gnomes:
		gnome_dicts[gnome_id] = gnome_to_dict(c.gnomes[gnome_id])
	return {
		"next_id": c.next_id,
		"gnomes": gnome_dicts,
		"settlement_knowledge": c.settlement_knowledge.duplicate(true),
		"durable_records": c.durable_records.duplicate(true),
	}


static func colony_from_dict(d: Dictionary) -> Colony:
	var c := Colony.new()
	for gnome_id in d["gnomes"]:
		c.add(gnome_from_dict(d["gnomes"][gnome_id]))
	c.next_id = d["next_id"]
	c.settlement_knowledge = d["settlement_knowledge"].duplicate(true)
	c.durable_records = d["durable_records"].duplicate(true)
	return c


static func config_to_dict(cfg: WorldConfig) -> Dictionary:
	return {
		"generation_pace": cfg.generation_pace,
		"mortality": cfg.mortality,
		"discovery_pace": cfg.discovery_pace,
		"divinity": cfg.divinity,
		"chaos": cfg.chaos,
		"civilization_scale": cfg.civilization_scale,
		"faith_enlightenment": cfg.faith_enlightenment,
		"seed": cfg.seed,
		"region_size": cfg.region_size,
		"resource_abundance": cfg.resource_abundance,
		"hazard_frequency": cfg.hazard_frequency,
		"biome_variety": cfg.biome_variety,
		"exploration_fog": cfg.exploration_fog,
		"band_size": cfg.band_size,
		"temperament_leanings": cfg.temperament_leanings.duplicate(true),
		"culture_flavor": cfg.culture_flavor,
		"colony_name": cfg.colony_name,
		"quicken_budget": cfg.quicken_budget,
	}


static func config_from_dict(d: Dictionary) -> WorldConfig:
	var cfg := WorldConfig.new()
	cfg.generation_pace = d["generation_pace"]
	cfg.mortality = d["mortality"]
	cfg.discovery_pace = d["discovery_pace"]
	cfg.divinity = d["divinity"]
	cfg.chaos = d["chaos"]
	cfg.civilization_scale = d["civilization_scale"]
	cfg.faith_enlightenment = d["faith_enlightenment"]
	cfg.seed = d["seed"]
	cfg.region_size = d["region_size"]
	cfg.resource_abundance = d["resource_abundance"]
	cfg.hazard_frequency = d["hazard_frequency"]
	cfg.biome_variety = d["biome_variety"]
	cfg.exploration_fog = d["exploration_fog"]
	cfg.band_size = d["band_size"]
	cfg.temperament_leanings = d["temperament_leanings"].duplicate(true)
	cfg.culture_flavor = d["culture_flavor"]
	cfg.colony_name = d["colony_name"]
	cfg.quicken_budget = d["quicken_budget"]
	return cfg
