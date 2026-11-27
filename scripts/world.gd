extends Node3D
## Baut die Spielwelt (Küche, Werkstatt, Hof mit Nussberg) und steuert alles,
## was nicht direkt am Spieler oder an einem Gegenstand hängt.

const SPIELER_START := Vector3(0.15, 0.05, -0.9)
const TISCH_Y := 0.91
const TISCH_Z := -2.35
const ITEM_LIMIT := 260

var spieler: Spieler
var station: Knackstation
var hud: Hud
var menues: Menues
var glas: Behaelter
var eimer: Behaelter
var bruchschale: Behaelter
var kiste: Behaelter

var _schale_bereich: Area3D
var _werkstatt_tuer: Node3D
var _berg: Node3D
var _berg_schild: Label3D
var _pinnwand: Label3D
var _maschinen := {}                  # id -> Node3D (Optik)
var _walzen_status: Label3D
var _walzen_rollen: Array = []
var _laufrad_rad: Node3D
var _ofen_licht: OmniLight3D
var _band_kisten: Array = []

var _rutsche_timer := 0.0
var _walze_acc := 0.0
var _band_timer := 0.0
var _gier := 0.0
var _ruhe := 0.0
var _raubzug_timer := 0.0
var _raubzug_warnung := false
var _hebel_sperre := 0.0
var _pinn_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_raubzug_timer = _rng.randf_range(480.0, 720.0)
	_umgebung()
	_hof_und_berg()
	_kueche()
	_werkstatt()
	_behaelter_anlegen()
	spieler = Spieler.new()
	spieler.position = SPIELER_START
	add_child(spieler)
	hud = Hud.new()
	hud.spieler = spieler
	add_child(hud)
	menues = Menues.new()
	add_child(menues)
	menues.geschlossen.connect(func(): spieler.gesperrt = false)
	Game.maschine_gekauft.connect(_maschine_aufstellen)
	Game.aera_erreicht.connect(_aera_erreicht)
	Game.stand_geaendert.connect(_berg_aktualisieren)
	Game.berg_leer.connect(func(): _menue(menues.zeige_ende))
	for id in Game.maschinen:
		_maschine_aufstellen(id, false)
	_berg_aktualisieren()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Game.erster_start:
		call_deferred("_menue", menues.zeige_intro)
	if Game.selbsttest:
		var t := Node.new()
		var bilder := false
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--bilder"):
				bilder = true
		t.set_script(load("res://tests/bilder.gd" if bilder else "res://tests/selbsttest.gd"))
		add_child(t)


func _menue(oeffnen: Callable) -> void:
	spieler.gesperrt = true
	if spieler.aktive_station:
		spieler.aktive_station.druecken_ende()
		spieler.aktive_station = null
	oeffnen.call()


func _unhandled_input(event: InputEvent) -> void:
	if menues.ist_offen():
		return
	if event.is_action_pressed("pause"):
		_menue(menues.zeige_pause)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("talente"):
		_menue(menues.zeige_talente)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hilfsring"):
		Game.einstellungen.hilfsring = not Game.einstellungen.hilfsring
		Game.toast.emit("Hilfsring " + ("an" if Game.einstellungen.hilfsring else "aus"), Game.FARBE_INFO)
	elif event.is_action_pressed("cheat_geld"):
		Game.verdiene(5000, false)
		Game.toast.emit("Testhilfe: +5.000 Münzen", Game.FARBE_INFO)
	elif event.is_action_pressed("cheat_nuesse"):
		var n := Game.nuesse_vom_berg(1000)
		for i in n:
			Game.melde_knack("wal", "perfekt", false, 2)
		Game.toast.emit("Testhilfe: +%d Nüsse geknackt" % n, Game.FARBE_INFO)
	elif event.is_action_pressed("cheat_mp"):
		Game.mp += 5
		Game.mp_gesamt += 5
		Game.stand_geaendert.emit()
		Game.toast.emit("Testhilfe: +5 Meisterpunkte", Game.FARBE_INFO)


# =============================================================================
# Aufbau
# =============================================================================
func _umgebung() -> void:
	var env := Environment.new()
	var himmel := Sky.new()
	var hm := ProceduralSkyMaterial.new()
	hm.sky_top_color = Color(0.38, 0.55, 0.8)
	hm.sky_horizon_color = Color(0.92, 0.78, 0.6)
	hm.ground_horizon_color = Color(0.6, 0.5, 0.38)
	hm.ground_bottom_color = Color(0.25, 0.2, 0.15)
	hm.sun_angle_max = 30.0
	himmel.sky_material = hm
	env.background_mode = Environment.BG_SKY
	env.sky = himmel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.75, 0.6)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-38, 25, 0)
	sonne.light_color = Color(1.0, 0.88, 0.7)
	sonne.light_energy = 1.15
	sonne.shadow_enabled = true
	add_child(sonne)


