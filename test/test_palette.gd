extends GutTest

## R1.1 [rav §R-art] — the 16 Ravenna tesserae colors and the LUT built from
## them. The palette is the single source of truth for the mosaic render, so
## its size, exact hexes, and LUT round-trip are gated. Presentation-only.

# RGBA8 round-trips at 1/255 resolution; compare within one quantum.
const CHANNEL_TOL := 1.0 / 255.0 + 0.0001


func _color_eq(a: Color, b: Color) -> bool:
	return (
		absf(a.r - b.r) <= CHANNEL_TOL
		and absf(a.g - b.g) <= CHANNEL_TOL
		and absf(a.b - b.b) <= CHANNEL_TOL
	)


func test_palette_has_16_colors():
	assert_eq(Palette.COLORS.size(), 16, "the palette is exactly 16 tesserae")


func test_key_hexes_match_spec():
	# A representative sample of §R-art's table — the anchors the shader/
	# lighting reference by name.
	assert_true(_color_eq(Palette.COLORS[0], Color("0d1b3e")), "0 night-lapis")
	assert_true(_color_eq(Palette.COLORS[7], Color("d6a53a")), "7 gold")
	assert_true(_color_eq(Palette.COLORS[8], Color("f2d488")), "8 gold-lit")
	assert_true(_color_eq(Palette.COLORS[13], Color("f5efe0")), "13 bone-white")
	assert_true(_color_eq(Palette.COLORS[15], Color("080a12")), "15 near-black / grout")


func test_lut_image_is_16x1_and_matches_colors():
	var img := Palette.lut_image()
	assert_eq(img.get_width(), 16, "LUT is 16 wide")
	assert_eq(img.get_height(), 1, "LUT is 1 tall")
	for i in Palette.COLORS.size():
		assert_true(_color_eq(img.get_pixel(i, 0), Palette.COLORS[i]), "LUT pixel %d matches" % i)


func test_lut_texture_builds():
	var tex := Palette.lut_texture()
	assert_not_null(tex, "LUT texture builds")
	assert_eq(tex.get_width(), 16, "LUT texture 16 wide")


func test_nearest_snaps_to_palette():
	# A color a hair off gold-lit must snap to gold-lit; an exact entry
	# returns itself.
	var near_gold := Color("f2d488").lerp(Color.WHITE, 0.03)
	assert_true(_color_eq(Palette.nearest(near_gold), Palette.COLORS[8]), "snaps to nearest entry")
	assert_true(
		_color_eq(Palette.nearest(Palette.COLORS[3]), Palette.COLORS[3]), "exact entry fixed"
	)
