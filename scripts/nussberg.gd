class_name Nussberg
extends Node3D
## Der Berg aus 1.000.000 Nüssen als begehbares Höhenfeld.
## Wo gesammelt wird, sinkt er ab, Nüsse rutschen in Löcher nach. Die Anzahl ist fest an
## Game.berg_rest() gekoppelt: ist das Volumen weg, ist auch der Zähler bei null.
## Zu sehen sind nur echte Nüsse. Eine Grundlage bedeckt den ganzen Berg; in Spielernähe liegen
## darüber drei dicht gepackte, gegeneinander versetzte Lagen, sodass man zwischen den Nüssen
## wieder nur Nüsse sieht. Eine bemalte Fläche gibt es nicht mehr, nur tief unten eine schwarze
## Sichtsperre. Wer oben Nüsse wegnimmt, sieht sofort andere von unten nachrücken.

signal veraendert

const N := 112                       # Zellen je Seite
const ZELLE := 0.5                   # Meter je Zelle
const MITTE := Vector3(1.0, 0.0, -32.0)
const RADIUS := 22.0
const HOEHE := 10.0
const CHUNK := 16
const MAX_STUFE := 0.36              # größter Höhenunterschied zwischen Nachbarn (sonst rutscht es)
const NAH_KACHEL := 2.0              # Kantenlänge einer Kachel der oberen Lage
const NAH_ABSTAND := 2.0 / 11.0      # Abstand der Nüsse in der oberen Lage (11 je Kachelkante)
const NAH_RADIUS := [5.5, 7.0, 8.5]  # je Qualitätsstufe: so weit liegt die obere Lage um den Spieler
const TIEF_RADIUS := [4.0, 5.5, 7.0]  # so weit liegen die beiden tieferen Lagen um den Spieler
const TIEF_VERSATZ := [Vector2(0.5, 0.5), Vector2(0.0, 0.5)]   # gegen die obere Lage versetzt, in Zellen
const FERN_KACHEL := 8.0             # Kantenlänge einer Kachel der unteren Lage
const FERN_ABSTAND := [0.34, 0.3, 0.27]
const RUECK_DAUER := 0.26            # so lange braucht eine Nuss zum Nachrücken

var h := PackedFloat32Array()
var volumen := 0.0                   # Restvolumen in m³ (Summe h * Zellfläche)
var koerper: StaticBody3D

var _form: HeightMapShape3D
var _chunks := {}                    # Vector2i -> MeshInstance3D
var _schmutzig := {}                 # Vector2i -> true
var _kollision_schmutzig := false
var _kollision_timer := 0.0
var _bruch := 0.0                    # Nachkommastellen beim Zählen
var _nah := {}                       # Kachel -> [oben Walnuss, oben Haselnuss, tief Walnuss, tief Haselnuss, tief gebaut?]
var _nah_schmutzig := {}
var _tief_schmutzig := {}
var _netz_mittel: Array = []
var _nah_mitte := Vector3(INF, 0, INF)
var _fern := {}                      # Kachel -> [MultiMeshInstance3D, MultiMeshInstance3D]
var _fern_schmutzig := {}
var _fern_timer := 0.0
var _generation := {}                # Zelle der oberen Lage -> wie oft dort schon eine Nuss genommen wurde
var _rueckt := {}                    # Zelle -> [Startzeit, MultiMesh, Index, Ruhelage]
var _zeit := 0.0
var _netz_fein: Array = []
var _netz_grob: Array = []
var _nussmaterial: Array = []
var _material: Material


