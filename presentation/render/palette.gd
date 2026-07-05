class_name Palette
extends RefCounted
## R1.1 [rav §R-art]: the 16 Ravenna tesserae colors (Galla Placidia range)
## and the 16×1 LUT texture built from them. The COLORS array is the single
## source of truth — the LUT, the mosaic shader's palette-map, and the motif
## borders all read from it, so there is no second place a hex can drift.
## Presentation-only styling; the sim never sees any of this.

## Index → color, matching §R-art's table order (0 = deepest ground/shadow,
## 15 = grout/outline). Order is STABLE: the shader indexes by position.
const COLORS: Array[Color] = [
	Color("0d1b3e"),  # 0  night-lapis   — vault ground / deepest shadow
	Color("14285a"),  # 1  deep-lapis    — sky / water body
	Color("245a8c"),  # 2  mid-blue      — water highlight / mid ground
	Color("2f6d5f"),  # 3  verdigris     — foliage shadow / border scroll
	Color("5a8f6b"),  # 4  sage-green    — grass / field
	Color("9dc08b"),  # 5  pale-green    — lit grass / young crop
	Color("a97b18"),  # 6  gold-deep     — gold-leaf shadow
	Color("d6a53a"),  # 7  gold          — gold tesserae / halo / roof
	Color("f2d488"),  # 8  gold-lit      — gold highlight / shine
	Color("b07636"),  # 9  ochre         — earth / warm stone
	Color("a2432c"),  # 10 terracotta    — roof-tile / cursed border
	Color("5e1f1c"),  # 11 oxblood       — deep red accent / blood-omen
	Color("e8ddc4"),  # 12 cream         — robe / marble base
	Color("f5efe0"),  # 13 bone-white    — highlight / star
	Color("3a4152"),  # 14 slate-grey    — grout mid / cool stone
	Color("080a12"),  # 15 near-black    — grout / outline
]

## Named indices the render code references by role (readability only).
const NIGHT_LAPIS := 0
const GOLD := 7
const GOLD_LIT := 8
const TERRACOTTA := 10
const CREAM := 12
const BONE_WHITE := 13
const SLATE_GREY := 14
const GROUT := 15


## The palette as a 16×1 RGBA8 image — the shader samples this as its LUT.
static func lut_image() -> Image:
	var img := Image.create(COLORS.size(), 1, false, Image.FORMAT_RGBA8)
	for i in COLORS.size():
		img.set_pixel(i, 0, COLORS[i])
	return img


static func lut_texture() -> ImageTexture:
	return ImageTexture.create_from_image(lut_image())


## The nearest palette entry to an arbitrary color, by squared RGB distance —
## the CPU mirror of the shader's palette-map (used by motifs/masks and tests).
static func nearest(c: Color) -> Color:
	var best := COLORS[0]
	var best_d2 := INF
	for entry in COLORS:
		var dr := c.r - entry.r
		var dg := c.g - entry.g
		var db := c.b - entry.b
		var d2 := dr * dr + dg * dg + db * db
		if d2 < best_d2:
			best_d2 = d2
			best = entry
	return best
