shader_type spatial;
render_mode cull_disabled;
// Grashalme im Wind (MultiMesh). UV.y = 0 an der Spitze, 1 am Boden.

#include "res://shaders/rauschen.gdshaderinc"

uniform vec3 unten : source_color = vec3(0.16, 0.26, 0.08);
uniform vec3 oben : source_color = vec3(0.55, 0.66, 0.25);
uniform float wind = 0.08;

varying float v_hoehe;
varying vec3 v_tint;

void vertex() {
	vec3 welt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float biege = (1.0 - UV.y);
	biege *= biege;
	float w = sin(TIME * 1.7 + welt.x * 0.6 + welt.z * 0.4) + 0.5 * sin(TIME * 3.1 + welt.x * 1.3);
	VERTEX.x += w * wind * biege;
	VERTEX.z += w * wind * 0.5 * biege;
	v_hoehe = 1.0 - UV.y;
	v_tint = COLOR.rgb;
}

void fragment() {
	vec3 c = mix(unten, oben, v_hoehe) * v_tint;
	ALBEDO = c;
	ROUGHNESS = 0.8;
	BACKLIGHT = c * 0.5;
}
