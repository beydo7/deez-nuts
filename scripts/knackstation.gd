class_name Knackstation
extends Node3D
## Der Platz auf dem Tisch, an dem geknackt wird. Maustaste halten = zudrücken, loslassen = Druck weg.
## Es gibt keinen Balken im Spiel: Knarzen, Risse und das Zusammendrücken der Nuss zeigen den Druck.

const DRUCK_MAX := 1.3

var geladen := false
var nuss_daten := {}
var druck := 0.0
var drueckt := false
var zonen := {}
var _knarz_timer := 0.0
var _riss_gemeldet := false
var _schwach_gemeldet := false
var _sweet_gemeldet := false
var _sitz := Vector3(0, 0.07, 0)
var _werkzeug_knoten: Node3D
var _backe_l: Node3D
var _backe_r: Node3D
var _hammer: Node3D
var _nuss_vis: Node3D
var _riss_vis: MeshInstance3D
var _riss_vis2: MeshInstance3D
var koerper: Interaktiv


func _ready() -> void:
	Bau.klotz(self, Vector3(0.42, 0.04, 0.26), Vector3(0, 0.02, 0), Color(0.5, 0.33, 0.19))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.06
	ring.mesh = torus
	ring.material_override = Bau.mat(Color(0.3, 0.2, 0.12))
	ring.position = Vector3(0, 0.042, 0)
	add_child(ring)
	koerper = Interaktiv.erzeuge(self, Vector3(0.16, 0.15, 0.15), Vector3(0, 0.075, 0), "Knacker", Callable())
	koerper.set_meta("station", self)
	Game.werkzeug_geaendert.connect(_werkzeug_bauen)
	_werkzeug_bauen()


func _werkzeug_bauen() -> void:
	if _werkzeug_knoten:
		_werkzeug_knoten.queue_free()
	_werkzeug_knoten = Node3D.new()
	add_child(_werkzeug_knoten)
	_backe_l = null
	_backe_r = null
	_hammer = null
	var id := Game.werkzeug_aktiv
	match id:
		"haende":
			_backe_l = _backe(Bau.kugel_mesh(0.055), Bau.mat(Color(0.93, 0.74, 0.6), 0.7))
			_backe_r = _backe(Bau.kugel_mesh(0.055), Bau.mat(Color(0.93, 0.74, 0.6), 0.7))
		"holz":
			_backe_l = _backe(Bau.box_mesh(Vector3(0.05, 0.09, 0.09)), Bau.mat(Color(0.75, 0.12, 0.1), 0.5))
			_backe_r = _backe(Bau.box_mesh(Vector3(0.05, 0.09, 0.09)), Bau.mat(Color(0.12, 0.2, 0.6), 0.5))
			# kleiner Nussknacker-Soldat als Deko
			var soldat := Node3D.new()
			soldat.position = Vector3(0, 0.04, 0.1)
			_werkzeug_knoten.add_child(soldat)
			soldat.add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.035, 0.04, 0.12), Bau.mat(Color(0.75, 0.12, 0.1), 0.5), Vector3(0, 0.06, 0)))
			soldat.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.03), Bau.mat(Color(0.95, 0.8, 0.65)), Vector3(0, 0.15, 0)))
			soldat.add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.025, 0.03, 0.06), Bau.mat(Color(0.08, 0.08, 0.1)), Vector3(0, 0.2, 0)))
		"metall":
			_backe_l = _backe(Bau.box_mesh(Vector3(0.04, 0.07, 0.1)), Bau.mat(Color(0.7, 0.72, 0.75), 0.3, 0.9))
			_backe_r = _backe(Bau.box_mesh(Vector3(0.04, 0.07, 0.1)), Bau.mat(Color(0.7, 0.72, 0.75), 0.3, 0.9))
		"hammer":
			_hammer = Node3D.new()
			_werkzeug_knoten.add_child(_hammer)
			_hammer.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.07, 0.07, 0.14)), Bau.mat(Color(0.35, 0.36, 0.4), 0.3, 0.9)))
			var stiel := Bau.mesh_instanz(Bau.zylinder_mesh(0.012, 0.012, 0.3), Bau.mat(Color(0.6, 0.42, 0.22)), Vector3(0, 0.0, 0.2))
			stiel.rotation_degrees.x = 90
			_hammer.add_child(stiel)
		"schraubstock":
			_backe_l = _backe(Bau.box_mesh(Vector3(0.06, 0.1, 0.16)), Bau.mat(Color(0.25, 0.4, 0.3), 0.4, 0.6))
			_backe_r = _backe(Bau.box_mesh(Vector3(0.06, 0.1, 0.16)), Bau.mat(Color(0.25, 0.4, 0.3), 0.4, 0.6))
			var spindel := Bau.mesh_instanz(Bau.zylinder_mesh(0.012, 0.012, 0.36), Bau.mat(Color(0.7, 0.7, 0.72), 0.3, 0.9), Vector3(0, 0.08, 0))
			spindel.rotation_degrees.z = 90
			_werkzeug_knoten.add_child(spindel)
	koerper.text = Data.werkzeug(id).name
	_visual_aktualisieren()


