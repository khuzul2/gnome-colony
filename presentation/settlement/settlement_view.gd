class_name SettlementView
extends Node3D
## R3.2 [rav §R-build] — settlements on stage: for each live Settlement, a cluster
## of mosaic building props (R3.1) reflecting its structure stock, scattered
## deterministically around its basin (golden-angle sunflower packing by structure
## index — the sim has no per-building coords, so this is a stable presentation
## function of the structures, NO Rng). Props sit on the local relief. Reads the
## sim fold READ-ONLY; RunView refreshes it. Rebuilds a cluster only when its
## structure signature changes (no per-frame churn). Lives in the pixel stage so
## the props render through the mosaic. Presentation-only.

const SCATTER_ANGLE := 2.399054  ## the golden angle (radians)
const SCATTER_STEP := 1.1  ## world units per √index — packs denser as it grows

var _clusters := {}  ## sid → Node3D cluster
var _signatures := {}  ## sid → structure signature string


## Rebuild the on-stage clusters from the live settlements. `height_of` maps a
## world Vector2 → ground height so props sit on the relief; `place_of` maps
## sid → place id, `positions` maps place → world Vector3 (basin centre).
func refresh(
	settlements: Dictionary, place_of: Dictionary, positions: Dictionary, height_of: Callable
) -> void:
	for sid in _clusters.keys():
		var gone: bool = not settlements.has(sid) or settlements[sid].pop() <= 0.0
		if gone:
			_clusters[sid].queue_free()
			_clusters.erase(sid)
			_signatures.erase(sid)
	for sid in settlements:
		var s: Settlement = settlements[sid]
		var place: String = place_of.get(sid, "")
		if s.pop() <= 0.0 or not positions.has(place):
			continue
		var sig := _signature(s)
		if _signatures.get(sid, "") == sig:
			continue  # structures unchanged — leave the cluster as-is
		_signatures[sid] = sig
		if _clusters.has(sid):
			_clusters[sid].queue_free()
			_clusters.erase(sid)
		var cluster := _build_cluster(s, positions[place], height_of)
		add_child(cluster)
		_clusters[sid] = cluster


## A stable signature of the structure stock — the cluster rebuilds when it moves.
func _signature(s: Settlement) -> String:
	var parts := PackedStringArray()
	for id in Settlement.BUILDING_IDS:
		parts.append("%d" % int(round(s.structure_count(id))))
	return ",".join(parts)


func _build_cluster(s: Settlement, center: Vector3, height_of: Callable) -> Node3D:
	var root := Node3D.new()
	root.position = center
	var index := 0
	for id in Settlement.BUILDING_IDS:
		for _n in int(round(s.structure_count(id))):
			var prop := Props.build(id)
			if prop == null:
				continue
			var angle := index * SCATTER_ANGLE
			var radius := SCATTER_STEP * sqrt(float(index) + 0.5)
			var local_x := cos(angle) * radius
			var local_z := sin(angle) * radius
			var ground: float = height_of.call(Vector2(center.x + local_x, center.z + local_z))
			prop.position = Vector3(local_x, ground - center.y, local_z)
			root.add_child(prop)
			index += 1
	return root


func has_cluster(sid: int) -> bool:
	return _clusters.has(sid)


func cluster_prop_count(sid: int) -> int:
	return _clusters[sid].get_child_count() if _clusters.has(sid) else 0
