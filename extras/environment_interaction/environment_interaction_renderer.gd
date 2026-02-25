class_name EnvironmentInteractionRenderer
extends SubViewport

## The node to follow (typically the player character).
@export var target_path: NodePath
## World-space diameter of the interaction area.
@export var render_size: float = 30.0
## Minimum distance the target must move before the viewport repositions.
@export var reposition_threshold: float = 0.5
## Snap grid size for camera positioning (prevents texture swimming).
@export var snap_step: float = 2.0

var _last_position: Vector3 = Vector3.INF
var _camera: Camera3D


func _ready() -> void:
	# Configure viewport
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	size = Vector2i(512, 512)

	# Cache and configure camera
	_camera = _get_camera()
	var cam := _camera
	if cam:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = render_size
		cam.cull_mask = 1 << 18  # Layer 19 (0-indexed bit 18)
		cam.near = 0.1
		cam.far = 2000.0
		# Look DOWNWARD: -90° around X axis
		cam.rotation_degrees = Vector3(-90, 0, 0)

	# Set global shader parameters
	RenderingServer.global_shader_parameter_set("detail_viewport_texture", get_texture())
	RenderingServer.global_shader_parameter_set("detail_viewport_size", render_size)
	RenderingServer.global_shader_parameter_set(
		"detail_viewport_corner",
		Vector3(-render_size * 0.5, 0.0, -render_size * 0.5)
	)

	# Defer remaining setup
	call_deferred("_deferred_setup")


func _deferred_setup() -> void:
	if _camera:
		_camera.current = true

	_exclude_stamp_layer_from_cameras()


func _process(_delta: float) -> void:
	var target := get_node_or_null(target_path) as Node3D
	if not target:
		return

	var target_pos := target.global_position
	if target_pos.distance_to(_last_position) < reposition_threshold:
		return

	# Snap position to grid to prevent sub-pixel swimming
	_last_position = target_pos
	var snapped_pos := Vector3(
		snapped(target_pos.x, snap_step),
		snapped(target_pos.y + 1000.0, snap_step),
		snapped(target_pos.z, snap_step)
	)

	if _camera:
		_camera.global_position = snapped_pos

	# Update global uniforms
	var corner := Vector3(
		snapped_pos.x - render_size * 0.5,
		0.0,
		snapped_pos.z - render_size * 0.5
	)
	RenderingServer.global_shader_parameter_set("detail_viewport_size", render_size)
	RenderingServer.global_shader_parameter_set("detail_viewport_corner", corner)


func _get_camera() -> Camera3D:
	for child in get_children():
		if child is Camera3D:
			return child
	return null


func _exclude_stamp_layer_from_cameras() -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var stamp_bit := 1 << 18  # Layer 19
	for cam in _find_cameras(root):
		# Skip our own viewport camera
		if cam == _camera:
			continue
		if cam.cull_mask & stamp_bit:
			cam.cull_mask &= ~stamp_bit


func _find_cameras(node: Node) -> Array[Camera3D]:
	var result: Array[Camera3D] = []
	if node is Camera3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_cameras(child))
	return result
