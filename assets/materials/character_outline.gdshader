// ============================================================
//  GENSAKU — Character Outline Shader v1.0
//  Aplicar como SEGUNDO material en el mesh del personaje
//  Este shader solo dibuja el outline fino — funciona por
//  expansión de normales con cull_front (dibuja el reverso
//  del mesh expandido, creando el borde negro)
// ============================================================

shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

uniform float outline_thickness : hint_range(0.0, 0.02) = 0.004;
uniform vec4  outline_color     : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	// Expandir el mesh en dirección de las normales
	// Esto crea una "cáscara" ligeramente más grande que el mesh original
	// Al renderizarse con cull_front, solo se ve el borde expandido
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