func _hof_und_berg() -> void:
	var hof := Node3D.new()
	hof.name = "Hof"
	add_child(hof)
	Bau.klotz(hof, Vector3(120, 0.2, 120), Vector3(0, -0.1, -20), Color(0.42, 0.52, 0.25))
	# Bäume und Zaun
	var baum_pos := [Vector3(-12, 0, -14), Vector3(-15, 0, -24), Vector3(13, 0, -12), Vector3(16, 0, -25), Vector3(-6, 0, -32), Vector3(8, 0, -34), Vector3(-20, 0, -8), Vector3(20, 0, -6)]
	for p in baum_pos:
		var h := _rng.randf_range(4.0, 7.0)
		Bau.zylinder(hof, 0.25, h * 0.4, p + Vector3(0, h * 0.2, 0), Color(0.35, 0.24, 0.15))
		var krone := Bau.mesh_instanz(Bau.zylinder_mesh(0.0, h * 0.35, h * 0.75, 10), Bau.mat(Color(0.7, 0.42, 0.15).lerp(Color(0.35, 0.45, 0.18), _rng.randf())), p + Vector3(0, h * 0.4 + h * 0.37, 0))
		hof.add_child(krone)
	for i in 30:
		var x := -15.0 + i
		Bau.klotz(hof, Vector3(0.08, 1.0, 0.08), Vector3(x, 0.5, -30), Color(0.55, 0.42, 0.28), false)
	Bau.klotz(hof, Vector3(30, 0.08, 0.04), Vector3(0, 0.8, -30), Color(0.55, 0.42, 0.28), false)
	# Der Nussberg
	_berg = Node3D.new()
	_berg.position = Vector3(0.5, 0, -17)
	hof.add_child(_berg)
	var kuppe := Bau.mesh_instanz(Bau.kugel_mesh(7.0, true, 40), Bau.mat(Color(0.5, 0.34, 0.19), 0.95))
	_berg.add_child(kuppe)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var nuss_mesh := Bau.kugel_mesh(0.16, false, 8)
	var nm := StandardMaterial3D.new()
	nm.vertex_color_use_as_albedo = true
	nm.roughness = 0.8
	nuss_mesh.material = nm
	mm.mesh = nuss_mesh
	mm.instance_count = 900
	for i in mm.instance_count:
		var theta := _rng.randf() * TAU
		var phi := acos(_rng.randf())  # obere Halbkugel
		var r := 7.0 + _rng.randf_range(-0.05, 0.08)
		var p := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * r
		var basis := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.3))
		mm.set_instance_transform(i, Transform3D(basis, p))
		var farbe: Color = [Color(0.6, 0.43, 0.25), Color(0.66, 0.42, 0.2), Color(0.5, 0.33, 0.18), Color(0.72, 0.52, 0.32)][_rng.randi() % 4]
		mm.set_instance_color(i, farbe)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_berg.add_child(mmi)
	_berg_schild = Bau.schild(hof, "", Vector3(-6.5, 3.2, -9.5), 160, Color(1, 0.9, 0.6))
	_berg_schild.rotation_degrees.y = 20


func _berg_aktualisieren() -> void:
	if _berg == null:
		return
	var rest := float(Game.berg_rest()) / Data.BERG_GROESSE
	var s := 0.18 + 0.82 * pow(rest, 1.0 / 3.0)
	_berg.scale = Vector3(s, s, s)
	_berg.visible = rest > 0.0
	_berg_schild.text = "NUSSBERG\n%s" % Data.zahl(Game.berg_rest())


func _wand(eltern: Node3D, von: Vector3, bis: Vector3, farbe := Color(0.9, 0.85, 0.74)) -> Node3D:
	var groesse := (bis - von).abs()
	return Bau.klotz(eltern, groesse, (von + bis) * 0.5, farbe)


