class_name InteractionStamper
extends Node3D

## Packed scene for the grass trail stamp (channel G, follows entity).
@export var grass_trail_stamp: PackedScene
## Packed scene for the grass mark stamp (channel G, placed and fades over time).
@export var grass_mark_stamp: PackedScene
## Packed scene for the footprint stamp (channel R, placed and fades).
@export var footprint_stamp: PackedScene
## Minimum distance between footprint placements.
@export var footprint_spacing: float = 0.6
## Whether this entity leaves footprints (player only).
@export var enable_footprints: bool = true
## The node where ALL stamps are parented (must be the SubViewport).
@export var stamp_parent_path: NodePath

## Lateral offset from center for left/right foot placement (meters).
@export var foot_lateral_offset: float = 0.12

var _trail_left: MeshInstance3D
var _trail_right: MeshInstance3D
var _last_footprint_pos: Vector3 = Vector3.INF
var _terrain: Node  # Terrain3D reference for height queries
var _stamp_parent: Node
var _character: CharacterBody3D
var _next_foot_right: bool = false
var _last_pos: Vector3 = Vector3.INF
var _move_dir: Vector3 = Vector3.FORWARD


func _ready() -> void:
	_terrain = _find_terrain()
	_stamp_parent = get_node_or_null(stamp_parent_path)
	_character = get_parent() as CharacterBody3D

	if not _stamp_parent:
		return

	# Create two oval trail stamps (left/right foot presence)
	if grass_trail_stamp:
		for i in 2:
			var instance = grass_trail_stamp.instantiate()
			var mesh_inst := instance as MeshInstance3D
			if mesh_inst:
				mesh_inst.layers = 1 << 18
				_stamp_parent.add_child(mesh_inst)
				if i == 0:
					_trail_left = mesh_inst
				else:
					_trail_right = mesh_inst
			elif instance:
				instance.free()


func _process(_delta: float) -> void:
	var pos := global_position

	# Track movement direction from position delta
	if _last_pos != Vector3.INF:
		var delta_xz := pos - _last_pos
		delta_xz.y = 0.0
		if delta_xz.length_squared() > 0.0001:
			_move_dir = delta_xz.normalized()
	_last_pos = pos

	# Hide trail stamps and skip footprints when airborne
	var on_floor := _character.is_on_floor() if _character else true
	if not on_floor:
		if _trail_left:
			_trail_left.visible = false
		if _trail_right:
			_trail_right.visible = false
		return

	var right := _move_dir.cross(Vector3.UP).normalized()
	var yaw := atan2(_move_dir.x, _move_dir.z)

	# Position trail stamps at left/right foot positions
	if _trail_left:
		_trail_left.visible = true
		var left_pos := pos - right * foot_lateral_offset
		var gy := _get_terrain_height(left_pos)
		_trail_left.global_position = Vector3(left_pos.x, gy + 0.05, left_pos.z)
		_trail_left.rotation.y = yaw
	if _trail_right:
		_trail_right.visible = true
		var right_pos := pos + right * foot_lateral_offset
		var gy := _get_terrain_height(right_pos)
		_trail_right.global_position = Vector3(right_pos.x, gy + 0.05, right_pos.z)
		_trail_right.rotation.y = yaw

	if not enable_footprints or not footprint_stamp or not _stamp_parent:
		return

	if pos.distance_to(_last_footprint_pos) >= footprint_spacing:
		_last_footprint_pos = pos
		_spawn_footprint(pos)


func _spawn_footprint(pos: Vector3) -> void:
	var stamp := footprint_stamp.instantiate() as Node3D
	if not stamp:
		return
	_stamp_parent.add_child(stamp)
	if stamp is MeshInstance3D:
		stamp.layers = 1 << 18

	var right := _move_dir.cross(Vector3.UP).normalized()

	var side := 1.0 if _next_foot_right else -1.0
	var foot_pos := pos + right * foot_lateral_offset * side
	_next_foot_right = not _next_foot_right

	var ground_y := _get_terrain_height(foot_pos)
	stamp.global_position = Vector3(foot_pos.x, ground_y + 0.05, foot_pos.z)

	var yaw := atan2(_move_dir.x, _move_dir.z)
	stamp.rotation.y = yaw

	# Spawn a lasting grass mark at the same position (G channel, fades over time)
	if grass_mark_stamp:
		var grass_mark := grass_mark_stamp.instantiate() as Node3D
		if grass_mark:
			_stamp_parent.add_child(grass_mark)
			if grass_mark is MeshInstance3D:
				grass_mark.layers = 1 << 18
			grass_mark.global_position = Vector3(foot_pos.x, ground_y + 0.05, foot_pos.z)
			grass_mark.rotation.y = yaw


func _get_terrain_height(pos: Vector3) -> float:
	if _terrain:
		var data = _terrain.get("data")
		if data and data.has_method("get_height"):
			var h: float = data.get_height(pos)
			if not is_nan(h):
				return h
	return pos.y


func _find_terrain() -> Node:
	var root := get_tree().current_scene
	if not root:
		return null
	return _search_terrain(root)


func _search_terrain(node: Node) -> Node:
	if node.get_class() == "Terrain3D":
		return node
	for child in node.get_children():
		var found := _search_terrain(child)
		if found:
			return found
	return null
