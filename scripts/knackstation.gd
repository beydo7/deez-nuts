class_name Knackstation
extends Node3D
## Der Nussknacker auf dem Tisch. Maustaste halten = zudrücken, loslassen = knacken.
## Kein Balken im Spiel: Hebel, Hände, Knarzen, wachsende Risse und Zittern zeigen den Druck.

signal geknackt(ergebnis: String, pos: Vector3)

const DRUCK_MAX := 1.3
const BRETT_H := 0.025

var geladen := false
var nuss_daten := {}
var druck := 0.0
var drueckt := false
var zonen := {}
var koerper: Interaktiv
var haende_sichtbar := false
var letzte_nuss := "wal"

var _knarz_timer := 0.0
var _knister_timer := 0.0
var _riss_gemeldet := false
var _schwach_gemeldet := false
var _sweet_gemeldet := false
var _sitz := Vector3(0, 0.07, 0)
var _achse := Vector3.UP
var _unterlage := BRETT_H
var _werkzeug: Node3D
var _nuss_vis: MeshInstance3D
var _nuss_mat: ShaderMaterial
var _anzeige_druck := 0.0          # geglätteter Druck für die Optik
var _schlag := 0.0                 # Hammer: 1 = gerade zugeschlagen, klingt ab
var _wackeln := 0.0

# Werkzeugteile
var _backe_l: Node3D
var _backe_r: Node3D
var _hebel: Node3D
var _hebel_offen := 30.0
var _hebel_kontakt := 5.0
var _hammer: Node3D
var _kurbel: Node3D
var _kurbel_griff: Node3D
var hand_r: Hand
var hand_l: Hand
var _hand_l_ruhe := Transform3D.IDENTITY


func _ready() -> void:
	# Schneidebrett mit Mulde
	var brett := Bau.mesh_instanz(Bau.box_mesh(Vector3(0.5, BRETT_H, 0.32)), Look.holz(Look.KIEFER, 9.0, 0.15), Vector3(0, BRETT_H * 0.5, 0))
	add_child(brett)
	koerper = Interaktiv.erzeuge(self, Vector3(0.17, 0.15, 0.15), Vector3(0, 0.075, 0), "Knacker", Callable())
	koerper.set_meta("station", self)
	hand_r = Hand.erzeuge(false)
	hand_l = Hand.erzeuge(true)
	add_child(hand_r)
	add_child(hand_l)
	Game.werkzeug_geaendert.connect(_werkzeug_bauen)
	_werkzeug_bauen()
	zeige_haende(false)


func zeige_haende(an: bool) -> void:
	haende_sichtbar = an
	hand_r.visible = an
	hand_l.visible = an


func sitz_global() -> Vector3:
	return to_global(_sitz)


# =============================================================================
# Werkzeuge bauen
# =============================================================================
func _werkzeug_bauen() -> void:
	if _werkzeug:
		_werkzeug.queue_free()
	_werkzeug = Node3D.new()
	add_child(_werkzeug)
	_backe_l = null
	_backe_r = null
	_hebel = null
	_hammer = null
	_kurbel = null
	_kurbel_griff = null
	for h in [hand_r, hand_l]:
		if h.get_parent() != self:
			h.get_parent().remove_child(h)
			add_child(h)
		h.transform = Transform3D.IDENTITY
		if h == hand_l:
			h.scale = Vector3(-1, 1, 1)
	var id := Game.werkzeug_aktiv
	_unterlage = BRETT_H
	match id:
		"haende":
			_achse = Vector3.RIGHT
		"holz", "metall":
			_achse = Vector3.UP
			_hebelpresse(id == "metall")
		"hammer":
			_achse = Vector3.UP
			_hammer_bauen()
		"schraubstock":
			_achse = Vector3.RIGHT
			_schraubstock_bauen()
	koerper.text = Data.werkzeug(id).name
	_sitz_berechnen()
	if _nuss_mat:
		_nuss_mat.set_shader_parameter("achse", _achse)
	_visual_aktualisieren(0.0)