func _kueche() -> void:
	var k := Node3D.new()
	k.name = "Kueche"
	add_child(k)
	var wandfarbe := Color(0.82, 0.74, 0.6)
	# Boden und Decke
	Bau.klotz(k, Vector3(6, 0.1, 6), Vector3(0, -0.05, 0), Color(0.55, 0.38, 0.22))
	Bau.klotz(k, Vector3(6.4, 0.1, 6.4), Vector3(0, 3.05, 0), Color(0.82, 0.78, 0.7))
	for i in 8:
		Bau.klotz(k, Vector3(6, 0.003, 0.02), Vector3(0, 0.002, -2.62 + i * 0.75), Color(0.42, 0.28, 0.16), false)
	# Nordwand mit Fenster (x -0.6 .. 0.9, y 1.1 .. 2.1)
	_wand(k, Vector3(-3.1, 0, -3.1), Vector3(-0.6, 3, -2.9), wandfarbe)
	_wand(k, Vector3(0.9, 0, -3.1), Vector3(3.1, 3, -2.9), wandfarbe)
	_wand(k, Vector3(-0.6, 0, -3.1), Vector3(0.9, 1.1, -2.9), wandfarbe)
	_wand(k, Vector3(-0.6, 2.1, -3.1), Vector3(0.9, 3, -2.9), wandfarbe)
	Bau.klotz(k, Vector3(1.6, 0.05, 0.32), Vector3(0.15, 1.1, -2.98), Color(0.6, 0.42, 0.25))
	Bau.klotz(k, Vector3(0.06, 1.0, 0.06), Vector3(0.15, 1.6, -3.0), Color(0.6, 0.42, 0.25), false)
	# Westwand mit Verkaufsklappe (z -1.6 .. -0.8, y 0.8 .. 1.3)
	_wand(k, Vector3(-3.1, 0, -3.1), Vector3(-2.9, 3, -1.6), wandfarbe)
	_wand(k, Vector3(-3.1, 0, -0.8), Vector3(-2.9, 3, 3.1), wandfarbe)
	_wand(k, Vector3(-3.1, 0, -1.6), Vector3(-2.9, 0.8, -0.8), wandfarbe)
	_wand(k, Vector3(-3.1, 1.3, -1.6), Vector3(-2.9, 3, -0.8), wandfarbe)
	Bau.klotz(k, Vector3(0.5, 0.04, 0.9), Vector3(-3.0, 0.8, -1.2), Color(0.45, 0.3, 0.18))
	_verkaufsklappe(k, Vector3(-3.15, 1.05, -1.2), "VERKAUFSKLAPPE\nGlas, Bruchschale oder Eimer hineinwerfen", Vector3(-2.88, 1.6, -1.2), 90)
	# Südwand
	_wand(k, Vector3(-3.1, 0, 2.9), Vector3(3.1, 3, 3.1), wandfarbe)
	# Holzvertäfelung und Deckenbalken
	var holz := Color(0.5, 0.33, 0.19)
	Bau.klotz(k, Vector3(5.8, 0.9, 0.02), Vector3(0, 0.45, 2.89), holz, false)
	Bau.klotz(k, Vector3(0.02, 0.9, 5.8), Vector3(-2.89, 0.45, 0.6), holz, false)
	Bau.klotz(k, Vector3(2.3, 0.9, 0.02), Vector3(-1.75, 0.45, -2.89), holz, false)
	Bau.klotz(k, Vector3(1.9, 0.9, 0.02), Vector3(1.95, 0.45, -2.89), holz, false)
	for bz in [-2.0, 0.0, 2.0]:
		Bau.klotz(k, Vector3(6.0, 0.16, 0.14), Vector3(0, 2.92, bz), Color(0.42, 0.28, 0.16), false)
	# Ostwand mit Tür zur Werkstatt (z -1 .. 1)
	_wand(k, Vector3(2.9, 0, -3.1), Vector3(3.1, 3, -1.0), wandfarbe)
	_wand(k, Vector3(2.9, 0, 1.0), Vector3(3.1, 3, 3.1), wandfarbe)
	_wand(k, Vector3(2.9, 2.4, -1.0), Vector3(3.1, 3, 1.0), wandfarbe)
	if Game.aera < 2:
		_werkstatt_tuer = Bau.klotz(k, Vector3(0.12, 2.4, 2.0), Vector3(3.0, 1.2, 0), Color(0.45, 0.3, 0.18))
		Bau.schild(_werkstatt_tuer, "WERKSTATT\nöffnet nach 1.000 Nüssen", Vector3(-0.07, 0.3, 0), 64, Color(1, 0.9, 0.6)).rotation_degrees.y = -90
	# Licht
	var licht := OmniLight3D.new()
	licht.position = Vector3(0.2, 2.7, -0.8)
	licht.light_color = Color(1.0, 0.85, 0.65)
	licht.light_energy = 1.15
	licht.omni_range = 9.0
	licht.shadow_enabled = true
	k.add_child(licht)
	k.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.12), Bau.mat(Color(1, 0.95, 0.8)), Vector3(0.2, 2.85, -0.8)))
	# Tisch
	Bau.klotz(k, Vector3(2.4, 0.06, 0.9), Vector3(0.15, TISCH_Y - 0.03, TISCH_Z), Color(0.62, 0.44, 0.26))
	for bx in [-0.95, 1.25]:
		for bz in [-2.7, -2.0]:
			Bau.klotz(k, Vector3(0.07, TISCH_Y - 0.06, 0.07), Vector3(bx, (TISCH_Y - 0.06) * 0.5, bz), Color(0.5, 0.35, 0.2))
	# Knackstation
	station = Knackstation.new()
	station.position = Vector3(0.15, TISCH_Y, TISCH_Z)
	k.add_child(station)
	# Nussschale (Ablage für neue Nüsse)
	var schale := Node3D.new()
	schale.position = Vector3(-0.65, TISCH_Y, TISCH_Z)
	k.add_child(schale)
	Bau.klotz(schale, Vector3(0.46, 0.015, 0.4), Vector3(0, 0.008, 0), Color(0.48, 0.32, 0.18))
	for seite in [[Vector3(0.46, 0.06, 0.02), Vector3(0, 0.03, 0.2)], [Vector3(0.46, 0.06, 0.02), Vector3(0, 0.03, -0.2)], [Vector3(0.02, 0.06, 0.4), Vector3(0.23, 0.03, 0)], [Vector3(0.02, 0.06, 0.4), Vector3(-0.23, 0.03, 0)]]:
		Bau.klotz(schale, seite[0], seite[1], Color(0.48, 0.32, 0.18))
	_schale_bereich = Area3D.new()
	_schale_bereich.collision_layer = 0
	_schale_bereich.collision_mask = Data.L_ITEM
	var sc := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(0.46, 0.25, 0.4)
	sc.shape = sb
	sc.position.y = 0.12
	_schale_bereich.add_child(sc)
	schale.add_child(_schale_bereich)
	# Hebel und Rohr vom Berg
	var rohr := Bau.mesh_instanz(Bau.zylinder_mesh(0.07, 0.07, 0.62), Bau.mat(Color(0.5, 0.52, 0.55), 0.4, 0.7), Vector3(-0.68, 1.22, -2.72))
	rohr.rotation_degrees.x = -28
	k.add_child(rohr)
	k.add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.09, 0.09, 0.06), Bau.mat(Color(0.4, 0.42, 0.45), 0.4, 0.7), Vector3(-0.68, 1.5, -2.86)))
	var hebel_basis := Node3D.new()
	hebel_basis.position = Vector3(-1.35, 1.25, -2.86)
	k.add_child(hebel_basis)
	hebel_basis.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.16, 0.24, 0.06)), Bau.mat(Color(0.35, 0.35, 0.38), 0.4, 0.8)))
	var griff := Bau.mesh_instanz(Bau.zylinder_mesh(0.018, 0.018, 0.28), Bau.mat(Color(0.75, 0.15, 0.1), 0.4), Vector3(0, 0.12, 0.1))
	griff.rotation_degrees.x = 40
	hebel_basis.add_child(griff)
	hebel_basis.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.035), Bau.mat(Color(0.1, 0.1, 0.1), 0.3), Vector3(0, 0.22, 0.2)))
	Interaktiv.erzeuge(hebel_basis, Vector3(0.3, 0.5, 0.35), Vector3(0, 0.1, 0.1), "Hebel ziehen: Nüsse vom Berg holen", _hebel_ziehen)
	Bau.schild(k, "NÜSSE HOLEN", Vector3(-1.35, 1.58, -2.87), 30, Color(1, 0.9, 0.6))
	# Telefon / Bestellkatalog
	var tel := Node3D.new()
	tel.position = Vector3(-2.86, 1.35, 0.1)
	k.add_child(tel)
	tel.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.1, 0.3, 0.22)), Bau.mat(Color(0.65, 0.1, 0.08), 0.4)))
	var hoerer := Bau.mesh_instanz(Bau.box_mesh(Vector3(0.06, 0.06, 0.26)), Bau.mat(Color(0.1, 0.1, 0.1), 0.4), Vector3(0.07, 0.12, 0))
	tel.add_child(hoerer)
	Interaktiv.erzeuge(tel, Vector3(0.3, 0.45, 0.4), Vector3(0.1, 0, 0), "Bestellkatalog: Werkzeuge und Maschinen", func(_s): _menue(menues.zeige_laden))
	var tel_schild := Bau.schild(k, "BESTELLTELEFON", Vector3(-2.88, 1.7, 0.1), 52, Color(1, 0.9, 0.6))
	tel_schild.rotation_degrees.y = 90
	# Pinnwand mit Bestellungen
	Bau.klotz(k, Vector3(0.03, 0.8, 1.1), Vector3(-2.885, 1.6, 1.5), Color(0.7, 0.55, 0.35), false)
	_pinnwand = Bau.schild(k, "", Vector3(-2.86, 1.6, 1.5), 30, Color(0.15, 0.1, 0.05))
	_pinnwand.outline_size = 0
	_pinnwand.rotation_degrees.y = 90
	_pinnwand.width = 380
	_pinnwand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Opas Talentbaum an der Südwand
	var tafel := Node3D.new()
	tafel.position = Vector3(0, 1.55, 2.88)
	tafel.rotation_degrees.y = 180
	k.add_child(tafel)
	tafel.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(1.4, 1.0, 0.03)), Bau.mat(Color(0.93, 0.88, 0.75))))
	tafel.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.08, 0.5, 0.01)), Bau.mat(Color(0.4, 0.25, 0.12)), Vector3(0, -0.2, 0.02)))
	tafel.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.32, false, 14), Bau.mat(Color(0.4, 0.55, 0.25)), Vector3(0, 0.12, 0.0)))
	Interaktiv.erzeuge(tafel, Vector3(1.4, 1.0, 0.2), Vector3.ZERO, "Opas Talentbaum ansehen", func(_s): _menue(menues.zeige_talente))
	var tb := Bau.schild(tafel, "OPAS TALENTBAUM  [Tab]", Vector3(0, 0.62, 0.02), 52, Color(0.25, 0.15, 0.05))
	tb.outline_size = 0
	# Kompost hinter dem Fenster
	var kompost := Area3D.new()
	kompost.collision_layer = 0
	kompost.collision_mask = Data.L_ITEM | Data.L_BEHAELTER
	kompost.position = Vector3(0.15, 0.6, -4.6)
	var kc := CollisionShape3D.new()
	var kb := BoxShape3D.new()
	kb.size = Vector3(8, 2.5, 3)
	kc.shape = kb
	kompost.add_child(kc)
	add_child(kompost)
	kompost.body_entered.connect(_kompost)
	Bau.klotz(self, Vector3(1.6, 0.4, 1.0), Vector3(0.15, 0.2, -4.4), Color(0.3, 0.22, 0.12), false)
	Bau.schild(self, "KOMPOST", Vector3(0.15, 0.6, -3.85), 48, Color(0.8, 1, 0.6))


