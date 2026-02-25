class_name Terrain3DCollisionOverlay
extends Node3D

## Enable or disable collision generation at runtime.
@export var enabled: bool = true
## Radius around camera within which collision bodies are spawned.
@export var collision_radius: float = 150.0:
	set(value):
		collision_radius = value
		_remove_radius = value * 1.15
## How often (seconds) to check camera position and update bodies.
@export var update_interval: float = 0.5
## Physics collision layer for generated static bodies.
@export_flags_3d_physics var collision_layer: int = 1
## Physics collision mask for generated static bodies.
@export_flags_3d_physics var collision_mask: int = 0

var _terrain: Node  # Terrain3D parent (GDExtension, cannot be statically typed)
var _collision_shapes: Dictionary = {}  # mesh_id -> Shape3D
var _active_bodies: Dictionary = {}  # compound_key -> StaticBody3D
var _last_camera_pos: Vector3 = Vector3.INF
var _timer: float = 0.0
var _remove_radius: float  # collision_radius * 1.15 hysteresis


func _ready() -> void:
	_terrain = get_parent()
	if not _terrain or not _terrain.is_class("Terrain3D"):
		push_error("Terrain3DCollisionOverlay must be a child of a Terrain3D node")
		set_physics_process(false)
		return
	_remove_radius = collision_radius * 1.15
	_extract_collision_shapes()


func _physics_process(delta: float) -> void:
	if not enabled:
		if not _active_bodies.is_empty():
			_clear_all_bodies()
		return
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	_update_collision_bodies()


func _exit_tree() -> void:
	_clear_all_bodies()


func _extract_collision_shapes() -> void:
	if not _terrain.assets:
		push_warning("Terrain3DCollisionOverlay: No assets available yet")
		return
	var mesh_count: int = _terrain.assets.get_mesh_count()
	for i in mesh_count:
		var asset = _terrain.assets.get_mesh_asset(i)
		if not asset or not asset.scene_file:
			continue
		var scene_instance: Node = asset.scene_file.instantiate()
		var collision_shape: CollisionShape3D = _find_collision_shape(scene_instance)
		if collision_shape and collision_shape.shape:
			_collision_shapes[asset.id] = collision_shape.shape.duplicate()
		scene_instance.free()
	if _collision_shapes.size() > 0:
		print("Terrain3DCollisionOverlay: %d/%d mesh assets have collision" % [_collision_shapes.size(), mesh_count])


func _find_collision_shape(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D and node.shape:
		return node
	for child in node.get_children():
		var result := _find_collision_shape(child)
		if result:
			return result
	return null


func _update_collision_bodies() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or not _terrain.data:
		return

	var cam_pos := camera.global_position
	if cam_pos.distance_to(_last_camera_pos) < 10.0:
		return
	_last_camera_pos = cam_pos

	var cam_pos_2d := Vector2(cam_pos.x, cam_pos.z)
	var desired_keys: Dictionary = {}  # key -> Transform3D
	var collision_radius_sq := collision_radius * collision_radius
	var remove_radius_sq := _remove_radius * _remove_radius

	var regions: Array = _terrain.data.get_regions_active()
	var region_size: float = _terrain.get_region_size()
	var vertex_spacing: float = _terrain.get_vertex_spacing()

	for region in regions:
		var region_origin_2d := Vector2(region.location.x, region.location.y) * region_size * vertex_spacing

		var region_extent := region_size * vertex_spacing
		var closest_point := Vector2(
			clampf(cam_pos_2d.x, region_origin_2d.x, region_origin_2d.x + region_extent),
			clampf(cam_pos_2d.y, region_origin_2d.y, region_origin_2d.y + region_extent)
		)
		if closest_point.distance_squared_to(cam_pos_2d) > remove_radius_sq:
			continue

		var instances: Dictionary = region.instances
		# Region offset to convert local transforms to world space
		var region_offset := Vector3(
			region.location.x * region_size * vertex_spacing,
			0.0,
			region.location.y * region_size * vertex_spacing
		)
		for mesh_id in instances:
			if not _collision_shapes.has(mesh_id):
				continue
			var cells: Dictionary = instances[mesh_id]
			for cell_loc: Vector2i in cells:
				var cell_data: Array = cells[cell_loc]
				var transforms: Array = cell_data[0]
				for t_idx in transforms.size():
					var xform: Transform3D = transforms[t_idx]
					# Transforms are region-local, convert to world space
					var world_origin := xform.origin + region_offset
					var inst_pos_2d := Vector2(world_origin.x, world_origin.z)
					if inst_pos_2d.distance_squared_to(cam_pos_2d) <= collision_radius_sq:
						var key := _make_key(mesh_id, region.location, cell_loc, t_idx)
						var world_xform := xform
						world_xform.origin = world_origin
						desired_keys[key] = world_xform

	# Remove bodies outside remove radius
	var keys_to_remove: Array = []
	for key: String in _active_bodies:
		if not desired_keys.has(key):
			var body: StaticBody3D = _active_bodies[key]
			var body_pos_2d := Vector2(body.global_position.x, body.global_position.z)
			if body_pos_2d.distance_squared_to(cam_pos_2d) >= remove_radius_sq:
				keys_to_remove.append(key)

	for key: String in keys_to_remove:
		_active_bodies[key].queue_free()
		_active_bodies.erase(key)

	# Add new bodies within collision radius
	for key: String in desired_keys:
		if not _active_bodies.has(key):
			var mesh_id: int = _key_mesh_id(key)
			_spawn_body(key, mesh_id, desired_keys[key])


func _make_key(mesh_id: int, region_loc: Vector2i, cell_loc: Vector2i, t_idx: int) -> String:
	return "%d_%d_%d_%d_%d_%d" % [mesh_id, region_loc.x, region_loc.y, cell_loc.x, cell_loc.y, t_idx]


func _key_mesh_id(key: String) -> int:
	return key.split("_")[0].to_int()


func _spawn_body(key: String, mesh_id: int, xform: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask
	var col_shape := CollisionShape3D.new()
	col_shape.shape = _collision_shapes[mesh_id]
	body.add_child(col_shape)
	add_child(body)
	body.global_transform = xform
	_active_bodies[key] = body


func _clear_all_bodies() -> void:
	for key: String in _active_bodies:
		if is_instance_valid(_active_bodies[key]):
			_active_bodies[key].queue_free()
	_active_bodies.clear()
