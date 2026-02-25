class_name VegetationSoundSet
extends Resource

## Display name for this sound set (e.g., "Bush", "Grass", "Tree").
@export var name: StringName = &""
## Sounds for walking pace near this vegetation.
@export var walk: Array[AudioStream] = []
## Sounds for running pace near this vegetation.
@export var run: Array[AudioStream] = []
## Sounds for sprinting pace near this vegetation.
@export var sprint: Array[AudioStream] = []
## Maximum distance (meters) from a mesh instance to trigger this sound.
@export var trigger_radius: float = 1.5
