class_name Behaelter
extends RigidBody3D
## Glas, Eimer, Bruchschale und Maschinenkiste. Man kann sie tragen und Dinge hineinwerfen.
## Der Inhalt ist sichtbar: jede Kernhälfte, jedes Bruchstück, jede Schale liegt wirklich drin.

signal geaendert

var typ := "glas"                    # glas | eimer | bruch | kiste
var kapazitaet := 24
var haelften := 0
var bruch := 0
var schalen := 0
var wuermer := 0
var schmutz := 0
var wert := 0.0
var inhalt: Array = []               # "art|nuss" in Einfüllreihenfolge
var heim := Transform3D.IDENTITY
var gehalten := false
var gross := false

var _modell: Node3D
var _deckel: Node3D
var _oeffnung: Area3D
var _form: CollisionShape3D
var _plaetze: Array = []             # Transform3D je Platz
var _multis := {}                    # "art|nuss" -> MultiMeshInstance3D
var _mund_hoehe := 0.1

const NAMEN := {"glas": "Glas", "eimer": "Schaleneimer", "bruch": "Bruchschale", "kiste": "Maschinenkiste"}


static func erzeuge(art: String, gross_ := false) -> Behaelter:
	var b := Behaelter.new()
	b.typ = art
	b.gross = gross_
	b._aufbauen()
	return b


func anzeige_name() -> String:
	if typ == "glas" and gross:
		return "Großes Glas"
	return NAMEN.get(typ, typ)


func _aufbauen() -> void:
	collision_layer = Data.L_BEHAELTER
	collision_mask = Data.L_WELT | Data.L_ITEM | Data.L_BEHAELTER
	mass = 1.0
	can_sleep = true
	angular_damp = 3.0
	linear_damp = 0.5
	_form = CollisionShape3D.new()
	add_child(_form)
	_oeffnung = Area3D.new()
	_oeffnung.collision_layer = 0
	_oeffnung.collision_mask = Data.L_ITEM
	add_child(_oeffnung)
	_oeffnung.body_entered.connect(_koerper_rein)
	_modell_bauen()


