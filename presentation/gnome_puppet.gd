class_name GnomePuppet
extends Node3D
## A gnome's body on stage [plan T13.2]: reads a GnomeData and renders
## it — scale by life stage, tint by feeling (the slice's mapping: red
## rises with dread, warm gold with faith), hidden when dead. The puppet
## only READS sim data; movement is driven by T13.3's navigation.
## Scale/tint numbers are presentation styling, not sim numbers.

const STAGE_SCALE := {
	Enums.LifeStage.INFANT: 0.35,
	Enums.LifeStage.CHILD: 0.55,
	Enums.LifeStage.ADOLESCENT: 0.8,
	Enums.LifeStage.ADULT: 1.0,
	Enums.LifeStage.ELDER: 0.9,
	Enums.LifeStage.DEAD: 1.0,
}

var data: GnomeData
var body := MeshInstance3D.new()
## NavigationAgent3D, attached by NavWorld.route on first routing (T13.3).
var agent: NavigationAgent3D

var _material := StandardMaterial3D.new()


func _ready() -> void:
	body.mesh = CapsuleMesh.new()
	body.material_override = _material
	add_child(body)


func bind(gnome: GnomeData) -> void:
	data = gnome
	refresh()


## Re-read the bound data — cheap enough to call every frame for the
## quickened few; the pool handles everyone else.
func refresh() -> void:
	if data == null or not data.is_alive():
		visible = false
		return
	visible = true
	scale = Vector3.ONE * STAGE_SCALE[data.stage]
	var fear: float = maxf(
		data.get_feeling(Devotion.YOU, "fear"), data.get_feeling(data.location, "fear")
	)
	var faith: float = data.get_feeling(Devotion.YOU, "faith")
	_material.albedo_color = Color(
		0.5 + 0.5 * fear, 0.5 + 0.4 * faith - 0.2 * fear, 0.62 - 0.3 * fear
	)


func tint() -> Color:
	return _material.albedo_color
