shader_type spatial;
render_mode cull_disabled, shadows_disabled, unshaded;
// Flügelschlag für Vögel und Schmetterlinge (MultiMesh).
// UV.x = 0 am Körper, 1 an der Flügelspitze.
// INSTANCE_CUSTOM: x = Phase, y = Ausschlag, z = Tempo, w = Grundstellung (Flügel angehoben).

varying vec3 v_farbe;

void vertex() {
	float schlag = sin(TIME * INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.x * 6.283);
	VERTEX.y += UV.x * (INSTANCE_CUSTOM.w + INSTANCE_CUSTOM.y * schlag);
	VERTEX.x *= 1.0 - UV.x * 0.25 * abs(schlag);
	v_farbe = COLOR.rgb;
}

void fragment() {
	ALBEDO = v_farbe;
}
