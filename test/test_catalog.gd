extends GutTest

## T7.8 — seed catalog [algo §18]: the 15 phenomena load as data and
## validate; valence spread is the documented 4 benevolent (2 clean /
## 2 tainted) · 7 malevolent · 4 neutral; every chain hook resolves to a
## catalog entry or a known consequence marker; targets match §18's index;
## affordance gating is wired into the runner.

const TARGET_INDEX := {
	"ground_remembers": "point",
	"standing_stones": "point",
	"the_swallowing": "point",
	"landslide": "point",
	"still_air": "area",
	"weeping_sky": "area",
	"the_quickening": "area",
	"the_blight": "area",
	"long_dark": "region",
	"coming_herd": "region-edge",
	"thing_in_dark": "region-edge",
	"wrongness_blood": "settlement",
	"birds_silent": "settlement",
	"shared_dream": "settlement",
	"day_twice": "settlement",
}


func test_all_fifteen_load_and_validate():
	var defs := Catalog.defs()
	assert_eq(defs.size(), 15)
	for id in defs:
		assert_eq(Phenomenon.validate(defs[id]), [], "%s validates clean" % id)
		assert_eq(defs[id]["id"], id, "keyed by its own id")


func test_valence_spread_matches_section_18():
	var spread := Phenomenon.valence_spread(Catalog.defs().values())
	assert_eq(spread, {"benevolent": 4, "malevolent": 7, "neutral": 4})
	var clean := 0
	var tainted := 0
	for d in Catalog.defs().values():
		if d.get("taint", "") == "clean":
			clean += 1
		elif d.get("taint", "") == "tainted":
			tainted += 1
	assert_eq([clean, tainted], [2, 2], "2 clean / 2 tainted boons")


func test_balance_rule_holds():
	assert_eq(Phenomenon.balance_report(Catalog.defs().values()), [])


func test_every_chain_resolves():
	var defs := Catalog.defs()
	for id in defs:
		for hook in defs[id]["chain_hooks"]:
			var child: String = hook["phenom"]
			assert_true(
				defs.has(child) or child in Catalog.CONSEQUENCES,
				"%s chains to unresolvable '%s'" % [id, child]
			)


func test_targets_match_section_18_index():
	var defs := Catalog.defs()
	for id in TARGET_INDEX:
		assert_true(defs.has(id), "missing §18 entry: %s" % id)
		assert_eq(defs[id]["target"], TARGET_INDEX[id], "%s target" % id)


func test_affordance_gating_blocks_and_admits():
	Rng.seed_with(7800)
	var colony := Colony.new()
	var world := WorldState.new()
	watch_signals(EventBus)
	var flat := Influence.cast(colony, world, Catalog.defs()["landslide"], "meadow")
	assert_eq(flat, {}, "you cannot slide a hill that is not there [design §2.7b]")
	assert_signal_not_emitted(EventBus, "phenomenon")
	world.affordances["scarp"] = ["slope"]
	var slide := Influence.cast(colony, world, Catalog.defs()["landslide"], "scarp")
	assert_eq(slide["type"], "landslide")
	assert_signal_emitted(EventBus, "phenomenon")


func test_any_affordance_always_casts():
	Rng.seed_with(7801)
	var colony := Colony.new()
	var world := WorldState.new()
	var stim := Influence.cast(colony, world, Catalog.defs()["still_air"], "anywhere")
	assert_eq(stim["type"], "still_air")


func test_landslide_handler_is_wired():
	assert_true(Catalog.handlers().has("landslide"), "the canonical first act has its handler")