func _backe(mesh: Mesh, m: Material) -> Node3D:
	var n := Node3D.new()
	n.add_child(Bau.mesh_instanz(mesh, m))
	_werkzeug_knoten.add_child(n)
	return n


func kann_laden() -> bool:
	return not geladen


func lade(daten: Dictionary) -> bool:
	if geladen or daten.get("art", "") != "nuss":
		return false
	geladen = true
	nuss_daten = daten.duplicate()
	druck = 0.0
	drueckt = false
	_zonen_berechnen()
	_nuss_bauen()
	Sfx.spiele("ablegen", -8.0, 1.4)
	return true


func entnehme() -> Dictionary:
	if not geladen or drueckt:
		return {}
	geladen = false
	var d := nuss_daten
	nuss_daten = {}
	if _nuss_vis:
		_nuss_vis.queue_free()
		_nuss_vis = null
	_visual_aktualisieren()
	return d


func _zonen_berechnen() -> void:
	var info: Dictionary = Data.NUESSE[nuss_daten.nuss]
	var wz := Game.werkzeug_werte()
	var w: float = clampf(float(info.sweet) + float(wz.sweet), 0.05, 0.5)
	var mitte := 0.62
	if nuss_daten.get("angeknackst", false):
		mitte -= 0.15
	if info.get("springt", false):
		mitte += randf_range(-0.12, 0.12)
	var s0 := mitte - w * 0.5
	var s1 := mitte + w * 0.5
	var haerte: float = float(info.haerte) * (0.5 if nuss_daten.get("angeknackst", false) else 1.0)
	var kappe := DRUCK_MAX
	if float(wz.kraft) < haerte:
		kappe = s0 - 0.015
	zonen = {"a": max(0.08, s0 - 0.18), "s0": s0, "s1": s1, "m": min(1.22, s1 + 0.2), "kappe": kappe, "zeit": float(wz.zeit)}


func _nuss_bauen() -> void:
	if _nuss_vis:
		_nuss_vis.queue_free()
	var info: Dictionary = Data.NUESSE[nuss_daten.nuss]
	_nuss_vis = Node3D.new()
	_nuss_vis.position = _sitz
	add_child(_nuss_vis)
	var farbe: Color = info.farbe
	var m: Material = Bau.mat(farbe, 0.75)
	if nuss_daten.get("gold", false):
		m = Bau.mat(Color(1.0, 0.78, 0.2), 0.25, 0.9)
	elif nuss_daten.get("faul", false):
		m = Bau.mat(Color(0.26, 0.3, 0.16))
	var kugel := Bau.mesh_instanz(Bau.kugel_mesh(info.groesse, false, 18), m)
	kugel.scale = info.form
	_nuss_vis.add_child(kugel)
	var rm := Bau.mat(Color(0.12, 0.08, 0.04))
	_riss_vis = Bau.mesh_instanz(Bau.box_mesh(Vector3(0.006, info.groesse * 1.7, 0.006)), rm, Vector3(info.groesse * 0.9, 0, 0))
	_riss_vis2 = Bau.mesh_instanz(Bau.box_mesh(Vector3(0.006, info.groesse * 1.4, 0.006)), rm, Vector3(-info.groesse * 0.85, 0, info.groesse * 0.2))
	_riss_vis.rotation_degrees.z = 12
	_riss_vis2.rotation_degrees.z = -18
	_nuss_vis.add_child(_riss_vis)
	_nuss_vis.add_child(_riss_vis2)
	_riss_vis.visible = nuss_daten.get("angeknackst", false)
	_riss_vis2.visible = false
	_visual_aktualisieren()