func _hebelpresse(metall: bool) -> void:
	var holz := Look.holz(Look.NUSSBAUM, 6.0, 0.35)
	var mat_arm: Material = Look.metall(Color(0.78, 0.8, 0.84), 0.22) if metall else Look.holz(Look.EICHE, 6.0, 0.3)
	var griff_mat: Material = Look.plastik(Color(0.12, 0.12, 0.13), 0.5) if metall else Look.lackiert(Color(0.62, 0.12, 0.08), 0.7)
	_unterlage = BRETT_H + 0.022
	Bau.teil(_werkzeug, Bau.box_mesh(Vector3(0.34, 0.022, 0.13)), holz, Vector3(-0.02, BRETT_H + 0.011, 0))
	Bau.teil(_werkzeug, Bau.zylinder_mesh(0.028, 0.03, 0.004, 20), Look.metall(Color(0.55, 0.5, 0.45), 0.4), Vector3(0, _unterlage + 0.002, 0))
	# Pfosten mit Gelenk
	Bau.teil(_werkzeug, Bau.box_mesh(Vector3(0.04, 0.2, 0.06)), holz, Vector3(-0.15, _unterlage + 0.1, 0))
	Bau.teil(_werkzeug, Bau.zylinder_mesh(0.012, 0.012, 0.075, 12), Look.metall(Color(0.6, 0.55, 0.5), 0.3), Vector3(-0.15, _unterlage + 0.19, 0), Vector3(90, 0, 0))
	_hebel = Node3D.new()
	_hebel.position = Vector3(-0.15, _unterlage + 0.19, 0)
	_werkzeug.add_child(_hebel)
	var laenge := 0.36
	Bau.teil(_hebel, Bau.box_mesh(Vector3(laenge, 0.026, 0.036)), mat_arm, Vector3(laenge * 0.5 - 0.02, 0, 0))
	# Druckstempel über der Nuss (Abstand 0.15 zum Gelenk)
	Bau.teil(_hebel, Bau.zylinder_mesh(0.022, 0.026, 0.05, 16), mat_arm, Vector3(0.15, -0.035, 0))
	Bau.teil(_hebel, Bau.zylinder_mesh(0.03, 0.03, 0.006, 16), Look.metall(Color(0.5, 0.48, 0.45), 0.4), Vector3(0.15, -0.062, 0))
	# Griff
	Bau.teil(_hebel, Bau.zylinder_mesh(0.019, 0.019, 0.11, 14), griff_mat, Vector3(laenge - 0.06, 0.0, 0), Vector3(0, 0, 90))
	# Rechte Hand am Griff, linke Hand hält die Platte
	remove_child(hand_r)
	_hebel.add_child(hand_r)
	hand_r.position = Vector3(laenge - 0.06, 0.028, 0.012)
	hand_r.rotation_degrees = Vector3(0, -12, 0)
	hand_l.position = Vector3(-0.14, _unterlage + 0.02, 0.1)
	hand_l.rotation_degrees = Vector3(0, -25, 0)
	_hand_l_ruhe = hand_l.transform


func _hammer_bauen() -> void:
	_hammer = Node3D.new()
	_werkzeug.add_child(_hammer)
	var holz := Look.holz(Look.EICHE, 8.0, 0.25)
	Bau.teil(_hammer, Bau.zylinder_mesh(0.012, 0.014, 0.34, 12), holz, Vector3(-0.17, 0, 0), Vector3(0, 0, 90))
	Bau.teil(_hammer, Bau.box_mesh(Vector3(0.05, 0.05, 0.11)), Look.metall(Color(0.42, 0.43, 0.47), 0.3), Vector3(-0.33, 0, 0))
	Bau.teil(_hammer, Bau.zylinder_mesh(0.026, 0.026, 0.02, 16), Look.metall(Color(0.55, 0.56, 0.6), 0.25), Vector3(-0.33, -0.032, 0))
	remove_child(hand_r)
	_hammer.add_child(hand_r)
	hand_r.position = Vector3(-0.04, 0.02, 0.0)
	hand_r.rotation_degrees = Vector3(0, -8, 0)
	hand_l.position = Vector3(-0.16, BRETT_H + 0.02, 0.1)
	hand_l.rotation_degrees = Vector3(0, -30, 0)
	_hand_l_ruhe = hand_l.transform


