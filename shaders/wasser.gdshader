shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// Bachwasser: läuft entlang der UV (v = Meter flussabwärts), wird mit der Tiefe dunkler,
// schäumt am Ufer und am Wasserfall. Keine Spiegelung, nur Himmel und Glanz.

#include "res://shaders/rauschen.gdshaderinc"

uniform sampler2D tiefe : hint_depth_texture, filter_linear;
uniform vec3 flach : source_color = vec3(0.42, 0.52, 0.42);
uniform vec3 tief : source_color = vec3(0.09, 0.2, 0.22);
uniform float tempo = 0.55;
uniform float schaum_staerke = 0.0;   // 1 = Wasserfall
uniform float wellen = 1.0;

varying vec3 v_welt;

float wellenhoehe(vec2 uv, float t) {
	float a = rauschen(vec3(uv.x * 2.2, uv.y * 0.9 - t, 0.0));
	float b = rauschen(vec3(uv.x * 4.1 + 3.0, uv.y * 1.7 - t * 1.6, 5.0));
	float c = rauschen(vec3(uv.x * 9.0 + 7.0, uv.y * 3.5 - t * 2.3, 9.0));
	return a * 0.55 + b * 0.3 + c * 0.15;
}

void vertex() {
	v_welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * tempo;
	vec2 uv = UV;
	float e = 0.06;
	float h0 = wellenhoehe(uv, t);
	float hx = wellenhoehe(uv + vec2(e, 0.0), t);
	float hy = wellenhoehe(uv + vec2(0.0, e), t);
	vec3 n = normalize(vec3((h0 - hx) * 2.2 * wellen, 1.0, (h0 - hy) * 2.2 * wellen));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Wassertiefe unter diesem Pixel
	float d = texture(tiefe, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 sicht = INV_PROJECTION_MATRIX * ndc;
	sicht.xyz /= sicht.w;
	float dicke = max(0.0, -sicht.z + VERTEX.z);
	float a = max(clamp(dicke * 2.2, 0.0, 1.0), schaum_staerke * 0.85);

	// Schaum: am Ufer, an Steinen und am Wasserfall
	float muster = rauschen(vec3(uv.x * 6.0, uv.y * 2.5 - t * 2.5, 2.0));
	float schaum = (1.0 - smoothstep(0.0, 0.12, dicke)) * smoothstep(0.35, 0.7, muster);
	schaum = max(schaum, schaum_staerke * smoothstep(0.25, 0.65, muster + 0.2));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);

	vec3 c = mix(flach, tief, a);
	c = mix(c, vec3(0.92, 0.95, 0.93), schaum * 0.85);
	ALBEDO = c;
	ALPHA = clamp(mix(0.35, 0.88, a) + schaum * 0.5 + fresnel * 0.3, 0.0, 1.0);
	ROUGHNESS = mix(0.06, 0.6, schaum);
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
