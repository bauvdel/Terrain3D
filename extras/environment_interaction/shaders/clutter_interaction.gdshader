// clutter_interaction.gdshader
// Vegetation shader with environment interaction support.
// Applied as MaterialOverride on Terrain3D mesh assets at runtime by
// FoliageInteractionApplicator. Replicates clutter_vegetation rendering
// plus viewport-stamp-based bending and trampling.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, shadows_disabled,
	specular_disabled;

// Textures — filled at runtime from the original scene material
uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform bool normal_enabled = false;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

// DayZ grass material parameters (from RVMAT files)
uniform vec4 ambient_color = vec4(1.0, 1.0, 0.5, 2.0);
uniform vec3 diffuse_color = vec3(0.5, 0.5, 0.3);

// Wind
uniform float wind_amplitude : hint_range(0.0, 1.0) = 0.15;
uniform float wind_frequency : hint_range(0.0, 5.0) = 0.13;
uniform float wind_phase1 : hint_range(0.0, 200.0) = 0.94;
uniform float wind_phase2 : hint_range(0.0, 200.0) = 50.5;
uniform float wind_height : hint_range(0.1, 5.0) = 0.6;

// Environment interaction — reads from the viewport stamp system
global uniform sampler2D detail_viewport_texture;
global uniform float detail_viewport_size;
global uniform vec3 detail_viewport_corner;
uniform float interaction_bend_strength : hint_range(0.0, 5.0) = 2.0;

varying vec3 mesh_normal;
varying float v_tamp;

void vertex() {
	mesh_normal = NORMAL;
	float h = clamp((VERTEX.y - 0.05) / max(wind_height, 0.1), 0.0, 1.0);

	// Get world position for interaction sampling
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Sample viewport stamp texture
	vec3 delta = world_pos - detail_viewport_corner;
	vec2 vp_uv = delta.xz / detail_viewport_size;
	bool in_bounds = (vp_uv == clamp(vp_uv, 0.0, 1.0));

	if (in_bounds) {
		// Edge fade to avoid hard cutoff at viewport boundary
		vec2 center = detail_viewport_corner.xz + vec2(detail_viewport_size * 0.5);
		float dist = length(world_pos.xz - center);
		float fade = smoothstep(detail_viewport_size * 0.5, detail_viewport_size * 0.4, dist);
		vec4 data = textureLod(detail_viewport_texture, vp_uv, 0.0);

		float tamp_value = clamp(data.g * fade, 0.0, 1.0);
		float blade_interact = tamp_value * h;
		if (blade_interact > 0.01) {
			// Push grass downward when trampled
			VERTEX.y -= blade_interact * interaction_bend_strength * 0.5;
		}
		v_tamp = tamp_value;
	} else {
		v_tamp = 0.0;
	}

	// Wind (reduced on trampled grass)
	float sway = h * wind_amplitude * (1.0 - v_tamp * 0.8);
	VERTEX.x += sin(VERTEX.x * wind_phase1 * 1.123 + TIME * wind_frequency * 6.28) * sway;
	VERTEX.z += sin(VERTEX.z * wind_phase2 * 0.913 + TIME * wind_frequency * 8.17) * sway;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 color = tex.rgb * color_tint.rgb;
	vec3 base = color * diffuse_color;

	// Darken trampled grass slightly
	ALBEDO = mix(base, base * 0.7, v_tamp * 0.5);

	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;

	METALLIC = 0.0;
	ROUGHNESS = 1.0;

	// Ambient provides base visibility (warm-tinted, intensity from .a)
	EMISSION = color * ambient_color.rgb * ambient_color.a * 0.25;

	if (normal_enabled) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
}

void light() {
	float NdotL = abs(dot(mesh_normal, LIGHT));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * NdotL * 8.0;
}