func _ready() -> void:
	# Keine bemalte Fläche mehr. Tief unter den Nüssen liegt nur eine schwarze Sichtsperre ohne Muster
	# und ohne Licht, damit man nirgends durch den Berg auf die Wiese schaut.
	var sperre := StandardMaterial3D.new()
	sperre.albedo_color = Color(0.03, 0.018, 0.008)
	sperre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material = sperre
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
	for id in ["wal", "hasel"]:
		_netz_fein.append(Nussmodelle.ganz(id, 1, 0))
		_netz_grob.append(Nussmodelle.ganz(id, 0, 3))
		_netz_mittel.append(Nussmodelle.ganz(id, 2, 4))
		_nussmaterial.append(Look.nuss(id, false, false, false, true))
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
	_kollision_bauen()
	while not _schmutzig.is_empty():
		var k: Vector2i = _schmutzig.keys()[0]
		_schmutzig.erase(k)
		_chunk_bauen(k)
	# untere Lage für den ganzen Berg sofort, obere Lage folgt dem Spieler
	if not _netz_grob.is_empty():
		var halb := N * ZELLE * 0.5
		for kz in range(int(floor((MITTE.z - halb) / FERN_KACHEL)), int(floor((MITTE.z + halb) / FERN_KACHEL)) + 1):
			for kx in range(int(floor((MITTE.x - halb) / FERN_KACHEL)), int(floor((MITTE.x + halb) / FERN_KACHEL)) + 1):
				_fern_bauen(Vector2i(kx, kz))
		_fern_schmutzig.clear()
		for k in _nah:
			_nah_schmutzig[k] = true


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
	_nachruecken(punkt, radius, n)
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
	# Kacheln beider Nusslagen über der Stelle neu setzen (die Nüsse sinken mit dem Berg)
	var a := _welt(x0, z0)
	var b := _welt(x1, z1)
	for kz in range(int(floor(a.z / NAH_KACHEL)), int(floor(b.z / NAH_KACHEL)) + 1):
		for kx in range(int(floor(a.x / NAH_KACHEL)), int(floor(b.x / NAH_KACHEL)) + 1):
			if _nah.has(Vector2i(kx, kz)):
				_nah_schmutzig[Vector2i(kx, kz)] = true
				_tief_schmutzig[Vector2i(kx, kz)] = true
	for kz in range(int(floor(a.z / FERN_KACHEL)), int(floor(b.z / FERN_KACHEL)) + 1):
		for kx in range(int(floor(a.x / FERN_KACHEL)), int(floor(b.x / FERN_KACHEL)) + 1):
			_fern_schmutzig[Vector2i(kx, kz)] = true


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
	_zeit += delta
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		if Vector2(p.x - _nah_mitte.x, p.z - _nah_mitte.z).length() > 1.0:
			_nah_auswaehlen(p)
	# Je Bild ein paar Kacheln, die nächsten zuerst: Wo man steht, ist der Berg sofort voll
	for runde in 4:
		var k = _naechste(_nah_schmutzig)
		if k == null:
			break
		_nah_schmutzig.erase(k)
		if _nah.has(k):
			_nah_bauen(k)
	for runde in 2:
		var k = _naechste(_tief_schmutzig)
		if k == null:
			break
		_tief_schmutzig.erase(k)
		if _nah.has(k):
			_tief_bauen(k)
	_fern_timer -= delta
	if _fern_timer <= 0.0 and not _fern_schmutzig.is_empty():
		_fern_timer = 0.1
		var fk: Vector2i = _fern_schmutzig.keys()[0]
		_fern_schmutzig.erase(fk)
		_fern_bauen(fk)
	_rueck_laufen()


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
			p.y = wert - 0.34
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


# =============================================================================
# Die Nüsse: untere Lage überall, obere Lage um den Spieler, Nachrücken
# =============================================================================
func _qualitaet() -> int:
	return clampi(int(Game.einstellungen.get("qualitaet", 2)), 0, 2)


func _mmi(netz: Mesh, material: Material, schatten: bool) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = netz
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.layers = 2
	if not schatten:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _fuelle(mmi: MultiMeshInstance3D, lagen: Array, farben: Array) -> void:
	var mm := mmi.multimesh
	mm.instance_count = lagen.size()
	for j in lagen.size():
		mm.set_instance_transform(j, lagen[j])
		mm.set_instance_color(j, farben[j])
	mmi.visible = not lagen.is_empty()


## Die Kachel aus der Liste, die dem Spieler am nächsten liegt (null, wenn die Liste leer ist).
func _naechste(liste: Dictionary):
	var beste = null
	var kurz := INF
	for k in liste:
		var d := Vector2((k.x + 0.5) * NAH_KACHEL - _nah_mitte.x, (k.y + 0.5) * NAH_KACHEL - _nah_mitte.z).length_squared()
		if d < kurz:
			kurz = d
			beste = k
	return beste


