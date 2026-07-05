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

## R1.5 [rav §R-art] — a gnome is holy (gets a halo) when it is a prophet or
## has reached the §14 notability promotion line.
const HALO_NOTABILITY := 0.6

var data: GnomeData
var body := MeshInstance3D.new()
## NavigationAgent3D, attached by NavWorld.route on first routing (T13.3).
var agent: NavigationAgent3D
## R1.5 — the gold nimbus behind a holy figure (prophet / high notability).
var halo := MeshInstance3D.new()

var _material := StandardMaterial3D.new()
var _halo_material := StandardMaterial3D.new()


func _ready() -> void:
	body.mesh = CapsuleMesh.new()
	# R1.5 — a matte body with a warm rim, so figures read luminous on the
	# dark ground (the mosaic idiom); the mosaic shader quantizes on screen.
	_material.roughness = 1.0
	_material.rim_enabled = true
	_material.rim = StageLighting.FIGURE_RIM_STRENGTH
	body.material_override = _material
	add_child(body)
	# R1.5 — a gold billboard disc read as a nimbus through the mosaic pass.
	halo.mesh = QuadMesh.new()
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_material.albedo_color = Palette.COLORS[Palette.GOLD_LIT]
	_halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.material_override = _halo_material
	halo.position = Vector3(0.0, 1.1, 0.0)
	halo.visible = false
	add_child(halo)


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
	# R1.5 — Ravenna tones: a warm cream base pulls toward gold with faith and
	# toward oxblood-red with dread (fear still raises the red channel, read at
	# a glance, same direction as the slice).
	_material.albedo_color = Color(
		0.62 + 0.30 * fear + 0.10 * faith,
		0.55 + 0.30 * faith - 0.25 * fear,
		0.42 - 0.20 * fear - 0.10 * faith
	)
	halo.visible = is_holy()


## A prophet or a figure past the notability promotion line wears a nimbus.
func is_holy() -> bool:
	return not data.prophet.is_empty() or data.notability >= HALO_NOTABILITY


func tint() -> Color:
	return _material.albedo_color
