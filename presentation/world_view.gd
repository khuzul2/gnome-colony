class_name WorldView
extends Node3D
## The heightmap skin [plan T13.1, design §2.7b]: bakes a mesh from the
## sim's RegionGraph and re-bakes when the graph's version moves. The
## height field is inverse-distance-weighted region elevation on a grid —
## a skin the sim never knows exists (presentation reads sim, never the
## reverse). GRID/EXTENT are render resolution: graphics, not sim.

const GRID := 24
const EXTENT_KM := 14.0

var mesh_instance := MeshInstance3D.new()
var baked_version := -1
## The raw walkable triangles of the last bake (CPU-side) — NavWorld
## bakes its navmesh from these instead of re-reading GPU mesh data.
var walkable_faces := PackedVector3Array()

var _graph: RegionGraph


func _ready() -> void:
	add_child(mesh_instance)


## Lazy re-bake: only when the graph's version moved since the last bake.
func sync(graph: RegionGraph) -> void:
	_graph = graph
	if graph.version == baked_version:
		return
	_bake()
	baked_version = graph.version


## Skin height at a world-plane point — IDW over the basins (the same
## field the mesh is baked from, so tests and picking agree).
func height_at(point: Vector2) -> float:
	var weight_sum := 0.0
	var height := 0.0
	for region in _graph.regions:
		var d2: float = maxf(0.01, point.distance_squared_to(region["center"]))
		var w := 1.0 / d2
		weight_sum += w
		height += w * region["elevation"]
	return height / weight_sum if weight_sum > 0.0 else 0.0


func _bake() -> void:
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
			var verts := []
			for c in corners:
				verts.append(Vector3(c.x, height_at(c), c.y))
			for index in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(verts[index])
				walkable_faces.append(verts[index])
	st.generate_normals()
	mesh_instance.mesh = st.commit()