## Welche Kacheln der oberen Lage es um den Spieler gibt.
func _nah_auswaehlen(mitte: Vector3) -> void:
	_nah_mitte = mitte
	var radius: float = NAH_RADIUS[_qualitaet()]
	var kx0 := int(floor((mitte.x - radius) / NAH_KACHEL))
	var kz0 := int(floor((mitte.z - radius) / NAH_KACHEL))
	var kx1 := int(floor((mitte.x + radius) / NAH_KACHEL))
	var kz1 := int(floor((mitte.z + radius) / NAH_KACHEL))
	for kz in range(kz0, kz1 + 1):
		for kx in range(kx0, kx1 + 1):
			var k := Vector2i(kx, kz)
			var m := Vector2((kx + 0.5) * NAH_KACHEL, (kz + 0.5) * NAH_KACHEL)
			if _nah.has(k) or m.distance_to(Vector2(mitte.x, mitte.z)) > radius + 1.0:
				continue
			if absf(m.x - MITTE.x) > RADIUS + 4.0 or absf(m.y - MITTE.z) > RADIUS + 4.0:
				continue
			_nah[k] = [null, null, null, null, false]
			_nah_schmutzig[k] = true
			_tief_schmutzig[k] = true
	var tief: float = TIEF_RADIUS[_qualitaet()]
	for k in _nah.keys():
		var m := Vector2((k.x + 0.5) * NAH_KACHEL, (k.y + 0.5) * NAH_KACHEL)
		var weit := m.distance_to(Vector2(mitte.x, mitte.z))
		if weit > radius + 3.0:
			for i in 4:
				if _nah[k][i]:
					_nah[k][i].queue_free()
			_nah.erase(k)
			_nah_schmutzig.erase(k)
			_tief_schmutzig.erase(k)
		elif (weit <= tief) != bool(_nah[k][4]):
			_tief_schmutzig[k] = true


## Obere Lage einer Kachel: dicht, fein, hell. Jede Zelle hat ihre feste Nuss, bis dort eine genommen wird.
func _nah_bauen(k: Vector2i) -> void:
	var lagen := [[], []]
	var farben := [[], []]
	var zellen := [[], []]
	var je := int(round(NAH_KACHEL / NAH_ABSTAND))
	for iz in je:
		for ix in je:
			var zelle := Vector2i(k.x * je + ix, k.y * je + iz)
			var hsh := hash(Vector3i(zelle.x, zelle.y, int(_generation.get(zelle, 0))))
			var x := (zelle.x + float(hsh & 255) / 255.0) * NAH_ABSTAND
			var z := (zelle.y + float((hsh >> 8) & 255) / 255.0) * NAH_ABSTAND
			var y := hoehe_bei(x, z)
			if y < 0.12:
				continue
			var art := (hsh >> 16) & 1
			var dreh := Basis.from_euler(Vector3(float((hsh >> 4) & 63) * 0.1, float((hsh >> 10) & 63) * 0.1, float((hsh >> 22) & 63) * 0.1))
			var s := 1.6 + float((hsh >> 20) & 15) * 0.04
			var hell := 0.86 + float((hsh >> 26) & 31) / 31.0 * 0.3
			lagen[art].append(Transform3D(dreh.scaled(Vector3.ONE * s), Vector3(x, y - 0.015, z)))
			farben[art].append(Color(hell, hell, hell * 0.97))
			zellen[art].append(zelle)
	var paar: Array = _nah[k]
	for art in 2:
		if paar[art] == null:
			if lagen[art].is_empty():
				continue
			paar[art] = _mmi(_netz_fein[art], _nussmaterial[art], true)
		_fuelle(paar[art], lagen[art], farben[art])
		# Nüsse, die gerade nachrücken, finden hier ihren neuen Platz in der Liste
		for j in zellen[art].size():
			var zelle: Vector2i = zellen[art][j]
			if _rueckt.has(zelle):
				_rueckt[zelle][1] = paar[art].multimesh
				_rueckt[zelle][2] = j
				_rueckt[zelle][3] = lagen[art][j]


