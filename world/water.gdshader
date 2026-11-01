// Océan low-poly animé.
// Vagues calculées dans le vertex shader, couleur par fresnel dans le fragment.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.16, 0.55, 0.62);
uniform vec3 deep_color : source_color = vec3(0.02, 0.16, 0.30);
uniform vec3 sky_tint : source_color = vec3(0.75, 0.88, 0.95);
uniform float wave_speed = 0.9;
uniform float wave_height = 0.22;
uniform float wave_scale = 0.35;
uniform float transparency : hint_range(0.0, 1.0) = 0.86;

varying float v_wave;

void vertex() {
	vec2 p = VERTEX.xz * wave_scale;
	float w = sin(p.x * 1.7 + TIME * wave_speed) * 0.5
		+ sin(p.y * 2.3 + TIME * wave_speed * 1.3) * 0.3
		+ sin((p.x + p.y) * 1.1 + TIME * wave_speed * 0.7) * 0.2;
	VERTEX.y += w * wave_height;
	v_wave = w;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float fresnel = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.5);
	vec3 water = mix(deep_color, shallow_color, clamp(v_wave * 0.5 + 0.5, 0.0, 1.0));
	ALBEDO = mix(water, sky_tint, fresnel * 0.6);
	ROUGHNESS = mix(0.06, 0.35, fresnel);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = transparency;
}
