class_name EntityStampManager
extends Node

## The renderer node to check distance from.
@export var renderer_path: NodePath
## Grass trail stamp scene to attach to entities.
@export var trail_stamp: PackedScene
## How often to scan for nearby entities (seconds).
@export var scan_interval: float = 0.5
## Group name for entities that should get trail stamps.
@export var entity_group: String = "stampable"

var _timer: float = 0.0
var _tracked_entities: Dictionary = {}  # Node3D -> MeshInstance3D (trail stamp)
var _renderer: EnvironmentInteractionRenderer


func _ready() -> void:
	_renderer = get_node_or_null(renderer_path) as EnvironmentInteractionRenderer


func _process(delta: float) -> void:
	if not _renderer or not trail_stamp:
		return

	var target := _renderer.get_node_or_null(_renderer.target_path) as Node3D
	if not target:
		return

	_timer += delta
	if _timer < scan_interval:
		return
	_timer = 0.0

	var center := target.global_position
	var radius := _renderer.render_size * 0.5
	var entities := get_tree().get_nodes_in_group(entity_group)

	# Add stamps to entities in range
	for entity in entities:
		if entity is Node3D and entity != target:
			var dist := center.distance_to(entity.global_position)
			if dist <= radius and not _tracked_entities.has(entity):
				_attach_trail(entity)
			elif dist > radius * 1.15 and _tracked_entities.has(entity):
				_detach_trail(entity)

	# Clean up freed entities
	for entity in _tracked_entities.keys():
		if not is_instance_valid(entity):
			_tracked_entities.erase(entity)


func _attach_trail(entity: Node3D) -> void:
	var stamp := trail_stamp.instantiate() as MeshInstance3D
	if stamp:
		stamp.layers = 1 << 18
		entity.add_child(stamp)
		_tracked_entities[entity] = stamp


func _detach_trail(entity: Node3D) -> void:
	var stamp = _tracked_entities.get(entity)
	if stamp and is_instance_valid(stamp):
		stamp.queue_free()
	_tracked_entities.erase(entity)