## Die zwei tieferen Lagen einer Kachel, nur nah am Spieler: gleiche Nüsse wie oben, versetzt und
## je eine knappe Nussdicke tiefer. Sie füllen jede Lücke der oberen Lage mit weiteren Nüssen.
func _tief_bauen(k: Vector2i) -> void:
	var paar: Array = _nah[k]
	var m := Vector2((k.x + 0.5) * NAH_KACHEL, (k.y + 0.5) * NAH_KACHEL)
	var da: bool = m.distance_to(Vector2(_nah_mitte.x, _nah_mitte.z)) <= TIEF_RADIUS[_qualitaet()]
	paar[4] = da
	var lagen := [[], []]
	var farben := [[], []]
	if da:
		var je := int(round(NAH_KACHEL / NAH_ABSTAND))
		for lage in 2:
			var versatz: Vector2 = TIEF_VERSATZ[lage]
			for iz in je:
				for ix in je:
					var hsh := hash(Vector3i(k.x * je + ix, k.y * je + iz, 5000 + lage))
					var x := (k.x * je + ix + versatz.x + float(hsh & 255) / 255.0 * 0.8) * NAH_ABSTAND
					var z := (k.y * je + iz + versatz.y + float((hsh >> 8) & 255) / 255.0 * 0.8) * NAH_ABSTAND
					var y := hoehe_bei(x, z)
					if y < 0.2:
						continue
					var art := (hsh >> 16) & 1
					var dreh := Basis.from_euler(Vector3(float((hsh >> 4) & 63) * 0.1, float((hsh >> 10) & 63) * 0.1, float((hsh >> 22) & 63) * 0.1))
					var s := 1.75 + float((hsh >> 20) & 15) * 0.04
					# nur ganz leicht dunkler: den Rest erledigen die Schatten der Nüsse darüber
					var hell: float = [0.93, 0.86][lage] + float((hsh >> 26) & 31) / 31.0 * 0.12
					lagen[art].append(Transform3D(dreh.scaled(Vector3.ONE * s), Vector3(x, y - 0.085 - 0.075 * lage, z)))
					farben[art].append(Color(hell, hell, hell * 0.97))
	for art in 2:
		if paar[2 + art] == null:
			if lagen[art].is_empty():
				continue
			paar[2 + art] = _mmi(_netz_mittel[art], _nussmaterial[art], false)
		_fuelle(paar[2 + art], lagen[art], farben[art])


## Grundlage einer Kachel für den ganzen Berg: etwas größere Nüsse knapp unter der Oberfläche.
## Aus der Ferne ist sie der Berg, aus der Nähe liegt sie zwischen den anderen Lagen.
func _fern_bauen(k: Vector2i) -> void:
	var lagen := [[], []]
	var farben := [[], []]
	var abstand: float = FERN_ABSTAND[_qualitaet()]
	var je := int(ceil(FERN_KACHEL / abstand))
	var x0 := k.x * FERN_KACHEL
	var z0 := k.y * FERN_KACHEL
	for iz in je:
		for ix in je:
			var hsh := hash(Vector3i(k.x * 1000 + ix, k.y * 1000 + iz, 7919))
			var x := x0 + (ix + float(hsh & 255) / 255.0) * abstand
			var z := z0 + (iz + float((hsh >> 8) & 255) / 255.0) * abstand
			if x >= x0 + FERN_KACHEL or z >= z0 + FERN_KACHEL:
				continue
			var y := hoehe_bei(x, z)
			if y < 0.15:
				continue
			var art := (hsh >> 16) & 1
			var dreh := Basis.from_euler(Vector3(float((hsh >> 4) & 63) * 0.1, float((hsh >> 10) & 63) * 0.1, 0.0))
			var s := 2.25 + float((hsh >> 20) & 15) * 0.035
			var hell := 0.84 + float((hsh >> 26) & 31) / 31.0 * 0.22
			lagen[art].append(Transform3D(dreh.scaled(Vector3.ONE * s), Vector3(x, y - 0.12, z)))
			farben[art].append(Color(hell, hell * 0.97, hell * 0.92))
	if not _fern.has(k):
		if lagen[0].is_empty() and lagen[1].is_empty():
			return
		_fern[k] = [_mmi(_netz_grob[0], _nussmaterial[0], false), _mmi(_netz_grob[1], _nussmaterial[1], false)]
	for art in 2:
		_fuelle(_fern[k][art], lagen[art], farben[art])


