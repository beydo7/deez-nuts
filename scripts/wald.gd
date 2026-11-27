class_name Wald
extends Node3D
## Wald und Bewuchs des Haselgrunds. Der Waldgürtel auf den Hügeln wächst in Artengruppen
## (gesteuert von großflächigem Rauschen, mit Lichtungen), in der Talsohle stehen nur die
## Baumgruppen aus dem Weltplan. Dazu Unterholz am Waldrand, Bewuchs am Bach, Felsen am
## Wasserfall und Blumen auf der Wiese. Alles läuft als MultiMesh über den Streuer.

const GRUEN := ["wald/Tree_1_A_Color1.gltf", "wald/Tree_1_B_Color1.gltf", "wald/Tree_1_C_Color1.gltf",
	"wald/Tree_2_A_Color1.gltf", "wald/Tree_2_B_Color1.gltf", "wald/Tree_2_C_Color1.gltf",
	"wald/Tree_3_A_Color1.gltf", "wald/Tree_3_B_Color1.gltf"]
const KAHL := ["wald/Tree_Bare_1_A_Color1.gltf", "wald/Tree_Bare_2_A_Color1.gltf"]

var gelaende: Gelaende
var _rng := RandomNumberGenerator.new()
var _rausch := FastNoiseLite.new()
var _sammlung := {}        # "pfad|herbst" -> [Transform3D]
var _staemme: Array = []   # [Vector3, Radius]
## Orte, an denen kein Baum wachsen darf. [Mitte, Radius]
var _frei: Array = []


func _init(g: Gelaende) -> void:
	gelaende = g
	name = "Wald"
	_rng.seed = 1962
	_rausch.seed = 77
	_rausch.frequency = 1.0


func _ready() -> void:
	for ort in ["wasserfall", "koenigseiche", "mondlichtung", "hochsitz", "siedlung", "picknick", "heuschober", "angelplatz", "feuerstelle", "hoftor", "traktor"]:
		var p: Vector3 = WeltPlan.ORTE[ort]
		_frei.append([Vector2(p.x, p.z), 9.0 if ort in ["mondlichtung", "siedlung", "koenigseiche"] else 6.0])
	_waldguertel()
	_baumgruppen()
	_unterholz()
	_bachbewuchs()
	_wasserfall_felsen()
	_wiese()
	for schluessel in _sammlung:
		var teile: PackedStringArray = schluessel.split("|")
		var ist_baum := teile[0].begins_with("wald/Tree")
		var optionen := {
			"herbst": teile[1] == "1",
			"schatten": ist_baum or teile[0].contains("Rock_1_D") or teile[0].contains("Rock_2_C") or teile[0].contains("Rock_3_E"),
			"sicht": 0.0 if ist_baum else (70.0 if teile[0].begins_with("wald/Rock") or teile[0].begins_with("wald/Bush") else 45.0),
		}
		# KayKit-Felsen sind sehr blau, im Herbstlicht wärmer abtönen
		if teile[0].begins_with("wald/Rock"):
			optionen["ton"] = Color(1.18, 0.98, 0.76)
		Streuer.setzen(self, teile[0], _sammlung[schluessel], optionen)
	_kollision()


func _merke(pfad: String, t: Transform3D, herbst := false) -> void:
	var k := "%s|%d" % [pfad, 1 if herbst else 0]
	if not _sammlung.has(k):
		_sammlung[k] = []
	_sammlung[k].append(t)


func _ist_frei(p: Vector2, zusatz := 0.0) -> bool:
	for f in _frei:
		if p.distance_to(f[0]) < float(f[1]) + zusatz:
			return false
	return true


func _baum(pos: Vector3, art: String, skala: float) -> void:
	var herbst := false
	var pfad: String
	if art == "kahl" or (art != "gruen" and _rng.randf() < 0.05):
		pfad = KAHL[_rng.randi() % KAHL.size()]
		skala *= 1.3
	else:
		pfad = GRUEN[_rng.randi() % GRUEN.size()]
		match art:
			"herbst":
				herbst = _rng.randf() < 0.85
			"gemischt":
				herbst = _rng.randf() < 0.5
			_:
				herbst = _rng.randf() < 0.12
	_merke(pfad, Streuer.lage(pos + Vector3(0, -0.15, 0), _rng.randf() * TAU, skala, 0.06, _rng), herbst)
	_staemme.append([pos, 0.28 * skala])