func druecken_start() -> void:
	if not geladen or drueckt:
		return
	drueckt = true
	druck = 0.0
	_knarz_timer = 0.0
	_riss_gemeldet = false
	_schwach_gemeldet = false
	_sweet_gemeldet = false


func druecken_ende() -> void:
	if not drueckt:
		return
	drueckt = false
	_aufloesen()


func _process(delta: float) -> void:
	if drueckt:
		var vorher := druck
		druck = min(druck + delta / max(0.05, zonen.zeit), zonen.kappe)
		_knarz_timer -= delta
		if _knarz_timer <= 0.0:
			_knarz_timer = 0.11
			Sfx.spiele("knarzen", -12.0 + druck * 6.0, 0.7 + druck * 0.9, 0.04)
		if vorher < zonen.a and druck >= zonen.a and not _riss_gemeldet:
			_riss_gemeldet = true
			Sfx.spiele("knack_riss", -8.0, 1.3)
		if vorher < zonen.s0 and druck >= zonen.s0 and not _sweet_gemeldet:
			_sweet_gemeldet = true
		if druck >= zonen.kappe - 0.0001 and zonen.kappe < DRUCK_MAX and not _schwach_gemeldet:
			_schwach_gemeldet = true
			Game.knack_ergebnis.emit("schwach", "Zu schwach! Erst anknacksen, dann nochmal.")
		if druck >= DRUCK_MAX - 0.0001:
			drueckt = false
			_aufloesen()
	elif druck > 0.0:
		druck = max(0.0, druck - delta * 3.0)
	_visual_aktualisieren()


func _visual_aktualisieren() -> void:
	var info: Dictionary = Data.NUESSE[nuss_daten.get("nuss", "wal")]
	var r: float = info.groesse if geladen else 0.03
	var zu: float = clampf(druck, 0.0, 1.0)
	var offen := 0.06 * (1.0 - zu)
	var backen_breite := 0.03
	if Game.werkzeug_aktiv == "haende":
		backen_breite = 0.055
	elif Game.werkzeug_aktiv == "schraubstock":
		backen_breite = 0.03
	if _backe_l:
		_backe_l.position = _sitz + Vector3(-(r * 0.85 + backen_breite + offen), 0, 0)
	if _backe_r:
		_backe_r.position = _sitz + Vector3(r * 0.85 + backen_breite + offen, 0, 0)
	if _hammer:
		_hammer.position = _sitz + Vector3(0, r + 0.04 + 0.22 * (1.0 - zu), 0)
		_hammer.rotation_degrees.x = -25.0 * (1.0 - zu)
	if _nuss_vis and geladen:
		var quetsch := 1.0 - 0.18 * clampf((druck - zonen.get("a", 0.3)) / 0.6, 0.0, 1.0)
		_nuss_vis.scale = Vector3(quetsch, 1.0 + (1.0 - quetsch) * 0.4, 1.0)
		if drueckt and druck >= zonen.get("s0", 1.0):
			_nuss_vis.position = _sitz + Vector3(randf_range(-0.002, 0.002), randf_range(-0.002, 0.002), 0)
		else:
			_nuss_vis.position = _sitz
		if _riss_vis:
			_riss_vis.visible = nuss_daten.get("angeknackst", false) or druck >= zonen.get("a", 9.0)
		if _riss_vis2:
			_riss_vis2.visible = druck >= zonen.get("s0", 9.0)


