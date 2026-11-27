shader_type spatial;
// Prozeduraler Putz / Stein / Erde: fleckige Grundfarbe mit feiner Körnung.

#include "res://shaders/rauschen.gdshaderinc"

uniform vec3 farbe : source_color = vec3(0.86, 0.78, 0.64);
uniform vec3 farbe2 : source_color = vec3(0.78, 0.69, 0.55);
uniform float flecken_skala = 1.2;
uniform float koernung = 60.0;
uniform float beule_staerke = 1.0;
uniform float rauheit = 0.92;
uniform float kacheln = 0.0;           // >0: Fliesen/Steinplatten mit dieser Kantenlänge
uniform vec3 fugenfarbe : source_color = vec3(0.35, 0.32, 0.28);
uniform float kiesel = 0.0;            // >0: lauter runde Knubbel (Nusshaufen) dieser Größe
uniform vec3 kiesel_a : source_color = vec3(0.72, 0.55, 0.35);
uniform vec3 kiesel_b : source_color = vec3(0.74, 0.47, 0.22);

varying vec3 v_welt;

void vertex() {
	v_welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = v_welt;
	float f = fbm(p * flecken_skala);
	float k = rauschen(p * koernung);
	vec3 c = mix(farbe2, farbe, smoothstep(0.3, 0.7, f));
	c *= 0.94 + 0.1 * k;
	float h = k * 0.4 + f * 0.6;
	if (kacheln > 0.0) {
		vec3 q = p / kacheln;
		vec3 zell = floor(q);
		vec3 fr = fract(q);
		float rand_x = min(fr.x, 1.0 - fr.x);
		float rand_z = min(fr.z, 1.0 - fr.z);
		float fug = smoothstep(0.0, 0.03, min(rand_x, rand_z));
		c *= 0.88 + 0.2 * hash13(zell);
		c = mix(fugenfarbe, c, fug);
		h += fug * 2.0;
	}
	if (kiesel > 0.0) {
		vec3 z = zellen(p / kiesel);
		float knubbel = 1.0 - smoothstep(0.0, 0.75, z.x);
		vec3 nuss = mix(kiesel_a, kiesel_b, step(0.55, z.z)) * (0.8 + 0.4 * hash11(z.z * 91.0));
		nuss *= 0.85 + 0.3 * rauschen(p / kiesel * 6.0);
		c = mix(fugenfarbe, nuss, smoothstep(0.05, 0.45, knubbel));
		h = knubbel * 3.0;
	}
	ALBEDO = c;
	ROUGHNESS = rauheit;
	NORMAL = beule(VERTEX, NORMAL, h * 0.003 * beule_staerke, 1.0);
}
