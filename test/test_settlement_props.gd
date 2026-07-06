extends GutTest

## R3.1 [rav §R-build] — the building prop library: a simple low-poly mosaic prop
## per structure id, procedurally built (no binary .tscn), the basilica bearing the
## sacred monogram. Every id has a prop, and it loads headless.


func test_every_building_id_has_a_prop():
	for id in Settlement.BUILDING_IDS:
		var prop := Props.build(id)
		assert_not_null(prop, "a prop for '%s'" % id)
		if prop != null:
			assert_true(prop is Node3D, "…a Node3D [rendered through the stage]")
			assert_gt(prop.get_child_count(), 0, "…with geometry")
			prop.free()


func test_an_unknown_id_has_no_prop():
	assert_null(Props.build("zeppelin_hangar"), "an unknown structure yields no prop")


func test_the_basilica_bears_the_monogram():
	var basilica := Props.build("basilica")
	add_child_autofree(basilica)
	var mono := basilica.find_child("monogram", true, false)
	assert_not_null(mono, "the basilica wears the sacred monogram on its pediment [rav §R-art]")
	var mat := (mono as MeshInstance3D).material_override as StandardMaterial3D
	assert_not_null(mat.albedo_texture, "…as a textured billboard")


func test_a_plain_prop_carries_no_monogram():
	var dwelling := Props.build("dwelling")
	add_child_autofree(dwelling)
	assert_null(dwelling.find_child("monogram", true, false), "only the basilica is marked")
