class_name Motifs
extends RefCounted
## R1.6 [rav §R-art] — the Ravenna decorative vocabulary as placeable markers:
## a gold sacred medallion (a Chi-Rho-like monogram, the gnomes' OWN mark of
## the unseen will — late-antique Christian in style) laid over BLESSED ground,
## a red tessera ring over CURSED ground. Colors come from Palette; the
## monogram is drawn procedurally so no binary asset is needed. The mosaic
## shader quantizes it on screen and the gold blooms as leaf (the "gold-leaf
## accent" is realized by this geometry + StageLighting's bloom; the shader's
## screen-space bless_mask stays available for a future full-screen pass).
## Presentation-only.

const BLESSED := "blessed"
const CURSED := "cursed"


## The tessera-border color for a belief tag (transparent = no marker).
static func border_color(kind: String) -> Color:
	match kind:
		BLESSED:
			return Palette.COLORS[Palette.GOLD]
		CURSED:
			return Palette.COLORS[10]  # terracotta
	return Color(0.0, 0.0, 0.0, 0.0)


## A Chi-Rho-like gold monogram on transparent — the gnomes' mark of the unseen
## will. Drawn procedurally (a rho staff, a chi cross, a loop head).
static func monogram_image(px: int = 32) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var gold := Palette.COLORS[Palette.GOLD_LIT]
	var c := px / 2
	for i in px:
		_plot(img, c, i, gold)  # the vertical staff (rho)
		_plot(img, i, i, gold)  # the chi diagonal ↘
		_plot(img, i, px - 1 - i, gold)  # the chi diagonal ↙
	# A small loop head near the top of the staff (the rho's bowl).
	var head := int(px * 0.28)
	for a in 12:
		var ang := TAU * float(a) / 12.0
		_plot(img, c + int(round(cos(ang) * 3.0)), head + int(round(sin(ang) * 3.0)), gold)
	return img


## A ground marker for a tagged place: a flat ring in the tag's color, plus
## (blessed only) a billboard monogram above it. null for an untagged kind.
static func build_place_medallion(kind: String) -> Node3D:
	var col := border_color(kind)
	if col.a <= 0.0:
		return null
	var root := Node3D.new()
	var ring := MeshInstance3D.new()
	ring.name = "ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.2
	torus.outer_radius = 1.5
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)  # lie flat on the ground
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	ring.material_override = mat
	root.add_child(ring)
	if kind == BLESSED:
		var mono := MeshInstance3D.new()
		mono.name = "monogram"
		var quad := QuadMesh.new()
		quad.size = Vector2(1.4, 1.4)
		mono.mesh = quad
		var mmat := StandardMaterial3D.new()
		mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mmat.albedo_texture = ImageTexture.create_from_image(monogram_image())
		mono.material_override = mmat
		mono.position = Vector3(0.0, 1.2, 0.0)
		root.add_child(mono)
	return root


## The active belief marker for a place's tag map: blessed wins over cursed
## (reverence reads over dread), "" when neither is present.
static func kind_for(tags: Dictionary) -> String:
	if tags.get(BLESSED, 0.0) > 0.0:
		return BLESSED
	if tags.get(CURSED, 0.0) > 0.0:
		return CURSED
	return ""


static func _plot(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, col)