func _schraubstock_bauen() -> void:
	var gruen := Look.metall(Color(0.22, 0.38, 0.3), 0.45)
	var stahl := Look.metall(Color(0.7, 0.72, 0.75), 0.25)
	_unterlage = BRETT_H + 0.03
	Bau.teil(_werkzeug, Bau.box_mesh(Vector3(0.36, 0.03, 0.1)), gruen, Vector3(0.02, BRETT_H + 0.015, 0))
	_backe_l = Node3D.new()
	_werkzeug.add_child(_backe_l)
	Bau.teil(_backe_l, Bau.box_mesh(Vector3(0.04, 0.09, 0.12)), gruen, Vector3(-0.02, 0.0, 0))
	Bau.teil(_backe_l, Bau.box_mesh(Vector3(0.006, 0.07, 0.11)), stahl, Vector3(0.0, 0.0, 0))
	_backe_r = Node3D.new()
	_werkzeug.add_child(_backe_r)
	Bau.teil(_backe_r, Bau.box_mesh(Vector3(0.04, 0.09, 0.12)), gruen, Vector3(0.02, 0.0, 0))
	Bau.teil(_backe_r, Bau.box_mesh(Vector3(0.006, 0.07, 0.11)), stahl, Vector3(0.0, 0.0, 0))
	Bau.teil(_werkzeug, Bau.zylinder_mesh(0.01, 0.01, 0.3, 10), stahl, Vector3(0.12, _unterlage + 0.03, 0), Vector3(0, 0, 90))
	_kurbel = Node3D.new()
	_kurbel.position = Vector3(0.27, _unterlage + 0.03, 0)
	_werkzeug.add_child(_kurbel)
	Bau.teil(_kurbel, Bau.box_mesh(Vector3(0.012, 0.12, 0.016)), stahl, Vector3(0, -0.05, 0))
	_kurbel_griff = Node3D.new()
	_kurbel_griff.position = Vector3(0.02, -0.1, 0)
	_kurbel.add_child(_kurbel_griff)
	Bau.teil(_kurbel_griff, Bau.zylinder_mesh(0.012, 0.012, 0.05, 10), Look.plastik(Color(0.1, 0.1, 0.1)), Vector3(0.02, 0, 0), Vector3(0, 0, 90))
	hand_l.position = Vector3(-0.12, _unterlage + 0.02, 0.09)
	hand_l.rotation_degrees = Vector3(0, -25, 0)
	_hand_l_ruhe = hand_l.transform


func _sitz_berechnen() -> void:
	var info: Dictionary = Data.NUESSE[nuss_daten.get("nuss", "wal")]
	var unten := float(info.groesse)
	if _nuss_vis:
		unten = -_nuss_vis.mesh.get_aabb().position.y
	_sitz = Vector3(0, _unterlage + unten, 0)
	if _hebel:
		# Winkel, bei dem der Stempel die Nussoberseite berührt
		var oben := _sitz.y + (_nuss_vis.mesh.get_aabb().end.y if _nuss_vis else unten)
		_hebel_kontakt = _hebel_winkel_fuer(oben)
		_hebel_offen = _hebel_kontakt + 24.0


func _hebel_winkel_fuer(hoehe: float) -> float:
	# Stempelunterseite liegt im Hebel bei (0.15, -0.065)
	var best := 0.0
	var best_f := 99.0
	for i in 121:
		var w := deg_to_rad(-30.0 + i * 0.5)
		var y := _hebel.position.y + 0.15 * sin(w) - 0.065 * cos(w)
		var f := absf(y - hoehe)
		if f < best_f:
			best_f = f
			best = rad_to_deg(w)
	return best


# =============================================================================
# Laden und Entnehmen
# =============================================================================
func kann_laden() -> bool:
	return not geladen


func lade(daten: Dictionary) -> bool:
	if geladen or daten.get("art", "") != "nuss":
		return false
	geladen = true
	nuss_daten = daten.duplicate()
	druck = 0.0
	_anzeige_druck = 0.0
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
	_visual_aktualisieren(0.0)
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
	var id: String = nuss_daten.nuss
	_nuss_vis = MeshInstance3D.new()
	_nuss_vis.mesh = Nussmodelle.ganz(id, randi() % 3, 2)
	_nuss_mat = Look.nuss(id, nuss_daten.get("gold", false), nuss_daten.get("faul", false), true)
	_nuss_mat.set_shader_parameter("achse", _achse)
	_nuss_mat.set_shader_parameter("riss", 0.35 if nuss_daten.get("angeknackst", false) else 0.0)
	_nuss_vis.material_override = _nuss_mat
	_nuss_vis.rotation_degrees.y = randf_range(-25, 25)
	add_child(_nuss_vis)
	_sitz_berechnen()
	_visual_aktualisieren(0.0)


