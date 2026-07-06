class_name WorldView
extends Node3D
## The heightmap skin [plan T13.1, design §2.7b]: bakes a mesh from the
## sim's RegionGraph and re-bakes when the graph's version moves. The
## height field is inverse-distance-weighted region elevation on a grid —
## a skin the sim never knows exists (presentation reads sim, never the
## reverse). GRID/EXTENT are render resolution: graphics, not sim.

## G2.2 [gaea §gaea-gen]: 64² tessellation — fine enough to show the Gaea sub-basin
## detail (the old 24² was too coarse). walkable_faces scale with it (GRID²·6). NOTE the
## step (28/64 ≈ 0.4375 km) does NOT divide NavWorld.CELL_SIZE (0.5) as §gaea-gen's prose
## cautions, but the voxelizer rasterizes the terrain triangles at CELL_SIZE regardless —
## the binding constraint is map cell_size == navmesh cell_size (both 0.5, satisfied) — so
## routes are still found (test_nav_world/test_movement/test_phase13). PERF: this bake
## measures ~65-69 ms, over BAKE_BUDGET_MS 50 — G4.2 owns bringing it under budget.
const GRID := 64
const EXTENT_KM := 14.0

## R5.1 [leg §L-relief] — the raw region elevations (≈1–3 units) are ~0.1% of the
## 28 km plane, so the terrain read flat at Gate A. Normalize the baked height to
## a legible vertical relief and clamp sub-sea ground to a flat water plane, so the
## ground reads as literal 3-D in the mosaic style. Both tuned at Gate A2.
const RELIEF_KM := 2.6  ## peak-to-trough vertical span (≈9% of the 28 km plane)
const SEA_LEVEL_T := 0.15  ## normalized heights below this clamp up to the sea plane
## R5.3 [leg §L-relief]: darken a tessera by up to this fraction of its face slope
## (0 flat → 1 vertical) — the tesserae equivalent of an ambient-occlusion crease,
## so hillsides read dimensional. The shader then quantizes toward a darker palette
## entry. Tuned at Gate A2.
const SLOPE_SHADE := 0.28
## G3.1 [gaea §gaea-gen] — biome-varied palette bands (5 elevation bands per biome), COMPOSED
## with the elevation banding, every entry one of the 16 Palette.COLORS (mosaic discipline).
## meadow == the base terrain_color (neutral, so Uniform-variety worlds are unchanged); forest
## skews uplands greener, ridge ochre/gold, marsh wet-verdigris; the lowest band is always
## lapis (water). Presentation numbers, tunable at Gate G.
const BIOME_BANDS := {
	"meadow": [1, 4, 5, 9, 8],
	"forest": [1, 4, 5, 5, 8],
	"ridge": [1, 9, 9, 6, 8],
	"marsh": [1, 3, 4, 4, 9],
}

var mesh_instance := MeshInstance3D.new()
var baked_version := -1
## The raw walkable triangles of the last bake (CPU-side) — NavWorld
## bakes its navmesh from these instead of re-reading GPU mesh data.
var walkable_faces := PackedVector3Array()

var _graph: RegionGraph
## G2.1 [gaea §gaea-gen]: the Gaea-detailed height source. _raw_height delegates to it
## so the baked skin, height_at, and walkable_faces all read the same anchored field
## (basin field + attenuated Gaea detail). Built in sync() from WorldConfig.seed.
var _field: TerrainField
var _seed := 0
## Elevation bounds of the last bake — normalize the raw height into the relief
## envelope so height_at (picking/nav) agrees with the baked mesh.
var _min_e := 0.0
var _span := 1.0
## R1.5 — a matte, vertex-colored terrain material (palette bands by
## elevation), so the ground reads as tesserae through the mosaic pass.
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	mesh_instance.material_override = _material
	add_child(mesh_instance)


## R1.5 [rav §R-art] — elevation → palette band: lapis lowlands/water, sage
## and pale-green mid-slopes, ochre uplands, gold peaks. Pure; unit-tested.
static func terrain_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t < 0.20:
		return Palette.COLORS[1]  # deep-lapis (low ground / water)
	if t < 0.45:
		return Palette.COLORS[4]  # sage-green
	if t < 0.70:
		return Palette.COLORS[5]  # pale-green
	if t < 0.88:
		return Palette.COLORS[9]  # ochre
	return Palette.COLORS[8]  # gold-lit peaks


## G3.1 — elevation → band index (0 water … 4 peak), the SAME thresholds terrain_color uses;
## shared by the biome bands (BIOME_BANDS) so meadow reproduces terrain_color exactly.
static func _band_index(t: float) -> int:
	t = clampf(t, 0.0, 1.0)
	if t < 0.20:
		return 0
	if t < 0.45:
		return 1
	if t < 0.70:
		return 2
	if t < 0.88:
		return 3
	return 4


## G3.1 [gaea §gaea-gen] — the biome-biased band colour for a normalized elevation; unknown
## biomes fall back to the neutral meadow bands. Always a Palette.COLORS entry.
static func terrain_color_biomed(t: float, biome: String) -> Color:
	var bands: Array = BIOME_BANDS.get(biome, BIOME_BANDS["meadow"])
	return Palette.COLORS[bands[_band_index(t)]]


## R5.3 [leg §L-relief] — darken a tessera color by its face slope (0 flat, 1
## vertical) up to SLOPE_SHADE, so relief reads as laid, lit stone. Pure; tested.
static func slope_shade(color: Color, slope: float) -> Color:
	var f := 1.0 - SLOPE_SHADE * clampf(slope, 0.0, 1.0)
	return Color(color.r * f, color.g * f, color.b * f, color.a)


