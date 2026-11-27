class_name Behaelter
extends RigidBody3D
## Glas, Eimer, Bruchschale und Maschinenkiste. Man kann sie tragen und Dinge hineinwerfen.

signal geaendert

var typ := "glas"                    # glas | eimer | bruch | kiste
var kapazitaet := 24
var haelften := 0
var bruch := 0
var schalen := 0
var wuermer := 0
var schmutz := 0                     # Schalen in Kiste/Glas
var wert := 0.0
var heim := Transform3D.IDENTITY
var gehalten := false
var _schild: Label3D
var _fuellung: MeshInstance3D
var _deckel: MeshInstance3D
var _oeffnung: Area3D
var _fuell_hoehe := 0.2

const NAMEN := {"glas": "Glas", "eimer": "Schaleneimer", "bruch": "Bruchschale", "kiste": "Maschinenkiste"}


static func erzeuge(art: String) -> Behaelter:
	var b := Behaelter.new()
	b.typ = art
	b._aufbauen()
	return b


func anzeige_name() -> String:
	return NAMEN.get(typ, typ)


func _aufbauen() -> void:
	collision_layer = Data.L_BEHAELTER
	collision_mask = Data.L_WELT | Data.L_ITEM | Data.L_BEHAELTER
	mass = 1.0
	can_sleep = true
	angular_damp = 3.0
	linear_damp = 0.5
	var cs := CollisionShape3D.new()
	var mund_radius := 0.1
	var mund_hoehe := 0.1
	match typ:
		"glas":
			kapazitaet = 24
			var koerper := Bau.mesh_instanz(Bau.zylinder_mesh(0.085, 0.08, 0.22), Bau.mat(Color(0.75, 0.9, 0.95, 0.28), 0.05, 0.0, true), Vector3(0, 0.11, 0))
			add_child(koerper)
			_fuellung = Bau.mesh_instanz(Bau.zylinder_mesh(0.075, 0.072, 1.0), Bau.mat(Color(0.88, 0.74, 0.5)), Vector3.ZERO)
			add_child(_fuellung)
			_fuell_hoehe = 0.2
			_deckel = Bau.mesh_instanz(Bau.zylinder_mesh(0.09, 0.09, 0.025), Bau.mat(Color(0.75, 0.15, 0.12), 0.4, 0.3), Vector3(0, 0.235, 0))
			_deckel.visible = false
			add_child(_deckel)
			var form := CylinderShape3D.new()
			form.radius = 0.085
			form.height = 0.22
			cs.shape = form
			cs.position = Vector3(0, 0.11, 0)
			mund_radius = 0.13
			mund_hoehe = 0.28
		"eimer":
			kapazitaet = 30
			add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.17, 0.13, 0.3), Bau.mat(Color(0.55, 0.58, 0.62), 0.35, 0.7), Vector3(0, 0.15, 0)))
			_fuellung = Bau.mesh_instanz(Bau.zylinder_mesh(0.15, 0.125, 1.0), Bau.mat(Color(0.45, 0.3, 0.17)), Vector3.ZERO)
			add_child(_fuellung)
			_fuell_hoehe = 0.27
			var henkel := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.16
			torus.outer_radius = 0.175
			henkel.mesh = torus
			henkel.material_override = Bau.mat(Color(0.4, 0.4, 0.42), 0.4, 0.8)
			henkel.rotation_degrees.x = 90
			henkel.position.y = 0.3
			add_child(henkel)
			var form2 := CylinderShape3D.new()
			form2.radius = 0.16
			form2.height = 0.3
			cs.shape = form2
			cs.position = Vector3(0, 0.15, 0)
			mund_radius = 0.24
			mund_hoehe = 0.4
		"bruch":
			kapazitaet = 20
			mass = 0.5
			add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.13, 0.08, 0.07), Bau.mat(Color(0.82, 0.8, 0.74), 0.4), Vector3(0, 0.035, 0)))
			_fuellung = Bau.mesh_instanz(Bau.zylinder_mesh(0.115, 0.08, 1.0), Bau.mat(Color(0.85, 0.7, 0.45)), Vector3.ZERO)
			add_child(_fuellung)
			_fuell_hoehe = 0.06
			var form3 := CylinderShape3D.new()
			form3.radius = 0.13
			form3.height = 0.07
			cs.shape = form3
			cs.position = Vector3(0, 0.035, 0)
			mund_radius = 0.17
			mund_hoehe = 0.16
		"kiste":
			kapazitaet = 80
			mass = 3.0
			add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.5, 0.28, 0.36)), Bau.mat(Color(0.62, 0.45, 0.26)), Vector3(0, 0.14, 0)))
			_fuellung = Bau.mesh_instanz(Bau.box_mesh(Vector3(0.44, 1.0, 0.3)), Bau.mat(Color(0.88, 0.74, 0.5)), Vector3.ZERO)
			add_child(_fuellung)
			_fuell_hoehe = 0.24
			var form4 := BoxShape3D.new()
			form4.size = Vector3(0.5, 0.28, 0.36)
			cs.shape = form4
			cs.position = Vector3(0, 0.14, 0)
			mund_radius = 0.32
			mund_hoehe = 0.4
	add_child(cs)
	# Öffnung: alles, was hineinfällt, wird aufgenommen
	_oeffnung = Area3D.new()
	_oeffnung.collision_layer = 0
	_oeffnung.collision_mask = Data.L_ITEM
	var acs := CollisionShape3D.new()
	var asf := CylinderShape3D.new()
	asf.radius = mund_radius
	asf.height = mund_hoehe
	acs.shape = asf
	acs.position = Vector3(0, mund_hoehe * 0.5, 0)
	_oeffnung.add_child(acs)
	add_child(_oeffnung)
	_oeffnung.body_entered.connect(_koerper_rein)
	_schild = Bau.schild(self, "", Vector3(0, mund_hoehe + 0.06, 0), 22, Color.WHITE, true)
	_schild.pixel_size = 0.0016
	_schild.visibility_range_end = 3.2
	_schild.visibility_range_end_margin = 0.6
	_schild.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_aktualisieren()