func zone_von(d: float) -> String:
	if d < zonen.a:
		return "frueh"
	if d < zonen.s0:
		return "riss"
	if d <= zonen.s1:
		return "perfekt"
	if d < zonen.m:
		return "bruch"
	return "matsch"


func _aufloesen() -> void:
	var zone := zone_von(druck)
	var d := nuss_daten
	var info: Dictionary = Data.NUESSE[d.nuss]
	var welt := get_tree().current_scene
	var pos := global_position + _sitz
	if zone == "frueh":
		Game.knack_ergebnis.emit("frueh", "Zu früh losgelassen")
		return
	if zone == "riss":
		if not d.get("angeknackst", false):
			nuss_daten.angeknackst = true
			_zonen_berechnen()
			Sfx.spiele("knack_riss", -2.0)
			Game.knack_ergebnis.emit("riss", "Riss! Nochmal drücken")
		else:
			Game.knack_ergebnis.emit("frueh", "Noch zu wenig")
		return
	# Ab hier ist die Nuss offen
	geladen = false
	nuss_daten = {}
	if _nuss_vis:
		_nuss_vis.queue_free()
		_nuss_vis = null
	druck = 0.0
	var teile: Array = []
	var schalen := randi_range(3, 4)
	if d.get("faul", false):
		Sfx.spiele("stinken")
		Game.melde_knack(d.nuss, "faul", true)
		Game.knack_ergebnis.emit("faul", "Faul! Bäh.")
		if welt.has_method("stinkwolke"):
			welt.stinkwolke(pos)
		for i in schalen + 1:
			teile.append({"art": "schale", "nuss": d.nuss})
	else:
		match zone:
			"perfekt":
				var anzahl := 4 if d.get("doppel", false) else 2
				Game.melde_knack(d.nuss, "perfekt", true, anzahl)
				var einzel: float = float(info.wert) * (1.0 + Game.combo_bonus())
				if d.get("gold", false):
					einzel *= 25.0
					Game.gold += 1
					Game.toast.emit("Goldene Nuss! +1 Goldene Nuss", Game.FARBE_GOLD)
				for i in anzahl:
					teile.append({"art": "haelfte", "nuss": d.nuss, "wert": einzel, "gold": d.get("gold", false)})
				Sfx.spiele("knack_perfekt", 0.0, 1.0 + min(Game.combo, 20) * 0.015)
				var text := "PERFEKT!"
				if Game.combo >= 2:
					text += "  Combo ×%d (+%d %%)" % [Game.combo, int(Game.combo_bonus() * 100)]
				if d.get("doppel", false):
					text = "DOPPELNUSS!  " + text
				Game.knack_ergebnis.emit("perfekt", text)
			"bruch":
				Game.melde_knack(d.nuss, "bruch", true)
				for i in 3:
					teile.append({"art": "bruch", "nuss": d.nuss, "wert": float(info.wert) * 0.2})
				Sfx.spiele("knirschen")
				Game.knack_ergebnis.emit("bruch", "Bruch – zu fest")
			"matsch":
				Game.melde_knack(d.nuss, "matsch", true)
				Sfx.spiele("matsch")
				Game.knack_ergebnis.emit("matsch", "Matsch!")
		for i in schalen:
			teile.append({"art": "schale", "nuss": d.nuss})
		if d.get("wurm", false) and zone != "matsch":
			teile.append({"art": "wurm", "nuss": d.nuss})
	var erzeugt: Array = []
	if welt and welt.has_method("item_spawnen"):
		for t in teile:
			var richtung := Vector3(randf_range(-1, 1), randf_range(1.2, 2.0), randf_range(-0.4, 1.0)).normalized()
			erzeugt.append(welt.item_spawnen(t, pos + Vector3(0, 0.03, 0), richtung * randf_range(0.6, 1.3)))
		if welt.has_method("nach_knack"):
			welt.nach_knack(erzeugt)
	_visual_aktualisieren()
