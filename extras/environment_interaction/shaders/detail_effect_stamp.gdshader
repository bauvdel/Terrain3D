// detail_effect_stamp.gdshader
// Renders interaction stamps into the detail effects viewport.
// Each stamp writes to a single RGB channel using blend_add.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, blend_add;

uniform sampler2D stamp_alpha : hint_roughness_r, repeat_disable;
instance uniform float stamp_opacity : hint_range(0.0, 1.0) = 1.0;
// 0 = R (footprints), 1 = G (foliage), 2 = B (reserved)
uniform int effect_channel : hint_range(0, 2, 1) = 1;
uniform float effect_weight : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 color = vec3(0.0);
	color[effect_channel] = texture(stamp_alpha, UV).r * stamp_opacity * effect_weight;
	ALBEDO = color;
}
