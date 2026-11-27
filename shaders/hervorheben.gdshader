shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
// Leuchtender Rand um das, worauf man gerade schaut (als material_overlay).

uniform vec4 farbe : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float staerke = 0.55;

void fragment() {
	float rand = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float puls = 0.75 + 0.25 * sin(TIME * 6.0);
	float a = (pow(rand, 2.2) * 1.6 + 0.08) * staerke * puls;
	ALBEDO = farbe.rgb * a;
}
