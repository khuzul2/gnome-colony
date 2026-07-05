extends GutTest

## R1.5 [rav §R-art] — the material reskin: gnomes keep their bodies but take
## Ravenna tones (warm cream → gold with faith, → oxblood-red with dread) with
## a warm rim, a gold halo marks the holy (prophet / high notability), and the
## terrain wears palette bands by elevation. The mosaic shader quantizes on
## screen; here we gate direction + structure.


func _gnome() -> GnomeData:
	var g := GnomeData.new(0)
	g.stage = Enums.LifeStage.ADULT
	g.age = 30.0
	return g


func _puppet(g: GnomeData) -> GnomePuppet:
	var puppet := GnomePuppet.new()
	add_child_autofree(puppet)
	puppet.bind(g)
	return puppet


func test_dread_reddens_and_faith_gilds():
	var calm := _puppet(_gnome())
	var calm_tint := calm.tint()
	var afraid := _gnome()
	afraid.set_feeling(Devotion.YOU, "fear", 0.9)
	assert_gt(_puppet(afraid).tint().r, calm_tint.r, "dread raises the red channel")
	var faithful := _gnome()
	faithful.set_feeling(Devotion.YOU, "faith", 0.9)
	var gilded := _puppet(faithful).tint()
	assert_gt(gilded.g, calm_tint.g, "faith warms toward gold (green channel up)")
	assert_lt(gilded.b, calm_tint.b, "…and away from blue")


func test_the_body_carries_a_warm_rim():
	var puppet := _puppet(_gnome())
	var material := puppet.body.material_override as StandardMaterial3D
	assert_true(material.rim_enabled, "figures take a rim so they read on dark [§R-art]")
	assert_almost_eq(material.rim, StageLighting.FIGURE_RIM_STRENGTH, 0.001, "rim strength 0.4")


func test_only_the_holy_wear_a_halo():
	var ordinary := _puppet(_gnome())
	assert_false(ordinary.halo.visible, "an ordinary gnome has no nimbus")
	var prophet_gnome := _gnome()
	prophet_gnome.prophet = {"message": {"flavor": "mercy"}}
	assert_true(_puppet(prophet_gnome).halo.visible, "a prophet is haloed")
	var notable := _gnome()
	notable.notability = GnomePuppet.HALO_NOTABILITY
	assert_true(_puppet(notable).halo.visible, "a notable figure is haloed")


func test_terrain_bands_run_lapis_to_gold():
	assert_eq(WorldView.terrain_color(0.0), Palette.COLORS[1], "lowlands are lapis")
	assert_eq(WorldView.terrain_color(0.5), Palette.COLORS[5], "mid-slopes green")
	assert_eq(WorldView.terrain_color(1.0), Palette.COLORS[8], "peaks are gold")


func test_terrain_material_is_vertex_colored():
	var view := WorldView.new()
	add_child_autofree(view)
	var material := view.mesh_instance.material_override as StandardMaterial3D
	assert_not_null(material, "the terrain carries a material")
	assert_true(material.vertex_color_use_as_albedo, "palette bands ride vertex colors")
