shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform float glow = 0.0;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 base = albedo_color.rgb * tex.rgb * COLOR.rgb;
	ALBEDO = base;
	EMISSION = base * glow;
	ALPHA = tex.a * albedo_color.a * COLOR.a;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float wrap = clamp(dot(NORMAL, LIGHT) * 0.55 + 0.5, 0.0, 1.0);
	float cel = 0.55 + smoothstep(0.4, 0.72, wrap) * 0.45;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * cel;
}
