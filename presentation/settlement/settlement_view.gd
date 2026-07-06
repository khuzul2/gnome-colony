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
## R3.3 [rav §R-build] — a newly-built structure grows in over this long, so
## development READS as it happens rather than popping full-size.
const GROW_SECONDS := 0.6
## R3.3 — the civ-map tier medallion glyph: rosette (village), star (town), the
## sacred monogram (city, the seat of a basilica). Hamlets wear none.
const TIER_MEDALLION := {
	Enums.SettlementTier.HAMLET: "",
	Enums.SettlementTier.VILLAGE: "❀",
	Enums.SettlementTier.TOWN: "✦",
	Enums.SettlementTier.CITY: "☩",
}
const MEDALLION_HEIGHT := 6.0

var _clusters := {}  ## sid → Node3D cluster
var _signatures := {}  ## sid → structure signature string
## R3.3 — sid → floating tier medallion (Label3D); prev prop count for growth;
## props currently scaling in [{node, t}].
var _medallions := {}
var _prev_count := {}
var _growing := []


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
			_prev_count.erase(sid)
			if _medallions.has(sid):
				_medallions[sid].queue_free()
				_medallions.erase(sid)
	for sid in settlements:
		var s: Settlement = settlements[sid]
		var place: String = place_of.get(sid, "")
		if s.pop() <= 0.0 or not positions.has(place):
			continue
		# The tier medallion tracks the tier every refresh (a tier can turn without
		# the structure stock moving) [R3.3].
		_update_medallion(sid, s.tier, positions[place])
		var sig := _signature(s)
		if _signatures.get(sid, "") == sig:
			continue  # structures unchanged — leave the cluster as-is
		_signatures[sid] = sig
		if _clusters.has(sid):
			_clusters[sid].queue_free()
			_clusters.erase(sid)
		var cluster := _build_cluster(s, positions[place], height_of, _prev_count.get(sid, 0))
		add_child(cluster)
		_clusters[sid] = cluster
		_prev_count[sid] = cluster.get_child_count()


## A stable signature of the structure stock — the cluster rebuilds when it moves.
func _signature(s: Settlement) -> String:
	var parts := PackedStringArray()
	for id in Settlement.BUILDING_IDS:
		parts.append("%d" % int(round(s.structure_count(id))))
	return ",".join(parts)


## `old_count` props existed before this rebuild; the rest are NEW and grow in.
func _build_cluster(s: Settlement, center: Vector3, height_of: Callable, old_count: int) -> Node3D:
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
			# R3.3: a structure raised this refresh grows in rather than popping.
			if index >= old_count:
				prop.scale = Vector3.ONE * 0.05
				_growing.append({"node": prop, "t": 0.0})
			root.add_child(prop)
			index += 1
	return root


## R3.3 — a floating civ-map medallion above the settlement, its glyph by tier
## (rosette/star/monogram); hamlets wear none. Reused across refreshes.
func _update_medallion(sid: int, tier: int, center: Vector3) -> void:
	var glyph: String = TIER_MEDALLION.get(tier, "")
	if glyph == "":
		if _medallions.has(sid):
			_medallions[sid].queue_free()
			_medallions.erase(sid)
		return
	var label: Label3D = _medallions.get(sid)
	if label == null:
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = 0.06
		label.modulate = Palette.COLORS[Palette.GOLD_LIT]
		label.outline_modulate = Palette.COLORS[Palette.NIGHT_LAPIS]
		label.outline_size = 8
		add_child(label)
		_medallions[sid] = label
	label.text = glyph
	label.position = center + Vector3(0.0, MEDALLION_HEIGHT, 0.0)


func _process(delta: float) -> void:
	var alive: Array = []
	for g in _growing:
		var node: Node3D = g["node"]
		if not is_instance_valid(node):
			continue  # its cluster was rebuilt out from under it
		g["t"] = float(g["t"]) + delta / GROW_SECONDS
		var scale := clampf(g["t"], 0.0, 1.0)
		node.scale = Vector3.ONE * scale
		if scale < 1.0:
			alive.append(g)
	_growing = alive


func has_cluster(sid: int) -> bool:
	return _clusters.has(sid)


func cluster_prop_count(sid: int) -> int:
	return _clusters[sid].get_child_count() if _clusters.has(sid) else 0


func has_medallion(sid: int) -> bool:
	return _medallions.has(sid)


func medallion_glyph(sid: int) -> String:
	return (_medallions[sid] as Label3D).text if _medallions.has(sid) else ""
