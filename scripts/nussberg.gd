class_name Nussberg
extends Node3D
## Der Berg aus 1.000.000 Nüssen als begehbares Höhenfeld.
## Wo gesammelt wird, sinkt er ab, Nüsse rutschen in Löcher nach. Die Anzahl ist fest an
## Game.berg_rest() gekoppelt: ist das Volumen weg, ist auch der Zähler bei null.
## Aus der Ferne zeigt ein Shader lauter Nüsse, in Spielernähe liegen echte 3D-Nüsse oben drauf.

signal veraendert

const N := 112                       # Zellen je Seite
const ZELLE := 0.5                   # Meter je Zelle
const MITTE := Vector3(1.0, 0.0, -32.0)
const RADIUS := 22.0
const HOEHE := 10.0
const CHUNK := 16
const MAX_STUFE := 0.36              # größter Höhenunterschied zwischen Nachbarn (sonst rutscht es)
const DEKO_RADIUS := 7.5
const DEKO_ABSTAND := 0.2

var h := PackedFloat32Array()
var volumen := 0.0                   # Restvolumen in m³ (Summe h * Zellfläche)
var koerper: StaticBody3D

var _form: HeightMapShape3D
var _chunks := {}                    # Vector2i -> MeshInstance3D
var _schmutzig := {}                 # Vector2i -> true
var _kollision_schmutzig := false
var _kollision_timer := 0.0
var _bruch := 0.0                    # Nachkommastellen beim Zählen
var _deko: Array = []                # [MultiMeshInstance3D, nuss]
var _deko_mitte := Vector3(INF, 0, INF)
var _deko_schmutzig := true
var _deko_timer := 0.0
var _fern: Array = []                # [MultiMeshInstance3D, PackedVector3Array basis-positionen]
var _fern_timer := 0.0
var _fern_schmutzig := true
var _material: Material


func _ready() -> void:
	_material = Look.nusshaufen(0.2)
	koerper = StaticBody3D.new()
	koerper.collision_layer = Data.L_WELT
	koerper.collision_mask = 0
	koerper.set_meta("nussberg", self)
	var cs := CollisionShape3D.new()
	_form = HeightMapShape3D.new()
	_form.map_width = N + 1
	_form.map_depth = N + 1
	cs.shape = _form
	cs.scale = Vector3(ZELLE, 1.0, ZELLE)
	koerper.add_child(cs)
	koerper.position = MITTE
	add_child(koerper)
	if h.is_empty():
		erzeugen()
	for paar in [["wal", 1.0], ["hasel", 1.0]]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Nussmodelle.ganz(paar[0], 1, 0)
		mmi.multimesh = mm
		mmi.material_override = Look.nuss(paar[0], false, false, false, true)
		mmi.layers = 2
		add_child(mmi)
		_deko.append([mmi, paar[0]])
	_fern_anlegen()
	alles_neu()


# =============================================================================
# Form, Laden, Speichern
# =============================================================================
## Erzeugt die Ausgangsform: ein knubbeliger Haufen.
func erzeugen() -> void:
	var rausch := FastNoiseLite.new()
	rausch.seed = 1234
	rausch.frequency = 0.06
	var fein := FastNoiseLite.new()
	fein.seed = 77
	fein.frequency = 0.25
	h.resize((N + 1) * (N + 1))
	for z in N + 1:
		for x in N + 1:
			var p := _welt(x, z)
			var d := Vector2(p.x - MITTE.x, (p.z - MITTE.z) * 1.08)
			var r := d.length() / (RADIUS * (1.0 + rausch.get_noise_2d(p.x * 0.5, p.z * 0.5) * 0.12))
			var basis := HOEHE * pow(max(0.0, 1.0 - r * r), 0.8)
			if basis > 0.0:
				basis += rausch.get_noise_2d(p.x, p.z) * 1.3 * (basis / HOEHE) + fein.get_noise_2d(p.x, p.z) * 0.15 * min(1.0, basis)
			h[z * (N + 1) + x] = max(0.0, basis)
	_rand_nullen()
	_volumen_neu()


## Passt das Volumen an einen Zählerstand an (z. B. alter Spielstand ohne Bergdatei).
func an_rest_anpassen(rest: int) -> void:
	_volumen_neu()
	if volumen <= 0.0:
		return
	var anteil := clampf(float(rest) / float(Data.BERG_GROESSE), 0.0, 1.0)
	if anteil >= 0.999:
		return
	# Von außen nach innen abtragen: die Höhe nimmt überall ab, flache Ränder verschwinden zuerst
	var ziel := volumen * anteil
	var unten := 0.0
	var oben := HOEHE
	for i in 30:
		var m := (unten + oben) * 0.5
		var v := 0.0
		for wert in h:
			v += max(0.0, wert - m)
		v *= ZELLE * ZELLE
		if v > ziel:
			unten = m
		else:
			oben = m
	var schnitt := (unten + oben) * 0.5
	for i in h.size():
		h[i] = max(0.0, h[i] - schnitt)
	_volumen_neu()


