shader_type canvas_item;
// R1.3 [rav §R-art] — the mosaic post-process over the low-res stage:
//   (1) palette-map each pixel to the nearest of the 16 tesserae (with a
//       small ordered-dither nudge toward the 2 nearest),
//   (2) lay a tessera "grout" grid (dark lines on the grout_px lattice, with
//       a per-cell value jitter so flats read as laid stone),
//   (3) lift luminance where the blessed/high-devotion mask marks holy
//       ground (gold-leaf shine). Presentation-only.

uniform sampler2D palette_lut : filter_nearest;
uniform vec2 internal_size = vec2(384.0, 216.0);
uniform float grout_px = 4.0;
uniform vec4 grout_color : source_color = vec4(0.031, 0.039, 0.071, 1.0);
uniform float grout_alpha = 0.35;
uniform float jitter = 0.06;
uniform float dither_strength = 0.5;
uniform float gold_lift = 0.25;
// R1.6 feeds this; unset defaults to black → no lift.
uniform sampler2D bless_mask : hint_default_black;

const int PALETTE_SIZE = 16;

// Cheap per-cell hash for the tessera value jitter.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 4x4 Bayer ordered-dither threshold in [0,1).
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	// Standard 4x4 Bayer matrix / 16.
	float m[16] = {
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	};
	return m[i] / 16.0;
}

vec3 palette_map(vec3 c) {
	float best = 1e9;
	vec3 best_c = c;
	for (int i = 0; i < PALETTE_SIZE; i++) {
		vec3 e = texelFetch(palette_lut, ivec2(i, 0), 0).rgb;
		vec3 d = c - e;
		float dist = dot(d, d);
		if (dist < best) {
			best = dist;
			best_c = e;
		}
	}
	return best_c;
}

void fragment() {
	vec2 px = UV * internal_size;
	vec2 cell = floor(px / grout_px);

	vec3 col = texture(TEXTURE, UV).rgb;
	// Per-tessera value jitter (hashed by cell) so a flat field reads as stone.
	col += (hash12(cell) - 0.5) * 2.0 * jitter;
	// Ordered dither nudge toward a neighboring palette entry.
	col += (bayer4(cell) - 0.5) * dither_strength * 0.08;

	vec3 q = palette_map(clamp(col, 0.0, 1.0));

	// Gold-leaf accent on sanctified ground.
	float bless = texture(bless_mask, UV).r;
	q = clamp(q + bless * gold_lift, 0.0, 1.0);

	// Grout: darken the tessera edges (a band grout_px-wide lattice).
	vec2 f = fract(px / grout_px);
	float edge = 1.0 / grout_px;
	float line = clamp(step(f.x, edge) + step(f.y, edge), 0.0, 1.0);
	vec3 outc = mix(q, grout_color.rgb, line * grout_alpha);

	COLOR = vec4(outc, 1.0);
}