# =============================================================================
# Drücken
# =============================================================================
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
			_knarz_timer = 0.12 - druck * 0.05
			if Game.werkzeug_aktiv != "hammer":
				Sfx.spiele("knarzen", -14.0 + druck * 7.0, 0.7 + druck * 0.8, 0.05)
			else:
				Sfx.spiele("ausholen", -14.0 + druck * 5.0, 0.8 + druck * 0.5, 0.03)
		if vorher < zonen.a and druck >= zonen.a and not _riss_gemeldet:
			_riss_gemeldet = true
			Sfx.spiele("knack_riss", -8.0, 1.3)
		if druck >= zonen.s0 and druck <= zonen.s1:
			_knister_timer -= delta
			if _knister_timer <= 0.0:
				_knister_timer = 0.07
				Sfx.spiele("knistern", -9.0, 1.0 + (druck - zonen.s0) * 1.5, 0.15)
			if not _sweet_gemeldet:
				_sweet_gemeldet = true
		if druck >= zonen.kappe - 0.0001 and zonen.kappe < DRUCK_MAX and not _schwach_gemeldet:
			_schwach_gemeldet = true
			Game.knack_ergebnis.emit("schwach", "Zu schwach! Erst anknacksen, dann nochmal.")
			Sfx.spiele("fehler", -10.0, 0.8)
		if druck >= DRUCK_MAX - 0.0001:
			drueckt = false
			_aufloesen()
	elif druck > 0.0:
		druck = max(0.0, druck - delta * 3.0)
	_visual_aktualisieren(delta)


func _haende_an_schultern() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or not haende_sichtbar:
		return
	var b := cam.global_basis
	hand_r.schulter = cam.global_position + b * Vector3(0.3, -0.55, 0.1)
	hand_l.schulter = cam.global_position + b * Vector3(-0.3, -0.55, 0.1)


func _visual_aktualisieren(delta: float) -> void:
	_haende_an_schultern()
	var ziel := clampf(druck, 0.0, DRUCK_MAX)
	_anzeige_druck = ziel if delta == 0.0 else lerpf(_anzeige_druck, ziel, 1.0 - exp(-delta * 25.0))
	var d := _anzeige_druck
	var zu := clampf(d, 0.0, 1.0)
	_schlag = max(0.0, _schlag - delta * 6.0)
	_wackeln = max(0.0, _wackeln - delta * 3.0)
	var info: Dictionary = Data.NUESSE[nuss_daten.get("nuss", "wal")]
	var r: float = float(info.groesse) if geladen else 0.03
	var zittern := 0.0
	if drueckt and zonen.has("s0") and druck >= zonen.s0:
		zittern = 1.0 if druck <= zonen.s1 else 0.6
	var wack := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.0018 * zittern
	# Hände (ohne Werkzeug)
	if Game.werkzeug_aktiv == "haende":
		var offen := 0.05 * (1.0 - zu)
		hand_r.position = _sitz + Vector3(r * 0.9 + 0.012 + offen, 0.005, 0.03) + wack
		hand_r.rotation_degrees = Vector3(0, 10, -90)
		hand_l.position = _sitz + Vector3(-(r * 0.9 + 0.012 + offen), 0.005, 0.03) - wack
		hand_l.rotation_degrees = Vector3(0, -10, 90)
		hand_l.scale = Vector3(-1, 1, 1)
		hand_r.greifen = 0.3 + zu * 0.5
		hand_l.greifen = 0.3 + zu * 0.5
	# Hebelpresse
	if _hebel:
		var winkel := lerpf(_hebel_offen, _hebel_kontakt - 4.0, clampf((d - 0.05) / 1.0, 0.0, 1.0))
		if not geladen:
			winkel = _hebel_offen + 6.0
		_hebel.rotation_degrees.z = winkel
		_hebel.position.x = -0.15 + wack.x
		hand_r.greifen = 0.55 + zu * 0.35
		hand_l.greifen = 0.35
	# Hammer: Druck = Ausholen, Schlag = runter
	if _hammer:
		var hoch := lerpf(6.0, 62.0, zu) if drueckt else lerpf(8.0, 0.0, _schlag)
		if not drueckt and _schlag <= 0.0:
			hoch = 8.0 if geladen else 14.0
		_hammer.position = _sitz + Vector3(0.33, r + 0.03, 0.01) + wack
		_hammer.rotation_degrees.z = -hoch
		hand_r.greifen = 0.85
		hand_l.greifen = 0.3
	# Schraubstock
	if _backe_l:
		var offen2 := 0.045 * (1.0 - zu)
		_backe_l.position = _sitz + Vector3(-(r * 0.85 + 0.003 + offen2), 0.0, 0)
		_backe_r.position = _sitz + Vector3(r * 0.85 + 0.003 + offen2, 0.0, 0) + wack
		_backe_l.position.y = _unterlage + 0.045
		_backe_r.position.y = _unterlage + 0.045
		_kurbel.rotation_degrees.x = d * 900.0
		hand_r.global_position = _kurbel_griff.global_position + _kurbel_griff.global_basis.x * 0.02 + Vector3(0, 0.012, 0.0)
		hand_r.rotation_degrees = Vector3(0, -10, 0)
		hand_r.greifen = 0.8
		hand_l.greifen = 0.35
	# Nuss: quetschen und Risse
	if _nuss_vis and geladen:
		var a: float = zonen.get("a", 0.3)
		var quetsch := 1.0 - 0.16 * clampf((d - a) / 0.7, 0.0, 1.0)
		var breit := 1.0 + (1.0 - quetsch) * 0.45
		if _achse == Vector3.UP:
			_nuss_vis.scale = Vector3(breit, quetsch, breit)
			_nuss_vis.position = _sitz - Vector3(0, (1.0 - quetsch) * (_sitz.y - _unterlage), 0) + wack
		else:
			_nuss_vis.scale = Vector3(quetsch, breit, breit)
			_nuss_vis.position = _sitz + wack
		var riss := 0.0
		if nuss_daten.get("angeknackst", false):
			riss = 0.35
		if d >= a:
			riss = max(riss, 0.2 + 0.8 * clampf((d - a) / max(0.05, zonen.s1 - a), 0.0, 1.0))
		_nuss_mat.set_shader_parameter("riss", riss)


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