## Oben wurden Nüsse genommen: An ihrer Stelle rücken andere von unten nach.
func _nachruecken(punkt: Vector3, radius: float, anzahl: int) -> void:
	if anzahl <= 0 or _nah.is_empty():
		return
	var r: float = max(radius, 0.3)
	var kandidaten: Array = []
	for cz in range(int(floor((punkt.z - r) / NAH_ABSTAND)), int(floor((punkt.z + r) / NAH_ABSTAND)) + 1):
		for cx in range(int(floor((punkt.x - r) / NAH_ABSTAND)), int(floor((punkt.x + r) / NAH_ABSTAND)) + 1):
			var m := Vector2((cx + 0.5) * NAH_ABSTAND, (cz + 0.5) * NAH_ABSTAND)
			if m.distance_to(Vector2(punkt.x, punkt.z)) <= r and not _rueckt.has(Vector2i(cx, cz)):
				kandidaten.append(Vector2i(cx, cz))
	kandidaten.shuffle()
	var je := int(round(NAH_KACHEL / NAH_ABSTAND))
	for i in min(anzahl, kandidaten.size(), 28):
		var zelle: Vector2i = kandidaten[i]
		var k := Vector2i(int(floor(float(zelle.x) / je)), int(floor(float(zelle.y) / je)))
		if not _nah.has(k):
			continue
		_generation[zelle] = int(_generation.get(zelle, 0)) + 1
		_rueckt[zelle] = [_zeit + randf() * 0.09, null, -1, Transform3D.IDENTITY]
		_nah_schmutzig[k] = true


## Bewegt die nachrückenden Nüsse: Sie kommen klein von unten und setzen sich mit einem Ruck.
func _rueck_laufen() -> void:
	if _rueckt.is_empty():
		return
	for zelle in _rueckt.keys():
		var a: Array = _rueckt[zelle]
		if a[1] == null:
			if _zeit - float(a[0]) > 1.0:
				_rueckt.erase(zelle)     # Kachel gibt es nicht mehr
			continue
		var t := clampf((_zeit - float(a[0])) / RUECK_DAUER, 0.0, 1.0)
		var ruhe: Transform3D = a[3]
		if t >= 1.0:
			a[1].set_instance_transform(a[2], ruhe)
			_rueckt.erase(zelle)
			continue
		# weich heraus, am Ende ein kleiner Überschwinger
		var e := 1.0 - pow(1.0 - t, 3.0)
		var hoch := sin(t * PI) * 0.018
		var jetzt := Transform3D(ruhe.basis.scaled(Vector3.ONE * lerpf(0.5, 1.0, e)), ruhe.origin + Vector3(0, -0.1 * (1.0 - e) + hoch, 0))
		a[1].set_instance_transform(a[2], jetzt)


## Wie viele Nüsse gerade zu sehen sind (für Tests und Messungen).
func sichtbare_nuesse() -> Vector2i:
	var oben := 0
	var unten := 0
	for k in _nah:
		for i in 2:
			if _nah[k][i]:
				oben += _nah[k][i].multimesh.instance_count
	for k in _fern:
		for mmi in _fern[k]:
			unten += mmi.multimesh.instance_count
	return Vector2i(oben, unten)


func tiefe_nuesse() -> int:
	var n := 0
	for k in _nah:
		for i in [2, 3]:
			if _nah[k][i]:
				n += _nah[k][i].multimesh.instance_count
	return n


## Baut alle Lagen um eine Stelle sofort fertig (für Bildschirmfotos und Tests; im Spiel
## verteilt sich das über ein paar Bilder).
func sofort_um(mitte: Vector3) -> void:
	_nah_auswaehlen(mitte)
	for k in _nah.keys():
		_nah_bauen(k)
		_tief_bauen(k)
	_nah_schmutzig.clear()
	_tief_schmutzig.clear()
