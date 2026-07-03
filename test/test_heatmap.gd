extends GutTest

## T14.3 (heatmap half) — mood/belief heatmaps [plan Phase 14, design
## §2.7]: the heatmap READS the substrate — living gnomes by location
## (quickened grain) or folded Settlement aggregates (statistical
## grain) — and never computes sim state of its own. Mood is §5's
## 1 − mean(needs); belief axes are the feelings toward the unseen
## will. The color ramp is a presentation number.


func _gnome_at(colony: Colony, place: String, need_level: float, fear: float) -> GnomeData:
	var g := colony.spawn()
	g.age = 30.0
	g.stage = Enums.LifeStage.ADULT
	g.location = place
	for key in Enums.NEED_KEYS:
		g.needs[key] = need_level
	g.set_feeling(Devotion.YOU, "fear", fear)
	return g


func test_the_gnome_grain_reads_mood_and_belief_by_place():
	var colony := Colony.new()
	_gnome_at(colony, "the_hollow", 0.8, 0.6)
	_gnome_at(colony, "the_hollow", 0.6, 0.2)
	_gnome_at(colony, "meadow", 0.1, 0.0)
	var map := Heatmap.from_gnomes(colony)
	assert_almost_eq(map["the_hollow"]["mood"], 0.3, 0.001, "mood = 1 − mean(needs) [algo §5]")
	assert_almost_eq(map["the_hollow"]["fear"], 0.4, 0.001, "belief axes mean over locals")
	assert_almost_eq(map["meadow"]["mood"], 0.9, 0.001, "a lighter place reads brighter")
	assert_false(map.has("eastern_ridge"), "no gnomes, no reading — the map stays dark")


func test_the_dead_cast_no_shadow_on_the_map():
	var colony := Colony.new()
	_gnome_at(colony, "the_hollow", 0.2, 0.0)
	var ghost := _gnome_at(colony, "the_hollow", 1.0, 1.0)
	ghost.stage = Enums.LifeStage.DEAD
	var map := Heatmap.from_gnomes(colony)
	assert_almost_eq(map["the_hollow"]["mood"], 0.8, 0.001, "only the living color the substrate")


func test_the_settlement_grain_reads_the_folded_aggregates():
	var s := Settlement.new(0, 10.0, 1.0)
	s.mood = 0.35
	s.belief = {"faith": 0.5, "awe": 0.3, "fear": 0.1}
	var map := Heatmap.from_settlements({0: s}, {0: "the_hollow"})
	assert_almost_eq(map["the_hollow"]["mood"], 0.35, 0.001, "the fold IS the reading [§14]")
	assert_almost_eq(map["the_hollow"]["faith"], 0.5, 0.001)
	s.mood = 0.9
	map = Heatmap.from_settlements({0: s}, {0: "the_hollow"})
	assert_almost_eq(map["the_hollow"]["mood"], 0.9, 0.001, "substrate moves, heatmap follows")


func test_an_unmapped_settlement_still_gets_a_name():
	var s := Settlement.new(3, 10.0, 1.0)
	var map := Heatmap.from_settlements({3: s}, {})
	assert_true(map.has("settlement_3"), "no place mapping yet — a fallback key, not a crash")


func test_the_ramp_runs_cold_to_warm():
	assert_ne(Heatmap.color(0.0), Heatmap.color(1.0), "the ends differ")
	assert_gt(Heatmap.color(0.9).g, Heatmap.color(0.1).g, "high values read warmer/greener")
	assert_gt(Heatmap.color(0.1).r, Heatmap.color(0.9).r, "low values read redder")
