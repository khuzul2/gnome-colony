class_name WorldView
extends Node3D
## The heightmap skin [plan T13.1, design §2.7b]: bakes a mesh from the
## sim's RegionGraph and re-bakes when the graph's version moves. The
## height field is inverse-distance-weighted region elevation on a grid —
## a skin the sim never knows exists (presentation reads sim, never the
## reverse). GRID/EXTENT are render resolution: graphics, not sim.

const GRID := 24
const EXTENT_KM := 14.0

## R5.1 [leg §L-relief] — the raw region elevations (≈1–3 units) are ~0.1% of the
## 28 km plane, so the terrain read flat at Gate A. Normalize the baked height to
## a legible vertical relief and clamp sub-sea ground to a flat water plane, so the
## ground reads as literal 3-D in the mosaic style. Both tuned at Gate A2.
const RELIEF_KM := 2.6  ## peak-to-trough vertical span (≈9% of the 28 km plane)
const SEA_LEVEL_T := 0.15  ## normalized heights below this clamp up to the sea plane

var mesh_instance := MeshInstance3D.new()
var baked_version := -1
## The raw walkable triangles of the last bake (CPU-side) — NavWorld
## bakes its navmesh from these instead of re-reading GPU mesh data.
var walkable_faces := PackedVector3Array()

var _graph: RegionGraph
## Elevation bounds of the last bake — normalize raw IDW height into the relief
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


## Lazy re-bake: only when the graph's version moved since the last bake.
func sync(graph: RegionGraph) -> void:
	_graph = graph
	if graph.version == baked_version:
		return
	_bake()
	baked_version = graph.version


## Raw IDW elevation over the basins (pre-relief) — the source field the
## normalized skin height is mapped from.
func _raw_height(point: Vector2) -> float:
	var weight_sum := 0.0
	var height := 0.0
	for region in _graph.regions:
		var d2: float = maxf(0.01, point.distance_squared_to(region["center"]))
		var w := 1.0 / d2
		weight_sum += w
		height += w * region["elevation"]
	return height / weight_sum if weight_sum > 0.0 else 0.0


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
	for gz in GRID:
		for gx in GRID:
			var x0 := -EXTENT_KM + gx * step
			var z0 := -EXTENT_KM + gz * step
			var corners := [
				Vector2(x0, z0),
				Vector2(x0 + step, z0),
				Vector2(x0 + step, z0 + step),
				Vector2(x0, z0 + step),
			]
			# Relief-mapped height + its palette band per corner [R5.1, leg §L-relief].
			var verts := []
			var bands := []
			for c in corners:
				var t := _relief_t(c)
				bands.append(t)
				verts.append(Vector3(c.x, _relief_y(t), c.y))
			for index in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = verts[index]
				st.set_color(terrain_color(bands[index]))
				st.add_vertex(v)
				walkable_faces.append(v)
	st.generate_normals()
	mesh_instance.mesh = st.commit()
