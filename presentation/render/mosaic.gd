class_name Mosaic
extends RefCounted
## R1.3 [rav §R-art]: builds the mosaic post-process ShaderMaterial that rides
## on the pixel stage's screen — palette-map + tessera grout + gold-leaf mask.
## The numbers here are §R-art's; the palette comes from Palette (single source
## of truth). GPU-exact behaviour is judged at Playtest Gate A (headless uses a
## dummy rasterizer with no pixel readback); this layer's tests gate the
## spec-wiring. Presentation-only.

const SHADER_PATH := "res://presentation/render/mosaic.gdshader"

# R5.3 [leg §L-relief]: grout pitch 3 (was §R-art's 4) — finer tesserae over the
# higher internal resolution. Tuned at Gate A2.
const GROUT_PX := 3.0
const GROUT_ALPHA := 0.35
const JITTER := 0.06
const DITHER_STRENGTH := 0.5
const GOLD_LIFT := 0.25
const INTERNAL_SIZE := Vector2(PixelStage.INTERNAL_WIDTH, PixelStage.INTERNAL_HEIGHT)


static func make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter("palette_lut", Palette.lut_texture())
	material.set_shader_parameter("internal_size", INTERNAL_SIZE)
	material.set_shader_parameter("grout_px", GROUT_PX)
	material.set_shader_parameter("grout_color", Palette.COLORS[Palette.GROUT])
	material.set_shader_parameter("grout_alpha", GROUT_ALPHA)
	material.set_shader_parameter("jitter", JITTER)
	material.set_shader_parameter("dither_strength", DITHER_STRENGTH)
	material.set_shader_parameter("gold_lift", GOLD_LIFT)
	return material


## CPU mirror of the shader's palette-map — used by motifs/masks (R1.6) and
## tests, guaranteeing the same quantization the GPU applies.
static func quantize(color: Color) -> Color:
	return Palette.nearest(color)
