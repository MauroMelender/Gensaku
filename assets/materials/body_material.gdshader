shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// --- CAPA BASE ---
uniform sampler2D texture_base : source_color, filter_linear_mipmap, repeat_disable;

// --- CAPA DETALLE 1 ---
uniform sampler2D texture_detail_1 : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform float intensity_detail_1 : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_detail_1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- CAPA DETALLE 2 ---
uniform sampler2D texture_detail_2 : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform float intensity_detail_2 : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_detail_2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- PARÁMETROS FÍSICOS ---
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic  : hint_range(0.0, 1.0) = 0.0;



void fragment() {
	// Lectura de texturas
	vec4 base = texture(texture_base, UV);
	vec4 d1   = texture(texture_detail_1, UV);
	vec4 d2   = texture(texture_detail_2, UV);

	// Paso 1: Mezclar Base con Detalle 1
	float mask1 = d1.a * intensity_detail_1;
	vec3 layer1 = mix(base.rgb, d1.rgb * tint_detail_1.rgb, mask1);

	// Paso 2: Mezclar el resultado anterior con Detalle 2
	float mask2 = d2.a * intensity_detail_2;
	vec3 final_color = mix(layer1, d2.rgb * tint_detail_2.rgb, mask2);

	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
    
    // Si quieres que sea sólido y ver las texturas bien:
//	ALPHA = 1.0;
}