func _modell_bauen() -> void:
	if _modell:
		_modell.queue_free()
	for k in _multis:
		_multis[k].queue_free()
	_multis.clear()
	for c in _oeffnung.get_children():
		c.queue_free()
	_modell = Node3D.new()
	add_child(_modell)
	var mund_radius := 0.1
	match typ:
		"glas":
			var r := 0.1 if gross else 0.082
			var h := 0.27 if gross else 0.21
			kapazitaet = 48 if gross else 24
			var koerper := CylinderMesh.new()
			koerper.top_radius = r
			koerper.bottom_radius = r * 0.97
			koerper.height = h
			koerper.cap_top = false
			koerper.radial_segments = 28
			Bau.teil(_modell, koerper, Look.glas(), Vector3(0, h * 0.5 + 0.008, 0))
			Bau.teil(_modell, Bau.zylinder_mesh(r * 0.97, r * 0.95, 0.012, 28), Look.glas(Color(0.75, 0.9, 0.95)), Vector3(0, 0.006, 0))
			# Gewinde-Rand
			var rand := TorusMesh.new()
			rand.inner_radius = r - 0.004
			rand.outer_radius = r + 0.005
			rand.rings = 28
			rand.ring_segments = 6
			Bau.teil(_modell, rand, Look.glas(), Vector3(0, h + 0.002, 0))
			# Etikett
			var etikett := CylinderMesh.new()
			etikett.top_radius = r + 0.0015
			etikett.bottom_radius = r + 0.0015
			etikett.height = h * 0.32
			etikett.cap_top = false
			etikett.cap_bottom = false
			etikett.radial_segments = 28
			var em := Look.stoff(Color(0.95, 0.9, 0.78)).duplicate()
			Bau.teil(_modell, etikett, em, Vector3(0, h * 0.45, 0)).set_meta("etikett", true)
			_deckel = Node3D.new()
			_deckel.position = Vector3(0, h + 0.012, 0)
			_deckel.visible = Game.hat_maschine("deckel")
			_modell.add_child(_deckel)
			Bau.teil(_deckel, Bau.zylinder_mesh(r + 0.008, r + 0.008, 0.022, 28), Look.metall(Color(0.78, 0.14, 0.1), 0.35))
			Bau.teil(_deckel, Bau.zylinder_mesh(r * 0.5, r * 0.6, 0.008, 20), Look.metall(Color(0.85, 0.85, 0.82), 0.3), Vector3(0, 0.014, 0))
			var form := CylinderShape3D.new()
			form.radius = r
			form.height = h
			_form.shape = form
			_form.position = Vector3(0, h * 0.5, 0)
			mund_radius = r + 0.05
			_mund_hoehe = h + 0.08
			_plaetze = _plaetze_zylinder(r - 0.034, h - 0.015, kapazitaet, 0.018)
		"eimer":
			kapazitaet = 30
			var zink := _beidseitig(Look.metall(Color(0.62, 0.65, 0.68), 0.45))
			var e := CylinderMesh.new()
			e.top_radius = 0.17
			e.bottom_radius = 0.13
			e.height = 0.3
			e.cap_top = false
			e.radial_segments = 24
			Bau.teil(_modell, e, zink, Vector3(0, 0.15, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for y in [0.05, 0.28]:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.13 + y * 0.13
				ring.outer_radius = 0.137 + y * 0.13
				Bau.teil(_modell, ring, zink, Vector3(0, y, 0))
			var henkel := TorusMesh.new()
			henkel.inner_radius = 0.165
			henkel.outer_radius = 0.175
			Bau.teil(_modell, henkel, Look.metall(Color(0.4, 0.4, 0.42), 0.4), Vector3(0, 0.3, 0), Vector3(90, 0, 0), Vector3(1, 0.7, 1))
			var form2 := CylinderShape3D.new()
			form2.radius = 0.16
			form2.height = 0.3
			_form.shape = form2
			_form.position = Vector3(0, 0.15, 0)
			mund_radius = 0.26
			_mund_hoehe = 0.42
			_plaetze = _plaetze_zylinder(0.1, 0.25, kapazitaet, 0.022)
		"bruch":
			kapazitaet = 20
			mass = 0.5
			var s := CylinderMesh.new()
			s.top_radius = 0.13
			s.bottom_radius = 0.075
			s.height = 0.065
			s.cap_top = false
			s.radial_segments = 28
			var keramik := StandardMaterial3D.new()
			keramik.albedo_color = Color(0.93, 0.92, 0.88)
			keramik.roughness = 0.25
			keramik.cull_mode = BaseMaterial3D.CULL_DISABLED
			Bau.teil(_modell, s, keramik, Vector3(0, 0.0325, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var blau := TorusMesh.new()
			blau.inner_radius = 0.126
			blau.outer_radius = 0.134
			blau.rings = 28
			Bau.teil(_modell, blau, Look.plastik(Color(0.2, 0.32, 0.6), 0.3), Vector3(0, 0.064, 0))
			var form3 := CylinderShape3D.new()
			form3.radius = 0.13
			form3.height = 0.065
			_form.shape = form3
			_form.position = Vector3(0, 0.0325, 0)
			mund_radius = 0.18
			_mund_hoehe = 0.16
			_plaetze = _plaetze_zylinder(0.07, 0.05, kapazitaet, 0.012)
		"kiste":
			kapazitaet = 80
			mass = 3.0
			var holz := Look.holz(Look.KIEFER, 8.0, 0.0)
			Bau.teil(_modell, Bau.box_mesh(Vector3(0.5, 0.02, 0.36)), holz, Vector3(0, 0.01, 0))
			for seite in [[Vector3(0.5, 0.26, 0.02), Vector3(0, 0.14, 0.17)], [Vector3(0.5, 0.26, 0.02), Vector3(0, 0.14, -0.17)],
					[Vector3(0.02, 0.26, 0.32), Vector3(0.24, 0.14, 0)], [Vector3(0.02, 0.26, 0.32), Vector3(-0.24, 0.14, 0)]]:
				Bau.teil(_modell, Bau.box_mesh(seite[0]), holz, seite[1])
			var form4 := BoxShape3D.new()
			form4.size = Vector3(0.5, 0.28, 0.36)
			_form.shape = form4
			_form.position = Vector3(0, 0.14, 0)
			mund_radius = 0.34
			_mund_hoehe = 0.42
			_plaetze = _plaetze_kiste(Vector3(0.44, 0.22, 0.3), kapazitaet)
	var acs := CollisionShape3D.new()
	var asf := CylinderShape3D.new()
	asf.radius = mund_radius
	asf.height = _mund_hoehe
	acs.shape = asf
	acs.position = Vector3(0, _mund_hoehe * 0.5, 0)
	_oeffnung.add_child(acs)
	_aktualisieren()


func _beidseitig(m: Material) -> Material:
	var k = m.duplicate()
	if k is BaseMaterial3D:
		k.cull_mode = BaseMaterial3D.CULL_DISABLED
	return k


## Plätze in einem Zylinder: Lagen von unten nach oben, leicht verwürfelt.
func _plaetze_zylinder(radius: float, hoehe: float, anzahl: int, lage: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(typ) + anzahl
	var aus: Array = []
	var pro_lage: int = max(3, int(round(anzahl * lage / hoehe)))
	for i in anzahl:
		var l := i / pro_lage
		var k := i % pro_lage
		var w := TAU * float(k) / float(pro_lage) + l * 0.9
		var rr := radius * (0.35 + 0.65 * float(k % 2 == 0)) if pro_lage > 4 else radius * 0.6
		if k == 0 and pro_lage > 5:
			rr = 0.0
		var p := Vector3(cos(w) * rr + rng.randf_range(-0.006, 0.006), 0.012 + l * lage + rng.randf_range(0, 0.006), sin(w) * rr + rng.randf_range(-0.006, 0.006))
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))).scaled(Vector3.ONE * 0.78)
		aus.append(Transform3D(b, p))
	return aus


func _plaetze_kiste(innen: Vector3, anzahl: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var aus: Array = []
	var nx := 6
	var nz := 4
	for i in anzahl:
		var l := i / (nx * nz)
		var k := i % (nx * nz)
		var p := Vector3(-innen.x * 0.5 + (k % nx + 0.5) * innen.x / nx, 0.03 + l * 0.03, -innen.z * 0.5 + (k / nx + 0.5) * innen.z / nz)
		p += Vector3(rng.randf_range(-0.01, 0.01), 0, rng.randf_range(-0.01, 0.01))
		aus.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, 0)), p))
	return aus