func _verkaufsklappe(eltern: Node3D, pos: Vector3, text: String, schild_pos: Vector3, drehung: float) -> void:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = Data.L_BEHAELTER
	a.position = pos
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.6, 0.55, 0.85)
	cs.shape = b
	a.add_child(cs)
	eltern.add_child(a)
	a.body_entered.connect(_klappe_betreten)
	var s := Bau.schild(eltern, text, schild_pos, 56, Color(1, 0.9, 0.6))
	s.rotation_degrees.y = drehung


func _werkstatt() -> void:
	var w := Node3D.new()
	w.name = "Werkstatt"
	add_child(w)
	var wf := Color(0.7, 0.64, 0.55)
	Bau.klotz(w, Vector3(7, 0.1, 6), Vector3(6.5, -0.05, 0), Color(0.45, 0.45, 0.44))
	Bau.klotz(w, Vector3(7.2, 0.1, 6.4), Vector3(6.5, 3.05, 0), Color(0.6, 0.55, 0.5))
	_wand(w, Vector3(3.0, 0, -3.1), Vector3(10.1, 3, -2.9), wf)
	_wand(w, Vector3(3.0, 0, 2.9), Vector3(10.1, 3, 3.1), wf)
	# Ostwand mit zweiter Klappe (z -2.2 .. -1.4, y 0.7 .. 1.3)
	_wand(w, Vector3(9.9, 0, -3.1), Vector3(10.1, 3, -2.2), wf)
	_wand(w, Vector3(9.9, 0, -1.4), Vector3(10.1, 3, 3.1), wf)
	_wand(w, Vector3(9.9, 0, -2.2), Vector3(10.1, 0.7, -1.4), wf)
	_wand(w, Vector3(9.9, 1.3, -2.2), Vector3(10.1, 3, -1.4), wf)
	_verkaufsklappe(w, Vector3(10.15, 1.0, -1.8), "KLAPPE\nMaschinenkiste", Vector3(9.88, 1.55, -1.8), -90)
	var licht := OmniLight3D.new()
	licht.position = Vector3(6.5, 2.7, 0)
	licht.light_color = Color(1.0, 0.9, 0.75)
	licht.light_energy = 1.1
	licht.omni_range = 10.0
	licht.shadow_enabled = true
	w.add_child(licht)
	Bau.schild(w, "Maschinen bestellst du am Telefon in der Küche.", Vector3(6.5, 2.2, 2.88), 48, Color(1, 0.9, 0.6)).rotation_degrees.y = 180


func _behaelter_anlegen() -> void:
	glas = _neuer_behaelter("glas", Vector3(0.78, TISCH_Y, -2.5))
	bruchschale = _neuer_behaelter("bruch", Vector3(0.95, TISCH_Y, -2.12))
	eimer = _neuer_behaelter("eimer", Vector3(1.55, 0.0, -2.2))
	kiste = _neuer_behaelter("kiste", Vector3(7.4, 0.0, -1.4))
	glas.setze_deckel(Game.hat_maschine("deckel"))
	var gespeichert: Dictionary = Game.behaelter
	for paar in [["glas", glas], ["eimer", eimer], ["bruch", bruchschale], ["kiste", kiste]]:
		if gespeichert.has(paar[0]):
			paar[1].aus_dict(gespeichert[paar[0]])


func _neuer_behaelter(typ: String, pos: Vector3) -> Behaelter:
	var b := Behaelter.erzeuge(typ)
	b.position = pos + Vector3(0, 0.005, 0)
	add_child(b)
	b.heim = b.global_transform
	return b


