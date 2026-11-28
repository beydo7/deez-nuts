class_name Nussmodelle
extends RefCounted
## Baut die Nussformen aus Code: ganze Nüsse, Kernhälften, Schalenhälften, Bruchstücke.
## Jede Sorte hat ihre eigene Silhouette, die Feinheiten (Furchen, Risse) macht der Shader.

static var _cache := {}
static var _rausch: FastNoiseLite


static func _noise() -> FastNoiseLite:
	if _rausch == null:
		_rausch = FastNoiseLite.new()
		_rausch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_rausch.frequency = 1.0
	return _rausch


## Ganze Nuss. detail: 2 = nah (Knacker), 1 = normal, 0 = Berg (wenige Dreiecke)
static func ganz(id: String, variante := 0, detail := 1) -> ArrayMesh:
	var k := "ganz|%s|%d|%d" % [id, variante, detail]
	if not _cache.has(k):
		# 3 = grob, für Nüsse in der Tiefe des Bergs und in der Ferne
		var ringe: int = [7, 14, 22, 4][detail]
		var segmente: int = [10, 22, 34, 7][detail]
		var form := func(d: Vector3) -> Vector3: return _nuss_form(id, d, variante)
		_cache[k] = _kugel(ringe, segmente, form, Data.NUESSE[id].groesse)
	return _cache[k]


## Kernhälfte: flache Seite unten, gewölbte Seite oben.
static func kernhaelfte(id: String, variante := 0) -> ArrayMesh:
	var k := "kern|%s|%d" % [id, variante]
	if not _cache.has(k):
		var r: float = Data.NUESSE[id].groesse * 0.86
		var falten: float = Data.NUESSE[id].falten
		var form := func(d: Vector3) -> Vector3:
			var v := _nuss_form(id, d, variante + 17) * Vector3(1.0, 0.9, 1.0)
			if falten > 0.5:
				# zwei Hirnlappen mit Furche in der Mitte
				v *= 1.0 - 0.16 * exp(-d.x * d.x * 50.0) * clampf(d.y * 2.0, 0.0, 1.0)
				v *= 1.0 + 0.05 * sin(d.z * 14.0 + d.x * 9.0) * d.y
			return v
		_cache[k] = _kuppel(form, r, false)
	return _cache[k]


## Leere Schalenhälfte (Außenseite Schale, Innenseite hell).
static func schalenhaelfte(id: String, variante := 0) -> ArrayMesh:
	var k := "schale|%s|%d" % [id, variante]
	if not _cache.has(k):
		var r: float = Data.NUESSE[id].groesse
		var form := func(d: Vector3) -> Vector3: return _nuss_form(id, d, variante)
		_cache[k] = _kuppel(form, r, true)
	return _cache[k]


## Unregelmäßiges Bruchstück vom Kern.
static func bruchstueck(id: String, variante := 0) -> ArrayMesh:
	var k := "bruch|%s|%d" % [id, variante]
	if not _cache.has(k):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(k)
		var dellen: Array = []
		for i in 5:
			dellen.append([Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.25, 0.5)])
		var form := func(d: Vector3) -> Vector3:
			var f := 1.0
			for dl in dellen:
				var a: float = maxf(0.0, d.dot(dl[0]) - 0.35)
				f -= a * dl[1] * 1.6
			return d * Vector3(1.0, 0.7, 0.85) * maxf(f, 0.35)
		_cache[k] = _kugel(5, 8, form, Data.NUESSE[id].groesse * 0.42)
	return _cache[k]


## Kleiner Schalensplitter (für Partikel).
static func splitter() -> ArrayMesh:
	if not _cache.has("splitter"):
		var form := func(d: Vector3) -> Vector3: return d * Vector3(1.0, 0.25, 0.7)
		_cache["splitter"] = _kugel(3, 5, form, 0.008)
	return _cache["splitter"]


