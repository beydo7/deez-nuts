shader_type spatial;
// Baumkronen: knubbelige Kugeln, Herbstfarben, leichtes Wiegen im Wind.

#include "res://shaders/rauschen.gdshaderinc"

uniform vec3 farbe : source_color = vec3(0.75, 0.42, 0.12);
uniform vec3 farbe2 : source_color = vec3(0.45, 0.48, 0.15);
uniform float knubbel = 0.25;

varying vec3 v_welt;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = fbm(w * 0.9);
	VERTEX += NORMAL * (n - 0.5) * knubbel * 2.0;
	VERTEX.x += sin(TIME * 0.9 + w.y * 0.7 + w.x * 0.2) * 0.04 * max(VERTEX.y, 0.0);
	v_welt = w;
}

void fragment() {
	float n = fbm(v_welt * 2.2);
	float blatt = rauschen(v_welt * 14.0);
	vec3 c = mix(farbe2, farbe, smoothstep(0.3, 0.75, n));
	c *= 0.75 + 0.45 * blatt;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	BACKLIGHT = c * 0.4;
	NORMAL = beule(VERTEX, NORMAL, blatt * 0.05, 1.0);
}