func behaelter_speichern() -> Dictionary:
	return {"glas": glas.als_dict(), "eimer": eimer.als_dict(), "bruch": bruchschale.als_dict(), "kiste": kiste.als_dict()}


# =============================================================================
# Maschinen
# =============================================================================
func _maschine_aufstellen(id: String, neu := true) -> void:
	match id:
		"deckel":
			glas.setze_deckel(true)
		"rutsche":
			var r := Node3D.new()
			r.position = Vector3(-0.65, TISCH_Y, TISCH_Z)
			add_child(r)
			var rutsche := Bau.mesh_instanz(Bau.box_mesh(Vector3(0.14, 0.02, 0.5)), Bau.mat(Color(0.55, 0.4, 0.22)), Vector3(0.38, 0.12, 0))
			rutsche.rotation_degrees = Vector3(0, 90, -14)
			r.add_child(rutsche)
			_maschinen[id] = r
		"mimi":
			var katze := Katze.new()
			katze.position = Vector3(-1.5, 0, 1.5)
			add_child(katze)
			_maschinen[id] = katze
			if neu:
				Sfx.spiele("miau")
		"sieb":
			var s := Node3D.new()
			s.position = Vector3(0.15, TISCH_Y, TISCH_Z + 0.26)
			add_child(s)
			s.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.5, 0.01, 0.16)), Bau.mat(Color(0.7, 0.72, 0.75), 0.3, 0.8), Vector3(0, 0.005, 0)))
			for i in 6:
				s.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.005, 0.012, 0.16)), Bau.mat(Color(0.3, 0.3, 0.32)), Vector3(-0.22 + i * 0.088, 0.012, 0)))
			_maschinen[id] = s
		"ofen":
			var o := Node3D.new()
			o.position = Vector3(4.3, 0, -2.3)
			add_child(o)
			Bau.klotz(o, Vector3(1.0, 1.0, 0.8), Vector3(0, 0.5, 0), Color(0.18, 0.17, 0.17))
			o.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.5, 0.3, 0.02)), Bau.mat(Color(1.0, 0.45, 0.1), 0.5), Vector3(0, 0.45, 0.41)))
			o.add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.12, 0.12, 2.0), Bau.mat(Color(0.2, 0.2, 0.2)), Vector3(0, 2.0, -0.2)))
			_ofen_licht = OmniLight3D.new()
			_ofen_licht.position = Vector3(0, 0.5, 0.7)
			_ofen_licht.light_color = Color(1.0, 0.5, 0.15)
			_ofen_licht.light_energy = 0.8
			_ofen_licht.omni_range = 3.0
			o.add_child(_ofen_licht)
			var a := Area3D.new()
			a.collision_layer = 0
			a.collision_mask = Data.L_BEHAELTER
			a.position = Vector3(0, 1.2, 0)
			var cs := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = Vector3(1.2, 0.6, 1.0)
			cs.shape = b
			a.add_child(cs)
			o.add_child(a)
			a.body_entered.connect(_ofen_betreten)
			Bau.schild(o, "SCHALENOFEN\nEimer hier hineinwerfen", Vector3(0, 1.55, 0.42), 40, Color(1, 0.85, 0.6))
			_maschinen[id] = o
		"walze":
			var wz := Node3D.new()
			wz.position = Vector3(6.4, 0, -2.4)
			add_child(wz)
			Bau.klotz(wz, Vector3(1.0, 0.8, 0.7), Vector3(0, 0.4, 0), Color(0.3, 0.42, 0.55))
			var trichter := Bau.mesh_instanz(Bau.zylinder_mesh(0.35, 0.12, 0.4, 4), Bau.mat(Color(0.5, 0.52, 0.55), 0.4, 0.7), Vector3(0, 1.0, 0))
			trichter.rotation_degrees.y = 45
			wz.add_child(trichter)
			var rohr := Bau.mesh_instanz(Bau.zylinder_mesh(0.08, 0.08, 1.6), Bau.mat(Color(0.5, 0.52, 0.55), 0.4, 0.7), Vector3(0, 1.75, -0.4))
			rohr.rotation_degrees.x = 30
			wz.add_child(rohr)
			_walzen_rollen.clear()
			for x in [-0.12, 0.12]:
				var rolle := Bau.mesh_instanz(Bau.zylinder_mesh(0.1, 0.1, 0.6), Bau.mat(Color(0.7, 0.7, 0.72), 0.3, 0.9), Vector3(x, 0.85, 0.0))
				rolle.rotation_degrees.z = 90
				wz.add_child(rolle)
				_walzen_rollen.append(rolle)
			wz.add_child(Bau.mesh_instanz(Bau.box_mesh(Vector3(0.3, 0.04, 0.6)), Bau.mat(Color(0.55, 0.4, 0.22)), Vector3(0.75, 0.35, 0.65)))
			_walzen_status = Bau.schild(wz, "", Vector3(0, 1.45, 0.4), 40, Color(1, 0.95, 0.8), true)
			_maschinen[id] = wz
		"band":
			var bd := Node3D.new()
			add_child(bd)
			var band := Bau.mesh_instanz(Bau.box_mesh(Vector3(2.3, 0.06, 0.5)), Bau.mat(Color(0.15, 0.15, 0.16), 0.6), Vector3(8.75, 0.85, -1.8))
			bd.add_child(band)
			for x in 6:
				Bau.klotz(bd, Vector3(0.05, 0.82, 0.05), Vector3(7.7 + x * 0.42, 0.41, -1.8), Color(0.4, 0.4, 0.42), false)
			_maschinen[id] = bd
		"laufrad":
			var lr := Node3D.new()
			lr.position = Vector3(8.5, 0, 1.8)
			add_child(lr)
			Bau.klotz(lr, Vector3(0.1, 1.0, 0.1), Vector3(0, 0.5, -0.25), Color(0.4, 0.3, 0.2))
			_laufrad_rad = Node3D.new()
			_laufrad_rad.position = Vector3(0, 0.6, 0)
			lr.add_child(_laufrad_rad)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.42
			torus.outer_radius = 0.48
			var rad := Bau.mesh_instanz(torus, Bau.mat(Color(0.6, 0.45, 0.25)))
			rad.rotation_degrees.x = 90
			_laufrad_rad.add_child(rad)
			for i in 6:
				var speiche := Bau.mesh_instanz(Bau.box_mesh(Vector3(0.02, 0.9, 0.02)), Bau.mat(Color(0.5, 0.38, 0.2)))
				speiche.rotation_degrees.z = i * 30.0
				_laufrad_rad.add_child(speiche)
			var tier := Eichhoernchen.new()
			tier.set_process(false)
			tier.position = Vector3(0, -0.45, 0)
			lr.add_child(tier)
			tier.remove_from_group("eichhoernchen")
			Bau.schild(lr, "EICHHÖRNCHEN-LAUFRAD\n+1 Energie pro Sekunde", Vector3(0, 1.4, 0), 36, Color(1, 0.9, 0.6), true)
			_maschinen[id] = lr