## Bäume auf den Hügeln: dicht, in Artengruppen, mit ein paar Lichtungen.
func _waldguertel() -> void:
	var raster := 4.4
	var x := -118.0
	while x < 118.0:
		var z := -133.0
		while z < 98.0:
			var px := x + _rng.randf_range(-1.7, 1.7)
			var pz := z + _rng.randf_range(-1.7, 1.7)
			z += raster
			var r := WeltPlan.tal_r(px, pz)
			if r < 0.9 or r > WeltPlan.GRENZE + 0.35:
				continue
			var dichte := smoothstep(0.9, 1.04, r)
			var lichtung := _rausch.get_noise_2d(px * 0.05, pz * 0.05)
			if lichtung < -0.42 and r < 1.3:
				continue
			if _rng.randf() > dichte * 0.92:
				continue
			if gelaende.bach_abstand(px, pz) < 3.6 or gelaende.weg_bei(px, pz) > 0.25:
				continue
			if not _ist_frei(Vector2(px, pz)):
				continue
			var gruppe := _rausch.get_noise_2d(px * 0.025 + 40.0, pz * 0.025)
			var art := "gemischt"
			if gruppe < -0.18:
				art = "gruen"
			elif gruppe > 0.22:
				art = "herbst"
			var skala := _rng.randf_range(1.15, 1.6) + clampf((r - 1.05) * 1.2, 0.0, 0.5)
			_baum(gelaende.position(px, pz), art, skala)
		x += raster


func _baumgruppen() -> void:
	for g in WeltPlan.BAUMGRUPPEN:
		var mitte: Vector2 = g[0]
		var gesetzt: Array = []
		var versuche := 0
		while gesetzt.size() < int(g[1]) and versuche < 60:
			versuche += 1
			var w := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * float(g[2])
			var p := mitte + Vector2(cos(w), sin(w)) * d
			var zu_nah := false
			for q in gesetzt:
				if p.distance_to(q) < 3.2:
					zu_nah = true
			if zu_nah or gelaende.bach_abstand(p.x, p.y) < 3.0 or gelaende.weg_bei(p.x, p.y) > 0.3:
				continue
			if WeltPlan.bebaut(p.x, p.y, 2.5) or not _ist_frei(p, -2.0):
				continue
			gesetzt.append(p)
			_baum(gelaende.position(p.x, p.y), g[3], _rng.randf_range(1.05, 1.45))


## Am Waldrand: Büsche, Steine, umgestürzte Stämme, Baumstümpfe, Pilze, hohes Gras.
func _unterholz() -> void:
	var arten := [
		["wald/Bush_1_C_Color1.gltf", 0.9, 1.5, 0.30, true],
		["wald/Bush_2_C_Color1.gltf", 0.6, 1.0, 0.12, true],
		["wald/Bush_3_A_Color1.gltf", 1.0, 1.6, 0.18, true],
		["wald/Rock_1_D_Color1.gltf", 0.8, 1.5, 0.06, false],
		["wald/Rock_3_A_Color1.gltf", 0.8, 1.6, 0.05, false],
		["natur/log_large.glb", 2.6, 3.4, 0.03, false],
		["natur/stump_old.glb", 2.6, 3.4, 0.04, false],
		["natur/mushroom_redGroup.glb", 1.4, 2.0, 0.05, false],
		["natur/mushroom_tanGroup.glb", 1.4, 2.0, 0.05, false],
		["wald/Grass_2_C_Color1.gltf", 0.9, 1.3, 0.12, false],
	]
	var summe := 0.0
	for a in arten:
		summe += float(a[3])
	var n := 0
	var versuche := 0
	while n < 620 and versuche < 9000:
		versuche += 1
		var w := _rng.randf() * TAU
		var r := _rng.randf_range(0.86, 1.22)
		var px := WeltPlan.TAL_MITTE.x + cos(w) * WeltPlan.TAL_RADIEN.x * r
		var pz := WeltPlan.TAL_MITTE.y + sin(w) * WeltPlan.TAL_RADIEN.y * r
		if gelaende.bach_abstand(px, pz) < 2.6 or gelaende.weg_bei(px, pz) > 0.2 or not _ist_frei(Vector2(px, pz), -2.0):
			continue
		var wahl := _rng.randf() * summe
		var art: Array = arten[0]
		for a in arten:
			wahl -= float(a[3])
			if wahl <= 0.0:
				art = a
				break
		var herbst: bool = art[4] and _rng.randf() < 0.45
		_merke(art[0], Streuer.lage(gelaende.position(px, pz) + Vector3(0, -0.05, 0), _rng.randf() * TAU, _rng.randf_range(art[1], art[2]), 0.08, _rng), herbst)
		n += 1


