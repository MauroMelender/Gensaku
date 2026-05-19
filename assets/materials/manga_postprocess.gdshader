// ============================================================
//  GENSAKU — Manga Post-Process Shader v8.0
//  B/N limpio + outlines variables + color protagonista
// ============================================================

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture  : hint_depth_texture,  filter_nearest;

// ---------- BLANCO Y NEGRO ----------
uniform float ink_contrast      : hint_range(0.5, 4.0) = 1.6;
uniform float brightness        : hint_range(0.5, 2.0) = 1.0;

// ---------- BORDES ----------
uniform float edge_threshold     : hint_range(0.0, 1.0) = 0.06;
uniform float edge_thickness_min : hint_range(0.5, 3.0) = 0.8;
uniform float edge_thickness_max : hint_range(1.0, 5.0) = 2.6;
uniform float edge_var_scale     : hint_range(1.0, 20.0) = 6.0;

// ---------- PROTAGONISTA ----------
uniform vec4  protagonist_color   : source_color         = vec4(0.29, 0.56, 0.85, 1.0);
uniform float color_hue_range     : hint_range(0.0, 0.4) = 0.13;
uniform float color_sat_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float color_preserve      : hint_range(0.0, 1.0) = 0.88;

// ---------- VIÑETA ----------
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.28;

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

float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0*f);
	return mix(
		mix(hash(i), hash(i+vec2(1,0)), f.x),
		mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x),
		f.y
	);
}

float sobel(sampler2D tex, vec2 uv, float thick) {
	vec2 px = thick / vec2(textureSize(tex, 0));
	float tl=luminance(texture(tex,uv+px*vec2(-1,-1)).rgb);
	float tm=luminance(texture(tex,uv+px*vec2( 0,-1)).rgb);
	float tr=luminance(texture(tex,uv+px*vec2( 1,-1)).rgb);
	float ml=luminance(texture(tex,uv+px*vec2(-1, 0)).rgb);
	float mr=luminance(texture(tex,uv+px*vec2( 1, 0)).rgb);
	float bl=luminance(texture(tex,uv+px*vec2(-1, 1)).rgb);
	float bm=luminance(texture(tex,uv+px*vec2( 0, 1)).rgb);
	float br=luminance(texture(tex,uv+px*vec2( 1, 1)).rgb);
	float gx=-tl-2.0*ml-bl+tr+2.0*mr+br;
	float gy=-tl-2.0*tm-tr+bl+2.0*bm+br;
	return sqrt(gx*gx+gy*gy);
}

float sobel_d(sampler2D tex, vec2 uv, float thick) {
	vec2 px = thick / vec2(textureSize(tex, 0));
	float tl=texture(tex,uv+px*vec2(-1,-1)).r;
	float tm=texture(tex,uv+px*vec2( 0,-1)).r;
	float tr=texture(tex,uv+px*vec2( 1,-1)).r;
	float ml=texture(tex,uv+px*vec2(-1, 0)).r;
	float mr=texture(tex,uv+px*vec2( 1, 0)).r;
	float bl=texture(tex,uv+px*vec2(-1, 1)).r;
	float bm=texture(tex,uv+px*vec2( 0, 1)).r;
	float br=texture(tex,uv+px*vec2( 1, 1)).r;
	float gx=-tl-2.0*ml-bl+tr+2.0*mr+br;
	float gy=-tl-2.0*tm-tr+bl+2.0*bm+br;
	return sqrt(gx*gx+gy*gy)*10.0;
}

void fragment() {
	vec2 uv    = SCREEN_UV;
	vec3 scene = texture(screen_texture, uv).rgb;

	// Protagonista
	vec3  hsv     = rgb_to_hsv(scene);
	vec3  phsv    = rgb_to_hsv(protagonist_color.rgb);
	bool  is_hero = hue_dist(hsv.x, phsv.x) < color_hue_range
					&& hsv.y > color_sat_threshold;

	// B/N con contraste y brillo
	float lum = luminance(scene);
	lum = pow(clamp(lum * brightness, 0.0, 1.0), 1.0 / ink_contrast);
	vec3 manga = vec3(lum);

	// Bordes con grosor variable
	float vn    = noise(uv * edge_var_scale * 28.0) * 0.5 + 0.5;
	float thick = mix(edge_thickness_min, edge_thickness_max, vn);
	float ec    = sobel(screen_texture, uv, thick);
	float ed    = sobel_d(depth_texture, uv, thick);
	float edge  = smoothstep(edge_threshold, edge_threshold + 0.2, ec + ed);
	manga      *= (1.0 - edge);

	// Viñeta
	vec2  ctr = uv - 0.5;
	manga    *= clamp(1.0 - dot(ctr, ctr) * vignette_strength * 4.0, 0.0, 1.0);

	// Color protagonista
	ALBEDO = is_hero ? mix(manga, scene, hsv.y * color_preserve) : manga;
}