func _process(delta: float) -> void:
	if _hebel_sperre > 0.0:
		_hebel_sperre -= delta
	_rutsche(delta)
	_walze(delta)
	_band(delta)
	if Game.hat_maschine("laufrad"):
		Game.energie += delta
		if _laufrad_rad:
			_laufrad_rad.rotate_z(-delta * 4.0)
	if _ofen_licht:
		_ofen_licht.light_energy = 0.4 + min(Game.energie, 200.0) / 200.0 * 1.6 + randf() * 0.15
	_eichhoernchen_steuern(delta)
	_pinn_timer -= delta
	if _pinn_timer <= 0.0:
		_pinn_timer = 1.0
		_pinnwand_zeichnen()
	_aufraeumen()


func _rutsche(delta: float) -> void:
	if not Game.hat_maschine("rutsche"):
		return
	_rutsche_timer -= delta
	if _rutsche_timer > 0.0:
		return
	var stufe: int = max(0, Game.maschinen_stufe("rutsche"))
	_rutsche_timer = 2.0 / ((1.0 + 0.25 * stufe) * Game.maschinen_tempo())
	if station.kann_laden() and not station.drueckt:
		# eine Nuss aus der Schale nehmen, sonst direkt vom Berg
		var nuss: Item = null
		for b in _schale_bereich.get_overlapping_bodies():
			if b is Item and b.art == "nuss" and not b.gehalten and not b.faul:
				nuss = b
				break
		if nuss:
			if station.lade(nuss.daten()):
				nuss.queue_free()
		elif Game.nuesse_vom_berg(1) > 0:
			station.lade(_neue_nuss_daten())
	elif _nuesse_in_schale() < 12:
		_nuesse_holen(1, false)


func _walze(delta: float) -> void:
	if not Game.hat_maschine("walze"):
		return
	var status := ""
	var laeuft := false
	var am_platz := not kiste.gehalten and kiste.global_position.distance_to(kiste.heim.origin) < 0.6
	if Game.energie < 2.0:
		status = "Keine Energie – Schalen in den Ofen!"
	elif kiste.voll():
		status = "Kiste voll – zur Klappe bringen"
	elif not am_platz:
		status = "Kiste fehlt"
	elif Game.berg_rest() <= 0:
		status = "Berg leer"
	else:
		laeuft = true
		var stufe: int = max(0, Game.maschinen_stufe("walze"))
		_walze_acc += delta * 0.6 * (1.0 + 0.15 * stufe) * Game.maschinen_tempo()
		while _walze_acc >= 1.0 and laeuft:
			_walze_acc -= 1.0
			if Game.nuesse_vom_berg(1) == 0:
				break
			Game.energie -= 2.0
			var nuss := Data.zufalls_nuss(Game.genommen, Game.rng)
			var info: Dictionary = Data.NUESSE[nuss]
			var schalen_energie := 3.0 * Game.energie_pro_schale() * 0.15
			if float(info.haerte) > Data.WALZE_KRAFT:
				Game.melde_knack(nuss, "matsch", false)
			else:
				var p := Game.walzen_praezision()
				var r := Game.rng.randf()
				if r < p:
					var einzel: float = float(info.wert) * (1.0 + Game.combo_bonus())
					kiste.fuelle("haelfte", 2, einzel)
					Game.melde_knack(nuss, "perfekt", false, 2)
				elif r < p + (1.0 - p) * 0.7:
					kiste.fuelle("bruch", 3, float(info.wert) * 0.2)
					Game.melde_knack(nuss, "bruch", false)
				else:
					Game.melde_knack(nuss, "matsch", false)
			if Game.hat_maschine("sieb") and Game.hat_maschine("ofen"):
				Game.energie += schalen_energie
			elif not Game.hat_maschine("sieb"):
				kiste.schmutz_dazu(1)
			if Game.energie < 2.0 or kiste.voll():
				laeuft = false
		status = "Läuft · Präzision %d %%" % int(Game.walzen_praezision() * 100)
	if laeuft:
		for r in _walzen_rollen:
			r.rotate_x(delta * 12.0)
	if _walzen_status:
		_walzen_status.text = "WALZENKNACKER\n%s\nEnergie: %d" % [status, int(Game.energie)]


func _band(delta: float) -> void:
	for bk in _band_kisten.duplicate():
		bk.position.x += delta * 1.2
		if bk.position.x > 9.8:
			_band_kisten.erase(bk)
			bk.queue_free()
	if not Game.hat_maschine("band"):
		return
	_band_timer -= delta
	if _band_timer > 0.0:
		return
	_band_timer = 6.0
	var am_platz := not kiste.gehalten and kiste.global_position.distance_to(kiste.heim.origin) < 0.6
	if am_platz and kiste.haelften + kiste.bruch >= 10:
		var vis := Bau.mesh_instanz(Bau.box_mesh(Vector3(0.3, 0.2, 0.25)), Bau.mat(Color(0.62, 0.45, 0.26)), Vector3(7.7, 1.0, -1.8))
		add_child(vis)
		_band_kisten.append(vis)
		_verkaufe(kiste, false)
		Sfx.spiele("maschine", -6.0)


