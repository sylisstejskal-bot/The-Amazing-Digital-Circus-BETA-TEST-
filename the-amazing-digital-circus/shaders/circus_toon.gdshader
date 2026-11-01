shader_type spatial;
render_mode cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform float glow = 0.0;
uniform float vertex_color_amount = 1.0;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 paint = mix(vec3(1.0), COLOR.rgb, vertex_color_amount);
	vec3 base = albedo_color.rgb * tex.rgb * paint;
	ALBEDO = base;
	EMISSION = base * glow;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float cel = 0.72;
	if (ndotl > 0.35) {
		cel = 1.0;
	}
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * cel;
}
