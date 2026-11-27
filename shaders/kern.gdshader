shader_type spatial;
// Nusskern: wachsig, leicht durchscheinend, mit Falten (Walnuss) oder glatt.

#include "res://shaders/rauschen.gdshaderinc"

uniform vec3 farbe : source_color = vec3(0.85, 0.68, 0.45);
uniform vec3 farbe2 : source_color = vec3(0.62, 0.42, 0.22);
uniform float radius = 0.04;
uniform float falten = 1.0;            // 1 = Walnuss-Hirn, 0 = glatt
uniform float gold = 0.0;
uniform bool instanzfarbe = false;

varying vec3 v_roh;
varying vec3 v_tint;

void vertex() {
	v_roh = VERTEX / radius;
	v_tint = instanzfarbe ? COLOR.rgb : vec3(1.0);
}

void fragment() {
	vec3 p = v_roh;
	float g = grate(p * 2.6) * falten + fbm(p * 5.0) * (1.0 - falten) * 0.4;
	float haut = fbm(p * 8.0);
	vec3 c = mix(farbe2, farbe, clamp(g * 0.9 + haut * 0.3, 0.0, 1.0));
	c *= v_tint;
	if (gold > 0.0) {
		c = mix(c, vec3(1.0, 0.8, 0.3), gold);
		METALLIC = gold * 0.8;
		EMISSION = vec3(1.0, 0.75, 0.25) * 0.15 * gold;
	}
	ALBEDO = c;
	ROUGHNESS = 0.5 - 0.15 * haut;
	SPECULAR = 0.55;
	BACKLIGHT = c * 0.35;
	NORMAL = beule(VERTEX, NORMAL, g * radius * 0.1, 1.0);
}
