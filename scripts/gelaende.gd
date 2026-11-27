class_name Gelaende
extends Node3D
## Das Tal als festes Höhenfeld: ebene Talsohle, bewaldete Hügel ringsum, Bachbett mit Felsstufe
## und Wasserfall. Wege, Ufer und Waldboden stehen als Farbmasken in den Eckpunkten und werden
## vom Boden-Shader eingefärbt. Der Nussberg liegt als eigenes Höhenfeld darauf.

const ZELLE := 1.0
const X0 := -120.0
const Z0 := -135.0
const BREITE := 241          # Punkte in x
const TIEFE := 236           # Punkte in z
const KACHEL := 32           # Zellen je Mesh-Kachel

const SH_BODEN := preload("res://shaders/boden.gdshader")

var hoehen := PackedFloat32Array()
var _weg := PackedFloat32Array()
var _ufer := PackedFloat32Array()
var _bach_abstand := PackedFloat32Array()
var _bach_hoehe := PackedFloat32Array()
var _rausch := FastNoiseLite.new()
var _rausch2 := FastNoiseLite.new()
var material: ShaderMaterial


func _init() -> void:
	name = "Gelaende"
	_rausch.seed = 1974
	_rausch.frequency = 1.0
	_rausch.fractal_octaves = 3
	_rausch2.seed = 2026
	_rausch2.frequency = 1.0
	_rausch2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


func erzeugen() -> void:
	var n := BREITE * TIEFE
	hoehen.resize(n)
	_weg.resize(n)
	_ufer.resize(n)
	_bach_abstand.resize(n)
	_weg.fill(0.0)
	_ufer.fill(0.0)
	_bach_abstand.fill(999.0)
	_bach_hoehe.resize(n)
	_bach_hoehe.fill(0.0)
	# 1. Bach: Abstand zur Mittellinie und Wasserhöhe je Punkt (nur nahe Zellen anfassen)
	var reichweite := WeltPlan.BACH_BREITE * 0.5 + WeltPlan.BACH_UFER + 3.0
	for i in WeltPlan.BACH.size() - 1:
		var a: Vector3 = WeltPlan.BACH[i]
		var b: Vector3 = WeltPlan.BACH[i + 1]
		_rastern(Vector2(a.x, a.z), Vector2(b.x, b.z), reichweite, func(idx: int, d: float, t: float):
			if d < _bach_abstand[idx]:
				_bach_abstand[idx] = d
				# Beim Wasserfall bleibt das Wasser oben, bis die Kante erreicht ist
				var w := lerpf(a.y, b.y, t)
				if i == WeltPlan.BACH_KANTE:
					w = a.y if t < 0.12 else b.y
				_bach_hoehe[idx] = w)
	# 2. Wege
	for weg in WeltPlan.WEGE:
		var punkte: Array = weg[0]
		var breite: float = weg[1]
		for i in punkte.size() - 1:
			_rastern(punkte[i], punkte[i + 1], max(breite, 1.0) + 2.0, func(idx: int, d: float, _t: float):
				var m := 0.0
				if breite > 0.0:
					m = 1.0 - smoothstep(breite * 0.5 - 0.35, breite * 0.5 + 0.45, d)
				else:
					m = 0.5 * (1.0 - smoothstep(0.1, 0.8, d))
				_weg[idx] = maxf(_weg[idx], m))
	# 3. Höhen
	var becken: Vector3 = WeltPlan.BACH[WeltPlan.BACH_KANTE + 1]
	for zi in TIEFE:
		for xi in BREITE:
			var idx := zi * BREITE + xi
			var x := X0 + xi * ZELLE
			var z := Z0 + zi * ZELLE
			var h := _natur(x, z)
			var d := _bach_abstand[idx]
			# Becken unter dem Wasserfall
			var db := Vector2(x - becken.x, z - becken.z).length()
			if db < 4.0:
				d = minf(d, maxf(0.0, db - 2.0))
				if db < 4.0 and _bach_abstand[idx] > 3.0:
					_bach_hoehe[idx] = becken.y
			if d < 900.0:
				var w := _bach_hoehe[idx]
				var halb := WeltPlan.BACH_BREITE * 0.5 + 0.3
				var grund := w - WeltPlan.BACH_TIEFE - 0.12
				var schnitt: float
				if d < halb:
					var k := d / halb
					schnitt = grund + k * k * (WeltPlan.BACH_TIEFE + 0.25)
				else:
					var k2 := (d - halb) / WeltPlan.BACH_UFER
					schnitt = w + 0.13 + pow(k2, 1.6) * 6.0
				h = minf(h, schnitt)
				_ufer[idx] = 1.0 - smoothstep(halb - 0.2, halb + 1.8, d)
			hoehen[idx] = h
	_bauen()


