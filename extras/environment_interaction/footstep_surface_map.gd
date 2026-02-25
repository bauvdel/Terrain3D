class_name FootstepSurfaceMap
extends Resource

## Maps Terrain3D texture asset ID (int) -> FootstepSoundSet resource.
@export var texture_sounds: Dictionary = {}
## Fallback when texture ID has no mapping.
@export var default_sounds: FootstepSoundSet
## Weather override: used when Weather3D reports snow at position.
@export var snow_sounds: FootstepSoundSet
## Weather override: used when Weather3D reports rain (intensity > 0.3).
@export var wet_sounds: FootstepSoundSet

func get_sound_set(texture_id: int) -> FootstepSoundSet:
	return texture_sounds.get(texture_id, default_sounds) as FootstepSoundSet
