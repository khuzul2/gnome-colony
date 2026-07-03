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
		"mastered_skills": g.mastered_skills.duplicate(true),
		"partner_id": g.partner_id,
		"home_settlement": g.home_settlement,
		"hardship_rate": g.hardship_rate,
		"hardship_days": g.hardship_days.duplicate(true),
		"project": g.project.duplicate(true),
		"generation": g.generation,
		"constitutional_traits": g.constitutional_traits.duplicate(true),
		"outlier_type": g.outlier_type,
		"prophet_affinity": g.prophet_affinity,
		"prophet": g.prophet.duplicate(true),
		"habituation": g.habituation.duplicate(true),
		"location": g.location,
		"lod": g.lod,
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
	g.mastered_skills = d["mastered_skills"].duplicate(true)
	g.partner_id = d["partner_id"]
	g.home_settlement = d["home_settlement"]
	g.hardship_rate = d["hardship_rate"]
	g.hardship_days = d["hardship_days"].duplicate(true)
	g.project = d["project"].duplicate(true)
	g.generation = d["generation"]
	g.constitutional_traits = d["constitutional_traits"].duplicate(true)
	g.outlier_type = d["outlier_type"]
	g.prophet_affinity = d["prophet_affinity"]
	g.prophet = d["prophet"].duplicate(true)
	g.habituation = d["habituation"].duplicate(true)
	g.location = d["location"]
	g.lod = d["lod"]
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
		"beliefs": c.beliefs.duplicate(true),
		"place_tags": c.place_tags.duplicate(true),
		"belief_tracker": c.belief_tracker.duplicate(true),
		"devotion_peak": c.devotion_peak,
		"unlocked_tier": c.unlocked_tier,
		"unrest": c.unrest,
		"magic_understanding": c.magic_understanding.duplicate(true),
		"leaders": c.leaders.duplicate(true),
		"world_over": c.world_over,
	}


static func colony_from_dict(d: Dictionary) -> Colony:
	var c := Colony.new()
	for gnome_id in d["gnomes"]:
		c.add(gnome_from_dict(d["gnomes"][gnome_id]))
	c.next_id = d["next_id"]
	c.settlement_knowledge = d["settlement_knowledge"].duplicate(true)
	c.durable_records = d["durable_records"].duplicate(true)
	c.beliefs = d["beliefs"].duplicate(true)
	c.place_tags = d["place_tags"].duplicate(true)
	c.belief_tracker = d["belief_tracker"].duplicate(true)
	c.devotion_peak = d["devotion_peak"]
	c.unlocked_tier = d["unlocked_tier"]
	c.unrest = d["unrest"]
	c.magic_understanding = d["magic_understanding"].duplicate(true)
	c.leaders = d["leaders"].duplicate(true)
	c.world_over = d["world_over"]
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


static func node_to_dict(n: ResourceNode) -> Dictionary:
	return {
		"type": n.type,
		"capacity": n.capacity,
		"current": n.current,
		"regrowth": n.regrowth,
		"richness": n.richness,
	}


static func node_from_dict(d: Dictionary) -> ResourceNode:
	return ResourceNode.new(d["type"], d["capacity"], d["current"], d["regrowth"], d["richness"])


static func world_to_dict(w: WorldState) -> Dictionary:
	var sites := {}
	for id in w.sites:
		sites[id] = node_to_dict(w.sites[id])
	var hidden := {}
	for id in w.hidden_resources:
		var nodes := []
		for n in w.hidden_resources[id]:
			nodes.append(node_to_dict(n))
		hidden[id] = nodes
	return {
		"sites": sites,
		"hidden_resources": hidden,
		"paths": w.paths.duplicate(true),
		"affordances": w.affordances.duplicate(true),
		"wards": w.wards.duplicate(true),
	}


static func world_from_dict(d: Dictionary) -> WorldState:
	var w := WorldState.new()
	for id in d["sites"]:
		w.sites[id] = node_from_dict(d["sites"][id])
	for id in d["hidden_resources"]:
		var nodes := []
		for nd in d["hidden_resources"][id]:
			nodes.append(node_from_dict(nd))
		w.hidden_resources[id] = nodes
	w.paths = d["paths"].duplicate(true)
	w.affordances = d["affordances"].duplicate(true)
	w.wards = d["wards"].duplicate(true)
	return w


static func settlement_to_dict(s: Settlement) -> Dictionary:
	return {
		"sid": s.sid,
		"base_k": s.base_k,
		"richness_sum": s.richness_sum,
		"by_stage": s.by_stage.duplicate(true),
		"mean_traits": s.mean_traits.duplicate(true),
		"mood": s.mood,
		"belief": s.belief.duplicate(true),
	}


static func settlement_from_dict(d: Dictionary) -> Settlement:
	var s := Settlement.new(d["sid"], d["base_k"], d["richness_sum"])
	s.by_stage = d["by_stage"].duplicate(true)
	s.mean_traits = d["mean_traits"].duplicate(true)
	s.mood = d["mood"]
	s.belief = d["belief"].duplicate(true)
	return s


static func time_to_dict(t: TimeService) -> Dictionary:
	return {
		"total_days": t.total_days,
		"speed": t.speed,
		"speed_before_pause": t._speed_before_pause,
	}


static func time_from_dict(d: Dictionary) -> TimeService:
	var t := TimeService.new()
	t.total_days = d["total_days"]
	t.speed = d["speed"]
	t._speed_before_pause = d["speed_before_pause"]
	return t


## Full save-game envelope [plan T12.1]: everything a run is — colony
## (with its belief/culture graph), world, settlement aggregates, config,
## calendar, chronicle, and the RNG stream position — as PLAIN data
## (JSON-safe, no objects). Loading returns live objects keyed the same
## way and restores the Rng stream as a side effect, so play continues
## the exact sequence an uninterrupted run would have produced.
static func save_to_dict(
	colony: Colony,
	world: WorldState,
	settlements: Array,
	config: WorldConfig,
	time: TimeService,
	chronicle: Array,
) -> Dictionary:
	var settlement_dicts := []
	for s in settlements:
		settlement_dicts.append(settlement_to_dict(s))
	return {
		"version": 1,
		"colony": colony_to_dict(colony),
		"world": world_to_dict(world),
		"settlements": settlement_dicts,
		"config": config_to_dict(config),
		"time": time_to_dict(time),
		"chronicle": chronicle.duplicate(true),
		# As a STRING: JSON numbers are doubles and would silently corrupt
		# a 64-bit stream position (reviewer catch — the exactness promise
		# must survive a real trip through disk).
		"rng_state": str(Rng.get_state()),
	}


static func save_from_dict(d: Dictionary) -> Dictionary:
	var settlements := []
	for sd in d["settlements"]:
		settlements.append(settlement_from_dict(sd))
	Rng.set_state(int(d["rng_state"]))
	return {
		"colony": colony_from_dict(d["colony"]),
		"world": world_from_dict(d["world"]),
		"settlements": settlements,
		"config": config_from_dict(d["config"]),
		"time": time_from_dict(d["time"]),
		"chronicle": d["chronicle"].duplicate(true),
	}