## Ruft f(idx, abstand, t) für alle Gitterpunkte nahe der Strecke a-b auf.
func _rastern(a: Vector2, b: Vector2, r: float, f: Callable) -> void:
	var x_min := int(floor((minf(a.x, b.x) - r - X0) / ZELLE))
	var x_max := int(ceil((maxf(a.x, b.x) + r - X0) / ZELLE))
	var z_min := int(floor((minf(a.y, b.y) - r - Z0) / ZELLE))
	var z_max := int(ceil((maxf(a.y, b.y) + r - Z0) / ZELLE))
	var ab := b - a
	var laenge2 := maxf(ab.length_squared(), 0.0001)
	for zi in range(maxi(z_min, 0), mini(z_max, TIEFE - 1) + 1):
		for xi in range(maxi(x_min, 0), mini(x_max, BREITE - 1) + 1):
			var p := Vector2(X0 + xi * ZELLE, Z0 + zi * ZELLE)
			var t := clampf((p - a).dot(ab) / laenge2, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d <= r:
				f.call(zi * BREITE + xi, d, t)


## Die natürliche Form ohne Bach: Talsohle, Hügel, Buckel, Felsstufe.
func _natur(x: float, z: float) -> float:
	var r := WeltPlan.tal_r(x, z)
	var wellig := _rausch.get_noise_2d(x * 0.013, z * 0.013)
	var h := WeltPlan.SOHLE
	# Hügel am Talrand: unregelmäßiger Rand, mal steil, mal sanft
	var rand := smoothstep(0.94, 1.48, r + wellig * 0.09)
	h += WeltPlan.HUEGEL_HOEHE * rand * (0.7 + 0.55 * (_rausch2.get_noise_2d(x * 0.021, z * 0.021) * 0.5 + 0.5))
	# Leichte Wellen in der Talsohle, außer dort, wo es eben sein muss
	var eben := _eben_faktor(x, z)
	h += (_rausch2.get_noise_2d(x * 0.045, z * 0.045) * 0.28 + 0.12) * eben * (1.0 - rand)
	for bu in WeltPlan.BUCKEL:
		var d := Vector2(x, z).distance_to(bu[0])
		var k := clampf(1.0 - d / float(bu[1]), 0.0, 1.0)
		h += float(bu[2]) * k * k * (3.0 - 2.0 * k) * eben
	var fs: Array = WeltPlan.FELSSTUFE
	var df := Vector2(x, z).distance_to(fs[0]) + wellig * 2.0
	var kf := 1.0 - smoothstep(float(fs[1]), float(fs[1]) + float(fs[2]), df)
	h = maxf(h, float(fs[3]) * kf + WeltPlan.SOHLE)
	return h


## 0 = muss eben bleiben, 1 = darf wellig sein.
func _eben_faktor(x: float, z: float) -> float:
	var f := 1.0
	var p := Vector2(x, z)
	for e in WeltPlan.EBEN:
		f = minf(f, smoothstep(float(e[1]), float(e[1]) + 9.0, p.distance_to(e[0])))
	for po in Data.POSTEN:
		var punkte: Array = [po.pos] + po.weg
		for i in punkte.size() - 1:
			var a := Vector2(punkte[i].x, punkte[i].z)
			var b := Vector2(punkte[i + 1].x, punkte[i + 1].z)
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			f = minf(f, smoothstep(2.5, 8.0, q.distance_to(p)))
	return f


# --- Abfragen ------------------------------------------------------------------
func hoehe_bei(x: float, z: float) -> float:
	var fx := clampf((x - X0) / ZELLE, 0.0, BREITE - 1.001)
	var fz := clampf((z - Z0) / ZELLE, 0.0, TIEFE - 1.001)
	var xi := int(fx)
	var zi := int(fz)
	var tx := fx - xi
	var tz := fz - zi
	var i := zi * BREITE + xi
	var h0 := lerpf(hoehen[i], hoehen[i + 1], tx)
	var h1 := lerpf(hoehen[i + BREITE], hoehen[i + BREITE + 1], tx)
	return lerpf(h0, h1, tz)


func _wert(arr: PackedFloat32Array, x: float, z: float) -> float:
	var xi := clampi(int(round((x - X0) / ZELLE)), 0, BREITE - 1)
	var zi := clampi(int(round((z - Z0) / ZELLE)), 0, TIEFE - 1)
	return arr[zi * BREITE + xi]


func weg_bei(x: float, z: float) -> float:
	return _wert(_weg, x, z)


func bach_abstand(x: float, z: float) -> float:
	return _wert(_bach_abstand, x, z)


func ufer_bei(x: float, z: float) -> float:
	return _wert(_ufer, x, z)


## Steigung (0 = flach, 1 = 45°) an einer Stelle.
func steigung(x: float, z: float) -> float:
	var dx := hoehe_bei(x + 0.7, z) - hoehe_bei(x - 0.7, z)
	var dz := hoehe_bei(x, z + 0.7) - hoehe_bei(x, z - 0.7)
	return Vector2(dx, dz).length() / 1.4


func position(x: float, z: float) -> Vector3:
	return Vector3(x, hoehe_bei(x, z), z)


# --- Mesh und Kollision ----------------------------------------------------------
func _bauen() -> void:
	material = ShaderMaterial.new()
	material.shader = SH_BODEN
	var kx := int(ceil(float(BREITE - 1) / KACHEL))
	var kz := int(ceil(float(TIEFE - 1) / KACHEL))
	for cz in kz:
		for cx in kx:
			_kachel(cx * KACHEL, cz * KACHEL, mini(KACHEL, BREITE - 1 - cx * KACHEL), mini(KACHEL, TIEFE - 1 - cz * KACHEL))
	# Kollision: ein Höhenfeld über alles
	var koerper := StaticBody3D.new()
	koerper.name = "GelaendeKoerper"
	koerper.collision_layer = Data.L_WELT
	var form := HeightMapShape3D.new()
	form.map_width = BREITE
	form.map_depth = TIEFE
	form.map_data = hoehen
	var cs := CollisionShape3D.new()
	cs.shape = form
	cs.position = Vector3(X0 + (BREITE - 1) * 0.5 * ZELLE, 0.0, Z0 + (TIEFE - 1) * 0.5 * ZELLE)
	koerper.add_child(cs)
	add_child(koerper)
	_grenze()


func _kachel(x_start: int, z_start: int, nx: int, nz: int) -> void:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var farben := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for zi in range(z_start, z_start + nz + 1):
		for xi in range(x_start, x_start + nx + 1):
			var i := zi * BREITE + xi
			var x := X0 + xi * ZELLE
			var z := Z0 + zi * ZELLE
			v.append(Vector3(x, hoehen[i], z))
			var hl := hoehen[zi * BREITE + maxi(xi - 1, 0)]
			var hr := hoehen[zi * BREITE + mini(xi + 1, BREITE - 1)]
			var ho := hoehen[maxi(zi - 1, 0) * BREITE + xi]
			var hu := hoehen[mini(zi + 1, TIEFE - 1) * BREITE + xi]
			nrm.append(Vector3(hl - hr, 2.0 * ZELLE, ho - hu).normalized())
			var wald := smoothstep(0.9, 1.08, WeltPlan.tal_r(x, z))
			farben.append(Color(_weg[i], _ufer[i], wald, 1.0))
			uv.append(Vector2(x, z))
	var reihe := nx + 1
	for zi in nz:
		for xi in nx:
			var a := zi * reihe + xi
			# Uhrzeigersinn von oben gesehen = Vorderseite nach oben
			idx.append_array([a, a + 1, a + reihe, a + 1, a + reihe + 1, a + reihe])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = farben
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	add_child(mi)


## Unsichtbare Grenze auf den Hügeln, damit man nicht aus dem Tal läuft.
func _grenze() -> void:
	var k := StaticBody3D.new()
	k.name = "Talgrenze"
	k.collision_layer = Data.L_WELT
	var n := 96
	for i in n:
		var w := TAU * float(i) / n
		var w2 := TAU * float(i + 1) / n
		var a := WeltPlan.TAL_MITTE + Vector2(cos(w) * WeltPlan.TAL_RADIEN.x, sin(w) * WeltPlan.TAL_RADIEN.y) * WeltPlan.GRENZE
		var b := WeltPlan.TAL_MITTE + Vector2(cos(w2) * WeltPlan.TAL_RADIEN.x, sin(w2) * WeltPlan.TAL_RADIEN.y) * WeltPlan.GRENZE
		var m := (a + b) * 0.5
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(a.distance_to(b) + 0.6, 40.0, 0.5)
		cs.shape = box
		cs.position = Vector3(m.x, hoehe_bei(m.x, m.y) + 5.0, m.y)
		cs.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		k.add_child(cs)
	add_child(k)