# --- Formen -------------------------------------------------------------------
static func _nuss_form(id: String, d: Vector3, variante: int) -> Vector3:
	var n := _noise()
	n.seed = variante * 31 + 7
	var info: Dictionary = Data.NUESSE[id]
	var v := d
	match id:
		"hasel":
			v = d * Vector3(1.0, 1.0, 0.96)
			if d.y > 0.0:
				v *= 1.0 + 0.22 * pow(d.y, 3.0)
				v.x *= 1.0 - 0.18 * pow(d.y, 2.0)
				v.z *= 1.0 - 0.18 * pow(d.y, 2.0)
			if d.y < -0.7:
				v.y = lerpf(v.y, -0.72, 0.7)
			v *= 1.0 + n.get_noise_3dv(d * 2.0) * 0.03
		"wal":
			v = d * Vector3(0.98, 1.06, 1.0)
			v *= 1.0 + 0.07 * exp(-d.x * d.x * 140.0)
			v *= 1.0 + n.get_noise_3dv(d * 3.2) * 0.055 + absf(n.get_noise_3dv(d * 7.0 + Vector3(5, 1, 2))) * -0.04
			v.y *= 1.0 + 0.1 * pow(maxf(d.y, 0.0), 8.0)
		"mandel":
			v = d * Vector3(0.62, 0.42, 1.2)
			var spitz: float = maxf(d.z, 0.0)
			v.x *= 1.0 - 0.45 * spitz * spitz
			v.y *= 1.0 - 0.35 * spitz * spitz
			v *= 1.0 + n.get_noise_3dv(d * 2.5) * 0.04
		"pekan":
			v = d * Vector3(0.7, 0.7, 1.32)
			var ende := d.z * d.z
			v.x *= 1.0 - 0.3 * ende * ende
			v.y *= 1.0 - 0.3 * ende * ende
			v *= 1.0 + n.get_noise_3dv(d * 2.0) * 0.025
		"para":
			var w := atan2(d.y, d.x)
			var drei := 1.0 + 0.2 * cos(3.0 * w + PI * 0.5)
			v = Vector3(d.x * drei * 0.72, d.y * drei * 0.72, d.z * 1.32)
			var ende2 := d.z * d.z
			v.x *= 1.0 - 0.35 * ende2 * ende2
			v.y *= 1.0 - 0.35 * ende2 * ende2
			v *= 1.0 + n.get_noise_3dv(d * 4.0) * 0.05
		"macadamia":
			v = d * (1.0 + 0.03 * exp(-d.x * d.x * 200.0) + n.get_noise_3dv(d * 1.5) * 0.015)
		_:
			v = d * Vector3(info.form)
	return v


# --- Gitter -------------------------------------------------------------------
## Geschlossene Kugel mit verformten Richtungen. Pole als einzelne Punkte, keine Nahtkante.
static func _kugel(ringe: int, segmente: int, form: Callable, radius: float) -> ArrayMesh:
	var pos := PackedVector3Array()
	var idx := PackedInt32Array()
	pos.append(form.call(Vector3.UP) * radius)
	for i in range(1, ringe):
		var theta := PI * float(i) / float(ringe)
		for j in segmente:
			var phi := TAU * float(j) / float(segmente)
			var d := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			pos.append(form.call(d) * radius)
	pos.append(form.call(Vector3.DOWN) * radius)
	var unten := pos.size() - 1
	for j in segmente:
		var j2 := (j + 1) % segmente
		idx.append_array([0, 1 + j, 1 + j2])
	for i in range(ringe - 2):
		var a := 1 + i * segmente
		var b := a + segmente
		for j in segmente:
			var j2 := (j + 1) % segmente
			idx.append_array([a + j, b + j, b + j2, a + j, b + j2, a + j2])
	var letzte := 1 + (ringe - 2) * segmente
	for j in segmente:
		var j2 := (j + 1) % segmente
		idx.append_array([unten, letzte + j2, letzte + j])
	return _mesh_aus([[pos, idx, Vector3.ZERO, 1.0]])


