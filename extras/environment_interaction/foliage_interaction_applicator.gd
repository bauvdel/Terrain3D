class_name FoliageInteractionApplicator
extends Node

## Applies the interaction ShaderMaterial as MaterialOverride on Terrain3D
## grass/clutter mesh assets at runtime, enabling viewport-stamp-based bending.
##
## Add this as a child of (or sibling to) your Terrain3D node and configure
## terrain_path to point at it. On _ready it iterates every mesh asset and
## replaces its material with the clutter_interaction shader, copying texture
## uniforms from the original scene material.

## Path to the Terrain3D node.
@export var terrain_path: NodePath
## Which mesh asset IDs to apply interaction to. Empty = apply to ALL.
@export var mesh_asset_ids: Array[int] = []

const INTERACTION_SHADER := preload(
	"res://addons/terrain_3d/extras/environment_interaction/shaders/clutter_interaction.gdshader"
)


func _ready() -> void:
	# Defer to ensure Terrain3D has finished initializing
	call_deferred("_apply_materials")


func _apply_materials() -> void:
	var terrain := get_node_or_null(terrain_path)
	if not terrain:
		push_warning("FoliageInteractionApplicator: Terrain3D not found at '%s'" % terrain_path)
		return

	var assets = terrain.get("assets")
	if not assets:
		push_warning("FoliageInteractionApplicator: Terrain3D has no assets")
		return

	var mesh_count: int = assets.get_mesh_count()
	var applied := 0

	for i in range(mesh_count):
		var mesh_asset = assets.get_mesh_asset(i)
		if not mesh_asset:
			continue

		# Skip if we have a filter list and this ID isn't in it
		if not mesh_asset_ids.is_empty() and mesh_asset.get("id") not in mesh_asset_ids:
			continue

		# Skip if mesh asset is disabled
		if not mesh_asset.get("enabled"):
			continue

		# Only apply to clutter/grass assets (prefix "c_") unless explicitly listed
		var asset_name: String = mesh_asset.get("name")
		if mesh_asset_ids.is_empty() and not asset_name.begins_with("c_") and not asset_name.begins_with("l_"):
			continue

		var mat := _create_interaction_material(mesh_asset)
		if mat:
			mesh_asset.set("material_override", mat)
			applied += 1
			print("FoliageInteractionApplicator: Applied to mesh asset %d (%s)" % [
				i, mesh_asset.get("name")
			])

	print("FoliageInteractionApplicator: Applied interaction material to %d/%d mesh assets" % [
		applied, mesh_count
	])

	# Force the instancer to rebuild all MultiMesh instances with new materials
	if applied > 0:
		var instancer = terrain.get("instancer")
		if instancer and instancer.has_method("update_mmis"):
			instancer.update_mmis(-1, Vector2i.ZERO, true)
			print("FoliageInteractionApplicator: Forced instancer MMI rebuild")


func _create_interaction_material(mesh_asset) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = INTERACTION_SHADER

	# Try to copy textures from the original scene material
	var original_mat: Material = mesh_asset.get("material_override")
	if original_mat == null:
		# No override was set — Terrain3D extracts materials from the scene file.
		# We can try to get textures from the scene file's first mesh surface.
		original_mat = _extract_scene_material(mesh_asset)

	if original_mat is ShaderMaterial:
		_copy_shader_params(original_mat, mat)
	elif original_mat is StandardMaterial3D:
		_copy_standard_params(original_mat, mat)

	return mat


func _extract_scene_material(mesh_asset) -> Material:
	var scene: PackedScene = mesh_asset.get("scene_file")
	if not scene:
		return null

	var instance := scene.instantiate()
	var mat: Material = null

	# Find first MeshInstance3D and grab its surface material
	var meshes := _find_mesh_instances(instance)
	if not meshes.is_empty():
		var mi: MeshInstance3D = meshes[0]
		# Check surface override first, then mesh surface material
		mat = mi.get_surface_override_material(0)
		if not mat and mi.mesh:
			mat = mi.mesh.surface_get_material(0)

	instance.free()
	return mat


func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result


func _copy_shader_params(from: ShaderMaterial, to: ShaderMaterial) -> void:
	# Copy texture and color uniforms from the original clutter_vegetation shader
	var params := [
		"albedo_texture", "normal_texture", "normal_enabled",
		"color_tint", "alpha_scissor",
		"ambient_color", "diffuse_color",
		"wind_amplitude", "wind_frequency",
		"wind_phase1", "wind_phase2", "wind_height",
	]
	for param in params:
		var val = from.get_shader_parameter(param)
		if val != null:
			to.set_shader_parameter(param, val)


func _copy_standard_params(from: StandardMaterial3D, to: ShaderMaterial) -> void:
	# Map StandardMaterial3D properties to our shader uniforms
	if from.albedo_texture:
		to.set_shader_parameter("albedo_texture", from.albedo_texture)
	to.set_shader_parameter("color_tint", from.albedo_color)
	if from.normal_enabled and from.normal_texture:
		to.set_shader_parameter("normal_enabled", true)
		to.set_shader_parameter("normal_texture", from.normal_texture)
