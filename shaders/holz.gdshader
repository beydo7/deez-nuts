shader_type spatial;
// Prozedurales Holz: Jahresringe, feine Maserung, optional Dielen mit Fugen.

#include "res://shaders/rauschen.gdshaderinc"

uniform vec3 farbe_hell : source_color = vec3(0.72, 0.52, 0.32);
uniform vec3 farbe_dunkel : source_color = vec3(0.45, 0.29, 0.16);
uniform float ringdichte = 7.0;
uniform float skala = 1.0;
uniform float dielen_breite = 0.0;     // 0 = keine Dielen
uniform float dielen_laenge = 1.6;
uniform float fuge = 0.012;
uniform float lack = 0.0;              // 0 = matt, 1 = glänzend lackiert
uniform bool welt_koordinaten = false;
uniform bool uv_koordinaten = false;   // Blender-Modelle: Maserkoordinaten liegen in UV (längs, quer) und UV2 (quer, Zufall je Brett)
uniform float beule_staerke = 1.0;
uniform float abnutzung = 0.0;         // hellere, abgewetzte Stellen

varying vec3 v_pos;
varying float v_zufall;

void vertex() {
	v_pos = welt_koordinaten ? (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz : VERTEX;
	v_zufall = 0.5;
	if (uv_koordinaten) {
		v_pos = vec3(UV.x, UV.y, UV2.x);
		v_zufall = UV2.y;
	}
}

void fragment() {
	vec3 p = v_pos * skala;
	float brett = 0.0;
	float fugen = 1.0;
	float brett_zufall = 0.5;
	if (dielen_breite > 0.0) {
		float z = p.z / dielen_breite;
		brett = floor(z);
		float fz = fract(z);
		brett_zufall = hash11(brett * 7.13 + 1.0);
		float x = p.x / dielen_laenge + brett_zufall * 3.0;
		float stoss = floor(x);
		float fx = fract(x);
		brett_zufall = hash11(brett * 7.13 + stoss * 3.7 + 1.0);
		float fb = fuge / dielen_breite;
		float fl = fuge / dielen_laenge;
		fugen = smoothstep(0.0, fb, fz) * smoothstep(1.0, 1.0 - fb, fz) * smoothstep(0.0, fl, fx) * smoothstep(1.0, 1.0 - fl, fx);
		p += vec3(brett_zufall * 13.0, brett_zufall * 5.0, brett_zufall * 11.0);
	}
	float verzug = fbm(p * vec3(0.35, 2.2, 2.2)) * 0.8;
	float r = length(p.yz + vec2(4.0, 2.5)) + verzug;
	float ringe = fract(r * ringdichte);
	ringe = smoothstep(0.0, 0.25, ringe) * smoothstep(1.0, 0.55, ringe);
	float maser = fbm(p * vec3(0.6, 30.0, 30.0));
	float flecken = fbm(p * 1.3);
	float t = clamp(ringe * 0.55 + maser * 0.35 + flecken * 0.25 - 0.08, 0.0, 1.0);
	vec3 farbe = mix(farbe_dunkel, farbe_hell, t);
	farbe *= 0.86 + 0.28 * brett_zufall;
	farbe *= 0.84 + 0.32 * v_zufall;
	farbe = mix(farbe, farbe * 1.25, abnutzung * smoothstep(0.55, 0.8, flecken));
	farbe *= mix(0.25, 1.0, fugen);
	ALBEDO = farbe;
	ROUGHNESS = mix(mix(0.72, 0.88, maser), 0.32, lack);
	SPECULAR = mix(0.35, 0.55, lack);
	float h = maser * 0.6 + ringe * 0.25 + fugen * 1.5;
	NORMAL = beule(VERTEX, NORMAL, h * 0.004 * beule_staerke, 1.0);
}