## Halbe Kugel (y >= 0). hohl = true: Schale mit Innenseite und Rand, sonst flacher Boden.
static func _kuppel(form: Callable, radius: float, hohl: bool) -> ArrayMesh:
	var ringe := 9
	var segmente := 24
	var aussen := PackedVector3Array()
	var ai := PackedInt32Array()
	aussen.append(form.call(Vector3.UP) * radius)
	for i in range(1, ringe + 1):
		var theta := PI * 0.5 * float(i) / float(ringe)
		for j in segmente:
			var phi := TAU * float(j) / float(segmente)
			var d := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			aussen.append(form.call(d) * radius)
	for j in segmente:
		ai.append_array([0, 1 + j, 1 + (j + 1) % segmente])
	for i in range(ringe - 1):
		var a := 1 + i * segmente
		var b := a + segmente
		for j in segmente:
			var j2 := (j + 1) % segmente
			ai.append_array([a + j, b + j, b + j2, a + j, b + j2, a + j2])
	var rand_start := 1 + (ringe - 1) * segmente
	var teile: Array = [[aussen, ai, Vector3.ZERO, 1.0]]
	if hohl:
		var innen := PackedVector3Array()
		for p in aussen:
			innen.append(Vector3(p.x * 0.86, p.y * 0.8, p.z * 0.86))
		var ii := PackedInt32Array()
		for t in range(0, ai.size(), 3):
			ii.append_array([ai[t], ai[t + 1], ai[t + 2]])
		# Rand: Ring zwischen äußerem und innerem Rand
		var rand := PackedVector3Array()
		var ri := PackedInt32Array()
		for j in segmente:
			rand.append(aussen[rand_start + j])
			rand.append(innen[rand_start + j])
		for j in segmente:
			var j2 := (j + 1) % segmente
			ri.append_array([j * 2, j2 * 2, j2 * 2 + 1, j * 2, j2 * 2 + 1, j * 2 + 1])
		teile[0].append(0)
		teile.append([innen, ii, Vector3.ZERO, -1.0, 1])
		teile.append([rand, ri, Vector3(0, radius * 3.0, 0), 1.0, 1])
	else:
		var boden := PackedVector3Array()
		var bi := PackedInt32Array()
		boden.append(Vector3.ZERO)
		for j in segmente:
			boden.append(aussen[rand_start + j])
		for j in segmente:
			bi.append_array([0, 1 + (j + 1) % segmente, 1 + j])
		teile.append([boden, bi, Vector3(0, radius * 3.0, 0), 1.0])
	return _mesh_aus(teile)


## Baut ein ArrayMesh aus Teilen [positionen, indizes, mitte, aussen_vorzeichen, (fläche)].
## Die Dreiecke werden so gedreht, dass sie von außen im Uhrzeigersinn erscheinen (Godot-Vorderseite)
## und die Normalen werden weich berechnet.
static func _mesh_aus(teile: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var flaechen := {}
	for t in teile:
		var flaeche: int = t[4] if t.size() > 4 else 0
		if not flaechen.has(flaeche):
			flaechen[flaeche] = []
		flaechen[flaeche].append(t)
	for f in flaechen.keys():
		var alle_pos := PackedVector3Array()
		var alle_norm := PackedVector3Array()
		var alle_idx := PackedInt32Array()
		for t in flaechen[f]:
			var pos: PackedVector3Array = t[0]
			var idx: PackedInt32Array = t[1]
			var mitte: Vector3 = t[2]
			var vz: float = t[3]
			var norm := PackedVector3Array()
			norm.resize(pos.size())
			var basis := alle_pos.size()
			for i in range(0, idx.size(), 3):
				var a := pos[idx[i]]
				var b := pos[idx[i + 1]]
				var c := pos[idx[i + 2]]
				var n := (b - a).cross(c - a)
				var raus := ((a + b + c) / 3.0 - mitte) * vz
				if n.dot(raus) > 0.0:
					var tmp := idx[i + 1]
					idx[i + 1] = idx[i + 2]
					idx[i + 2] = tmp
					n = -n
				# Normale zeigt nach außen, Wicklung ist "von außen im Uhrzeigersinn"
				for v in [idx[i], idx[i + 1], idx[i + 2]]:
					norm[v] -= n
			for i in norm.size():
				norm[i] = norm[i].normalized()
			alle_pos.append_array(pos)
			alle_norm.append_array(norm)
			for i in idx:
				alle_idx.append(i + basis)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = alle_pos
		arr[Mesh.ARRAY_NORMAL] = alle_norm
		arr[Mesh.ARRAY_INDEX] = alle_idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
