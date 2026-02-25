@tool
class_name SnowOverlay
extends Node

## Controls snow overlay on the Terrain3D material via shader_override parameters.
## Add as a child of (or sibling to) the Terrain3D node.

@export_group("Snow Coverage")
@export var enabled: bool = false:
	set(v):
		enabled = v
		if is_inside_tree():
			_set_param("snow_enabled", v)
@export_range(0.0, 1.0) var amount: float = 0.0:
	set(v):
		amount = v
		if is_inside_tree():
			_set_param("snow_amount", v)

@export_group("Snow Distribution")
@export_range(-500.0, 2000.0) var altitude_start: float = -500.0:
	set(v):
		altitude_start = v
		if is_inside_tree():
			_set_param("snow_altitude_start", v)
@export_range(-500.0, 2000.0) var altitude_full: float = -400.0:
	set(v):
		altitude_full = v
		if is_inside_tree():
			_set_param("snow_altitude_full", v)
@export_range(0.0, 1.0) var slope_threshold: float = 0.3:
	set(v):
		slope_threshold = v
		if is_inside_tree():
			_set_param("snow_slope_threshold", v)
@export_range(0.001, 1.0) var noise_scale: float = 0.02:
	set(v):
		noise_scale = v
		if is_inside_tree():
			_set_param("snow_noise_scale", v)

@export_group("Snow Appearance")
@export var color: Color = Color(0.92, 0.93, 0.97):
	set(v):
		color = v
		if is_inside_tree():
			_set_param("snow_color", Vector3(v.r, v.g, v.b))
@export_range(0.0, 1.0) var roughness: float = 0.85:
	set(v):
		roughness = v
		if is_inside_tree():
			_set_param("snow_roughness", v)
@export_range(0.0, 1.0) var normal_flatten: float = 0.7:
	set(v):
		normal_flatten = v
		if is_inside_tree():
			_set_param("snow_normal_flatten", v)

@export_group("Snow Depth")
## How high snow raises the terrain mesh (world units). Drives accumulation.
@export_range(0.0, 2.0) var base_height: float = 0.3:
	set(v):
		base_height = v
		if is_inside_tree():
			_set_param("snow_base_height", v)

@export_group("Footprints")
@export var footprint_color: Color = Color(0.45, 0.42, 0.38):
	set(v):
		footprint_color = v
		if is_inside_tree():
			_set_param("footprint_color", Vector3(v.r, v.g, v.b))
## Roughness of compacted snow in footprints (lower = wetter/shinier).
@export_range(0.0, 1.0) var footprint_roughness: float = 0.3:
	set(v):
		footprint_roughness = v
		if is_inside_tree():
			_set_param("footprint_roughness", v)

var _material: Object  # Terrain3DMaterial


func _ready() -> void:
	_material = _find_terrain_material()
	if not _material:
		push_warning("SnowOverlay: Could not find Terrain3DMaterial")
		return
	# Load and apply the shader override from external file
	var shader := load("res://world/terrain/terrain_shader_override.gdshader") as Shader
	if shader:
		_material.set("shader_override", shader)
		print("SnowOverlay: Applied shader override from .gdshader file")
	else:
		push_warning("SnowOverlay: Could not load terrain_shader_override.gdshader")
	if not _material.get("shader_override_enabled"):
		_material.set("shader_override_enabled", true)
	_push_all_params()


func _push_all_params() -> void:
	if not _material:
		return
	_set_param("snow_enabled", enabled)
	_set_param("snow_amount", amount)
	_set_param("snow_altitude_start", altitude_start)
	_set_param("snow_altitude_full", altitude_full)
	_set_param("snow_slope_threshold", slope_threshold)
	_set_param("snow_noise_scale", noise_scale)
	_set_param("snow_color", Vector3(color.r, color.g, color.b))
	_set_param("snow_roughness", roughness)
	_set_param("snow_normal_flatten", normal_flatten)
	_set_param("snow_base_height", base_height)
	_set_param("footprint_color", Vector3(footprint_color.r, footprint_color.g, footprint_color.b))
	_set_param("footprint_roughness", footprint_roughness)


func _set_param(param_name: String, value: Variant) -> void:
	if not _material:
		_material = _find_terrain_material()
	if _material and _material.has_method("set_shader_param"):
		_material.set_shader_param(param_name, value)


func _find_terrain_material() -> Object:
	var parent := get_parent()
	if parent and parent.get_class() == "Terrain3D":
		var mat = parent.get("material")
		if mat:
			return mat
	if parent:
		for child in parent.get_children():
			if child.get_class() == "Terrain3D":
				var mat = child.get("material")
				if mat:
					return mat
	if not is_inside_tree():
		return null
	var root := get_tree().current_scene
	if root:
		return _search_terrain_material(root)
	return null


func _search_terrain_material(node: Node) -> Object:
	if node.get_class() == "Terrain3D":
		var mat = node.get("material")
		if mat:
			return mat
	for child in node.get_children():
		var found := _search_terrain_material(child)
		if found:
			return found
	return null
