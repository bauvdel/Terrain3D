// detail_effects_library.gdshaderinc
// Shared sampling function for the detail effects viewport stamp system.
// Include this in any shader that needs to read interaction data.
//
// Channel layout:
//   R = terrain deformation (footprints in snow/mud)
//   G = foliage bending (grass, small plants)
//   B = reserved (water, future)

global uniform sampler2D detail_viewport_texture;
global uniform float detail_viewport_size;
global uniform vec3 detail_viewport_corner;

// Returns interaction data at a world position.
// RGB = per-channel interaction intensity, A = edge fade factor (1.0 at center, 0.0 at edge).
// Returns vec4(0.0) if world_position is outside the viewport area.
vec4 sample_detail_effects(vec3 world_position) {
	vec3 delta = world_position - detail_viewport_corner;
	vec2 uv = delta.xz / detail_viewport_size;
	// Early-out if outside viewport bounds
	if (uv != clamp(uv, 0.0, 1.0)) {
		return vec4(0.0);
	}
	// Edge fade: smoothstep from full radius to 80% radius
	vec2 center = detail_viewport_corner.xz + vec2(detail_viewport_size * 0.5);
	float dist = length(world_position.xz - center);
	float fade = smoothstep(detail_viewport_size * 0.5, detail_viewport_size * 0.4, dist);
	vec4 data = textureLod(detail_viewport_texture, uv, 0.0);
	return vec4(data.rgb * fade, fade);
}

// Returns the slope direction at a point by sampling neighbors.
// Used by grass shader to determine which direction to bend.
// center_val: already-sampled value at world_position (avoids redundant texture read)
// channel: which RGB channel to read (0=R, 1=G, 2=B)
vec3 sample_detail_slope(vec3 world_position, float center_val, int channel, float sample_range) {
	float north_val = sample_detail_effects(world_position + vec3(0.0, 0.0, sample_range))[channel];
	float east_val = sample_detail_effects(world_position + vec3(sample_range, 0.0, 0.0))[channel];

	vec3 to_north = vec3(0.0, north_val - center_val, sample_range);
	vec3 to_east = vec3(sample_range, east_val - center_val, 0.0);
	vec3 slope = cross(to_north, to_east);
	slope.y = 0.0;
	return length(slope) > 0.001 ? normalize(slope) : vec3(0.0);
}
