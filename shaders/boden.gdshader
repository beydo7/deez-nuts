shader_type spatial;
// Talboden: Wiese mit Flecken, darin Wege, nasses Ufer, Waldboden mit Laub und Fels an steilen Stellen.
// Masken kommen aus den Eckpunktfarben: R = Weg, G = Ufer, B = Wald.

#include "res://shaders/rauschen.gdshaderinc"

uniform vec3 gruen : source_color = vec3(0.30, 0.42, 0.16);
uniform vec3 gruen_hell : source_color = vec3(0.47, 0.57, 0.22);
uniform vec3 trocken : source_color = vec3(0.60, 0.54, 0.30);
uniform vec3 erde : source_color = vec3(0.42, 0.31, 0.19);
uniform vec3 kies : source_color = vec3(0.55, 0.49, 0.40);
uniform vec3 schlamm : source_color = vec3(0.24, 0.19, 0.13);
uniform vec3 laub_a : source_color = vec3(0.50, 0.28, 0.10);
uniform vec3 laub_b : source_color = vec3(0.66, 0.46, 0.16);
uniform vec3 fels : source_color = vec3(0.45, 0.42, 0.38);
uniform vec3 moos : source_color = vec3(0.26, 0.34, 0.13);

varying vec3 v_welt;
varying vec4 v_maske;
varying float v_hang;

void vertex() {
	v_welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_maske = COLOR;
	v_hang = 1.0 - NORMAL.y;
}

void fragment() {
	vec2 p = v_welt.xz;
	float gross = fbm(vec3(p * 0.06, 0.0));
	float mittel = fbm(vec3(p * 0.42, 3.0));
	float fein = rauschen(vec3(p * 16.0, 7.0));
	float krumen = rauschen(vec3(p * 5.0, 11.0));

	// Wiese
	vec3 c = mix(gruen, gruen_hell, smoothstep(0.35, 0.7, mittel));
	c = mix(c, trocken, smoothstep(0.6, 0.78, gross) * 0.6);

	// Waldboden: Laub in zwei Tönen, mit Moosflecken
	float wald = smoothstep(0.1, 0.9, v_maske.b + (mittel - 0.5) * 0.4);
	vec3 laub = mix(laub_a, laub_b, smoothstep(0.3, 0.7, krumen));
	laub = mix(laub, moos, smoothstep(0.62, 0.75, mittel) * 0.7);
	c = mix(c, laub, wald * 0.85);

	// Weg: ausgetretene Erde mit Kieseln, ausgefranster Rand
	float rand = (mittel - 0.5) * 0.5 + (fein - 0.5) * 0.25;
	float weg = smoothstep(0.25, 0.55, v_maske.r + rand);
	vec3 wegfarbe = mix(erde, kies, smoothstep(0.72, 0.8, fein) * 0.8);
	wegfarbe *= 0.9 + 0.2 * krumen;
	c = mix(c, wegfarbe, weg);

	// Ufer: dunkler, nasser Grund
	float ufer = smoothstep(0.2, 0.7, v_maske.g + rand * 0.5);
	vec3 uferfarbe = mix(schlamm, kies * 0.8, smoothstep(0.6, 0.75, krumen));
	c = mix(c, uferfarbe, ufer);

	// Steile Stellen: Fels mit Moos an der Oberkante
	float hang = smoothstep(0.32, 0.5, v_hang + (fein - 0.5) * 0.08);
	vec3 felsfarbe = fels * (0.8 + 0.35 * mittel);
	felsfarbe = mix(felsfarbe, moos, smoothstep(0.55, 0.7, gross) * 0.5);
	c = mix(c, felsfarbe, hang);

	c *= 0.86 + 0.28 * fein;
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.55, ufer * 0.8);
	SPECULAR = mix(0.4, 0.6, ufer);
	NORMAL = beule(VERTEX, NORMAL, fein * (0.01 + weg * 0.01 + hang * 0.03), 1.0);
}
