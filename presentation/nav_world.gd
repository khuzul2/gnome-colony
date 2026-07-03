class_name NavWorld
extends Node3D
## Navigation for the quickened [plan T13.3]: bakes a NavigationMesh
## from the WorldView's terrain onto a server-side map (explicit RIDs —
## reliable headless and under tests, no node-lifecycle sync races),
## places sites at world positions, and routes materialized puppets
## with NavigationAgent3D bound to that map. The sim's abstract truth
## outranks geometry: a leg whose named path is buried
## (WorldState.paths, T7.3) is refused before the navmesh is asked.
## Agent radius/height/cell sizes are presentation numbers.

const CELL_SIZE := 0.5
const CELL_HEIGHT := 0.25

var site_positions := {}
## The last baked mesh, kept for introspection/tests.
var last_navigation_mesh: NavigationMesh

var _map: RID
var _region: RID
var _world: WorldState


func _ready() -> void:
	_map = NavigationServer3D.map_create()
	# The map's voxel cells must MATCH the baked mesh's cells or the
	# server silently rejects the region's polygons.
	NavigationServer3D.map_set_cell_size(_map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(_map, CELL_HEIGHT)
	# Synchronous iterations: 4.7's async map builds never land headless
	# (found by probe), and a handful of basins needs no async anyway.
	NavigationServer3D.map_set_use_async_iterations(_map, false)
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_enabled(_region, true)
	NavigationServer3D.region_set_map(_region, _map)


func _exit_tree() -> void:
	NavigationServer3D.free_rid(_region)
	NavigationServer3D.free_rid(_map)


## Bake walkable geometry from the skin's mesh (synchronous; call after
## view.sync — re-bake on reshape the same way).
func bake(view: WorldView) -> void:
	var nav_mesh := NavigationMesh.new()
	# Whole multiples of the cell sizes, so the voxelizer doesn't round.
	nav_mesh.cell_size = CELL_SIZE
	nav_mesh.cell_height = CELL_HEIGHT
	# Binary-exact multiples of the cells, so the voxelizer never rounds
	# (0.3-style decimals trip float precision and spam warnings).
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.25
	nav_mesh.agent_max_climb = 0.75
	var source := NavigationMeshSourceGeometryData3D.new()
	# Raw CPU faces from the skin — never re-read GPU mesh data at runtime.
	source.add_faces(view.walkable_faces, Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	last_navigation_mesh = nav_mesh
	NavigationServer3D.region_set_navigation_mesh(_region, nav_mesh)
	NavigationServer3D.map_force_update(_map)


## The sim world whose paths dictionary gates travel.
func attach(world: WorldState) -> void:
	_world = world


func place_site(site_id: String, position_3d: Vector3) -> void:
	site_positions[site_id] = position_3d


## A walkable route between two sites — empty when either end's named
## path is buried (the sim's verdict) or the navmesh finds no way.
func path_between(a_site: String, b_site: String) -> PackedVector3Array:
	if _leg_buried(a_site) or _leg_buried(b_site):
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(
		_map, site_positions[a_site], site_positions[b_site], true
	)


## Give a materialized puppet an agent (once) and send it to a site.
func route(puppet: GnomePuppet, to_site: String) -> void:
	if puppet.agent == null:
		puppet.agent = NavigationAgent3D.new()
		puppet.add_child(puppet.agent)
		puppet.agent.set_navigation_map(_map)
	puppet.agent.target_position = site_positions[to_site]


func _leg_buried(site_id: String) -> bool:
	if _world == null:
		return false
	return _world.paths.get("%s_path" % site_id, true) == false
