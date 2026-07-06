class_name Props
extends RefCounted
## R3.1 [rav §R-build] — the mosaic building props: one simple low-poly mesh per
## structure id, styled (matte palette albedos, gold/terracotta roofs, the
## basilica's monogram gable) so a settlement reads as late-antique Christian-
## mosaic architecture through the R1 post-process. Built procedurally — no binary
## .tscn (same choice as Motifs' monogram; keeps assets out of a network-blocked
## build and lets the palette do the skinning). Presentation-only; the sim never
## sees these. R3.2 places them; scale is unit-ish and tuned there. The canonical
## id list lives on Settlement.BUILDING_IDS — build() matches it id-for-id.


## A Node3D prop for a building id (null for an unknown id).
static func build(building_id: String) -> Node3D:
	match building_id:
		"dwelling":
			return _gabled(
				Vector3(0.9, 0.6, 0.9), Palette.COLORS[9], Palette.COLORS[Palette.TERRACOTTA]
			)
		"farm":
			return _field()
		"well":
			return _well()
		"granary":
			return _gabled(
				Vector3(0.9, 1.1, 0.8),
				Palette.COLORS[Palette.CREAM],
				Palette.COLORS[Palette.TERRACOTTA]
			)
		"workshop":
			return _colonnaded(Vector3(1.3, 0.7, 1.0), Palette.COLORS[9])
		"shrine":
			return _aedicula(0.7, false)
		"basilica":
			return _basilica()
		"wall":
			return _wall()
		"market":
			return _stoa()
	return null


static func _matte(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


static func _box(size: Vector3, color: Color, y: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _matte(color)
	mesh.position.y = y
	return mesh


## A gabled hall: a walled box under a triangular-prism roof.
static func _gabled(size: Vector3, wall: Color, roof: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "gabled"
	root.add_child(_box(size, wall, size.y * 0.5))
	var roof_mesh := MeshInstance3D.new()
	roof_mesh.name = "roof"
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x * 1.05, size.y * 0.55, size.z * 1.05)
	roof_mesh.mesh = prism
	roof_mesh.material_override = _matte(roof)
	roof_mesh.position.y = size.y + size.y * 0.27
	root.add_child(roof_mesh)
	return root


## A thin sage-green field patch, furrowed by a couple of darker strips.
static func _field() -> Node3D:
	var root := Node3D.new()
	root.name = "field"
	root.add_child(_box(Vector3(1.4, 0.05, 1.4), Palette.COLORS[4], 0.02))
	for i in 3:
		var furrow := _box(Vector3(1.3, 0.06, 0.12), Palette.COLORS[3], 0.03)
		furrow.position.z = -0.45 + i * 0.45
		root.add_child(furrow)
	return root


static func _well() -> Node3D:
	var root := Node3D.new()
	root.name = "well"
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 0.4
	ring.mesh = cyl
	ring.material_override = _matte(Palette.COLORS[Palette.SLATE_GREY])
	ring.position.y = 0.2
	root.add_child(ring)
	return root


## A columned hall: a low box fronted by a row of columns.
static func _colonnaded(size: Vector3, wall: Color) -> Node3D:
	var root := _gabled(size, wall, Palette.COLORS[Palette.TERRACOTTA])
	root.name = "colonnaded"
	for i in 4:
		var column := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = size.y
		column.mesh = cyl
		column.material_override = _matte(Palette.COLORS[Palette.CREAM])
		column.position = Vector3(
			-size.x * 0.4 + i * size.x * 0.27, size.y * 0.5, size.z * 0.5 + 0.1
		)
		root.add_child(column)
	return root


## A little aedicula (shrine): a small gabled shrine, gilt at the peak. When
## `grand`, larger and bearing the sacred monogram on its pediment (the basilica).
static func _aedicula(scale: float, grand: bool) -> Node3D:
	var wall: Color = Palette.COLORS[Palette.CREAM]
	var roof: Color = Palette.COLORS[Palette.GOLD] if grand else Palette.COLORS[Palette.TERRACOTTA]
	var root := _gabled(Vector3(scale, scale * 1.1, scale * 0.8), wall, roof)
	root.name = "basilica" if grand else "shrine"
	if grand:
		var mono := MeshInstance3D.new()
		mono.name = "monogram"
		var quad := QuadMesh.new()
		quad.size = Vector2(scale * 0.5, scale * 0.5)
		mono.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = ImageTexture.create_from_image(Motifs.monogram_image())
		mono.material_override = mat
		mono.position = Vector3(0.0, scale * 1.3, scale * 0.42)
		root.add_child(mono)
	return root


## The basilica: a grand gabled hall with the monogram on its pediment.
static func _basilica() -> Node3D:
	return _aedicula(1.4, true)


static func _wall() -> Node3D:
	var root := Node3D.new()
	root.name = "wall"
	root.add_child(_box(Vector3(1.6, 0.5, 0.25), Palette.COLORS[Palette.SLATE_GREY], 0.25))
	return root


## A market stoa: a flat roof carried on a row of columns.
static func _stoa() -> Node3D:
	var root := Node3D.new()
	root.name = "stoa"
	root.add_child(_box(Vector3(1.5, 0.08, 0.7), Palette.COLORS[9], 0.85))
	for i in 5:
		var column := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = 0.8
		column.mesh = cyl
		column.material_override = _matte(Palette.COLORS[Palette.CREAM])
		column.position = Vector3(-0.6 + i * 0.3, 0.4, 0.0)
		root.add_child(column)
	return root
