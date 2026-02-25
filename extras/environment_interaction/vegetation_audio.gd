class_name VegetationAudio
extends Node3D

## Plays vegetation interaction audio (bush rustling, grass swishing, branch snaps)
## when the player moves near Terrain3D instanced meshes. Attach as a child of
## (or near) a CharacterBody3D.

@export var sound_map: VegetationSoundMap
@export var terrain_path: NodePath
@export var character_path: NodePath

@export_group("Timing")
## Step interval when walking.
@export var walk_interval: float = 0.5
## Step interval when running.
@export var run_interval: float = 0.35
## Step interval when sprinting.
@export var sprint_interval: float = 0.25

@export_group("Audio")
## Base volume in dB (lower than footsteps to layer underneath).
@export var volume_db: float = -6.0
## Random pitch variation (±).
@export var pitch_variation: float = 0.08
## Maximum audible distance.
@export var max_distance: float = 30.0
## Audio bus name.
@export var bus: StringName = &"SFX"

@export_group("Detection")
## How often (seconds) to scan for nearby mesh instances.
@export var scan_interval: float = 0.2

const POOL_SIZE := 3

var _terrain: Node
var _character: CharacterBody3D
var _players: Array[AudioStreamPlayer3D] = []
var _next_player: int = 0
var _step_timer: float = 0.0
var _scan_timer: float = 0.0
var _last_index: int = -1
var _was_moving: bool = false

# Cached from last proximity scan
var _nearest_sound_set: VegetationSoundSet = null


func _ready() -> void:
	if terrain_path:
		_terrain = get_node_or_null(terrain_path)
	if character_path:
		_character = get_node_or_null(character_path) as CharacterBody3D

	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = bus
		p.max_distance = max_distance
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		add_child(p)
		_players.append(p)


func _process(delta: float) -> void:
	if not _character or not _terrain or not sound_map:
		return

	# Audio follows the player.
	var char_pos := _character.global_position
	for p in _players:
		p.global_position = char_pos

	if not _character.is_on_floor():
		return

	# Check horizontal velocity — no sound when stationary.
	var xz_velocity := Vector2(_character.velocity.x, _character.velocity.z)
	var is_moving := xz_velocity.length() >= 0.5
	if not is_moving:
		_step_timer = 0.0
		_nearest_sound_set = null
		_was_moving = false
		return

	# Scan immediately when starting to move, then on interval.
	var force_scan := not _was_moving
	_was_moving = true

	_scan_timer += delta
	if force_scan or _scan_timer >= scan_interval:
		_scan_timer = 0.0
		var prev_set := _nearest_sound_set
		_nearest_sound_set = _find_nearest_vegetation()
		# Play immediately when first entering vegetation.
		if _nearest_sound_set and not prev_set:
			_step_timer = _get_step_interval()

	if not _nearest_sound_set:
		return

	var interval := _get_step_interval()
	_step_timer += delta
	if _step_timer >= interval:
		_play_step(interval)
		_step_timer -= interval


func _get_step_interval() -> float:
	var sprinting = _character.get("is_sprinting")
	if sprinting is bool and sprinting:
		return sprint_interval
	var walking = _character.get("is_walking")
	if walking is bool and walking:
		return walk_interval
	return run_interval


func _find_nearest_vegetation() -> VegetationSoundSet:
	var data = _terrain.get("data")
	if not data or not data.has_method("get_regions_active"):
		return null

	var pos := _character.global_position
	var pos_2d := Vector2(pos.x, pos.z)
	var regions: Array = data.get_regions_active()
	var region_size: float = _terrain.get_region_size()
	var vertex_spacing: float = _terrain.get_vertex_spacing()

	var best_dist_sq: float = INF
	var best_mesh_id: int = -1

	for region in regions:
		var region_offset := Vector3(
			region.location.x * region_size * vertex_spacing,
			0.0,
			region.location.y * region_size * vertex_spacing
		)

		# Quick reject: skip regions too far away.
		var region_center_2d := Vector2(
			region_offset.x + region_size * vertex_spacing * 0.5,
			region_offset.z + region_size * vertex_spacing * 0.5
		)
		if region_center_2d.distance_squared_to(pos_2d) > 10000.0:  # >100m away
			continue

		var instances: Dictionary = region.instances
		for mesh_id: int in instances:
			var sound_set := sound_map.get_sound_set(mesh_id)
			if not sound_set:
				continue

			var max_radius_sq: float = sound_set.trigger_radius * sound_set.trigger_radius
			var cells: Dictionary = instances[mesh_id]
			for cell_loc: Vector2i in cells:
				var cell_data: Array = cells[cell_loc]
				var transforms: Array = cell_data[0]
				for xform: Transform3D in transforms:
					var world_origin := xform.origin + region_offset
					var inst_2d := Vector2(world_origin.x, world_origin.z)
					var dist_sq := inst_2d.distance_squared_to(pos_2d)
					if dist_sq < max_radius_sq and dist_sq < best_dist_sq:
						best_dist_sq = dist_sq
						best_mesh_id = mesh_id

	if best_mesh_id >= 0:
		return sound_map.get_sound_set(best_mesh_id)
	return null


func _play_step(current_interval: float) -> void:
	if not _nearest_sound_set:
		return

	var sounds: Array[AudioStream]
	if is_equal_approx(current_interval, sprint_interval):
		sounds = _nearest_sound_set.sprint
	elif is_equal_approx(current_interval, walk_interval):
		sounds = _nearest_sound_set.walk
	else:
		sounds = _nearest_sound_set.run

	# Fallback chain: run -> walk -> sprint.
	if sounds.is_empty():
		if _nearest_sound_set.run.size() > 0:
			sounds = _nearest_sound_set.run
		elif _nearest_sound_set.walk.size() > 0:
			sounds = _nearest_sound_set.walk
		elif _nearest_sound_set.sprint.size() > 0:
			sounds = _nearest_sound_set.sprint

	if not sounds.is_empty():
		_play_random(sounds)


func _play_random(sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return

	# Pick next player in pool — skip if still playing to avoid stacking.
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	if player.playing:
		return

	var idx := randi() % sounds.size()
	if idx == _last_index and sounds.size() > 1:
		idx = (idx + 1) % sounds.size()
	_last_index = idx

	player.stream = sounds[idx]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
