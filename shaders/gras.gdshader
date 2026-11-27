shader_type spatial;
// Wiesenboden: Grün mit helleren und trockenen Flecken, dazu Erde.

#include "res://shaders/rauschen.gdshaderinc"

uniform vec3 gruen : source_color = vec3(0.30, 0.42, 0.16);
uniform vec3 gruen_hell : source_color = vec3(0.48, 0.58, 0.22);
uniform vec3 trocken : source_color = vec3(0.62, 0.56, 0.3);
uniform vec3 erde : source_color = vec3(0.36, 0.26, 0.16);

varying vec3 v_welt;

void vertex() {
	v_welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_welt.xz;
	float gross = fbm(vec3(p * 0.08, 0.0));
	float mittel = fbm(vec3(p * 0.45, 3.0));
	float fein = rauschen(vec3(p * 18.0, 7.0));
	vec3 c = mix(gruen, gruen_hell, smoothstep(0.35, 0.7, mittel));
	c = mix(c, trocken, smoothstep(0.58, 0.75, gross) * 0.7);
	float pfad = smoothstep(0.7, 0.82, fbm(vec3(p * 0.25, 9.0)));
	c = mix(c, erde, pfad * 0.8);
	c *= 0.85 + 0.3 * fein;
	ALBEDO = c;
	ROUGHNESS = 0.95;
	NORMAL = beule(VERTEX, NORMAL, fein * 0.01, 1.0);
}