func speichern(pfad: String) -> void:
	var f := FileAccess.open_compressed(pfad, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f:
		f.store_var(h)


func laden(pfad: String) -> bool:
	if not FileAccess.file_exists(pfad):
		return false
	var f := FileAccess.open_compressed(pfad, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var d = f.get_var()
	if d is PackedFloat32Array and d.size() == (N + 1) * (N + 1):
		h = d
		_volumen_neu()
		return true
	return false


func alles_neu() -> void:
	for cz in N / CHUNK:
		for cx in N / CHUNK:
			_schmutzig[Vector2i(cx, cz)] = true
	_kollision_schmutzig = true
	_kollision_timer = 0.0
	_deko_schmutzig = true
	_fern_schmutzig = true
	_kollision_bauen()
	while not _schmutzig.is_empty():
		var k: Vector2i = _schmutzig.keys()[0]
		_schmutzig.erase(k)
		_chunk_bauen(k)


func _volumen_neu() -> void:
	var v := 0.0
	for wert in h:
		v += wert
	volumen = v * ZELLE * ZELLE


func _rand_nullen() -> void:
	for i in N + 1:
		h[i] = 0.0
		h[N * (N + 1) + i] = 0.0
		h[i * (N + 1)] = 0.0
		h[i * (N + 1) + N] = 0.0


# =============================================================================
# Abfragen
# =============================================================================
func _welt(x: int, z: int) -> Vector3:
	return Vector3(MITTE.x + (x - N * 0.5) * ZELLE, 0.0, MITTE.z + (z - N * 0.5) * ZELLE)


func _gitter(p: Vector3) -> Vector2:
	return Vector2((p.x - MITTE.x) / ZELLE + N * 0.5, (p.z - MITTE.z) / ZELLE + N * 0.5)


## Höhe der Nussoberfläche an einer Stelle (bilinear).
func hoehe_bei(x: float, z: float) -> float:
	var g := _gitter(Vector3(x, 0, z))
	if g.x < 0.0 or g.y < 0.0 or g.x >= N or g.y >= N:
		return 0.0
	var ix := int(g.x)
	var iz := int(g.y)
	var fx := g.x - ix
	var fz := g.y - iz
	var a := h[iz * (N + 1) + ix]
	var b := h[iz * (N + 1) + ix + 1]
	var c := h[(iz + 1) * (N + 1) + ix]
	var d := h[(iz + 1) * (N + 1) + ix + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


func ist_berg(o) -> bool:
	return o == koerper


## Nächster Punkt mit genug Nüssen (für Helfer). Sucht auf einem groben Raster.
func naechste_stelle(von: Vector3, mindest := 0.4, zufall := 0.0) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	var schritt := 3
	for z in range(0, N + 1, schritt):
		for x in range(0, N + 1, schritt):
			var wert := h[z * (N + 1) + x]
			if wert < mindest:
				continue
			var p := _welt(x, z)
			var d := Vector2(p.x - von.x, p.z - von.z).length() + randf() * zufall
			if d < best_d:
				best_d = d
				best = Vector3(p.x, wert, p.z)
	return best


func rest_anteil() -> float:
	return float(Game.berg_rest()) / float(Data.BERG_GROESSE)


# =============================================================================
# Abbauen
# =============================================================================
## Nimmt bis zu "anzahl" Nüsse rund um einen Punkt weg. Gibt zurück, wie viele es wirklich waren.
func abbauen(punkt: Vector3, radius: float, anzahl: int) -> int:
	var rest := Game.berg_rest()
	if anzahl <= 0 or rest <= 0 or volumen <= 0.000001:
		return 0
	radius = max(radius, ZELLE * 1.6)
	var ziel_vol: float = float(min(anzahl, rest)) / float(rest) * volumen
	var g := _gitter(punkt)
	var rz := int(ceil(radius / ZELLE))
	var x0 := clampi(int(g.x) - rz, 1, N - 1)
	var x1 := clampi(int(g.x) + rz + 1, 1, N - 1)
	var z0 := clampi(int(g.y) - rz, 1, N - 1)
	var z1 := clampi(int(g.y) + rz + 1, 1, N - 1)
	var gewichte := {}
	var summe := 0.0
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var p := _welt(x, z)
			var d := Vector2(p.x - punkt.x, p.z - punkt.z).length() / radius
			if d >= 1.0:
				continue
			var i := z * (N + 1) + x
			if h[i] <= 0.0:
				continue
			var w := (1.0 - d * d) * (1.0 - d * d)
			gewichte[i] = w
			summe += w
	if summe <= 0.0:
		return 0
	var zell := ZELLE * ZELLE
	var k := ziel_vol / (summe * zell)
	var weg := 0.0
	# zweimal verteilen, damit leere Stellen den Rest an volle abgeben
	for runde in 2:
		var neu_summe := 0.0
		for i in gewichte:
			var d_h: float = min(h[i], k * gewichte[i])
			h[i] -= d_h
			weg += d_h * zell
			if h[i] < 0.03:
				weg += h[i] * zell
				h[i] = 0.0
			elif h[i] > 0.0:
				neu_summe += gewichte[i]
		if weg >= ziel_vol * 0.98 or neu_summe <= 0.0:
			break
		k = (ziel_vol - weg) / (neu_summe * zell)
	var vorher := volumen
	volumen = max(0.0, volumen - weg)
	var genau := weg / vorher * float(rest) + _bruch
	var n := int(floor(genau))
	_bruch = genau - n
	if volumen <= 0.0001:
		n = rest
	n = min(n, rest)
	_rutschen(x0 - 3, x1 + 3, z0 - 3, z1 + 3)
	_markieren(x0 - 4, x1 + 4, z0 - 4, z1 + 4)
	if n > 0:
		veraendert.emit()
	return n


## Lässt zu steile Stellen nachrutschen (Volumen bleibt gleich).
func _rutschen(x0: int, x1: int, z0: int, z1: int) -> void:
	x0 = clampi(x0, 1, N - 1)
	x1 = clampi(x1, 1, N - 1)
	z0 = clampi(z0, 1, N - 1)
	z1 = clampi(z1, 1, N - 1)
	for runde in 4:
		var bewegt := false
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var i := z * (N + 1) + x
				for j in [i + 1, i - 1, i + N + 1, i - N - 1]:
					var diff: float = h[i] - h[j]
					if diff > MAX_STUFE:
						var fluss := (diff - MAX_STUFE) * 0.35
						h[i] -= fluss
						h[j] += fluss
						bewegt = true
		if not bewegt:
			break
	_rand_nullen()


func _markieren(x0: int, x1: int, z0: int, z1: int) -> void:
	for cz in range(max(0, z0 / CHUNK), min(N / CHUNK - 1, z1 / CHUNK) + 1):
		for cx in range(max(0, x0 / CHUNK), min(N / CHUNK - 1, x1 / CHUNK) + 1):
			_schmutzig[Vector2i(cx, cz)] = true
	_kollision_schmutzig = true
	_deko_schmutzig = true
	_fern_schmutzig = true


# =============================================================================
# Darstellung
# =============================================================================
func _process(delta: float) -> void:
	var gebaut := 0
	while not _schmutzig.is_empty() and gebaut < 4:
		var k: Vector2i = _schmutzig.keys()[0]
		_schmutzig.erase(k)
		_chunk_bauen(k)
		gebaut += 1
	_kollision_timer -= delta
	if _kollision_schmutzig and _kollision_timer <= 0.0:
		_kollision_bauen()
	_deko_timer -= delta
	var cam := get_viewport().get_camera_3d()
	if cam and _deko_timer <= 0.0:
		var p := cam.global_position
		if _deko_schmutzig or Vector2(p.x - _deko_mitte.x, p.z - _deko_mitte.z).length() > 1.5:
			_deko_timer = 0.2
			_deko_bauen(p)
	_fern_timer -= delta
	if _fern_schmutzig and _fern_timer <= 0.0:
		_fern_timer = 2.0
		_fern_aktualisieren()


func _kollision_bauen() -> void:
	_kollision_schmutzig = false
	_kollision_timer = 0.2
	var d := PackedFloat32Array()
	d.resize(h.size())
	for i in h.size():
		d[i] = h[i] - 0.05
	_form.map_data = d


func _chunk_bauen(k: Vector2i) -> void:
	var mi: MeshInstance3D = _chunks.get(k)
	var x0 := k.x * CHUNK
	var z0 := k.y * CHUNK
	var leer := true
	for z in range(z0, z0 + CHUNK + 1):
		for x in range(x0, x0 + CHUNK + 1):
			if h[z * (N + 1) + x] > 0.02:
				leer = false
				break
		if not leer:
			break
	if leer:
		if mi:
			mi.visible = false
		return
	var pos := PackedVector3Array()
	var norm := PackedVector3Array()
	var idx := PackedInt32Array()
	var b := CHUNK + 1
	for z in range(z0, z0 + b):
		for x in range(x0, x0 + b):
			var p := _welt(x, z)
			var wert := h[z * (N + 1) + x]
			p.y = wert - 0.06
			pos.append(p)
			var hl := h[z * (N + 1) + max(x - 1, 0)]
			var hr := h[z * (N + 1) + min(x + 1, N)]
			var hd := h[max(z - 1, 0) * (N + 1) + x]
			var hu := h[min(z + 1, N) * (N + 1) + x]
			norm.append(Vector3(hl - hr, 2.0 * ZELLE, hd - hu).normalized())
	for z in CHUNK:
		for x in CHUNK:
			var a := z * b + x
			# Uhrzeigersinn von oben gesehen = Vorderseite in Godot
			idx.append_array([a, a + 1, a + b, a + 1, a + b + 1, a + b])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = norm
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = _material
		mi.layers = 2
		add_child(mi)
		_chunks[k] = mi
	mi.mesh = mesh
	mi.visible = true


## Echte 3D-Nüsse in Spielernähe, damit der Berg aus der Nähe nach Nüssen aussieht.
func _deko_bauen(mitte: Vector3) -> void:
	_deko_schmutzig = false
	_deko_mitte = mitte
	var listen := [[], []]
	var schritte := int(DEKO_RADIUS / DEKO_ABSTAND)
	var gx := floorf(mitte.x / DEKO_ABSTAND)
	var gz := floorf(mitte.z / DEKO_ABSTAND)
	for iz in range(-schritte, schritte + 1):
		for ix in range(-schritte, schritte + 1):
			var zx := gx + ix
			var zz := gz + iz
			var hsh := hash(Vector2i(int(zx), int(zz)))
			var jx := float(hsh & 255) / 255.0
			var jz := float((hsh >> 8) & 255) / 255.0
			var x := (zx + jx) * DEKO_ABSTAND
			var z := (zz + jz) * DEKO_ABSTAND
			if Vector2(x - mitte.x, z - mitte.z).length() > DEKO_RADIUS:
				continue
			var y := hoehe_bei(x, z)
			if y < 0.12:
				continue
			var art := (hsh >> 16) & 1
			var dreh := Basis.from_euler(Vector3(float((hsh >> 4) & 63) * 0.1, float((hsh >> 10) & 63) * 0.1, 0.0))
			var s := 1.6 + float((hsh >> 20) & 15) * 0.04
			listen[art].append(Transform3D(dreh.scaled(Vector3.ONE * s), Vector3(x, y - 0.02, z)))
	for i in 2:
		var mm: MultiMesh = _deko[i][0].multimesh
		var liste: Array = listen[i]
		mm.instance_count = liste.size()
		for j in liste.size():
			mm.set_instance_transform(j, liste[j])
			var hsh2 := j * 2654435761
			var hell := 0.85 + float(hsh2 & 63) / 63.0 * 0.3
			mm.set_instance_color(j, Color(hell, hell, hell))


## Locker verteilte Nüsse auf dem ganzen Berg, damit er auch von weitem plastisch wirkt.
func _fern_anlegen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for paar in [["wal", 4500], ["hasel", 2500]]:
		var basis := PackedVector3Array()
		for i in paar[1]:
			var w := rng.randf() * TAU
			var r := sqrt(rng.randf()) * RADIUS * 1.05
			basis.append(Vector3(MITTE.x + cos(w) * r, rng.randf() * TAU, MITTE.z + sin(w) * r))
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Nussmodelle.ganz(paar[0], 0, 0)
		mm.instance_count = basis.size()
		for i in basis.size():
			var hell := rng.randf_range(0.85, 1.15)
			mm.set_instance_color(i, Color(hell, hell, hell * 0.95))
		mmi.multimesh = mm
		mmi.material_override = Look.nuss(paar[0], false, false, false, true)
		mmi.layers = 2
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_fern.append([mmi, basis])


func _fern_aktualisieren() -> void:
	_fern_schmutzig = false
	for paar in _fern:
		var mm: MultiMesh = paar[0].multimesh
		var basis: PackedVector3Array = paar[1]
		for i in basis.size():
			var b := basis[i]
			var y := hoehe_bei(b.x, b.z)
			var s := 2.6 if y > 0.15 else 0.0
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, b.y).rotated(Vector3.RIGHT, b.y * 2.0).scaled(Vector3.ONE * s), Vector3(b.x, y - 0.03, b.z)))
