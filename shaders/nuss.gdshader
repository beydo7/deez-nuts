shader_type spatial;
// Nussschale: Muster je Sorte, Risse wachsen mit dem Druck (Uniform "riss").

#include "res://shaders/rauschen.gdshaderinc"

uniform vec3 farbe : source_color = vec3(0.62, 0.44, 0.26);
uniform vec3 farbe2 : source_color = vec3(0.4, 0.27, 0.15);
uniform int art = 1;                   // 0 hasel 1 wal 2 mandel 3 pekan 4 para 5 macadamia 9 schale-innen
uniform float radius = 0.045;
uniform float riss : hint_range(0.0, 1.0) = 0.0;
uniform float gold : hint_range(0.0, 1.0) = 0.0;
uniform float faul : hint_range(0.0, 1.0) = 0.0;
uniform float saat = 0.0;
uniform bool instanzfarbe = false;
uniform float glanz = 0.0;
uniform vec3 achse = vec3(1.0, 0.0, 0.0);   // Richtung, aus der gedrückt wird

varying vec3 v_roh;
varying vec3 v_tint;

void vertex() {
	v_roh = VERTEX / radius;
	v_tint = instanzfarbe ? COLOR.rgb : vec3(1.0);
}

void fragment() {
	vec3 q = v_roh;
	vec3 p = q + vec3(saat * 7.31, saat * 3.17, saat * 5.03);
	float h = 0.0;
	vec3 c = farbe;
	float rau = 0.78;
	if (art == 1) {
		vec3 w = p * 2.4 + vec3(fbm(p * 1.7), fbm(p * 1.7 + 4.0), fbm(p * 1.7 + 8.0)) * 1.2;
		float l1 = 1.0 - abs(rauschen(w) * 2.0 - 1.0);
		float l2 = 1.0 - abs(rauschen(w * 2.3 + 3.0) * 2.0 - 1.0);
		float furche = smoothstep(0.7, 0.96, l1) * 0.85 + smoothstep(0.8, 0.98, l2) * 0.25;
		furche = clamp(furche, 0.0, 1.0);
		float flecken = fbm(p * 3.0);
		c = mix(farbe, farbe * 0.9, flecken);
		c = mix(c, farbe2, furche * 0.7);
		h = -furche + flecken * 0.3;
		float naht = exp(-q.x * q.x * 90.0);
		c = mix(c, farbe * 0.9, naht * 0.4);
		h += naht * 1.2;
	} else if (art == 0) {
		float s = fbm(vec3(p.x * 7.0, p.y * 0.9, p.z * 7.0));
		c = mix(farbe2, farbe, smoothstep(0.3, 0.75, s));
		float kappe = smoothstep(0.55, 0.85, q.y);
		c = mix(c, farbe * vec3(1.18, 1.12, 1.0) * (0.85 + 0.3 * rauschen(p * 30.0)), kappe);
		float narbe = smoothstep(-0.62, -0.85, q.y);
		c = mix(c, vec3(0.62, 0.55, 0.44), narbe);
		h = s * 0.3 + kappe * rauschen(p * 30.0);
		rau = mix(0.45, 0.9, kappe);
	} else if (art == 2) {
		vec3 z = zellen(p * 5.5);
		float grube = smoothstep(0.05, 0.4, z.x);
		c = mix(farbe2, farbe, grube * 0.75 + 0.25 * fbm(p * 3.0));
		h = grube;
		rau = 0.9;
	} else if (art == 3) {
		float s = fbm(vec3(p.x * 2.5, p.y * 2.5, p.z * 0.5));
		float spritzer = smoothstep(0.7, 0.76, fbm(p * 4.0)) * 0.5;
		c = mix(farbe, farbe2, smoothstep(0.45, 0.72, s));
		c = mix(c, farbe2 * 0.6, spritzer);
		h = s * 0.2;
		rau = 0.42;
	} else if (art == 4) {
		float g = grate(p * 1.4);
		c = mix(farbe2, farbe, g * 0.8);
		h = g;
		rau = 0.85;
	} else if (art == 5) {
		float s = fbm(p * 3.0);
		c = mix(farbe2, farbe, s);
		float naht = exp(-q.x * q.x * 160.0);
		c = mix(c, farbe * 1.25, naht * 0.6);
		h = s * 0.15;
		rau = 0.35;
	} else if (art == 9) {
		float s = fbm(p * 4.0);
		c = mix(farbe2, farbe, s);
		h = s * 0.5;
		rau = 0.95;
	}
	// Risse: Voronoi-Kanten, die von den Backen (±x) zur Mitte wandern
	if (riss > 0.001) {
		vec3 qw = q * 1.5 + (vec3(fbm(q * 3.0 + saat), fbm(q * 3.0 + 5.0), fbm(q * 3.0 + 9.0)) - 0.5) * 0.9;
		vec3 z = zellen(qw + vec3(saat * 3.0));
		float kante = z.y - z.x;
		float front = abs(dot(q, achse)) - (1.05 - riss * 1.35);
		float maske = smoothstep(-0.3, 0.15, front) * step(0.25, z.z);
		float breite = 0.008 + riss * 0.045;
		float linie = (1.0 - smoothstep(0.0, breite, kante)) * maske;
		c = mix(c, vec3(0.05, 0.03, 0.02), linie * 0.95);
		h -= linie * 1.5;
	}
	if (faul > 0.0) {
		float schimmel = smoothstep(0.45, 0.65, fbm(p * 3.5));
		c = mix(c, mix(vec3(0.22, 0.27, 0.12), vec3(0.55, 0.62, 0.45), schimmel), faul);
	}
	c *= v_tint;
	if (gold > 0.0) {
		c = mix(c, vec3(1.0, 0.7, 0.16) * (0.85 + 0.3 * fbm(p * 3.0)), gold);
		METALLIC = gold * 0.75;
		rau = mix(rau, 0.22, gold);
		float funkeln = pow(rauschen(p * 9.0 + vec3(TIME * 2.0)), 12.0) * 6.0;
		EMISSION = vec3(1.0, 0.7, 0.2) * (0.35 + funkeln) * gold;
	}
	ALBEDO = c;
	ROUGHNESS = mix(rau, 0.25, glanz);
	NORMAL = beule(VERTEX, NORMAL, h * radius * 0.06, 1.0);
}
