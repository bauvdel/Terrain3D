class_name FootstepAudio
extends Node3D

## Plays 3D positional footstep sounds based on terrain surface, weather, and movement state.
## Attach as a child of (or near) a CharacterBody3D. Requires a FootstepSurfaceMap resource
## that maps Terrain3D texture IDs to sound sets.

@export var surface_map: FootstepSurfaceMap
@export var terrain_path: NodePath
@export var weather_path: NodePath
@export var character_path: NodePath

@export_group("Timing")
@export var walk_interval: float = 0.55
@export var run_interval: float = 0.35
@export var sprint_interval: float = 0.25

@export_group("Audio")
@export var volume_db: float = 0.0
@export var pitch_variation: float = 0.08
@export var max_distance: float = 30.0
@export var bus: StringName = &"SFX"

var _terrain: Node
var _weather: Node
var _character: CharacterBody3D
var _player: AudioStreamPlayer3D
var _step_timer: float = 0.0
var _last_index: int = -1
var _was_on_floor: bool = true


func _ready() -> void:
	if terrain_path:
		_terrain = get_node_or_null(terrain_path)
	if weather_path:
		_weather = get_node_or_null(weather_path)
	if character_path:
		_character = get_node_or_null(character_path) as CharacterBody3D

	_player = AudioStreamPlayer3D.new()
	_player.bus = bus
	_player.max_distance = max_distance
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(_player)


func _process(delta: float) -> void:
	if not _character or not _terrain or not surface_map:
		return

	# Sync audio position to character.
	_player.global_position = _character.global_position

	# Landing detection: transitioned from airborne to grounded this frame.
	var on_floor := _character.is_on_floor()
	if on_floor and not _was_on_floor:
		_play_land()
	_was_on_floor = on_floor

	if not on_floor:
		return

	# Check horizontal velocity — ignore vertical component.
	var xz_velocity := Vector2(_character.velocity.x, _character.velocity.z)
	if xz_velocity.length() < 0.5:
		_step_timer = 0.0
		return

	var interval := _get_step_interval()
	_step_timer += delta
	if _step_timer >= interval:
		_play_step(interval)
		_step_timer -= interval


func _get_step_interval() -> float:
	# Duck-type check character properties for movement state.
	var sprinting = _character.get("is_sprinting")
	if sprinting is bool and sprinting:
		return sprint_interval

	var walking = _character.get("is_walking")
	if walking is bool and walking:
		return walk_interval

	return run_interval


func _get_sound_set() -> FootstepSoundSet:
	var pos := _character.global_position

	# Weather overrides take priority.
	if _weather:
		if _weather.has_method("is_snowing_at") and _weather.is_snowing_at(pos):
			if surface_map.snow_sounds:
				return surface_map.snow_sounds
		if _weather.has_method("is_raining_at") and _weather.is_raining_at(pos):
			if surface_map.wet_sounds:
				return surface_map.wet_sounds

	# Terrain texture lookup.
	var data = _terrain.get("data")
	if data and data.has_method("get_texture_id"):
		var tex_info: Vector3 = data.get_texture_id(pos)
		var base_id := int(tex_info.x)
		return surface_map.get_sound_set(base_id)

	return surface_map.default_sounds


func _play_step(current_interval: float) -> void:
	var sound_set := _get_sound_set()
	if not sound_set:
		return

	# Choose the array matching the current movement cadence.
	var sounds: Array[AudioStream]
	if is_equal_approx(current_interval, sprint_interval):
		sounds = sound_set.sprint
	elif is_equal_approx(current_interval, walk_interval):
		sounds = sound_set.walk
	else:
		sounds = sound_set.run

	# Fallback chain: if chosen array is empty, try run -> walk -> sprint.
	if sounds.is_empty():
		if sound_set.run.size() > 0:
			sounds = sound_set.run
		elif sound_set.walk.size() > 0:
			sounds = sound_set.walk
		elif sound_set.sprint.size() > 0:
			sounds = sound_set.sprint

	if not sounds.is_empty():
		_play_random(sounds)


func _play_land() -> void:
	var sound_set := _get_sound_set()
	if not sound_set:
		return
	if sound_set.land.size() > 0:
		_play_random(sound_set.land)


func _play_random(sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return

	var idx := randi() % sounds.size()
	if idx == _last_index and sounds.size() > 1:
		idx = (idx + 1) % sounds.size()
	_last_index = idx

	_player.stream = sounds[idx]
	_player.volume_db = volume_db
	_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	_player.play()
