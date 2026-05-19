// ============================================================
//  GENSAKU — Character Shader v1.0
//  Aplicar al mesh del personaje (Ziel_TheCrystalChimera)
//  - Preserva el color azul original del personaje
//  - Outline fino propio independiente del post-process
//  - El resto del cuerpo en B/N para integrarse con la escena
// ============================================================

shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// ---------- TEXTURA ----------
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform bool      has_texture = false; // activar si el mesh tiene textura

// ---------- COLOR ----------
// Hue del color a preservar (azul = ~0.60 en HSV)
uniform float preserve_hue        : hint_range(0.0, 1.0) = 0.60;
uniform float preserve_hue_range  : hint_range(0.0, 0.3) = 0.12; // rango de hue a preservar
uniform float preserve_sat_min    : hint_range(0.0, 1.0) = 0.25; // saturación mínima para preservar
uniform float color_boost         : hint_range(0.5, 3.0) = 1.4;  // intensidad del color preservado

// ---------- B/N PARA EL RESTO ----------
uniform float bw_contrast   : hint_range(0.5, 3.0) = 1.4;
uniform float bw_brightness : hint_range(0.5, 2.0) = 1.1;

// ---------- OUTLINE FINO ----------
uniform float outline_thickness : hint_range(0.0, 0.1) = 0.001;
uniform vec4  outline_color     : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// ============================================================
//  HELPERS
// ============================================================
float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w-q.y)/(6.0*d+1e-10)), d/(q.x+1e-10), q.x);
}

float hue_dist(float a, float b) {
	float d = abs(a - b);
	return min(d, 1.0 - d);
}

// ============================================================
//  VERTEX — outline por expansión de normales
// ============================================================
void vertex() {
	// El outline se hace en un segundo pass expandiendo el mesh
	// por las normales — pero en Godot spatial se hace con
	// un material separado. Ver nota al pie.
}

// ============================================================
//  FRAGMENT
// ============================================================
void fragment() {
	// Color base — textura o blanco si no hay
	vec3 base;
	if (has_texture) {
		base = texture(texture_albedo, UV).rgb;
	} else {
		base = vec3(0.75); // gris claro base para el mesh sin textura
	}

	// Analizar el color en HSV
	vec3  hsv       = rgb_to_hsv(base);
	float h_diff    = hue_dist(hsv.x, preserve_hue);
	bool  is_blue   = h_diff < preserve_hue_range && hsv.y > preserve_sat_min;

	vec3 final_color;

	if (is_blue) {
		// Preservar y potenciar el color azul
		final_color = base * color_boost;
		final_color = clamp(final_color, 0.0, 1.0);
	} else {
		// Convertir a B/N con contraste
		float lum = luminance(base) * bw_brightness;
		lum = pow(clamp(lum, 0.0, 1.0), 1.0 / bw_contrast);
		final_color = vec3(lum);
	}

	ALBEDO = final_color;
}
