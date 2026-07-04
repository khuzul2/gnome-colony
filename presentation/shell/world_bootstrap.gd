class_name WorldBootstrap
extends RefCounted
## Final-assembly world bootstrap [PROGRESS T17.1, DONE.md handover note
## 3]: WorldConfig → Tuning's world block → RegionGraph → the WorldState
## a run plays in — deterministic per seed (caller seeds Rng first, as
## every composition does). This is GLUE, not gameplay: the sites promote
## the CANONICAL integration-fixture composition unchanged — the epochal
## food node (test_epochal.gd) at the colony's home basin and the
## playtest slice's ridge pattern (stone + hidden iron + slope + road)
## at every ridge basin BEYOND home — the band clears its own ground,
## so home is always the hollow (the slice's home carried no hazard
## affordance either; a ridge-biome home keeps only its name). Worlds
## whose seed rolls no other ridge basin simply offer no slope this
## run — world variety, same as every tested composition. Bent only
## by Tuning's already-resolved
## abundance multiplier, whose world-gen consumer was deferred at T12.3.
## Defaults resolve ×1.0, so the default world IS the tested fixture.
## Fixture constants below are assembly structure (same standing as
## T13.1's world-gen scaffolding numbers), not §17 gameplay numbers.
## Non-ridge basins stay bare named places: affordance-gated phenomena
## that need lived terrain (farmland/built_up/crowded/drought/wilds)
## fizzle there exactly as they always have — the world never authored
## those tags in any tested composition, and inventing a mapping would
## be new gameplay (out of Phase-17 scope; noted in PROGRESS).

## The epochal larder [test_epochal.gd / test_phase15_exit.gd fixture].
const FOOD_CAPACITY := 100.0
const FOOD_REGROWTH := 10.0
const FOOD_RICHNESS := 1.0
## The fixture crowding K every integration run passes to SimRunner.
const COLONY_K := 60.0
## The slice's ridge pattern [playtest_slice.gd / test_landslide.gd].
const STONE_CAPACITY := 40.0
const STONE_REGROWTH := 2.0
const STONE_RICHNESS := 0.8
const IRON_CAPACITY := 30.0
const IRON_RICHNESS := 1.5


## Returns {graph, world, food, capacity, home}: everything GameRun
## needs to found a colony — the food node doubles as the home SITE so
## a phenomenon burying home really empties the larder (slice wiring).
static func build(cfg: WorldConfig) -> Dictionary:
	var params: Dictionary = Tuning.resolve(cfg)
	var abundance: float = params["world"]["abundance_mult"]
	var graph := RegionGraph.generate(params["world"])
	var world := WorldState.new()
	var home := place_id(graph.regions[0])
	var food := ResourceNode.new(
		"food",
		FOOD_CAPACITY * abundance,
		FOOD_CAPACITY * abundance,
		FOOD_REGROWTH * abundance,
		FOOD_RICHNESS
	)
	world.sites[home] = food
	for region in graph.regions:
		var place := place_id(region)
		if place == home:
			continue
		world.paths["%s_path" % place] = true
		# World-gen truth [T18.1, §18 "near wilds"]: every basin beyond
		# the settled edge is wild, and so is the edge you cross to
		# reach it (the id namespace RunView's edge paint uses).
		world.affordances[place] = ["wilds"]
		world.affordances["%s_edge" % place] = ["wilds"]
		if region["biome"] == "ridge":
			world.sites[place] = ResourceNode.new(
				"stone",
				STONE_CAPACITY * abundance,
				STONE_CAPACITY * abundance,
				STONE_REGROWTH * abundance,
				STONE_RICHNESS
			)
			world.hidden_resources[place] = [
				ResourceNode.new(
					"iron", IRON_CAPACITY * abundance, IRON_CAPACITY * abundance, 0.0, IRON_RICHNESS
				)
			]
			world.affordances[place] = ["slope", "wilds"]
	return {
		"graph": graph,
		"world": world,
		"food": food,
		"capacity": COLONY_K * abundance,
		"home": home,
	}


## One stable, human-readable place id per basin — the namespace shared
## by gnome locations, world sites, attention regions, and act targets.
static func place_id(region: Dictionary) -> String:
	return "%s_%d" % [region["biome"], region["id"]]
