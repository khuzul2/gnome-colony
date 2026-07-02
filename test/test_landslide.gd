extends GutTest

## T7.3 — the canonical first act [algo §18 "landslide", design §3.4]:
## the hillside lets go — the site is buried, hidden iron is exposed, the
## path is blocked, and gnomes present may die. Casualty probability per
## present gnome = |effects.population| · intensity (the population-axis
## weight IS the lethality dial — interpretive, no separate spec number).

var _def := {
	"id": "landslide",
	"category": 2,
	"valence": "malevolent",
	"target": "point",
	"base_intensity": 0.6,
	"event_drama": 0.6,
	"tier": 2,
	"effects":
	{"material": -0.3, "population": -0.3, "discovery": 0.4, "belief": 0.5, "social": "=culture"},
	"affordance_req": "slope",
	"chain_hooks": [{"phenom": "dam_flood", "prob": 0.15}, {"phenom": "cursed_place", "prob": 0.2}],
	"tail_risk": 0.03,
}


func _setup() -> Array:
	var colony := Colony.new()
	for i in 20:
		var g := colony.spawn()
		g.age = 30.0
		g.stage = Enums.LifeStage.ADULT
		g.location = "eastern_ridge" if i < 10 else "village"
	var world := WorldState.new()
	world.affordances["eastern_ridge"] = ["slope"]
	world.sites["eastern_ridge"] = ResourceNode.new("stone", 10.0, 10.0, 0.1, 1.0)
	world.hidden_resources["eastern_ridge"] = [ResourceNode.new("iron", 30.0, 30.0, 0.0, 1.0)]
	world.paths["eastern_ridge_path"] = true
	return [colony, world]


func _cast(colony: Colony, world: WorldState) -> void:
	Influence.cast(colony, world, _def, "eastern_ridge", 1.0, 1.0, Landslide.handlers())


func test_landslide_kills_some_of_those_present():
	Rng.seed_with(7300)
	var setup := _setup()
	var deaths := []
	var listener := func(p: Dictionary) -> void: deaths.append(p)
	EventBus.gnome_died.connect(listener)
	_cast(setup[0], setup[1])
	EventBus.gnome_died.disconnect(listener)
	assert_between(deaths.size(), 1, 6, "≈1.8 expected of 10 present at p=0.18")
	for d in deaths:
		assert_eq(d["cause"], "landslide")
		var victim: GnomeData = setup[0].gnomes[d["id"]]
		assert_eq(victim.location, "eastern_ridge", "the village was untouched")


func test_landslide_reveals_the_iron():
	Rng.seed_with(7301)
	var setup := _setup()
	_cast(setup[0], setup[1])
	assert_true(setup[1].sites.has("eastern_ridge_iron"), "the scar glints with ore")
	assert_eq(setup[1].sites["eastern_ridge_iron"].type, "iron")


func test_landslide_buries_site_and_path():
	Rng.seed_with(7302)
	var setup := _setup()
	_cast(setup[0], setup[1])
	assert_lt(setup[1].sites["eastern_ridge"].current, 10.0, "the site is buried under rock")
	assert_false(setup[1].paths["eastern_ridge_path"], "the path is blocked")


func test_landslide_leaves_other_places_alone():
	Rng.seed_with(7303)
	var setup := _setup()
	setup[1].sites["village_field"] = ResourceNode.new("food", 8.0, 8.0, 1.0, 1.0)
	setup[1].paths["south_pass"] = true
	_cast(setup[0], setup[1])
	assert_eq(setup[1].sites["village_field"].current, 8.0)
	assert_true(setup[1].paths["south_pass"])