# =============================================================================
# Nüsse holen, spawnen, sortieren
# =============================================================================
func _hebel_ziehen(_s) -> void:
	if _hebel_sperre > 0.0:
		return
	_hebel_sperre = 0.8
	if Game.berg_rest() <= 0:
		Game.toast.emit("Der Berg ist leer!", Game.FARBE_INFO)
		return
	var frei := 30 - _nuesse_in_schale()
	if frei <= 0:
		Game.toast.emit("Die Nussschale ist voll", Game.FARBE_WARN)
		Sfx.spiele("fehler")
		return
	Sfx.spiele("hebel")
	_nuesse_holen(min(8, frei), true)


func _nuesse_in_schale() -> int:
	var n := 0
	for b in _schale_bereich.get_overlapping_bodies():
		if b is Item and b.art == "nuss":
			n += 1
	return n


func _neue_nuss_daten() -> Dictionary:
	var d := {"art": "nuss", "nuss": Data.zufalls_nuss(Game.genommen, Game.rng)}
	var r := Game.rng.randf()
	if r < Game.gold_chance():
		d.gold = true
	elif r < Game.gold_chance() + Data.CHANCE_FAUL:
		d.faul = true
	elif r < Game.gold_chance() + Data.CHANCE_FAUL + Data.CHANCE_WURM:
		d.wurm = true
	elif r < Game.gold_chance() + Data.CHANCE_FAUL + Data.CHANCE_WURM + Data.CHANCE_DOPPEL:
		d.doppel = true
	return d


func _nuesse_holen(anzahl: int, mit_ton: bool) -> void:
	var n := Game.nuesse_vom_berg(anzahl)
	for i in n:
		var pos := Vector3(-0.65 + randf_range(-0.12, 0.12), TISCH_Y + 0.35 + i * 0.06, TISCH_Z + randf_range(-0.1, 0.1))
		item_spawnen(_neue_nuss_daten(), pos, Vector3(randf_range(-0.2, 0.2), -0.5, randf_range(-0.2, 0.2)))
	if mit_ton and n > 0:
		Game.toast.emit("%d Nüsse vom Berg geholt" % n, Game.FARBE_INFO)


func item_spawnen(daten: Dictionary, pos: Vector3, geschw: Vector3) -> Item:
	var it := Item.erzeuge(daten)
	it.position = pos
	it.add_to_group("items")
	add_child(it)
	it.linear_velocity = geschw
	return it


func glas_position() -> Vector3:
	return glas.global_position


func nach_knack(teile: Array) -> void:
	if not Game.hat_maschine("sieb"):
		return
	await get_tree().create_timer(0.55).timeout
	for t in teile:
		if not is_instance_valid(t) or t.gehalten:
			continue
		var ziel: Behaelter = null
		match t.art:
			"haelfte":
				ziel = glas
			"bruch":
				ziel = bruchschale
			"schale":
				ziel = eimer
			"wurm":
				t.queue_free()
				continue
		if ziel == null or ziel.gehalten or ziel.voll():
			continue
		_flieg_in(t, ziel)