func _koerper_rein(body: Node) -> void:
	if gehalten:
		return
	if body is Item and not body.gehalten and body.linear_velocity.length() < 6.0:
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


func nimmt_auf(d: Dictionary) -> bool:
	if not akzeptiert(d.art) or voll():
		return false
	match d.art:
		"haelfte":
			haelften += 1
			wert += float(d.wert)
		"bruch":
			bruch += 1
			wert += float(d.wert)
		"schale":
			schalen += 1
		"wurm":
			wuermer += 1
	_aktualisieren()
	return true


## Fügt mehrere Teile auf einmal hinzu (Maschinen, Sieb). Gibt zurück, wie viel nicht mehr passte.
func fuelle(art: String, anzahl: int, einzelwert: float) -> int:
	var rest := 0
	for i in anzahl:
		if not nimmt_auf({"art": art, "wert": einzelwert}):
			rest += 1
	return rest


func schmutz_dazu(anzahl: int) -> void:
	schmutz = min(schmutz + anzahl, kapazitaet - (haelften + bruch + schalen + wuermer))
	_aktualisieren()


func nimm_haelften(anzahl: int) -> int:
	var n: int = min(anzahl, haelften)
	if n <= 0:
		return 0
	var anteil := wert * float(n) / float(max(1, haelften + bruch))
	haelften -= n
	wert = max(0.0, wert - anteil)
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
	return v * Game.preis_faktor()


func leeren() -> void:
	haelften = 0
	bruch = 0
	schalen = 0
	wuermer = 0
	schmutz = 0
	wert = 0.0
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


func setze_deckel(an: bool) -> void:
	if _deckel:
		_deckel.visible = an


func _aktualisieren() -> void:
	var anteil := float(belegt()) / float(kapazitaet)
	if _fuellung:
		_fuellung.visible = anteil > 0.0
		var h: float = max(0.001, _fuell_hoehe * anteil)
		_fuellung.scale = Vector3(1, h, 1)
		_fuellung.position.y = h * 0.5 + 0.005
	if _schild:
		var zeile := "%s  %d/%d" % [anzeige_name(), belegt(), kapazitaet]
		if typ == "glas" or typ == "kiste":
			if belegt() > 0:
				zeile += "\nQualität %d %%  ·  %s Münzen" % [int(qualitaet() * 100), Data.zahl(verkaufswert())]
		elif typ == "bruch" and belegt() > 0:
			zeile += "\n%s Münzen" % Data.zahl(verkaufswert())
		if voll():
			zeile += "\nVOLL"
		_schild.text = zeile
	geaendert.emit()


func als_dict() -> Dictionary:
	return {"haelften": haelften, "bruch": bruch, "schalen": schalen, "wuermer": wuermer, "schmutz": schmutz, "wert": wert}


func aus_dict(d: Dictionary) -> void:
	haelften = int(d.get("haelften", 0))
	bruch = int(d.get("bruch", 0))
	schalen = int(d.get("schalen", 0))
	wuermer = int(d.get("wuermer", 0))
	schmutz = int(d.get("schmutz", 0))
	wert = float(d.get("wert", 0.0))
	_aktualisieren()