func setze_gross(an: bool) -> void:
	if typ != "glas" or gross == an:
		return
	gross = an
	_modell_bauen()


func setze_deckel(an: bool) -> void:
	if _deckel:
		_deckel.visible = an


func _koerper_rein(body: Node) -> void:
	if gehalten:
		return
	if body is Item and not body.gehalten and body.linear_velocity.length() < 6.0 and not body.fliegt:
		if nimmt_auf(body.daten()):
			Sfx.spiele("einwurf", -6.0)
			body.queue_free()


func akzeptiert(art: String) -> bool:
	match typ:
		"glas":
			return art == "haelfte" or art == "bruch" or art == "wurm"
		"eimer":
			return art == "schale"
		"bruch":
			return art == "bruch"
		"kiste":
			return art == "haelfte" or art == "bruch"
	return false


func belegt() -> int:
	return haelften + bruch + schalen + schmutz + wuermer


func voll() -> bool:
	return belegt() >= kapazitaet


func frei() -> int:
	return max(0, kapazitaet - belegt())


func nimmt_auf(d: Dictionary) -> bool:
	if not akzeptiert(d.art) or voll():
		return false
	match d.art:
		"haelfte":
			haelften += 1
			wert += float(d.get("wert", 0.0))
		"bruch":
			bruch += 1
			wert += float(d.get("wert", 0.0))
		"schale":
			schalen += 1
		"wurm":
			wuermer += 1
	inhalt.append("%s|%s" % [d.art, d.get("nuss", "wal")])
	_aktualisieren()
	return true


## Fügt mehrere Teile auf einmal hinzu (Maschinen). Gibt zurück, wie viel nicht mehr passte.
func fuelle(art: String, anzahl: int, einzelwert: float, nuss := "wal") -> int:
	var rest := 0
	for i in anzahl:
		if not nimmt_auf({"art": art, "wert": einzelwert, "nuss": nuss}):
			rest += 1
	return rest


func schmutz_dazu(anzahl: int) -> void:
	var n: int = min(anzahl, frei())
	schmutz += n
	for i in n:
		inhalt.append("schale|wal")
	_aktualisieren()


func nimm_haelften(anzahl: int) -> int:
	var n: int = min(anzahl, haelften)
	if n <= 0:
		return 0
	var anteil := wert * float(n) / float(max(1, haelften + bruch))
	haelften -= n
	wert = max(0.0, wert - anteil)
	var weg := n
	for i in range(inhalt.size() - 1, -1, -1):
		if weg <= 0:
			break
		if str(inhalt[i]).begins_with("haelfte|"):
			inhalt.remove_at(i)
			weg -= 1
	_aktualisieren()
	return n


func qualitaet() -> float:
	var teile := haelften + bruch + schmutz
	if teile == 0:
		return 1.0
	var q := float(haelften) / float(teile)
	q -= 0.1 * wuermer
	return clampf(q, 0.0, 1.0)


