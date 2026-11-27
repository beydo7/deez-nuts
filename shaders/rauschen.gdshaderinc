// Gemeinsame Rausch-Funktionen für alle prozeduralen Materialien.
// Keine Texturen nötig: alles wird im Shader berechnet.

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Wertrauschen, glatt interpoliert, Bereich 0..1
float rauschen(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float g = hash13(i + vec3(1.0, 0.0, 1.0));
	float h = hash13(i + vec3(0.0, 1.0, 1.0));
	float k = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * rauschen(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s / 0.9375;
}

// Gratrauschen: scharfe Furchen (für Walnuss und Rinde)
float grate(vec3 p) {
	float s = 0.0;
	float a = 0.6;
	for (int i = 0; i < 3; i++) {
		float n = 1.0 - abs(rauschen(p) * 2.0 - 1.0);
		s += a * n * n;
		p = p * 2.1 + vec3(3.1, 1.3, 7.7);
		a *= 0.5;
	}
	return s;
}

// Zellen (Voronoi): x = Abstand zum nächsten Punkt, y = zum zweitnächsten, z = Zufallswert der Zelle
vec3 zellen(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = o + hash33(i + o) - f;
		float d = dot(r, r);
		if (d < d1) {
			d2 = d1;
			d1 = d;
			id = hash13(i + o);
		} else if (d < d2) {
			d2 = d;
		}
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}

// Bump-Mapping aus einer Höhe h (Mikkelsen 2010). Arbeitet im View-Space.
vec3 beule(vec3 vertex, vec3 normal, float h, float staerke) {
	vec3 dpdx = dFdx(vertex);
	vec3 dpdy = dFdy(vertex);
	vec3 r1 = cross(dpdy, normal);
	vec3 r2 = cross(normal, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * normal - grad * staerke);
}