## Lazy re-bake: rebuild the Gaea field + mesh only when the graph's version moved or
## the seed changed. `seed` is WorldConfig.seed (default 0 keeps bare-graph test callers
## working); a reshape bumps graph.version so the field regenerates on the new elevations.
func sync(graph: RegionGraph, world_seed := 0) -> void:
	_graph = graph
	if graph.version == baked_version and _field != null and world_seed == _seed:
		return
	_seed = world_seed
	_field = TerrainField.new()
	_field.generate(graph, world_seed)
	_bake()
	baked_version = graph.version


## The anchored raw height (pre-relief) — the basin field plus attenuated Gaea detail
## [gaea §gaea-anchor], the source field the normalized skin height is mapped from. Same
## units and (at basin centers) the same values as the old IDW, so relief/picking agree.
func _raw_height(point: Vector2) -> float:
	return _field.raw_height(point)


## R5.1 [leg §L-relief] — normalized elevation of a point in [0,1] over the bake's
## elevation bounds; drives both the vertex height and the palette band.
func _relief_t(point: Vector2) -> float:
	return clampf((_raw_height(point) - _min_e) / _span, 0.0, 1.0)


## R5.1 [leg §L-relief] — normalized elevation → mesh height: amplified to the
## relief envelope, with sub-sea ground clamped up to the flat water plane.
static func _relief_y(t: float) -> float:
	return RELIEF_KM * maxf(t, SEA_LEVEL_T)


## Skin height at a world-plane point — the relief-mapped mesh height (the SAME
## field the mesh is baked from, so picking / nav / puppet placement agree).
func height_at(point: Vector2) -> float:
	return _relief_y(_relief_t(point))


## G3.1 — the biome of the basin nearest a world point (Voronoi): the skin tints its bands
## by which region's country the ground sits in. Read-only over the sim's RegionGraph.
## (O(regions) per call — folded into the bake's per-corner scan; G4.2 owns bake perf.)
func _biome_at(point: Vector2) -> String:
	var nearest := ""
	var best := INF
	for region in _graph.regions:
		var d2: float = point.distance_squared_to(region["center"])
		if d2 < best:
			best = d2
			nearest = region["biome"]
	return nearest


func _bake() -> void:
	# Elevation bounds normalize the raw IDW height into the relief envelope; the
	# same bounds drive the palette bands, so terraces and geometry agree [R5.1].
	var min_e := INF
	var max_e := -INF
	for region in _graph.regions:
		min_e = minf(min_e, region["elevation"])
		max_e = maxf(max_e, region["elevation"])
	_min_e = min_e
	_span = maxf(0.001, max_e - min_e)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	walkable_faces = PackedVector3Array()
	var step := 2.0 * EXTENT_KM / GRID
	# G4.2 [gaea §gaea-gen] — sample each UNIQUE grid vertex once. Adjacent quads share ~3/4 of
	# their corners, and the per-corner height (_relief_t → idw + Gaea detail) and biome scan are
	# the bake's dominant cost, so caching the (GRID+1)² grid points cuts that ~4× (was ~80 ms,
	# now well under BAKE_BUDGET_MS). Behavior-preserving: each vertex is built from the SAME
	# point its height was sampled at, so height_at still agrees with the mesh; the full suite +
	# test_walkable_faces_agree_with_height_at confirm the geometry is unchanged.
	var pts := GRID + 1
	var pos := []
	var vy := []
	var col := []
	pos.resize(pts * pts)
	vy.resize(pts * pts)
	col.resize(pts * pts)
	for iz in pts:
		for ix in pts:
			var p := Vector2(-EXTENT_KM + ix * step, -EXTENT_KM + iz * step)
			var t := _relief_t(p)
			var idx := iz * pts + ix
			pos[idx] = p
			vy[idx] = _relief_y(t)
			col[idx] = terrain_color_biomed(t, _biome_at(p))
	for gz in GRID:
		for gx in GRID:
			# The quad's four corner grid indices: (gx,gz) (gx+1,gz) (gx+1,gz+1) (gx,gz+1).
			var ci := [
				gz * pts + gx,
				gz * pts + gx + 1,
				(gz + 1) * pts + gx + 1,
				(gz + 1) * pts + gx,
			]
			var verts := [
				Vector3(pos[ci[0]].x, vy[ci[0]], pos[ci[0]].y),
				Vector3(pos[ci[1]].x, vy[ci[1]], pos[ci[1]].y),
				Vector3(pos[ci[2]].x, vy[ci[2]], pos[ci[2]].y),
				Vector3(pos[ci[3]].x, vy[ci[3]], pos[ci[3]].y),
			]
			# Two triangles per quad; each is slope-shaded by its own face normal so
			# relief reads dimensional in the tesserae [R5.3, leg §L-relief].
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = verts[tri[0]]
				var b: Vector3 = verts[tri[1]]
				var c2: Vector3 = verts[tri[2]]
				var face_normal := (b - a).cross(c2 - a).normalized()
				var slope := 1.0 - absf(face_normal.y)
				for index in tri:
					st.set_color(slope_shade(col[ci[index]], slope))
					st.add_vertex(verts[index])
					walkable_faces.append(verts[index])
	st.generate_normals()
	mesh_instance.mesh = st.commit()