## Am Bach: Steine im Wasser, Gras und Büsche am Ufer.
func _bachbewuchs() -> void:
	var weg := Bach.glaetten(WeltPlan.BACH, 1.5)
	for i in weg.size():
		var p: Vector3 = weg[i]
		if p.y > 1.0:
			continue
		var vor: Vector3 = (weg[mini(i + 1, weg.size() - 1)] - weg[maxi(i - 1, 0)])
		vor.y = 0.0
		vor = vor.normalized()
		var quer := Vector3(-vor.z, 0, vor.x)
		# Steine im Wasser
		if _rng.randf() < 0.35:
			var s := p + quer * _rng.randf_range(-1.1, 1.1)
			s.y = gelaende.hoehe_bei(s.x, s.z) - 0.05
			_merke("wald/Rock_2_A_Color1.gltf", Streuer.lage(s, _rng.randf() * TAU, _rng.randf_range(1.6, 3.2), 0.3, _rng))
		# Ufergras und -steine
		for seite in [-1.0, 1.0]:
			if _rng.randf() < 0.55:
				var u: Vector3 = p + quer * seite * _rng.randf_range(2.0, 3.4)
				if gelaende.weg_bei(u.x, u.z) > 0.2 or not _ist_frei(Vector2(u.x, u.z), -3.0):
					continue
				var pfad := "wald/Grass_2_C_Color1.gltf" if _rng.randf() < 0.7 else "wald/Grass_1_C_Color1.gltf"
				_merke(pfad, Streuer.lage(gelaende.position(u.x, u.z), _rng.randf() * TAU, _rng.randf_range(0.9, 1.4)))
			if _rng.randf() < 0.08:
				var u2: Vector3 = p + quer * seite * _rng.randf_range(2.4, 3.6)
				if _ist_frei(Vector2(u2.x, u2.z), -3.0):
					_merke("wald/Rock_1_A_Color1.gltf", Streuer.lage(gelaende.position(u2.x, u2.z), _rng.randf() * TAU, _rng.randf_range(1.0, 1.8), 0.2, _rng))


## Große Felsen rahmen den Wasserfall und verdecken die Kante der Felsstufe.
func _wasserfall_felsen() -> void:
	var k := WeltPlan.BACH_KANTE
	var kante: Vector3 = WeltPlan.BACH[k]
	var becken: Vector3 = WeltPlan.BACH[k + 1]
	var richtung := Vector3(becken.x - kante.x, 0, becken.z - kante.z).normalized()
	var quer := Vector3(-richtung.z, 0, richtung.x)
	var felsen := [
		# [Modell, seitlich, entlang, Höhe über Becken, Skala]
		["wald/Rock_3_E_Color1.gltf", 2.9, 0.6, 2.4, 3.2],
		["wald/Rock_3_E_Color1.gltf", -3.0, 0.4, 2.2, 3.4],
		["wald/Rock_1_D_Color1.gltf", 4.6, -1.2, 3.4, 3.0],
		["wald/Rock_1_D_Color1.gltf", -4.8, -1.0, 3.2, 2.8],
		["wald/Rock_2_C_Color1.gltf", 3.4, 3.4, 0.0, 1.8],
		["wald/Rock_2_C_Color1.gltf", -3.6, 3.0, 0.0, 2.0],
		["wald/Rock_3_A_Color1.gltf", 2.2, 5.2, 0.0, 1.4],
		["wald/Rock_1_A_Color1.gltf", -2.4, 5.6, 0.0, 1.3],
		["wald/Rock_3_A_Color1.gltf", 6.6, 1.2, 1.4, 2.4],
		["wald/Rock_3_A_Color1.gltf", -6.8, 1.0, 1.2, 2.6],
	]
	for f in felsen:
		var p: Vector3 = kante + quer * float(f[1]) + richtung * float(f[2])
		p.y = becken.y + float(f[3])
		_merke(f[0], Streuer.lage(p, _rng.randf() * TAU, float(f[4]), 0.15, _rng))
		_staemme.append([p, 0.6 * float(f[4])])
	# Moos und Farn auf den Felsen
	for i in 8:
		var p2: Vector3 = kante + quer * _rng.randf_range(-6.0, 6.0) + richtung * _rng.randf_range(-3.0, 1.0)
		if absf(quer.dot(p2 - kante)) < 1.8:
			continue
		_merke("wald/Bush_3_A_Color1.gltf", Streuer.lage(gelaende.position(p2.x, p2.z), _rng.randf() * TAU, _rng.randf_range(0.8, 1.3)))