# =============================================================================
# Auflösen
# =============================================================================
func _aufloesen() -> void:
	var zone := zone_von(druck)
	var d := nuss_daten
	letzte_nuss = d.nuss
	var info: Dictionary = Data.NUESSE[d.nuss]
	var welt := get_tree().current_scene
	var pos := sitz_global()
	if Game.werkzeug_aktiv == "hammer":
		_schlag = 1.0
		Sfx.spiele("hammer", -2.0)
	if zone == "frueh":
		Game.knack_ergebnis.emit("frueh", "Zu früh losgelassen")
		geknackt.emit("frueh", pos)
		return
	if zone == "riss":
		if not d.get("angeknackst", false):
			nuss_daten.angeknackst = true
			_zonen_berechnen()
			Sfx.spiele("knack_riss", -2.0)
			Game.knack_ergebnis.emit("riss", "Riss! Nochmal drücken")
			geknackt.emit("riss", pos)
		else:
			Game.knack_ergebnis.emit("frueh", "Noch zu wenig")
			geknackt.emit("frueh", pos)
		return
	# Ab hier ist die Nuss offen
	geladen = false
	nuss_daten = {}
	if _nuss_vis:
		_nuss_vis.queue_free()
		_nuss_vis = null
	druck = 0.0
	var teile: Array = []
	var schalen := 2 if d.nuss != "para" else 3
	var ergebnis := zone
	if d.get("faul", false):
		ergebnis = "faul"
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
					ergebnis = "gold"
					Game.toast.emit("Goldene Nuss! +1 Goldene Nuss", Game.FARBE_GOLD)
				for i in anzahl:
					teile.append({"art": "haelfte", "nuss": d.nuss, "wert": einzel, "gold": d.get("gold", false)})
				Sfx.spiele("knack_perfekt", 0.0, 1.0 + min(Game.combo, 20) * 0.018)
				var text := "PERFEKT!"
				if d.get("doppel", false):
					text = "DOPPELNUSS!"
				if d.get("gold", false):
					text = "GOLDNUSS!"
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
			var seite := -1.0 if randf() < 0.5 else 1.0
			var richtung := Vector3(seite * randf_range(0.4, 1.0), randf_range(1.0, 1.8), randf_range(-0.3, 0.6)).normalized()
			if t.art == "haelfte":
				richtung = Vector3(randf_range(-0.3, 0.3), 2.0, randf_range(-0.1, 0.3)).normalized()
			erzeugt.append(welt.item_spawnen(t, pos + Vector3(0, 0.02, 0), richtung * randf_range(0.7, 1.3)))
		if welt.has_method("nach_knack"):
			welt.nach_knack(erzeugt)
	geknackt.emit(ergebnis, pos)
	_visual_aktualisieren(0.0)
