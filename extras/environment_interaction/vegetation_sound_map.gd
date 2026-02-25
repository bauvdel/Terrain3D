class_name VegetationSoundMap
extends Resource

## Maps Terrain3D mesh asset ID (int) -> VegetationSoundSet resource.
@export var mesh_sounds: Dictionary = {}
## Fallback when mesh ID has no mapping.
@export var default_sounds: VegetationSoundSet

## Returns the sound set for the given mesh asset ID, or default_sounds if unmapped.
func get_sound_set(mesh_id: int) -> VegetationSoundSet:
	return mesh_sounds.get(mesh_id, default_sounds) as VegetationSoundSet