## Blumen und Grasbüschel auf der Wiese, in Flecken statt gleichmäßig.
func _wiese() -> void:
	var arten := [
		["natur/flower_redA.glb", 1.3, 1.8], ["natur/flower_yellowA.glb", 1.3, 1.8], ["natur/flower_purpleA.glb", 1.2, 1.6],
		["natur/flower_redB.glb", 1.2, 1.6], ["natur/flower_yellowB.glb", 1.2, 1.6],
	]
	var flecken := 0
	var versuche := 0
	while flecken < 70 and versuche < 2000:
		versuche += 1
		var px := _rng.randf_range(-60.0, 62.0)
		var pz := _rng.randf_range(-80.0, 54.0)
		var r := WeltPlan.tal_r(px, pz)
		if r > 0.9 or not _wiese_frei(px, pz, 3.0):
			continue
		flecken += 1
		var art: Array = arten[_rng.randi() % arten.size()]
		for i in _rng.randi_range(8, 20):
			var w := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * 1.8
			var q := Vector2(px + cos(w) * d, pz + sin(w) * d)
			if not _wiese_frei(q.x, q.y, 0.5):
				continue
			_merke(art[0], Streuer.lage(gelaende.position(q.x, q.y), _rng.randf() * TAU, _rng.randf_range(art[1], art[2])))
		for i in _rng.randi_range(1, 4):
			var q2 := Vector2(px + _rng.randf_range(-3, 3), pz + _rng.randf_range(-3, 3))
			if _wiese_frei(q2.x, q2.y, 0.5):
				_merke("wald/Grass_1_C_Color1.gltf", Streuer.lage(gelaende.position(q2.x, q2.y), _rng.randf() * TAU, _rng.randf_range(0.8, 1.2)))


func _wiese_frei(x: float, z: float, rand: float) -> bool:
	if Vector2(x - Nussberg.MITTE.x, z - Nussberg.MITTE.z).length() < Nussberg.RADIUS + 4.0 + rand:
		return false
	if x > -8.0 - rand and x < 13.0 + rand and z > -10.0 - rand and z < 8.0 + rand:
		return false
	if gelaende.bach_abstand(x, z) < 3.5 or gelaende.weg_bei(x, z) > 0.15:
		return false
	if WeltPlan.bebaut(x, z, rand):
		return false
	for po in Data.POSTEN:
		if Vector2(x - po.pos.x, z - po.pos.z).length() < 5.0 + rand:
			return false
	return true


## Baumstämme und große Felsen bekommen Kollision (ein Körper, viele Zylinder).
func _kollision() -> void:
	var k := StaticBody3D.new()
	k.name = "Stammkollision"
	k.collision_layer = Data.L_WELT
	for s in _staemme:
		var cs := CollisionShape3D.new()
		var z := CylinderShape3D.new()
		z.radius = float(s[1])
		z.height = 4.0
		cs.shape = z
		cs.position = s[0] + Vector3(0, 2.0, 0)
		k.add_child(cs)
	add_child(k)