func _flieg_in(t: Item, ziel: Behaelter) -> void:
	t.freeze = true
	t.collision_layer = 0
	var tw := create_tween()
	tw.tween_property(t, "global_position", ziel.global_position + Vector3(0, 0.45, 0), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(t, "global_position", ziel.global_position + Vector3(0, 0.12, 0), 0.15)
	tw.tween_callback(func():
		if is_instance_valid(t):
			if is_instance_valid(ziel) and ziel.nimmt_auf(t.daten()):
				Sfx.spiele("einwurf", -12.0)
			t.queue_free())


func wischen(punkt: Vector3) -> void:
	var anzahl := 0
	for t in get_tree().get_nodes_in_group("items"):
		if not is_instance_valid(t) or t.gehalten or t.art != "schale":
			continue
		if Vector2(t.global_position.x - punkt.x, t.global_position.z - punkt.z).length() > 0.75:
			continue
		if abs(t.global_position.y - punkt.y) > 0.4:
			continue
		if not eimer.gehalten and not eimer.voll() and eimer.global_position.distance_to(punkt) < 3.0:
			_flieg_in(t, eimer)
		else:
			t.linear_velocity = Vector3(0, 1, 1.5)
		anzahl += 1
	if anzahl > 0:
		Sfx.spiele("wischen", -4.0)


func stinkwolke(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 30
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.8
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var m := Bau.kugel_mesh(0.03, false, 6)
	m.material = Bau.mat(Color(0.55, 0.75, 0.25, 0.6), 1.0, 0.0, true)
	p.mesh = m
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _aufraeumen() -> void:
	var alle := get_tree().get_nodes_in_group("items")
	if alle.size() <= ITEM_LIMIT:
		return
	for t in alle:
		if alle.size() <= ITEM_LIMIT - 20:
			break
		if is_instance_valid(t) and not t.gehalten and t.art == "schale":
			t.queue_free()
			alle.erase(t)


# =============================================================================
# Verkaufen, Ofen, Kompost
# =============================================================================
func _klappe_betreten(body: Node) -> void:
	if not (body is Behaelter):
		return
	var b: Behaelter = body
	if b.belegt() == 0:
		Game.toast.emit("%s ist leer" % b.anzeige_name(), Game.FARBE_WARN)
		_zurueck(b)
		return
	_verkaufe(b, true)


func _verkaufe(b: Behaelter, zurueck: bool) -> void:
	var betrag := 0.0
	if b.typ == "eimer":
		betrag = b.schalen * 0.2 * Game.preis_faktor()
	else:
		betrag = b.verkaufswert()
	betrag = Game.verdiene(betrag)
	Sfx.spiele("verkauf")
	var name := b.anzeige_name()
	Game.toast.emit("%s verkauft: +%s Münzen" % [name, Data.zahl(betrag)], Game.FARBE_GUT)
	_schwebetext("+%s" % Data.zahl(betrag), b.global_position + Vector3(0, 0.4, 0), Stil.GOLD)
	b.leeren()
	if zurueck:
		_zurueck(b)


func _zurueck(b: Behaelter) -> void:
	if spieler.gehalten == b:
		spieler._loslassen(Vector3.ZERO)
	b.heimkehren()


func _ofen_betreten(body: Node) -> void:
	if not (body is Behaelter):
		return
	var b: Behaelter = body
	if b.typ != "eimer":
		Game.toast.emit("In den Ofen gehören nur Schalen", Game.FARBE_WARN)
		_zurueck(b)
		return
	var e := b.schalen * Game.energie_pro_schale()
	Game.energie += e
	Sfx.spiele("maschine")
	Game.toast.emit("+%d Energie" % int(e), Game.FARBE_GUT)
	b.leeren()
	_zurueck(b)


func _kompost(body: Node) -> void:
	if body is Behaelter:
		if body.typ == "eimer" and body.schalen > 0:
			Game.toast.emit("Schalen auf den Kompost gekippt", Game.FARBE_INFO)
			body.leeren()
		_zurueck(body)
		return
	if body is Item and not body.gehalten:
		if body.faul or body.art == "wurm":
			var lohn := 2.0 if body.art == "wurm" else 1.0
			Game.verdiene(lohn, false)
			_schwebetext("+%d" % int(lohn), body.global_position + Vector3(0, 0.3, 0), Stil.GRUEN)
		body.queue_free()


func _schwebetext(text: String, pos: Vector3, farbe: Color) -> void:
	var l := Bau.schild(self, text, pos, 72, farbe, true)
	l.no_depth_test = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3(0, 0.6, 0), 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(l.queue_free)


func _pinnwand_zeichnen() -> void:
	if _pinnwand == null:
		return
	var t := "BESTELLUNGEN\n"
	for b in Game.bestellungen:
		t += "\n%s:\n%d/%d %s-Hälften · %d:%02d\n" % [b.kunde, b.stand, b.menge, Data.NUESSE[b.nuss].name, int(b.zeit) / 60, int(b.zeit) % 60]
	_pinnwand.text = t


# =============================================================================
# Eichhörnchen
# =============================================================================
func ruhe_vor_eichhoernchen(sekunden: float) -> void:
	_ruhe = sekunden
	for e in get_tree().get_nodes_in_group("eichhoernchen"):
		e.verscheuchen()
	Game.toast.emit("Der König ist bestochen: %d Minuten Ruhe" % int(sekunden / 60), Game.FARBE_GOLD)


func _eichhoernchen_steuern(delta: float) -> void:
	if Game.hat_talent("koenigsbund"):
		hud.zeige_warnung("")
		return
	if _ruhe > 0.0:
		_ruhe -= delta
		hud.zeige_warnung("")
		return
	var vorrat := glas.haelften + (kiste.haelften if Game.aera >= 2 else 0)
	if vorrat > 3:
		_gier += delta * float(vorrat) / 1500.0
	if _gier >= 1.0:
		_gier = 0.0
		_eichhoernchen_schicken(1)
	if Game.aera >= 2:
		_raubzug_timer -= delta
		if _raubzug_timer <= 10.0 and not _raubzug_warnung:
			_raubzug_warnung = true
			if Game.hat_talent("waldkenner"):
				Sfx.spiele("warnung", -4.0)
		if _raubzug_warnung and Game.hat_talent("waldkenner") and _raubzug_timer > 0.0:
			hud.zeige_warnung("Raubzug in %d s!" % int(ceil(_raubzug_timer)))
		if _raubzug_timer <= 0.0:
			_raubzug_timer = _rng.randf_range(480.0, 720.0)
			_raubzug_warnung = false
			hud.zeige_warnung("")
			if not Game.hat_talent("waldkenner"):
				Sfx.spiele("warnung", -4.0)
			Game.toast.emit("RAUBZUG! Die Eichhörnchen kommen!", Game.FARBE_WARN)
			_raubzug(4 + Game.aera * 2)


func _raubzug(anzahl: int) -> void:
	for i in anzahl:
		_eichhoernchen_schicken(1)
		await get_tree().create_timer(0.6).timeout


func _eichhoernchen_schicken(anzahl: int) -> void:
	for i in anzahl:
		var ziel: Behaelter = null
		var weg: Array = []
		var glas_ok := not glas.gehalten and glas.haelften > 0
		var kiste_ok := Game.aera >= 2 and not kiste.gehalten and kiste.haelften > 0
		if glas_ok and (not kiste_ok or glas.haelften >= kiste.haelften or randf() < 0.5):
			ziel = glas
			var x := randf_range(-0.4, 0.7)
			weg = [Vector3(x, 0.0, -5.5), Vector3(x, 1.12, -3.25), Vector3(x, 1.12, -2.95), Vector3(x, TISCH_Y, -2.72), glas.global_position]
		elif kiste_ok:
			ziel = kiste
			weg = [Vector3(9.6, 0.0, 4.5), Vector3(9.6, 0.0, 2.7), Vector3(8.5, 0.0, 0.5), kiste.global_position]
		if ziel == null:
			return
		var e := Eichhoernchen.new()
		e.weg = weg
		e.ziel_behaelter = ziel
		e.add_to_group("eichhoernchen")
		add_child(e)


# =============================================================================
# Ären
# =============================================================================
func _aera_erreicht(aera: int, schicht: String) -> void:
	match aera:
		2:
			if _werkstatt_tuer:
				_werkstatt_tuer.queue_free()
				_werkstatt_tuer = null
			Game.toast.emit("Neue Bergschicht: %s! Die Werkstatt ist offen, neue Nüsse und Maschinen im Katalog." % schicht, Game.FARBE_GOLD)
		3:
			Game.toast.emit("Neue Bergschicht: %s! Paranüsse und Macadamia tauchen auf." % schicht, Game.FARBE_GOLD)
		_:
			Game.toast.emit("Neue Bergschicht: %s!" % schicht, Game.FARBE_GOLD)
	hud.zeige_toast("Ära %d erreicht" % aera, Game.FARBE_GOLD)
