class_name PixelStage
extends Control
## R1.2 [rav §R-art]: the low-res render surface for the mosaic look. The 3D
## world (lights, camera, terrain, puppets) lives inside `world` — a
## SubViewport at INTERNAL_SIZE with its own World3D — and `_screen` (a
## nearest-neighbor TextureRect filling this Control) presents it upscaled to
## the window. The mosaic post-process (R1.3) is a ShaderMaterial set on
## `_screen` via set_screen_material(). Presentation-only; the sim never sees
## any of this.
##
## Coordinate note: because the camera renders INTO `world` (384×216), a
## window-space mouse point must be scaled to viewport space before it meets
## the camera's project_ray — RunView does that via to_viewport(), using this
## stage's displayed size. Headless (no display) leaves the size at 0, and
## to_viewport is the identity, so the analytic picking tests round-trip
## unchanged.

const INTERNAL_WIDTH := 384
const INTERNAL_HEIGHT := 216

var world: SubViewport
var _screen: TextureRect


func _init() -> void:
	world = SubViewport.new()
	world.size = Vector2i(INTERNAL_WIDTH, INTERNAL_HEIGHT)
	world.own_world_3d = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.transparent_bg = false
	world.handle_input_locally = false
	add_child(world)
	_screen = TextureRect.new()
	_screen.name = "screen"
	_screen.stretch_mode = TextureRect.STRETCH_SCALE
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# The ViewportTexture resolves only once `world` is in the tree.
	_screen.texture = world.get_texture()


## Window-space point → `world` viewport space. Identity when the stage has no
## displayed size (headless), so analytic picking round-trips unchanged.
func to_viewport(point: Vector2) -> Vector2:
	var shown := _screen.size
	if shown.x <= 0.0 or shown.y <= 0.0:
		return point
	return point * (Vector2(world.size) / shown)


## Fit the displayed surface to a window rect (real play only; headless leaves
## it at 0). Called by RunView on _ready and on viewport resize.
func fit_to(window_size: Vector2) -> void:
	size = window_size


func set_screen_material(material: Material) -> void:
	_screen.material = material