func verkaufswert() -> float:
	var v := wert
	if typ == "glas" or typ == "kiste":
		v *= 1.0 + 0.5 * qualitaet()
		var schwelle := 0.5 if Game.hat_talent("grosshandel") else 1.0
		if belegt() >= int(kapazitaet * schwelle):
			v *= 1.2
	elif typ == "eimer":
		v = schalen * 0.2
	return v * Game.preis_faktor()


## Eine Zeile für den Hinweis am Fadenkreuz.
func info_text() -> String:
	var t := "%s  %d/%d" % [anzeige_name(), belegt(), kapazitaet]
	if (typ == "glas" or typ == "kiste" or typ == "bruch") and belegt() > 0:
		t += "  ·  %s Münzen" % Data.zahl(verkaufswert())
		if typ != "bruch":
			t += "  ·  Qualität %d %%" % int(qualitaet() * 100)
	if voll():
		t += "  ·  VOLL"
	return t


func leeren() -> void:
	haelften = 0
	bruch = 0
	schalen = 0
	wuermer = 0
	schmutz = 0
	wert = 0.0
	inhalt.clear()
	_aktualisieren()


func heimkehren() -> void:
	freeze = true
	global_transform = heim
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree() and not gehalten:
		freeze = false


## Kleiner Hüpfer, wenn etwas hineinfällt.
func stoss() -> void:
	if _modell == null:
		return
	var tw := create_tween()
	_modell.scale = Vector3(1.08, 0.92, 1.08)
	tw.tween_property(_modell, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Wo ein neues Teil landen würde (für Flugbahnen).
func naechster_platz_global() -> Vector3:
	var i: int = min(inhalt.size(), _plaetze.size() - 1)
	if i < 0:
		return global_position
	return to_global(_plaetze[i].origin)


func _aktualisieren() -> void:
	_inhalt_zeigen()
	geaendert.emit()


func _inhalt_zeigen() -> void:
	var gruppen := {}
	for i in min(inhalt.size(), _plaetze.size()):
		var k: String = inhalt[i]
		if not gruppen.has(k):
			gruppen[k] = []
		gruppen[k].append(_plaetze[i])
	for k in _multis.keys():
		if not gruppen.has(k):
			_multis[k].multimesh.instance_count = 0
	for k in gruppen:
		var mmi: MultiMeshInstance3D = _multis.get(k)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			var teile: PackedStringArray = str(k).split("|")
			var art: String = teile[0]
			var nuss: String = teile[1] if Data.NUESSE.has(teile[1]) else "wal"
			match art:
				"haelfte":
					mm.mesh = Nussmodelle.kernhaelfte(nuss, 0)
					mmi.material_override = Look.kern(nuss)
				"bruch":
					mm.mesh = Nussmodelle.bruchstueck(nuss, 1)
					mmi.material_override = Look.kern(nuss)
				"schale":
					mm.mesh = Nussmodelle.schalenhaelfte(nuss, 0)
					mmi.material_override = Look.nuss(nuss)
				_:
					mm.mesh = Bau.kugel_mesh(0.008, false, 6)
					mmi.material_override = Look.plastik(Color(0.95, 0.6, 0.65))
			mmi.multimesh = mm
			mmi.set_meta("ohne_rand", true)
			add_child(mmi)
			_multis[k] = mmi
		var liste: Array = gruppen[k]
		mmi.multimesh.instance_count = liste.size()
		for j in liste.size():
			mmi.multimesh.set_instance_transform(j, liste[j])


func als_dict() -> Dictionary:
	return {"haelften": haelften, "bruch": bruch, "schalen": schalen, "wuermer": wuermer, "schmutz": schmutz, "wert": wert, "inhalt": inhalt}


func aus_dict(d: Dictionary) -> void:
	haelften = int(d.get("haelften", 0))
	bruch = int(d.get("bruch", 0))
	schalen = int(d.get("schalen", 0))
	wuermer = int(d.get("wuermer", 0))
	schmutz = int(d.get("schmutz", 0))
	wert = float(d.get("wert", 0.0))
	inhalt = d.get("inhalt", [])
	if inhalt.size() != belegt():
		inhalt.clear()
		for i in haelften:
			inhalt.append("haelfte|wal")
		for i in bruch:
			inhalt.append("bruch|wal")
		for i in schalen + schmutz:
			inhalt.append("schale|wal")
		for i in wuermer:
			inhalt.append("wurm|wal")
	_aktualisieren()
