extends Node3D
## Baut die Spielwelt (Küche, Werkstatt, Hof mit Nussberg) und steuert alles,
## was nicht direkt am Spieler oder an einem Gegenstand hängt.

const SPIELER_START := Vector3(0.15, 0.05, -0.9)
const TISCH_Y := 0.91
const TISCH_Z := -2.35
const ITEM_LIMIT := 260
const SCHALE_POS := Vector3(-0.4, TISCH_Y, -2.4)
const GLAS_POS := Vector3(0.62, TISCH_Y, -2.5)
const BRUCH_POS := Vector3(0.66, TISCH_Y, -2.13)
const EIMER_POS := Vector3(1.55, 0.0, -2.0)
const ROHR_OBEN := Vector3(-0.45, 1.5, -2.93)
const ROHR_UNTEN := Vector3(-0.42, TISCH_Y + 0.17, -2.56)
const FENSTER_X := Vector2(-0.25, 1.35)
const FENSTER_Y := Vector2(1.05, 2.15)
const TUER_X := Vector2(1.75, 2.7)
const SILO_POS := Vector3(-1.15, 0.0, -4.05)
const ABGABE_POS := Vector3(-1.15, 0.0, -5.6)
const ABGABE_RADIUS := 1.25

var spieler: Spieler
var station: Knackstation
var hud: Hud
var menues: Menues
var glas: Behaelter
var eimer: Behaelter
var bruchschale: Behaelter
var kiste: Behaelter = null
var berg: Nussberg
var gelaende: Gelaende
var umwelt: Environment
var himmel: Himmel
var tierwelt: Tierwelt
var geheimnisse: Geheimnisse
var aeren: Aeren
var flug: NussFlug

var _schale_bereich: Area3D
var _werkstatt_tuer: Node3D
var _berg_text: Label3D
var _abgaben: Array = []              # {pos, name, knoten}
var _abliefern_laeuft := false
var _helfer_knoten: Array = []
var _silo_fuell: Node3D
var _silo_text: Label3D
var _band_nuesse := {}                # posten-id -> [MultiMeshInstance3D, von, bis, phase]
var _band_aktiv := {}
var _pinn_zettel: Array = []
var _maschinen := {}
var _walzen_status: Label3D
var _walzen_rollen: Array = []
var _laufrad_rad: Node3D
var _ofen_licht: OmniLight3D
var _band_kisten: Array = []
var _hebel_arm: Node3D
var _klappe: Node3D
var _uhr_zeiger: Array = []
var sonne: DirectionalLight3D

var _rutsche_timer := 0.0
var _walze_acc := 0.0
var _band_timer := 0.0
var _gier := 0.0
var _ruhe := 0.0
var _raubzug_timer := 0.0
var _raubzug_warnung := false
var _hebel_sperre := 0.0
var _pinn_timer := 0.0
var _nachlegen_laeuft := false
var _rohrpost_laeuft := false
var _glas_war_voll := false
var _unterwegs := {}                  # Behaelter -> Anzahl Teile im Flug
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_raubzug_timer = _rng.randf_range(480.0, 720.0)
	_umgebung()
	flug = NussFlug.new()
	add_child(flug)
	_hof_und_berg()
	_kueche()
	_werkstatt()
	_behaelter_anlegen()
	spieler = Spieler.new()
	spieler.position = SPIELER_START
	add_child(spieler)
	hud = Hud.new()
	hud.spieler = spieler
	hud.welt = self
	add_child(hud)
	menues = Menues.new()
	add_child(menues)
	menues.geschlossen.connect(func(): spieler.gesperrt = false)
	Game.maschine_gekauft.connect(_maschine_aufstellen)
	Game.aera_erreicht.connect(_aera_erreicht)
	Game.stand_geaendert.connect(_berg_aktualisieren)
	Game.helfer_gekauft.connect(_helfer_aufstellen)
	Game.posten_gekauft.connect(_posten_bauen)
	Game.lager_geaendert.connect(_silo_aktualisieren)
	for pid in Game.posten:
		_posten_bauen(pid)
	_helfer_aufstellen()
	_silo_aktualisieren()
	Game.berg_leer.connect(func():
		Sfx.spiele("meilenstein")
		hud.zeige_banner("Der Berg ist leer!", "Wo die Kuppe war, liegt etwas im Boden")
		Game.toast.emit("Der Berg ist leer! Schau nach, was dort liegt, wo die Kuppe war.", Game.FARBE_GOLD))
	station.geknackt.connect(_knack_effekt)
	for id in Game.maschinen:
		_maschine_aufstellen(id, false)
	_berg_aktualisieren()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	himmel = Himmel.new(self)
	add_child(himmel)
	tierwelt = Tierwelt.new(self)
	add_child(tierwelt)
	geheimnisse = Geheimnisse.new(self)
	add_child(geheimnisse)
	aeren = Aeren.new(self)
	add_child(aeren)
	Sfx.musik_starten()
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
	if spieler.sitz_station:
		spieler.sitz_station.abbrechen()
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
	elif event.is_action_pressed("hebel") and not spieler.sitzt:
		hebel_ziehen()
	elif event.is_action_pressed("cheat_geld"):
		Game.verdiene(5000, false)
		Game.toast.emit("Testhilfe: +5.000 Münzen", Game.FARBE_INFO)
	elif event.is_action_pressed("cheat_nuesse"):
		Game.einlagern({"wal": 600, "hasel": 400}, spieler.global_position)
		Game.toast.emit("Testhilfe: +1.000 Nüsse ins Lager", Game.FARBE_INFO)
	elif event.is_action_pressed("cheat_mp"):
		Game.verdiene(50000, false)
		Game.toast.emit("Testhilfe: +50.000 Münzen", Game.FARBE_INFO)
	elif event.is_action_pressed("laden"):
		_menue(menues.zeige_laden)
		get_viewport().set_input_as_handled()


# =============================================================================
# Licht und Himmel
# =============================================================================
func _umgebung() -> void:
	var env := Environment.new()
	var himmel := Sky.new()
	var hm := ProceduralSkyMaterial.new()
	hm.sky_top_color = Color(0.3, 0.5, 0.82)
	hm.sky_horizon_color = Color(0.86, 0.78, 0.66)
	hm.ground_horizon_color = Color(0.72, 0.64, 0.52)
	hm.ground_bottom_color = Color(0.32, 0.27, 0.2)
	hm.sun_angle_max = 18.0
	hm.sky_curve = 0.12
	himmel.sky_material = hm
	env.background_mode = Environment.BG_SKY
	env.sky = himmel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.ssil_enabled = true
	env.ssil_radius = 2.5
	env.ssil_intensity = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.78, 0.7)
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0035
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.88)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 32.0
	env.volumetric_fog_ambient_inject = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	umwelt = env
	sonne = DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-30, 160, 0)
	sonne.light_color = Color(1.0, 0.86, 0.68)
	sonne.light_energy = 2.4
	sonne.shadow_enabled = true
	sonne.shadow_blur = 1.5
	sonne.directional_shadow_max_distance = 45.0
	sonne.light_volumetric_fog_energy = 2.5
	add_child(sonne)


# =============================================================================
# Hof und Nussberg
# =============================================================================
func _hof_und_berg() -> void:
	var hof := Node3D.new()
	hof.name = "Hof"
	add_child(hof)
	# Das Tal: Gelände mit Hügeln und Bachbett, Wasser, Wald
	gelaende = Gelaende.new()
	gelaende.erzeugen()
	add_child(gelaende)
	add_child(Bach.new(gelaende))
	add_child(Wald.new(gelaende))
	_bruecken(hof)
	# Der Nussberg (begehbar, abbaubar)
	berg = Nussberg.new()
	if not berg.laden(Game.BERG_PFAD):
		berg.erzeugen()
		if Game.genommen > 0:
			berg.an_rest_anpassen(Game.berg_rest())
	add_child(berg)
	_anwesen(hof)
	_siedlung(hof)
	_grashalme(hof)
	_hof_ausstatten(hof)
	# Schild mit dem Zählerstand am Weg zum Berg
	var schild := Bau.holzschild(hof, "NUSSBERG", Vector3(3.6, 1.6, -7.2), Vector2(1.7, 0.85), Vector3(0, -15, 0), 150)
	Bau.teil(hof, Bau.box_mesh(Vector3(0.1, 1.6, 0.1)), Look.holz(Look.ALTHOLZ), Vector3(3.6, 0.8, -7.25))
	_berg_text = Bau.schrift(schild, "", Vector3(0, -0.18, 0.0135), 110, Color(0.35, 0.15, 0.05))
	# Trampelpfad von der Hütte zum Berg
	for i in 14:
		var t := float(i) / 13.0
		var p := Vector3(lerpf(2.2, 1.0, t) + sin(t * 5.0) * 0.4, 0.0, lerpf(-3.6, -11.0, t))
		Bau.teil(hof, Bau.zylinder_mesh(0.28, 0.32, 0.04, 10), Look.putz(Color(0.64, 0.56, 0.45), Color(0.52, 0.45, 0.36), 40.0), p + Vector3(0, -0.005, 0), Vector3(0, _rng.randf() * 90, 0), Vector3(1.0, 1.0, 0.8))



## Kleinkram am Silo. Der Bewuchs des Tals kommt aus wald.gd, die Orte aus dem Weltplan.
func _hof_ausstatten(hof: Node3D) -> void:
	# Holzlager und Fässer neben dem Silo
	Modelle.setze(hof, "rohstoffe/Pallet_Wood.gltf", Vector3(1.2, 0, -4.5), 8.0, 0.8)
	Modelle.setze(hof, "kueche/bag.glb", Vector3(1.0, 0.24, -4.4), 30.0, 1.5)
	Modelle.setze(hof, "kueche/bag.glb", Vector3(1.45, 0.24, -4.65), -50.0, 1.4)
	Modelle.setze(hof, "natur/log_stack.glb", Vector3(5.2, 0, -3.9), 90.0, 2.6)


## Brücken über den Bach (Modellplätze für Blender, bis dahin aus Holz gebaut).
func _bruecken(hof: Node3D) -> void:
	for b in [["bruecke_oma", Vector2(-24.0, 10.0), Vector2(-33.0, 13.4), 7.6, 0.55],
			["bruecke_hof", Vector2(2.4, 31.0), Vector2(2.6, 39.0), 6.4, 0.25]]:
		var von: Vector2 = b[1]
		var bis: Vector2 = b[2]
		var richtung := (bis - von).normalized()
		var mitte := gelaende.position(WeltPlan.ORTE[b[0]].x, WeltPlan.ORTE[b[0]].z)
		mitte.y = maxf(gelaende.hoehe_bei(von.x, von.y), gelaende.hoehe_bei(bis.x, bis.y))
		var laenge: float = b[3]
		var bogen: float = b[4]
		Modelle.platz(hof, b[0], mitte, rad_to_deg(atan2(-richtung.y, richtung.x)), func(k: Node3D): Ersatz.bruecke(k, laenge, 2.0 if b[0] == "bruecke_oma" else 3.0, bogen))


func _grashalme(hof: Node3D) -> void:
	var halm := ArrayMesh.new()
	var v := PackedVector3Array([Vector3(-0.02, 0, 0), Vector3(0.02, 0, 0), Vector3(-0.012, 0.12, 0.01), Vector3(0.012, 0.12, 0.01), Vector3(0.0, 0.23, 0.03)])
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0.5, 0)])
	var n := PackedVector3Array([Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0.2, 1), Vector3(0, 0.2, 1), Vector3(0, 0.4, 1)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3, 2, 4, 3])
	halm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = halm
	var liste: Array = []
	var versuche := 0
	while liste.size() < 42000 and versuche < 160000:
		versuche += 1
		var p := Vector3(_rng.randf_range(-66, 68), 0, _rng.randf_range(-90, 58))
		if WeltPlan.tal_r(p.x, p.z) > 1.0:
			continue
		if absf(p.x - 3.5) < 7.2 and p.z > -3.4 and p.z < 3.4:
			continue
		if WeltPlan.bebaut(p.x, p.z, 0.1) and not (p.x < -7.5 and p.z > 8.0 and p.z < 17.0):
			continue
		if berg.hoehe_bei(p.x, p.z) > 0.02:
			continue
		if Vector2(p.x - Nussberg.MITTE.x, (p.z - Nussberg.MITTE.z) * 1.08).length() < Nussberg.RADIUS * 0.92:
			continue
		if gelaende.bach_abstand(p.x, p.z) < 2.2 or gelaende.weg_bei(p.x, p.z) > 0.45 + _rng.randf() * 0.3:
			continue
		p.y = gelaende.hoehe_bei(p.x, p.z)
		liste.append(p)
	mm.instance_count = liste.size()
	for i in liste.size():
		var s := _rng.randf_range(0.6, 1.5)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.7, 1.3), s)), liste[i]))
		var g := _rng.randf_range(0.75, 1.2)
		mm.set_instance_color(i, Color(g * _rng.randf_range(0.9, 1.15), g, g * 0.9))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Look.halm()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hof.add_child(mmi)


func _berg_aktualisieren() -> void:
	if _berg_text:
		_berg_text.text = Data.zahl(Game.berg_rest())


func berg_speichern(pfad: String) -> void:
	if berg:
		berg.speichern(pfad)


# =============================================================================
# Küche
# =============================================================================
func _kueche() -> void:
	var k := Node3D.new()
	k.name = "Kueche"
	add_child(k)
	var wand := Look.putz(Color(0.93, 0.86, 0.72), Color(0.84, 0.75, 0.6), 70.0)
	var holz_wand := Look.holz(Look.NUSSBAUM, 4.0, 0.2)
	var weiss := Look.lackiert(Color(0.93, 0.91, 0.86), 0.5)
	# Boden und Decke
	Bau.block(k, Vector3(6, 0.1, 6), Vector3(0, -0.05, 0), Look.holz([Color(0.7, 0.5, 0.32), Color(0.44, 0.28, 0.16)], 6.0, 0.25, 0.16, true))
	Bau.block(k, Vector3(6.4, 0.1, 6.4), Vector3(0, 3.05, 0), Look.holz(Look.KIEFER, 6.0, 0.0, 0.2, true), false)
	for bz in [-2.0, 0.0, 2.0]:
		Bau.block(k, Vector3(6.0, 0.18, 0.16), Vector3(0, 2.91, bz), Look.holz(Look.NUSSBAUM, 5.0), false)
	# Nordwand mit Fenster
	_wand(k, Vector3(-3.1, 0, -3.1), Vector3(FENSTER_X.x, 3, -2.9), wand)
	_wand(k, Vector3(FENSTER_X.y, 0, -3.1), Vector3(TUER_X.x, 3, -2.9), wand)
	_wand(k, Vector3(TUER_X.y, 0, -3.1), Vector3(3.1, 3, -2.9), wand)
	_wand(k, Vector3(TUER_X.x, 2.25, -3.1), Vector3(TUER_X.y, 3, -2.9), wand)
	_haustuer(k)
	# Kerben neben der Tür: Opa hat hier nicht die Enkel gemessen, sondern den Berg
	for kerbe in [["1974", 0.3], ["1981", 0.72], ["1990", 1.2], ["2003", 1.68], ["2019", 2.05]]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.07, 0.006, 0.004)), Bau.mat(Color(0.3, 0.2, 0.12)), Vector3(2.755, float(kerbe[1]), -2.897))
		Bau.schrift(k, str(kerbe[0]), Vector3(2.835, float(kerbe[1]) + 0.012, -2.896), 26, Color(0.3, 0.2, 0.12))
	Bau.schrift(k, "Berg", Vector3(2.8, 2.2, -2.896), 26, Color(0.3, 0.2, 0.12))
	_wand(k, Vector3(FENSTER_X.x, 0, -3.1), Vector3(FENSTER_X.y, FENSTER_Y.x, -2.9), wand)
	_wand(k, Vector3(FENSTER_X.x, FENSTER_Y.y, -3.1), Vector3(FENSTER_X.y, 3, -2.9), wand)
	_fenster(k)
	# Westwand mit Verkaufsklappe (z -1.6 .. -0.8, y 0.8 .. 1.35)
	_wand(k, Vector3(-3.1, 0, -3.1), Vector3(-2.9, 3, -1.6), wand)
	_wand(k, Vector3(-3.1, 0, -0.8), Vector3(-2.9, 3, 3.1), wand)
	_wand(k, Vector3(-3.1, 0, -1.6), Vector3(-2.9, 0.8, -0.8), wand)
	_wand(k, Vector3(-3.1, 1.35, -1.6), Vector3(-2.9, 3, -0.8), wand)
	_verkaufsklappe(k)
	# Südwand
	_wand(k, Vector3(-3.1, 0, 2.9), Vector3(3.1, 3, 3.1), wand)
	# Ostwand mit Tür zur Werkstatt (z -1 .. 1)
	_wand(k, Vector3(2.9, 0, -3.1), Vector3(3.1, 3, -1.0), wand)
	_wand(k, Vector3(2.9, 0, 1.0), Vector3(3.1, 3, 3.1), wand)
	_wand(k, Vector3(2.9, 2.4, -1.0), Vector3(3.1, 3, 1.0), wand)
	for s in [-1.0, 1.0]:
		Bau.block(k, Vector3(0.24, 2.4, 0.1), Vector3(2.9, 1.2, s * 1.04), weiss, false)
	Bau.block(k, Vector3(0.24, 0.1, 2.18), Vector3(2.9, 2.44, 0), weiss, false)
	if Game.aera < 2:
		_werkstatt_tuer = Node3D.new()
		_werkstatt_tuer.position = Vector3(3.0, 0, 0)
		k.add_child(_werkstatt_tuer)
		Bau.block(_werkstatt_tuer, Vector3(0.08, 2.38, 1.98), Vector3(0, 1.19, 0), Look.holz(Look.EICHE, 6.0, 0.3))
		Bau.teil(_werkstatt_tuer, Bau.kugel_mesh(0.035, false, 12), Look.metall(Color(0.75, 0.6, 0.3)), Vector3(-0.07, 1.05, 0.75))
		Bau.holzschild(_werkstatt_tuer, "WERKSTATT\nab %s Nüssen" % Data.zahl(Data.SCHICHTEN[1].ab), Vector3(-0.06, 1.55, 0), Vector2(0.8, 0.36), Vector3(0, -90, 0), 72)
	# Holzvertäfelung unten
	Bau.block(k, Vector3(5.8, 0.95, 0.03), Vector3(0, 0.475, 2.885), holz_wand, false)
	Bau.block(k, Vector3(0.03, 0.95, 2.2), Vector3(-2.885, 0.475, 1.8), holz_wand, false)
	Bau.block(k, Vector3(0.03, 0.95, 0.85), Vector3(-2.885, 0.475, -0.35), holz_wand, false)
	Bau.block(k, Vector3(0.03, 0.95, 1.3), Vector3(-2.885, 0.475, -2.3), holz_wand, false)
	Bau.block(k, Vector3(2.75, 0.95, 0.03), Vector3(-1.72, 0.475, -2.885), holz_wand, false)
	Bau.block(k, Vector3(TUER_X.x - FENSTER_X.y - 0.1, 0.95, 0.03), Vector3((TUER_X.x + FENSTER_X.y) * 0.5 - 0.05, 0.475, -2.885), holz_wand, false)
	Bau.block(k, Vector3(1.6, 0.95, 0.03), Vector3(FENSTER_X.x + 0.8, 0.475, -2.885), holz_wand, false)
	Bau.block(k, Vector3(0.03, 0.95, 1.85), Vector3(2.885, 0.475, -2.0), holz_wand, false)
	Bau.block(k, Vector3(0.03, 0.95, 1.85), Vector3(2.885, 0.475, 2.0), holz_wand, false)
	# Licht
	var lampe := Einrichtung.haengelampe(k, Vector3(0.15, 2.15, -1.6), 1.8)
	lampe.name = "Lampe"
	var fuell := OmniLight3D.new()
	fuell.position = Vector3(0.0, 2.2, 1.6)
	fuell.light_color = Color(1.0, 0.85, 0.7)
	fuell.light_energy = 0.5
	fuell.omni_range = 5.0
	k.add_child(fuell)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(6, 3, 6)
	probe.position = Vector3(0, 1.5, 0)
	probe.box_projection = true
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	k.add_child(probe)
	# Tisch, Hocker, Teppich
	Einrichtung.tisch(k, Vector3(0.15, 0, TISCH_Z), Vector3(2.4, TISCH_Y, 0.9))
	Einrichtung.hocker(k, Vector3(0.15, 0, -1.55))
	var sitz := Interaktiv.erzeuge(k, Vector3(0.4, 0.62, 0.4), Vector3(0.15, 0.31, -1.55), "An die Knackbank setzen", func(s): s.hinsetzen(station))
	sitz.info = func(): return "Hocker"
	Einrichtung.teppich(k, Vector3(0.15, 0, -1.4), Vector2(2.6, 1.6), Color(0.62, 0.2, 0.14), Color(0.5, 0.15, 0.1))
	# Knackstation
	station = Knackstation.new()
	station.position = Vector3(0.15, TISCH_Y, TISCH_Z)
	k.add_child(station)
	# Nussschale (Ablage für neue Nüsse)
	var schale := Node3D.new()
	schale.position = SCHALE_POS
	k.add_child(schale)
	var tablett := Look.holz(Look.EICHE, 7.0, 0.3)
	Bau.teil(schale, Bau.box_mesh(Vector3(0.38, 0.015, 0.34)), tablett, Vector3(0, 0.008, 0))
	for seite in [[Vector3(0.38, 0.055, 0.02), Vector3(0, 0.03, 0.17)], [Vector3(0.38, 0.055, 0.02), Vector3(0, 0.03, -0.17)],
			[Vector3(0.02, 0.055, 0.34), Vector3(0.19, 0.03, 0)], [Vector3(0.02, 0.055, 0.34), Vector3(-0.19, 0.03, 0)]]:
		Bau.block(schale, seite[0], seite[1], tablett)
	Bau.block(schale, Vector3(0.38, 0.015, 0.34), Vector3(0, 0.008, 0), tablett)
	_schale_bereich = Area3D.new()
	_schale_bereich.collision_layer = 0
	_schale_bereich.collision_mask = Data.L_ITEM
	var sc := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(0.38, 0.25, 0.34)
	sc.shape = sb
	sc.position.y = 0.12
	_schale_bereich.add_child(sc)
	schale.add_child(_schale_bereich)
	# Rohr vom Berg und Hebel
	var kupfer := Look.metall(Color(0.78, 0.47, 0.3), 0.32)
	Einrichtung.rohr(k, ROHR_OBEN, ROHR_UNTEN, 0.055, kupfer)
	Bau.teil(k, Bau.zylinder_mesh(0.075, 0.075, 0.04, 20), kupfer, ROHR_OBEN + Vector3(0, 0, 0.03), Vector3(90, 0, 0))
	var muendung := Einrichtung.rohr(k, ROHR_UNTEN, ROHR_UNTEN + (ROHR_UNTEN - ROHR_OBEN).normalized() * 0.04, 0.068, kupfer)
	muendung.name = "Muendung"
	var hebel := Node3D.new()
	hebel.position = Vector3(-1.05, 1.3, -2.87)
	k.add_child(hebel)
	Bau.teil(hebel, Bau.box_mesh(Vector3(0.18, 0.26, 0.06)), Look.metall(Color(0.3, 0.32, 0.3), 0.5))
	Bau.teil(hebel, Bau.zylinder_mesh(0.02, 0.02, 0.08, 12), Look.metall(Color(0.6, 0.6, 0.62), 0.3), Vector3(0, 0.0, 0.05), Vector3(90, 0, 0))
	_hebel_arm = Node3D.new()
	_hebel_arm.position = Vector3(0, 0, 0.08)
	_hebel_arm.rotation_degrees.x = 35
	hebel.add_child(_hebel_arm)
	Bau.teil(_hebel_arm, Bau.zylinder_mesh(0.014, 0.014, 0.26, 10), Look.metall(Color(0.7, 0.7, 0.72), 0.3), Vector3(0, 0.13, 0))
	Bau.teil(_hebel_arm, Bau.kugel_mesh(0.035, false, 14), Look.plastik(Color(0.78, 0.12, 0.08), 0.3), Vector3(0, 0.27, 0))
	Interaktiv.erzeuge(hebel, Vector3(0.3, 0.5, 0.35), Vector3(0, 0.1, 0.1), "Hebel ziehen: Nüsse vom Berg holen", func(_s): hebel_ziehen())
	Bau.holzschild(k, "NÜSSE", Vector3(-1.05, 1.68, -2.88), Vector2(0.4, 0.15), Vector3.ZERO, 60)
	# Telefon / Bestellkatalog
	var tel := Einrichtung.telefon(k, Vector3(-2.75, 1.2, 0.1), 90)
	var ti := Interaktiv.erzeuge(tel, Vector3(0.4, 0.35, 0.3), Vector3(0, 0.05, 0.08), "Bestellen: Werkzeuge und Maschinen", func(_s): _menue(menues.zeige_laden))
	ti.info = func(): return "%s Münzen in der Kasse" % Data.zahl(Game.muenzen)
	Bau.holzschild(k, "BESTELLUNGEN", Vector3(-2.88, 1.62, 0.1), Vector2(0.62, 0.16), Vector3(0, 90, 0), 60)
	# Pinnwand mit Bestellzetteln
	var pinn := Node3D.new()
	pinn.position = Vector3(-2.88, 1.55, 1.5)
	pinn.rotation_degrees.y = 90
	k.add_child(pinn)
	Bau.teil(pinn, Bau.box_mesh(Vector3(1.15, 0.8, 0.03)), Look.holz(Look.NUSSBAUM, 4.0, 0.3))
	Bau.teil(pinn, Bau.box_mesh(Vector3(1.05, 0.7, 0.01)), Look.putz(Color(0.72, 0.55, 0.36), Color(0.62, 0.45, 0.28), 200.0), Vector3(0, 0, 0.018))
	for i in 4:
		var z := Node3D.new()
		z.position = Vector3(-0.39 + i * 0.26, 0.0, 0.026)
		z.rotation_degrees.z = _rng.randf_range(-4, 4)
		pinn.add_child(z)
		Bau.teil(z, Bau.box_mesh(Vector3(0.24, 0.32, 0.002)), Look.plastik(Color(0.97, 0.95, 0.88), 0.9))
		Bau.teil(z, Bau.kugel_mesh(0.012, false, 8), Look.plastik(Color(0.8, 0.15, 0.1), 0.3), Vector3(0, 0.14, 0.004))
		var l := Bau.schrift(z, "", Vector3(0, -0.01, 0.002), 34, Color(0.15, 0.12, 0.25), Vector3.ZERO, 500)
		l.width = 190
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pinn_zettel.append([z, l])
	# Opas Talentbaum an der Südwand
	var tafel := Node3D.new()
	tafel.position = Vector3(0, 1.6, 2.86)
	tafel.rotation_degrees.y = 180
	k.add_child(tafel)
	Bau.teil(tafel, Bau.box_mesh(Vector3(1.3, 0.95, 0.05)), Look.holz(Look.NUSSBAUM, 4.0, 0.5))
	Bau.teil(tafel, Bau.box_mesh(Vector3(1.16, 0.81, 0.01)), Look.putz(Color(0.95, 0.9, 0.78), Color(0.88, 0.8, 0.65), 150.0), Vector3(0, 0, 0.027))
	Bau.teil(tafel, Bau.box_mesh(Vector3(0.06, 0.36, 0.01)), Look.plastik(Color(0.4, 0.25, 0.12), 0.9), Vector3(0, -0.2, 0.033))
	for zw in [[-0.17, -0.02], [0.0, 0.06], [0.17, -0.01], [-0.08, 0.13], [0.09, 0.14]]:
		Bau.teil(tafel, Bau.kugel_mesh(0.09, false, 14), Look.plastik(Color(0.45, 0.62, 0.26), 0.9), Vector3(zw[0], zw[1], 0.03), Vector3.ZERO, Vector3(1, 1, 0.08))
	Bau.schrift(tafel, "OPAS TALENTBAUM", Vector3(0, 0.31, 0.034), 56, Color(0.3, 0.16, 0.06))
	var tt := Interaktiv.erzeuge(tafel, Vector3(1.3, 0.95, 0.2), Vector3.ZERO, "Opas Notizbuch (Skillbaum)", func(_s): _menue(menues.zeige_talente))
	tt.info = func(): return "%d Skills gelernt  ·  auch mit [Tab]" % Game.skills.size()
	# Deko
	_uhr_zeiger = Einrichtung.uhr(k, Vector3(2.88, 2.68, 0.0), -90)
	var regal := Einrichtung.regal(k, Vector3(2.9, 1.45, 2.05), 1.3, 2, -90)
	var sorten := ["wal", "hasel", "mandel", "wal", "pekan", "hasel"]
	for i in 6:
		Einrichtung.vorratsglas(regal, Vector3(-0.45 + (i % 3) * 0.42, (i / 3) * 0.4 + 0.013, 0.12), sorten[i], _rng.randf_range(0.4, 0.95), 0.2 + (i % 2) * 0.05)
	Einrichtung.sack(k, Vector3(-2.45, 0, -2.45), 0.6)
	Einrichtung.sack(k, Vector3(-2.0, 0, -2.6), -0.3, "hasel")
	Einrichtung.sack(k, Vector3(-2.5, 0, -1.95), 1.4)
	_draussen(k)
	Einrichtung.sessel(k, Vector3(-2.2, 0, 2.2), 135)
	Einrichtung.teppich(k, Vector3(-1.9, 0, 1.9), Vector2(1.5, 1.5), Color(0.3, 0.42, 0.55), Color(0.22, 0.32, 0.45))
	Einrichtung.pflanze(k, Vector3(2.55, 0, -2.55), 2.2)
	# Bild von Opa
	var bild := Node3D.new()
	bild.position = Vector3(-1.3, 1.85, 2.88)
	bild.rotation_degrees.y = 180
	k.add_child(bild)
	Bau.teil(bild, Bau.box_mesh(Vector3(0.42, 0.52, 0.03)), Look.metall(Color(0.75, 0.58, 0.28), 0.4))
	Bau.teil(bild, Bau.box_mesh(Vector3(0.34, 0.44, 0.01)), Look.putz(Color(0.62, 0.52, 0.4), Color(0.5, 0.42, 0.32), 30.0), Vector3(0, 0, 0.016))
	Bau.teil(bild, Bau.kugel_mesh(0.08, false, 14), Look.putz(Color(0.85, 0.7, 0.58)), Vector3(0, 0.06, 0.02), Vector3.ZERO, Vector3(1, 1.1, 0.2))
	Bau.teil(bild, Bau.kugel_mesh(0.085, true, 14), Look.putz(Color(0.95, 0.95, 0.95)), Vector3(0, -0.02, 0.022), Vector3(180, 0, 0), Vector3(0.9, 0.8, 0.2))
	Bau.teil(bild, Bau.box_mesh(Vector3(0.24, 0.12, 0.01)), Look.putz(Color(0.3, 0.25, 0.2)), Vector3(0, -0.15, 0.02))
	Bau.schrift(bild, "Opa Walter", Vector3(0, -0.24, 0.024), 26, Color(0.25, 0.18, 0.1))


func _wand(eltern: Node3D, von: Vector3, bis: Vector3, material: Material) -> Node3D:
	var groesse := (bis - von).abs()
	return Bau.block(eltern, groesse, (von + bis) * 0.5, material)


func _fenster(k: Node3D) -> void:
	var weiss := Look.lackiert(Color(0.93, 0.91, 0.86), 0.5)
	var b := FENSTER_X.y - FENSTER_X.x
	var mx := (FENSTER_X.x + FENSTER_X.y) * 0.5
	var my := (FENSTER_Y.x + FENSTER_Y.y) * 0.5
	var h := FENSTER_Y.y - FENSTER_Y.x
	Bau.block(k, Vector3(b + 0.25, 0.05, 0.34), Vector3(mx, FENSTER_Y.x - 0.02, -2.95), weiss)
	Bau.block(k, Vector3(b + 0.12, 0.08, 0.22), Vector3(mx, FENSTER_Y.y + 0.04, -3.0), weiss, false)
	for x in [FENSTER_X.x - 0.04, FENSTER_X.y + 0.04]:
		Bau.block(k, Vector3(0.08, h + 0.12, 0.22), Vector3(x, my, -3.0), weiss, false)
	# Fensterläden außen (offen) und Vorhänge innen
	var gruen := Look.lackiert(Color(0.24, 0.45, 0.32), 0.3)
	for s in [-1.0, 1.0]:
		var laden := Node3D.new()
		laden.position = Vector3(mx + s * (b * 0.5 + 0.38), my, -3.18)
		k.add_child(laden)
		Bau.teil(laden, Bau.box_mesh(Vector3(0.7, h + 0.06, 0.03)), gruen)
		for i in 7:
			Bau.teil(laden, Bau.box_mesh(Vector3(0.62, 0.025, 0.02)), gruen, Vector3(0, -h * 0.45 + i * h * 0.15, -0.02), Vector3(-25, 0, 0))
	Einrichtung.vorhang(k, Vector3(FENSTER_X.x - 0.2, FENSTER_Y.y + 0.15, -2.82), h + 0.45, Color(0.85, 0.3, 0.22))
	Einrichtung.vorhang(k, Vector3(FENSTER_X.y + 0.2, FENSTER_Y.y + 0.15, -2.82), h + 0.45, Color(0.85, 0.3, 0.22))
	Bau.teil(k, Bau.zylinder_mesh(0.012, 0.012, b + 0.9, 8), Look.metall(Color(0.6, 0.45, 0.25)), Vector3(mx, FENSTER_Y.y + 0.17, -2.82), Vector3(0, 0, 90))
	Einrichtung.pflanze(k, Vector3(FENSTER_X.y - 0.12, FENSTER_Y.x, -2.95), 0.9)


func _haustuer(k: Node3D) -> void:
	var weiss := Look.lackiert(Color(0.93, 0.91, 0.86), 0.5)
	for x in [TUER_X.x - 0.04, TUER_X.y + 0.04]:
		Bau.block(k, Vector3(0.08, 2.3, 0.24), Vector3(x, 1.15, -3.0), weiss, false)
	Bau.block(k, Vector3(TUER_X.y - TUER_X.x + 0.16, 0.08, 0.24), Vector3((TUER_X.x + TUER_X.y) * 0.5, 2.29, -3.0), weiss, false)
	# offene Tür, nach außen geklappt
	var tuer := Node3D.new()
	tuer.position = Vector3(TUER_X.y, 0, -3.12)
	tuer.rotation_degrees.y = -100
	k.add_child(tuer)
	Bau.block(tuer, Vector3(TUER_X.y - TUER_X.x, 2.2, 0.05), Vector3(-(TUER_X.y - TUER_X.x) * 0.5, 1.1, -0.03), Look.lackiert(Color(0.24, 0.45, 0.32), 0.3))
	Bau.teil(tuer, Bau.kugel_mesh(0.035, false, 12), Look.metall(Color(0.75, 0.6, 0.3)), Vector3(-(TUER_X.y - TUER_X.x) + 0.1, 1.05, -0.07))
	# Stufe vor der Tür
	Bau.block(k, Vector3(1.3, 0.08, 0.6), Vector3((TUER_X.x + TUER_X.y) * 0.5, 0.0, -3.45), Look.putz(Color(0.6, 0.58, 0.52), Color(0.5, 0.48, 0.44), 40.0))


## Alles direkt vor der Hütte: Nusssilo mit Trichter, Abgabekreis, Bestellbrett, Dach.
func _draussen(k: Node3D) -> void:
	var holz := Look.holz(Look.ALTHOLZ, 9.0, 0.1)
	var dunkel := Look.holz(Look.NUSSBAUM, 6.0, 0.2)
	var silo := Node3D.new()
	silo.position = SILO_POS
	k.add_child(silo)
	Bau.block(silo, Vector3(1.6, 1.5, 1.4), Vector3(0, 0.75, 0), holz)
	for x in [-0.8, 0.8]:
		for z in [-0.7, 0.7]:
			Bau.teil(silo, Bau.box_mesh(Vector3(0.1, 1.55, 0.1)), dunkel, Vector3(x, 0.77, z))
	# Sichtfenster mit Füllstand
	Bau.teil(silo, Bau.box_mesh(Vector3(0.5, 1.2, 0.02)), Look.glas(), Vector3(0, 0.75, -0.715))
	_silo_fuell = Node3D.new()
	_silo_fuell.position = Vector3(0, 0.15, -0.69)
	silo.add_child(_silo_fuell)
	Bau.teil(_silo_fuell, Bau.box_mesh(Vector3(0.48, 1.0, 0.02)), Look.nusshaufen(0.05), Vector3(0, 0.5, 0))
	# Trichter oben drauf
	var trichter := CylinderMesh.new()
	trichter.top_radius = 0.95
	trichter.bottom_radius = 0.35
	trichter.height = 0.55
	trichter.cap_top = false
	trichter.radial_segments = 4
	var tm := Look.metall(Color(0.62, 0.65, 0.68), 0.45).duplicate() as StandardMaterial3D
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	Bau.teil(silo, trichter, tm, Vector3(0, 1.78, -0.1), Vector3(0, 45, 0))
	Bau.holzschild(silo, "ABGABE", Vector3(0, 1.32, -0.72), Vector2(0.9, 0.22), Vector3(0, 180, 0), 90)
	_silo_text = Bau.schrift(silo, "", Vector3(0, 0.12, -0.73), 48, Color(1.0, 0.95, 0.8), Vector3(0, 180, 0), 600)
	_silo_text.outline_size = 8
	_silo_text.outline_modulate = Color(0.15, 0.08, 0.03)
	# Abgabekreis am Boden
	var ring := TorusMesh.new()
	ring.inner_radius = ABGABE_RADIUS - 0.08
	ring.outer_radius = ABGABE_RADIUS
	ring.rings = 48
	var rm := Bau.teil(k, ring, Look.leuchten(Color(1.0, 0.8, 0.25), 1.5), ABGABE_POS + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.15, 1))
	rm.set_meta("ohne_rand", true)
	rm.name = "Abgabekreis"
	var flaeche := CylinderMesh.new()
	flaeche.top_radius = ABGABE_RADIUS
	flaeche.bottom_radius = ABGABE_RADIUS
	flaeche.height = 0.01
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.8, 0.3, 0.18)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Bau.teil(k, flaeche, fm, ABGABE_POS + Vector3(0, 0.012, 0))
	_abgaben.append({"pos": ABGABE_POS, "name": "Trichter", "ziel": SILO_POS + Vector3(0, 1.9, 0)})
	# Bestellbrett (Laden) neben dem Silo
	var brett := Node3D.new()
	brett.position = Vector3(-2.95, 0, -5.4)
	brett.rotation_degrees.y = 200
	k.add_child(brett)
	for x in [-0.55, 0.55]:
		Bau.teil(brett, Bau.box_mesh(Vector3(0.08, 1.9, 0.08)), dunkel, Vector3(x, 0.95, 0))
	Bau.teil(brett, Bau.box_mesh(Vector3(1.3, 0.95, 0.05)), Look.putz(Color(0.2, 0.24, 0.2), Color(0.16, 0.19, 0.16), 120.0, 0.0, 0.9), Vector3(0, 1.35, 0.03))
	Bau.teil(brett, Bau.box_mesh(Vector3(1.4, 0.06, 0.08)), dunkel, Vector3(0, 1.85, 0.03))
	Bau.schrift(brett, "BESTELLBRETT\nWerkzeug · Beutel · Helfer", Vector3(0, 1.45, -0.0), 44, Color(0.95, 0.95, 0.9), Vector3(0, 180, 0), 500)
	var bi := Interaktiv.erzeuge(brett, Vector3(1.4, 1.0, 0.4), Vector3(0, 1.35, 0), "Bestellbrett: Werkzeug, Beutel, Helfer", func(_s): _menue(menues.zeige_laden))
	bi.info = func(): return "%s Münzen" % Data.zahl(Game.muenzen)
	# Dach über Küche und Werkstatt
	var ziegel := Look.putz(Color(0.62, 0.24, 0.16), Color(0.5, 0.18, 0.12), 30.0, 0.35, 0.8)
	for seite in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(6.8, 0.12, 4.3)), ziegel, Vector3(0, 4.15, seite * 1.75), Vector3(seite * 38.0, 0, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(7.6, 0.12, 4.3)), ziegel, Vector3(6.5, 4.15, seite * 1.75), Vector3(seite * 38.0, 0, 0))
	var gm := Look.putz(Color(0.93, 0.86, 0.72), Color(0.84, 0.75, 0.6), 70.0)
	for x in [-3.0, 3.0, 10.0]:
		_giebel(k, x, gm)
	Bau.teil(k, Bau.box_mesh(Vector3(1.0, 1.4, 0.8)), Look.putz(Color(0.55, 0.3, 0.22), Color(0.45, 0.24, 0.18), 20.0, 0.12, 0.9), Vector3(-1.8, 4.6, 1.4))


## Dreieckige Giebelwand (Prisma) quer zur x-Achse.
func _giebel(eltern: Node3D, x: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unten := 3.0
	var oben := 5.35
	var b := 3.1
	var d := 0.1
	var vorn := [Vector3(x - d, unten, -b), Vector3(x - d, oben, 0), Vector3(x - d, unten, b)]
	var hinten := [Vector3(x + d, unten, -b), Vector3(x + d, oben, 0), Vector3(x + d, unten, b)]
	for tri in [[vorn[0], vorn[1], vorn[2]], [hinten[2], hinten[1], hinten[0]]]:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	eltern.add_child(mi)


func _verkaufsklappe(k: Node3D) -> void:
	var holz := Look.holz(Look.EICHE, 6.0, 0.35)
	Bau.block(k, Vector3(0.55, 0.05, 1.0), Vector3(-2.95, 0.78, -1.2), holz)
	for z in [-1.63, -0.77]:
		Bau.block(k, Vector3(0.24, 0.6, 0.06), Vector3(-2.95, 1.07, z), holz, false)
	Bau.block(k, Vector3(0.24, 0.06, 0.92), Vector3(-2.95, 1.38, -1.2), holz, false)
	_klappe = Node3D.new()
	_klappe.position = Vector3(-3.06, 1.35, -1.2)
	k.add_child(_klappe)
	Bau.teil(_klappe, Bau.box_mesh(Vector3(0.03, 0.54, 0.8)), Look.lackiert(Color(0.25, 0.42, 0.3), 0.4), Vector3(0, -0.27, 0))
	Bau.teil(_klappe, Bau.kugel_mesh(0.022, false, 10), Look.metall(Color(0.8, 0.65, 0.3)), Vector3(0.025, -0.45, 0))
	# Glocke auf der Theke
	Bau.teil(k, Bau.kugel_mesh(0.045, true, 16), Look.metall(Color(0.85, 0.7, 0.35), 0.2), Vector3(-2.82, 0.805, -0.92))
	Bau.holzschild(k, "VERKAUF", Vector3(-2.88, 1.58, -1.2), Vector2(0.55, 0.16), Vector3(0, 90, 0), 66)
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = Data.L_BEHAELTER
	a.position = Vector3(-3.05, 1.05, -1.2)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.6, 0.5, 0.8)
	cs.shape = bx
	a.add_child(cs)
	k.add_child(a)
	a.body_entered.connect(_klappe_betreten)
	var ia := Interaktiv.erzeuge(k, Vector3(0.3, 0.55, 0.85), Vector3(-2.92, 1.07, -1.2), "Verkaufsklappe: bring ein Glas oder die Bruchschale", func(s): _klappe_benutzen(s))
	ia.mit_gegenstand = true
	ia.text_mit_gegenstand = "Verkaufen"
	ia.info = func(): return "Glas, Bruchschale oder Eimer hier abgeben"


# =============================================================================
# Werkstatt
# =============================================================================
func _werkstatt() -> void:
	var w := Node3D.new()
	w.name = "Werkstatt"
	add_child(w)
	var wf := Look.putz(Color(0.82, 0.8, 0.74), Color(0.74, 0.7, 0.64), 50.0)
	Bau.block(w, Vector3(7, 0.1, 6), Vector3(6.5, -0.05, 0), Look.putz(Color(0.55, 0.54, 0.5), Color(0.48, 0.47, 0.44), 30.0, 1.0, 0.85))
	Bau.block(w, Vector3(7.2, 0.1, 6.4), Vector3(6.5, 3.05, 0), Look.holz(Look.ALTHOLZ, 6.0, 0.0, 0.25, true), false)
	for bx in [4.5, 6.5, 8.5]:
		Bau.block(w, Vector3(0.16, 0.18, 6.0), Vector3(bx, 2.91, 0), Look.holz(Look.NUSSBAUM, 5.0), false)
	_wand(w, Vector3(3.0, 0, -3.1), Vector3(10.1, 3, -2.9), wf)
	_wand(w, Vector3(3.0, 0, 2.9), Vector3(10.1, 3, 3.1), wf)
	_wand(w, Vector3(9.9, 0, -3.1), Vector3(10.1, 3, -2.2), wf)
	_wand(w, Vector3(9.9, 0, -1.4), Vector3(10.1, 3, 3.1), wf)
	_wand(w, Vector3(9.9, 0, -2.2), Vector3(10.1, 0.7, -1.4), wf)
	_wand(w, Vector3(9.9, 1.3, -2.2), Vector3(10.1, 3, -1.4), wf)
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = Data.L_BEHAELTER
	a.position = Vector3(10.15, 1.0, -1.8)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.6, 0.55, 0.85)
	cs.shape = b
	a.add_child(cs)
	w.add_child(a)
	a.body_entered.connect(_klappe_betreten)
	Bau.holzschild(w, "KLAPPE", Vector3(9.88, 1.5, -1.8), Vector2(0.5, 0.16), Vector3(0, -90, 0), 66)
	Einrichtung.haengelampe(w, Vector3(6.5, 2.2, 0), 2.0)
	# Werkbank mit Lochwand
	Einrichtung.tisch(w, Vector3(6.5, 0, 2.5), Vector3(2.6, 0.9, 0.7))
	Bau.block(w, Vector3(2.4, 1.0, 0.03), Vector3(6.5, 1.65, 2.88), Look.holz(Look.KIEFER, 6.0, 0.1), false)
	for i in 6:
		var x := 5.5 + i * 0.4
		Bau.teil(w, Bau.box_mesh(Vector3(0.04, 0.3, 0.03)), Look.metall(Color(0.5, 0.5, 0.55)), Vector3(x, 1.7, 2.84))
	Bau.holzschild(w, "Maschinen gibt's am Telefon in der Küche", Vector3(6.5, 2.35, 2.86), Vector2(1.6, 0.18), Vector3(0, 180, 0), 50)
	_werkstatt_einrichten(w)


# =============================================================================
# Opas Anwesen (Etappe 2 des Weltplans)
# =============================================================================
const BRIEF_GEMEINDE := """Gemeinde Haselgrund · Bauamt

Sehr geehrter Herr Walter,

Betreff: Ihr Nusshaufen (unser Schreiben Nr. 47)

wir weisen erneut darauf hin, dass der Haufen auf Ihrem Grundstück inzwischen höher ist als das Rathaus. Eine Genehmigung liegt weiterhin nicht vor. Wir bitten um Abtragung bis spätestens Herbst 1998.

Mit freundlichen Grüßen
i. A. Krümel

P. S.: Die Eichhörnchen haben schon wieder unseren Briefträger bestohlen."""

const BAUPLAN_MOND := """Mondsiebmaschine, Entwurf 7

Manche Nüsse kommen vom Mond. Ich bin mir sicher. Sie sind silbern und schmecken nach nichts.

Die Maschine steht auf der Lichtung hinter dem Berg, da wo der graue Staub liegt. Erst sauber machen, dann einschalten!

Merken: Wegweiser im alten Dorf neu streichen (Mond: 384.400 km).

Am Rand, mit Bleistift: Nadel verloren. Irgendwo zwischen Heu und Abendrot."""


func _anwesen(hof: Node3D) -> void:
	var g := gelaende
	var o := WeltPlan.ORTE
	Modelle.platz(hof, "veranda", Vector3(2.0, 0.0, 4.3), 0.0, Ersatz.veranda)
	Modelle.platz(hof, "brunnen", g.position(o.brunnen.x, o.brunnen.z), 25.0, Ersatz.brunnen)
	Modelle.platz(hof, "huehnerstall", g.position(o.huehnerstall.x, o.huehnerstall.z), 0.0, Ersatz.huehnerstall)
	Modelle.platz(hof, "holzlager", g.position(o.holzlager.x, o.holzlager.z), 0.0, Ersatz.holzlager)
	# Feuerstelle; Opas Stuhl steht so, dass er über das Feuer genau auf die Kuppe schaut
	var feuer := g.position(o.feuerstelle.x, o.feuerstelle.z)
	Modelle.platz(hof, "feuerstelle", feuer, 0.0, Ersatz.feuerstelle)
	var zur_kuppe := Vector3(Nussberg.MITTE.x - feuer.x, 0, Nussberg.MITTE.z - feuer.z).normalized()
	var sitz := feuer - zur_kuppe * 1.9
	Modelle.platz(hof, "opas_stuhl", g.position(sitz.x, sitz.z), rad_to_deg(atan2(zur_kuppe.x, zur_kuppe.z)), Ersatz.opas_stuhl)
	# Hoftor, Zaun und Briefkasten
	Modelle.platz(hof, "hoftor", g.position(1.7, 21.3), 0.0, Ersatz.hoftor)
	_zaun(hof, Vector2(-14.2, 21.3), Vector2(-0.3, 21.3), 11, 1.0, [2])
	_zaun(hof, Vector2(3.7, 21.3), Vector2(18.0, 21.3), 12, 1.0, [5])
	var kasten := Modelle.platz(hof, "briefkasten", g.position(4.5, 22.4), -90.0, Ersatz.briefkasten)
	Interaktiv.erzeuge(kasten, Vector3(0.6, 0.7, 0.7), Vector3(0, 1.15, 0), "Briefkasten: Post für Opa",
		func(_s): _menue(menues.zeige_zettel.bind("Post für Opa", BRIEF_GEMEINDE)))
	# Der Traktor hat den Kampf gegen den Berg verloren
	var tp := g.position(o.traktor.x, o.traktor.z)
	var traktor := Modelle.platz(hof, "traktor_kaputt", tp + Vector3(0, -0.12, 0),
		rad_to_deg(atan2(Nussberg.MITTE.x - tp.x, Nussberg.MITTE.z - tp.z)), Ersatz.traktor)
	traktor.rotation_degrees.x = 5.0
	_garten(hof)


func _zaun(hof: Node3D, von: Vector2, bis: Vector2, saat: int, hoehe := 1.0, luecken: Array = []) -> void:
	var m := (von + bis) * 0.5
	var k := Node3D.new()
	k.name = "Zaun"
	k.position = gelaende.position(m.x, m.y)
	k.rotation.y = -atan2(bis.y - von.y, bis.x - von.x)
	hof.add_child(k)
	Ersatz.zaun(k, von.distance_to(bis), saat, hoehe, luecken)


## Gemüsegarten mit vier Beeten, Gewächshaus, Vogelscheuche; daneben der Apfelbaum mit Opas Leiter.
func _garten(hof: Node3D) -> void:
	var g := gelaende
	var x0 := -14.6
	var x1 := -7.6
	var z0 := 8.5
	var z1 := 16.0
	_zaun(hof, Vector2(x0, z0), Vector2(x1, z0), 21, 0.8)
	_zaun(hof, Vector2(x0, z1), Vector2(x1, z1), 22, 0.8)
	_zaun(hof, Vector2(x0, z0), Vector2(x0, z1), 23, 0.8)
	_zaun(hof, Vector2(x1, z0), Vector2(x1, 11.5), 24, 0.8)
	_zaun(hof, Vector2(x1, 13.0), Vector2(x1, z1), 25, 0.8)
	Modelle.platz(hof, "gewaechshaus", g.position(-13.2, 12.25), 90.0, Ersatz.gewaechshaus)
	Modelle.platz(hof, "vogelscheuche", g.position(-13.3, 9.5), 100.0, Ersatz.vogelscheuche)
	var erde := Look.putz(Color(0.32, 0.23, 0.15), Color(0.24, 0.17, 0.11), 45.0, 0.0, 1.0)
	var beete := [
		[9.3, ["natur/crops_cornStageD.glb", "natur/crops_cornStageB.glb", "natur/crops_cornStageC.glb"], 1.05],
		[10.6, ["natur/crop_carrot.glb", "natur/crop_turnip.glb"], 0.9],
		[13.9, ["natur/crops_leafsStageB.glb", "natur/crops_leafsStageA.glb"], 1.0],
		[15.2, ["natur/crops_wheatStageB.glb", "natur/crops_wheatStageA.glb"], 1.1],
	]
	var r := RandomNumberGenerator.new()
	r.seed = 88
	var lagen := {}
	for beet in beete:
		var z: float = beet[0]
		var h := g.hoehe_bei(-9.8, z)
		var b := Bau.teil(hof, Bau.box_mesh(Vector3(3.3, 0.16, 0.9)), erde, Vector3(-9.8, h + 0.05, z))
		b.set_meta("ohne_rand", true)
		var arten: Array = beet[1]
		for i in 8:
			if r.randf() < 0.1:
				continue   # hier ist nichts aufgegangen
			var pfad: String = arten[r.randi() % arten.size()]
			if not lagen.has(pfad):
				lagen[pfad] = []
			lagen[pfad].append(Streuer.lage(Vector3(-11.2 + i * 0.4 + r.randf_range(-0.05, 0.05), h + 0.16, z + r.randf_range(-0.12, 0.12)), r.randf() * TAU, float(beet[2]) * r.randf_range(0.85, 1.15)))
	# Kürbisse und Melonen an der Vogelscheuche
	for i in 6:
		var pfad2 := "natur/crop_pumpkin.glb" if i < 4 else "natur/crop_melon.glb"
		if not lagen.has(pfad2):
			lagen[pfad2] = []
		var p := g.position(-13.6 + (i % 3) * 0.75 + r.randf_range(-0.15, 0.15), 10.3 - (i / 3) * 0.7 + r.randf_range(-0.1, 0.1))
		lagen[pfad2].append(Streuer.lage(p + Vector3(0, 0.03, 0), r.randf() * TAU, r.randf_range(1.2, 1.8)))
	for pfad3 in lagen:
		Streuer.setzen(hof, pfad3, lagen[pfad3], {"schatten": false, "sicht": 70.0})
	# Apfelbaum mit Leiter und Korb
	var ap: Vector3 = WeltPlan.ORTE.apfelbaum
	var baum_pos := g.position(ap.x, ap.z)
	Modelle.setze(hof, "wald/Tree_3_B_Color1.gltf", baum_pos + Vector3(0, -0.15, 0), 40.0, 1.3)
	var stamm := Node3D.new()
	stamm.position = baum_pos
	hof.add_child(stamm)
	Ersatz._koll(stamm, Vector3(0.6, 3.0, 0.6), Vector3(0, 1.5, 0))
	Modelle.platz(hof, "leiter_apfelbaum", baum_pos + Vector3(0.15, 0, 1.15), 0.0, Ersatz.leiter)


# =============================================================================
# Alt-Haselgrund, Picknickplatz, Heuschober, Angelplatz, Hochsitz (Etappe 3)
# =============================================================================
func _siedlung(hof: Node3D) -> void:
	var g := gelaende
	var o := WeltPlan.ORTE
	Modelle.platz(hof, "koehlerhuette_ruine", g.position(-53.0, 23.0), 115.0, Ersatz.koehlerhuette)
	Modelle.platz(hof, "schuppen_ruine", g.position(-46.5, 26.5), -25.0, Ersatz.schuppen)
	var lager := Modelle.platz(hof, "lagerhaus_alt", g.position(-56.0, 15.0), 70.0, Ersatz.lagerhaus)
	var brett: Node3D = lager.find_child("Loses_Brett", true, false)
	if brett:
		var bi := Interaktiv.erzeuge(lager, Vector3(0.3, 1.2, 0.7), Vector3(2.1, 0.6, -0.4), "Loses Brett zur Seite schieben", func(_s): pass)
		bi.aktion = func(_s):
			Sfx.spiele("knarzen", -6.0, 0.8)
			var tw := create_tween()
			tw.tween_property(brett, "rotation_degrees:x", 62.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# erst etwas später entfernen, der Spieler zielt in diesem Moment noch darauf
			bi.collision_layer = 0
			get_tree().create_timer(0.3).timeout.connect(bi.queue_free)
	Modelle.platz(hof, "holzwagen_kaputt", g.position(-45.0, 15.6), 65.0, Ersatz.holzwagen)
	Modelle.platz(hof, "wegweiser", g.position(-35.5, 15.8), 0.0, func(k: Node3D):
		Ersatz.wegweiser(k, [["Alt-Haselgrund 0,3 km", 200.0], ["Stadt 14 km", 20.0], ["Mond 384.400 km", 95.0]]))
	Modelle.platz(hof, "heuschober", g.position(o.heuschober.x, o.heuschober.z), 90.0, Ersatz.heuschober)
	Modelle.platz(hof, "picknick", g.position(o.picknick.x, o.picknick.z), 30.0, Ersatz.picknick)
	Modelle.platz(hof, "sperre", g.position(o.sperre.x, o.sperre.z), 0.0, Ersatz.sperre)
	# Angelplatz: der Steg zeigt vom Ostufer ins Wasser
	var bach_a: Vector3 = WeltPlan.BACH[5]
	var bach_b: Vector3 = WeltPlan.BACH[6]
	var mitte := bach_a.lerp(bach_b, 0.5)
	var lauf := Vector3(bach_b.x - bach_a.x, 0, bach_b.z - bach_a.z).normalized()
	var ufer := Vector3(lauf.z, 0, -lauf.x)
	var steg := mitte + ufer * 3.3
	Modelle.platz(hof, "angelplatz", Vector3(steg.x, g.hoehe_bei(steg.x, steg.z) - 0.1, steg.z), rad_to_deg(atan2(-ufer.x, -ufer.z)), Ersatz.angelplatz)
	# Hochsitz: Front und Leiter zeigen zum Berg
	var hp := g.position(o.hochsitz.x, o.hochsitz.z)
	var zum_berg := Vector3(Nussberg.MITTE.x - hp.x, 0, Nussberg.MITTE.z - hp.z).normalized()
	var hochsitz := Modelle.platz(hof, "hochsitz", hp, rad_to_deg(atan2(zum_berg.x, zum_berg.z)), Ersatz.hochsitz)
	var oben := hp + Vector3(0, 3.75, 0) + zum_berg * 0.3
	var unten := g.position(hp.x + zum_berg.x * 2.8, hp.z + zum_berg.z * 2.8) + Vector3(0, 0.1, 0)
	Interaktiv.erzeuge(hochsitz, Vector3(0.9, 2.2, 0.5), Vector3(0, 1.2, 1.9), "Leiter hochklettern", func(sp):
		Sfx.variante("footstep_wood", -8.0, 0.9)
		sp.velocity = Vector3.ZERO
		sp.global_position = oben)
	Interaktiv.erzeuge(hochsitz, Vector3(0.8, 0.5, 0.4), Vector3(0, 3.95, 1.2), "Leiter hinunterklettern", func(sp):
		Sfx.variante("footstep_wood", -8.0, 0.9)
		sp.velocity = Vector3.ZERO
		sp.global_position = unten)


# =============================================================================
# Werkstatt-Einrichtung: Regal, Fotos, Bauplan, Opas Maschine unter der Plane
# =============================================================================
func _werkstatt_einrichten(w: Node3D) -> void:
	Einrichtung.teppich(w, Vector3(6.3, 0, 0.3), Vector2(2.6, 1.7), Color(0.42, 0.3, 0.22), Color(0.6, 0.48, 0.3))
	# Regal an der Ostwand mit Gläsern, Ölkannen und Ersatzteilen
	var regal := Einrichtung.regal(w, Vector3(9.88, 0.5, 1.0), 1.7, 4, -90.0)
	for i in 3:
		Einrichtung.vorratsglas(regal, Vector3(-0.6 + i * 0.3, 0.02, 0.12), ["wal", "hasel", "mandel"][i], 0.5 + 0.2 * i, 0.18)
	var kanne_rot := Look.lackiert(Color(0.6, 0.16, 0.12), 0.4)
	var blech := Look.metall(Color(0.55, 0.56, 0.58), 0.4)
	for kp in [Vector3(0.35, 0.42, 0.12), Vector3(0.62, 0.42, 0.13), Vector3(-0.3, 0.82, 0.12)]:
		Bau.teil(regal, Bau.zylinder_mesh(0.055, 0.065, 0.13, 12), kanne_rot, kp + Vector3(0, 0.065, 0))
		Bau.teil(regal, Bau.zylinder_mesh(0.006, 0.018, 0.14, 6), blech, kp + Vector3(0.06, 0.17, 0), Vector3(0, 0, -40))
	Modelle.setze(regal, "rohstoffe/Parts_Cog.gltf", Vector3(0.3, 0.9, 0.12), 20.0, 0.45).rotation_degrees.x = 90.0
	Modelle.setze(regal, "rohstoffe/Parts_Cog.gltf", Vector3(0.55, 0.86, 0.1), 0.0, 0.3).rotation_degrees.x = 90.0
	Bau.teil(regal, Bau.box_mesh(Vector3(0.4, 0.2, 0.2)), Look.holz(Look.KIEFER, 8.0, 0.0), Vector3(-0.45, 1.31, 0.12))
	Bau.schrift(regal, "Schrauben\n(krumm)", Vector3(-0.45, 1.31, 0.222), 22)
	# Fotos an der Nordwand: 52 Jahre in vier Bildern
	var rahmen := Look.holz(Look.NUSSBAUM, 8.0, 0.3)
	var papier := Look.putz(Color(0.86, 0.78, 0.6), Color(0.78, 0.69, 0.5), 90.0, 0.0, 0.9)
	var braun := Bau.mat(Color(0.36, 0.22, 0.12), 0.9)
	var fotos := [["1974", 0.025], ["1983", 0.05], ["1997", 0.085], ["2019", 0.13]]
	for i in fotos.size():
		var fp := Vector3(3.75 + i * 0.56, 1.62 + (0.03 if i % 2 == 0 else -0.02), -2.89)
		var foto := Node3D.new()
		foto.position = fp
		foto.rotation_degrees.z = [-2.0, 1.5, -1.0, 2.5][i]
		w.add_child(foto)
		Bau.teil(foto, Bau.box_mesh(Vector3(0.44, 0.38, 0.02)), rahmen)
		Bau.teil(foto, Bau.box_mesh(Vector3(0.38, 0.32, 0.006)), papier, Vector3(0, 0, 0.01))
		var gr: float = fotos[i][1]
		Bau.teil(foto, Bau.box_mesh(Vector3(0.36, 0.004, 0.002)), braun, Vector3(0, -0.07, 0.014))
		Bau.teil(foto, Bau.kugel_mesh(1.0, true, 14), braun, Vector3(-0.02, -0.07, 0.013), Vector3.ZERO, Vector3(gr * 1.5, gr, 0.004))
		Bau.teil(foto, Bau.box_mesh(Vector3(0.012, 0.05, 0.002)), braun, Vector3(0.13, -0.045, 0.014))
		Bau.teil(foto, Bau.kugel_mesh(0.012, false, 8), braun, Vector3(0.13, -0.012, 0.014), Vector3.ZERO, Vector3(1, 1, 0.2))
		Bau.schrift(foto, str(fotos[i][0]), Vector3(0, -0.125, 0.0145), 24, Color(0.3, 0.2, 0.12))
	# Aufgeschlagener Bauplan auf der Werkbank
	var buch := Node3D.new()
	buch.name = "Bauplan"
	buch.position = Vector3(5.75, 0.905, 2.45)
	buch.rotation_degrees.y = 168
	w.add_child(buch)
	for s in [-1.0, 1.0]:
		Bau.teil(buch, Bau.box_mesh(Vector3(0.17, 0.014, 0.24)), Bau.mat(Color(0.92, 0.88, 0.76)), Vector3(s * 0.088, 0.008, 0), Vector3(0, 0, s * 5.0))
	Bau.teil(buch, Bau.box_mesh(Vector3(0.37, 0.006, 0.26)), Look.stoff(Color(0.3, 0.16, 0.1)), Vector3(0, 0.0, 0))
	Bau.teil(buch, Bau.zylinder_mesh(0.045, 0.045, 0.002, 14), Bau.mat(Color(0.25, 0.25, 0.3)), Vector3(0.09, 0.019, 0.0))
	Bau.teil(buch, Bau.zylinder_mesh(0.004, 0.004, 0.15, 6), Bau.mat(Color(0.85, 0.7, 0.2)), Vector3(-0.2, 0.01, 0.05), Vector3(90, 30, 0))
	Interaktiv.erzeuge(buch, Vector3(0.45, 0.2, 0.35), Vector3(0, 0.08, 0), "Opas Bauplan lesen",
		func(_s): _menue(menues.zeige_zettel.bind("Opas Bauplan", BAUPLAN_MOND)))
	# Werkzeug an der Lochwand
	var griff := Look.holz(Look.EICHE, 9.0, 0.2)
	Bau.teil(w, Bau.box_mesh(Vector3(0.42, 0.11, 0.008)), blech, Vector3(7.2, 1.95, 2.85), Vector3(0, 0, -8))
	Bau.teil(w, Bau.box_mesh(Vector3(0.12, 0.13, 0.025)), griff, Vector3(7.46, 1.94, 2.845), Vector3(0, 0, -8))
	Bau.teil(w, Bau.box_mesh(Vector3(0.03, 0.3, 0.03)), griff, Vector3(5.75, 1.92, 2.85))
	Bau.teil(w, Bau.box_mesh(Vector3(0.13, 0.05, 0.05)), Look.metall(Color(0.35, 0.35, 0.38), 0.4), Vector3(5.75, 2.08, 2.85))
	# Opas Maschine unter der Plane: nur ein Zahnrad schaut heraus
	var plane := Node3D.new()
	plane.name = "PlaneMaschine"
	plane.position = Vector3(8.95, 0, 2.05)
	w.add_child(plane)
	var tuch := Look.stoff(Color(0.42, 0.46, 0.36))
	Bau.teil(plane, Bau.kugel_mesh(1.0, true, 18), tuch, Vector3(0, 0, 0), Vector3.ZERO, Vector3(0.85, 1.25, 0.7))
	Bau.teil(plane, Bau.kugel_mesh(1.0, true, 14), tuch, Vector3(-0.35, 0, 0.15), Vector3.ZERO, Vector3(0.6, 0.85, 0.6))
	Bau.teil(plane, Bau.kugel_mesh(1.0, true, 14), tuch, Vector3(0.3, 0, -0.2), Vector3.ZERO, Vector3(0.55, 1.5, 0.5))
	var rad := Modelle.setze(plane, "rohstoffe/Parts_Cog.gltf", Vector3(-0.78, 0.55, 0.1), 80.0, 2.3)
	rad.rotation_degrees.z = 12.0
	Bau.holzschild(plane, "NICHT ANFASSEN!", Vector3(-0.2, 0.5, -0.72), Vector2(0.62, 0.16), Vector3(-8, 180, 3), 56)
	Ersatz._koll(plane, Vector3(1.9, 1.5, 1.5), Vector3(-0.1, 0.75, 0))
	Interaktiv.erzeuge(plane, Vector3(1.9, 1.5, 1.5), Vector3(-0.15, 0.8, -0.1), "Unter die Plane schauen",
		func(_s):
			Sfx.spiele("fehler", -8.0)
			Game.toast.emit("Die Plane ist festgezurrt. Darunter tickt etwas.", Game.FARBE_INFO))


# =============================================================================
# Behälter
# =============================================================================
func _behaelter_anlegen() -> void:
	glas = _neuer_behaelter("glas", GLAS_POS)
	bruchschale = _neuer_behaelter("bruch", BRUCH_POS)
	eimer = _neuer_behaelter("eimer", EIMER_POS)
	glas.setze_deckel(Game.hat_maschine("deckel"))
	var gespeichert: Dictionary = Game.behaelter
	for paar in [["glas", glas], ["eimer", eimer], ["bruch", bruchschale]]:
		if gespeichert.has(paar[0]):
			paar[1].aus_dict(gespeichert[paar[0]])
	glas.geaendert.connect(_glas_geaendert)
	# Die Rohrpost über dem Glas verkauft volle Gläser von selbst
	var messing := Look.metall(Color(0.85, 0.66, 0.32), 0.25)
	var oben := GLAS_POS + Vector3(0, 0.62, 0)
	Bau.teil(self, Bau.zylinder_mesh(0.07, 0.07, 3.0 - oben.y, 20), messing, Vector3(oben.x, (3.0 + oben.y) * 0.5, oben.z))
	var glocke := CylinderMesh.new()
	glocke.top_radius = 0.07
	glocke.bottom_radius = 0.16
	glocke.height = 0.14
	glocke.cap_bottom = false
	var gm := messing.duplicate() as StandardMaterial3D
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	Bau.teil(self, glocke, gm, oben + Vector3(0, -0.05, 0))


func _neuer_behaelter(typ: String, pos: Vector3, gross := false) -> Behaelter:
	var b := Behaelter.erzeuge(typ, gross)
	b.position = pos + Vector3(0, 0.005, 0)
	add_child(b)
	b.heim = b.global_transform
	return b


func behaelter_speichern() -> Dictionary:
	return {"glas": glas.als_dict(), "eimer": eimer.als_dict(), "bruch": bruchschale.als_dict()}


func _glas_geaendert() -> void:
	if glas.voll() and not _glas_war_voll:
		_glas_war_voll = true
	elif not glas.voll():
		_glas_war_voll = false


# =============================================================================
# Maschinen
# =============================================================================
func _maschine_aufstellen(id: String, neu := true) -> void:
	match id:
		"deckel":
			glas.setze_deckel(true)
		"rutsche":
			var r := Node3D.new()
			add_child(r)
			var blech := Look.metall(Color(0.72, 0.74, 0.77), 0.3)
			var gelb := Look.lackiert(Color(0.85, 0.62, 0.15), 0.5)
			var rinne := Node3D.new()
			rinne.position = Vector3(SCHALE_POS.x + 0.235, TISCH_Y + 0.035, SCHALE_POS.z + 0.02)
			rinne.rotation_degrees.z = -10
			r.add_child(rinne)
			Bau.teil(rinne, Bau.box_mesh(Vector3(0.13, 0.006, 0.07)), blech)
			for sz in [-0.035, 0.035]:
				Bau.teil(rinne, Bau.box_mesh(Vector3(0.13, 0.025, 0.005)), blech, Vector3(0, 0.012, sz))
			Bau.teil(r, Bau.box_mesh(Vector3(0.12, 0.09, 0.08)), gelb, ROHR_UNTEN + Vector3(0.0, 0.08, -0.06))
			Bau.teil(r, Bau.zylinder_mesh(0.03, 0.03, 0.02, 16), blech, ROHR_UNTEN + Vector3(0.065, 0.08, -0.06), Vector3(0, 0, 90))
			_maschinen[id] = r
		"mimi":
			var katze := Katze.new()
			katze.position = Vector3(-1.5, 0, 1.5)
			add_child(katze)
			_maschinen[id] = katze
			if neu:
				Sfx.spiele("miau")
		"sieb":
			var sb := Node3D.new()
			sb.position = station.global_position + Vector3(0.33, 0.0, 0.1)
			add_child(sb)
			var stahl := Look.metall(Color(0.72, 0.74, 0.77), 0.3)
			Bau.teil(sb, Bau.box_mesh(Vector3(0.13, 0.008, 0.13)), stahl, Vector3(0, 0.004, 0))
			for i in 6:
				Bau.teil(sb, Bau.box_mesh(Vector3(0.004, 0.012, 0.13)), Look.metall(Color(0.35, 0.35, 0.37)), Vector3(-0.055 + i * 0.022, 0.01, 0))
			_maschinen[id] = sb
		"walze":
			var wz := Node3D.new()
			wz.position = Vector3(6.4, 0, -2.4)
			add_child(wz)
			var blau := Look.lackiert(Color(0.25, 0.4, 0.58), 0.6)
			var stahl := Look.metall(Color(0.7, 0.72, 0.75), 0.3)
			Bau.block(wz, Vector3(1.0, 0.8, 0.7), Vector3(0, 0.4, 0), blau)
			Bau.teil(wz, Bau.zylinder_mesh(0.35, 0.12, 0.4, 4), stahl, Vector3(0, 1.0, 0), Vector3(0, 45, 0))
			_walzen_rollen.clear()
			for x in [-0.12, 0.12]:
				_walzen_rollen.append(Bau.teil(wz, Bau.zylinder_mesh(0.1, 0.1, 0.6, 16), stahl, Vector3(x, 0.85, 0.0), Vector3(0, 0, 90)))
			# Rohr vom Silo durch die Wand
			Einrichtung.rohr(wz, Vector3(6.4, 1.3, -2.4), Vector3(6.4, 2.8, -2.4), 0.07, stahl)
			_walzen_status = Bau.schild(wz, "", Vector3(0, 1.55, 0.4), 40, Color(1, 0.95, 0.8), true)
			_walzen_status.font = Look.schrift(500)
			_maschinen[id] = wz
		"lagerhalle":
			var lh := Node3D.new()
			add_child(lh)
			Bau.block(lh, Vector3(2.2, 2.4, 1.8), SILO_POS + Vector3(-2.3, 1.2, 0.0), Look.holz(Look.ALTHOLZ, 9.0, 0.1))
			Bau.teil(lh, Bau.box_mesh(Vector3(2.4, 0.12, 2.0)), Look.putz(Color(0.62, 0.24, 0.16), Color(0.5, 0.18, 0.12), 30.0, 0.35, 0.8), SILO_POS + Vector3(-2.3, 2.46, 0.0))
			Bau.holzschild(lh, "LAGERHALLE", SILO_POS + Vector3(-2.3, 2.2, -0.92), Vector2(1.2, 0.22), Vector3(0, 180, 0), 80)
			_maschinen[id] = lh


func _process(delta: float) -> void:
	if _hebel_sperre > 0.0:
		_hebel_sperre -= delta
	_rutsche(delta)
	_walze(delta)
	_glas_auto()
	_abgaben_pruefen()
	_baender_bewegen(delta)
	_eichhoernchen_steuern(delta)
	_pinn_timer -= delta
	if _pinn_timer <= 0.0:
		_pinn_timer = 1.0
		_pinnwand_zeichnen()
		_uhr_stellen()
		_ziele_pruefen()
	_aufraeumen()


## Ziele, deren Bedingung schon erfüllt ist, gelten als geschafft (Reihenfolge egal).
func _ziele_pruefen() -> void:
	var z := Game.ziel_aktuell()
	if z.is_empty():
		return
	match z.id:
		"berg":
			if spieler.global_position.z < -6.0:
				Game.ziel_melden("berg")
		"voll":
			if Game.beutel_frei() == 0:
				Game.ziel_melden("voll")
		"loeffel":
			if Game.sammler.has("loeffel"):
				Game.ziel_melden("loeffel")
		"beutel":
			if Game.beutel_id != "taschen":
				Game.ziel_melden("beutel")
		"skill":
			if not Game.skills.is_empty():
				Game.ziel_melden("skill")


func _uhr_stellen() -> void:
	if _uhr_zeiger.is_empty():
		return
	var t := Time.get_time_dict_from_system()
	_uhr_zeiger[0].rotation.z = -TAU * float(t.minute) / 60.0
	_uhr_zeiger[1].rotation.z = -TAU * (float(t.hour % 12) + float(t.minute) / 60.0) / 12.0


func _rutsche(delta: float) -> void:
	if not Game.hat_maschine("rutsche"):
		return
	_rutsche_timer -= delta
	if _rutsche_timer > 0.0:
		return
	var stufe: int = max(0, Game.maschinen_stufe("rutsche"))
	_rutsche_timer = 2.0 / ((1.0 + 0.25 * stufe) * Game.rutschen_tempo())
	if _nuesse_in_schale() < 4 and _hebel_sperre <= 0.0 and Game.lager_menge() > 0:
		hebel_ziehen(true)
	elif station.kann_laden() and not station.drueckt and not spieler.sitzt:
		nuss_nachlegen(station)


## Ein volles Glas (oder eine volle Bruchschale) saust durch die Rohrpost und wird verkauft.
func _glas_auto() -> void:
	if not bruchschale.gehalten and bruchschale.voll() and not bruchschale.freeze:
		_verkaufe(bruchschale, false)
	if not eimer.gehalten and eimer.voll():
		Game.verdiene(eimer.schalen * 0.2, false)
		Game.toast.emit("Schaleneimer auf den Kompost gekippt (+%s)" % Data.zahl(eimer.schalen * 0.2), Game.FARBE_INFO)
		eimer.leeren()
	if _rohrpost_laeuft:
		return
	if not glas.voll() or glas.gehalten or glas.freeze or _unterwegs.get(glas, 0) > 0:
		return
	if glas.global_position.distance_to(glas.heim.origin) > 0.15:
		return
	_rohrpost_laeuft = true
	glas.freeze = true
	Sfx.spiele("rohrpost")
	var oben := GLAS_POS + Vector3(0, 0.62, 0)
	var tw := create_tween()
	tw.tween_property(glas, "global_position", oben, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(glas, "scale", Vector3(0.5, 1.3, 0.5), 0.35)
	tw.tween_callback(func():
		glas.visible = false
		_verkaufe(glas, false)
		glas.scale = Vector3.ONE)
	tw.tween_interval(0.6)
	tw.tween_callback(func():
		glas.visible = true
		glas.global_position = oben)
	tw.tween_property(glas, "global_position", glas.heim.origin, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		glas.freeze = false
		_rohrpost_laeuft = false)


## Der Walzenknacker knackt Nüsse aus dem Lager von selbst und verkauft die Kerne.
func _walze(delta: float) -> void:
	if not Game.hat_maschine("walze"):
		return
	var status := ""
	var laeuft := false
	if Game.lager_menge() <= 0:
		status = "Lager leer – Nüsse sammeln!"
	else:
		laeuft = true
		_walze_acc += delta * Game.walzen_tempo()
		var n := int(_walze_acc)
		if n > 0:
			_walze_acc -= n
			var summe := 0.0
			for nuss in Game.lager_nehmen(n):
				var info: Dictionary = Data.NUESSE[nuss]
				if float(info.haerte) > Data.WALZE_KRAFT + max(0, Game.maschinen_stufe("walze")):
					Game.melde_knack(nuss, "matsch", false)
					continue
				var r := Game.rng.randf()
				var p := Game.walzen_praezision()
				if r < p:
					summe += float(info.wert) * 2.0 * Game.preis_faktor()
					Game.melde_knack(nuss, "perfekt", false, 2)
				elif r < p + (1.0 - p) * 0.7:
					summe += float(info.wert) * 0.6 * Game.preis_faktor()
					Game.melde_knack(nuss, "bruch", false)
				else:
					Game.melde_knack(nuss, "matsch", false)
			if summe > 0.0:
				Game.verdiene(summe)
		status = "Läuft · %.1f Nüsse/s · Präzision %d %%" % [Game.walzen_tempo(), int(Game.walzen_praezision() * 100)]
	if laeuft:
		for r in _walzen_rollen:
			r.rotate_y(delta * 12.0)
	if _walzen_status:
		_walzen_status.text = "WALZENKNACKER\n%s\nLager: %s" % [status, Data.zahl(Game.lager_menge())]



# =============================================================================
# Nüsse holen, nachlegen, sortieren
# =============================================================================
func _hebel_ziehen(_s) -> void:
	hebel_ziehen()


func hebel_ziehen(leise := false) -> bool:
	if _hebel_sperre > 0.0:
		return false
	_hebel_sperre = 0.8
	if Game.lager_menge() <= 0:
		if not leise:
			Game.toast.emit("Das Lager ist leer! Sammel Nüsse am Berg und bring sie zum Trichter.", Game.FARBE_WARN)
			Sfx.spiele("fehler")
		return false
	var frei := 24 - _nuesse_in_schale()
	if frei <= 0:
		if not leise:
			Game.toast.emit("Die Nussschale ist voll", Game.FARBE_WARN)
			Sfx.spiele("fehler")
		return false
	Sfx.spiele("hebel", -4.0 if not leise else -12.0)
	if _hebel_arm:
		var tw := create_tween()
		tw.tween_property(_hebel_arm, "rotation_degrees:x", -40.0, 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_hebel_arm, "rotation_degrees:x", 35.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_nuesse_holen(min(8, frei), not leise)
	return true


func _nuesse_in_schale() -> int:
	var n := 0
	for b in _schale_bereich.get_overlapping_bodies():
		if b is Item and b.art == "nuss":
			n += 1
	return n


func _neue_nuss_daten(nuss: String) -> Dictionary:
	var d := {"art": "nuss", "nuss": nuss}
	var r := Game.rng.randf()
	var g := Game.gold_chance()
	var f := Game.faul_chance()
	if r < g:
		d.gold = true
	elif r < g + f:
		d.faul = true
	elif r < g + f + Data.CHANCE_WURM:
		d.wurm = true
	elif r < g + f + Data.CHANCE_WURM + Game.doppel_chance():
		d.doppel = true
	return d


func _nuesse_holen(anzahl: int, mit_ton: bool) -> void:
	var sorten := Game.lager_nehmen(anzahl)
	var richtung := (ROHR_UNTEN - ROHR_OBEN).normalized()
	for i in sorten.size():
		var daten := _neue_nuss_daten(sorten[i])
		get_tree().create_timer(0.09 * i).timeout.connect(func():
			var pos := ROHR_UNTEN + richtung * 0.05 + Vector3(randf_range(-0.01, 0.01), 0, 0)
			item_spawnen(daten, pos, richtung * 1.1 + Vector3(randf_range(-0.12, 0.12), 0, randf_range(0.05, 0.2)))
			Sfx.spiele("rollen", -12.0, randf_range(0.9, 1.2)))
	if mit_ton and sorten.size() > 0:
		Sfx.spiele("rutsch", -6.0)


func nuss_nachlegen(st: Knackstation) -> bool:
	if _nachlegen_laeuft or not st.kann_laden():
		return false
	var beste: Item = null
	var abstand := 99.0
	for b in _schale_bereich.get_overlapping_bodies():
		if b is Item and b.art == "nuss" and not b.gehalten and not b.fliegt:
			var a: float = b.global_position.distance_to(st.global_position)
			if a < abstand:
				abstand = a
				beste = b
	if beste == null:
		return false
	_nachlegen_laeuft = true
	beste.fliegt = true
	beste.freeze = true
	beste.collision_layer = 0
	var start := beste.global_position
	var ziel := st.sitz_global() + Vector3(0, 0.02, 0)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(beste):
			beste.global_position = start.lerp(ziel, t) + Vector3(0, sin(t * PI) * 0.12, 0)
			beste.rotation.y += 0.2, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_nachlegen_laeuft = false
		if is_instance_valid(beste):
			if st.lade(beste.daten()):
				beste.queue_free()
			else:
				beste.fliegt = false
				beste.freeze = false
				beste.collision_layer = Data.L_ITEM)
	return true


func item_spawnen(daten: Dictionary, pos: Vector3, geschw: Vector3) -> Item:
	var it := Item.erzeuge(daten)
	it.position = pos
	it.add_to_group("items")
	add_child(it)
	it.linear_velocity = geschw
	it.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	return it


func glas_position() -> Vector3:
	return glas.global_position


func _ziel_frei(b: Behaelter) -> bool:
	if b.gehalten or b.freeze or not b.visible:
		return false
	if b.global_position.distance_to(b.heim.origin) > 0.4:
		return false
	return b.frei() - int(_unterwegs.get(b, 0)) > 0


## Nach einem Knack: Kerne fliegen ins Glas, Bruch in die Schale, Schalen bleiben liegen (oder Sieb).
func nach_knack(teile: Array) -> void:
	var nr := 0
	for t in teile:
		if not is_instance_valid(t):
			continue
		match t.art:
			"haelfte":
				if _ziel_frei(glas):
					_flieg_in(t, glas, 0.12 + nr * 0.1)
					nr += 1
			"bruch":
				if _ziel_frei(bruchschale):
					_flieg_in(t, bruchschale, 0.15 + nr * 0.06)
					nr += 1
			"schale":
				if Game.hat_maschine("sieb") and _ziel_frei(eimer):
					_flieg_in(t, eimer, 0.6 + nr * 0.05)
					nr += 1
			"wurm":
				if Game.hat_maschine("sieb"):
					get_tree().create_timer(0.8).timeout.connect(func():
						if is_instance_valid(t):
							Game.verdiene(2.0, false)
							t.queue_free())


func _flieg_in(t: Item, ziel: Behaelter, verzoegerung := 0.0) -> void:
	t.fliegt = true
	_unterwegs[ziel] = int(_unterwegs.get(ziel, 0)) + 1
	var tw := create_tween()
	if verzoegerung > 0.0:
		tw.tween_interval(verzoegerung)
	var zust := {"start": t.global_position}
	tw.tween_callback(func():
		if is_instance_valid(t):
			t.freeze = true
			t.collision_layer = 0
			zust.start = t.global_position)
	var dauer := 0.42
	tw.tween_method(func(f: float):
		if not is_instance_valid(t) or not is_instance_valid(ziel):
			return
		var start: Vector3 = zust.start
		var ende := ziel.naechster_platz_global() + Vector3(0, 0.04, 0)
		var hoch: float = max(start.y, ende.y) + 0.22
		var mitte := Vector3((start.x + ende.x) * 0.5, hoch, (start.z + ende.z) * 0.5)
		var a := start.lerp(mitte, f)
		var b := mitte.lerp(ende, f)
		t.global_position = a.lerp(b, f)
		t.rotation += Vector3(0.25, 0.4, 0.1), 0.0, 1.0, dauer)
	tw.tween_callback(func():
		_unterwegs[ziel] = max(0, int(_unterwegs.get(ziel, 0)) - 1)
		if not is_instance_valid(t):
			return
		if is_instance_valid(ziel) and ziel.nimmt_auf(t.daten()):
			var ton := "plopp" if t.art == "haelfte" else "einwurf"
			Sfx.spiele(ton, -6.0, 0.9 + float(ziel.belegt()) / float(ziel.kapazitaet) * 0.6, 0.05)
			ziel.stoss()
			t.queue_free()
		else:
			t.fliegt = false
			t.freeze = false
			t.collision_layer = Data.L_ITEM)


## Wischt Schalen (und Bruch, Würmer) um einen Punkt in Eimer bzw. Bruchschale.
func wischen(punkt: Vector3) -> int:
	var anzahl := 0
	for t in get_tree().get_nodes_in_group("items"):
		if not is_instance_valid(t) or t.gehalten or t.fliegt:
			continue
		if Vector2(t.global_position.x - punkt.x, t.global_position.z - punkt.z).length() > 0.75:
			continue
		if absf(t.global_position.y - punkt.y) > 0.4:
			continue
		match t.art:
			"schale":
				if _ziel_frei(eimer) and eimer.global_position.distance_to(punkt) < 3.5:
					_flieg_in(t, eimer, anzahl * 0.025)
				else:
					t.linear_velocity = Vector3(1.5, 1, 0.8)
				anzahl += 1
			"bruch":
				if _ziel_frei(bruchschale):
					_flieg_in(t, bruchschale, anzahl * 0.025)
					anzahl += 1
			"wurm":
				Game.verdiene(2.0, false)
				Effekte.funken(self, t.global_position, Color(0.6, 1.0, 0.5), 6, 0.3)
				t.queue_free()
				anzahl += 1
	if anzahl > 0:
		Sfx.spiele("wischen", -4.0)
		Game.ziel_melden("wischen")
	return anzahl


func stinkwolke(pos: Vector3) -> void:
	Effekte.staub(self, pos, Color(0.55, 0.75, 0.25, 0.55), 24, 0.09)


## Saft und Wumms nach jedem Knack: Partikel, Kamerawackeln, Hitstop.
func _knack_effekt(ergebnis: String, pos: Vector3) -> void:
	var nuss: String = station.letzte_nuss
	var nah := spieler.sitzt
	match ergebnis:
		"perfekt":
			Effekte.kruemel(self, pos, nuss, 16)
			Effekte.staub(self, pos, Color(0.85, 0.72, 0.55, 0.35), 8)
			Effekte.funken(self, pos + Vector3(0, 0.03, 0), Color(1.0, 0.9, 0.55), 12, 0.6)
			Game.hitstop(0.055)
			spieler.wackeln(0.32 if nah else 0.15)
			spieler.fov_stoss(-2.5)
		"gold":
			Effekte.kruemel(self, pos, nuss, 20)
			Effekte.funken(self, pos + Vector3(0, 0.03, 0), Color(1.0, 0.8, 0.3), 40, 1.2)
			Game.hitstop(0.14, 0.03)
			spieler.wackeln(0.5)
			spieler.fov_stoss(-5.0)
			Sfx.spiele("gold")
		"bruch":
			Effekte.kruemel(self, pos, nuss, 28, 1.3)
			Effekte.staub(self, pos, Color(0.85, 0.72, 0.55, 0.5), 12)
			Game.hitstop(0.04)
			spieler.wackeln(0.42 if nah else 0.2)
		"matsch":
			Effekte.kruemel(self, pos, nuss, 34, 1.5)
			Effekte.staub(self, pos, Color(0.6, 0.45, 0.3, 0.6), 16, 0.07)
			Game.hitstop(0.05)
			spieler.wackeln(0.55 if nah else 0.25)
		"faul":
			spieler.wackeln(0.2)
		"riss":
			Effekte.kruemel(self, pos, nuss, 5, 0.6)
			spieler.wackeln(0.12)


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
	if not (body is Behaelter) or body.freeze:
		return
	var b: Behaelter = body
	if b.belegt() == 0:
		Game.toast.emit("%s ist leer" % b.anzeige_name(), Game.FARBE_WARN)
		_zurueck(b)
		return
	_verkaufe(b, true)


## [E] an der Klappe mit einem Behälter in der Hand: hineinschieben und verkaufen.
func _klappe_benutzen(s) -> void:
	if s == null or not (s.gehalten is Behaelter):
		Game.toast.emit("Bring ein Glas, die Bruchschale oder den Eimer hierher.", Game.FARBE_INFO)
		return
	var b: Behaelter = s.gehalten
	if b.belegt() == 0:
		Game.toast.emit("%s ist leer" % b.anzeige_name(), Game.FARBE_WARN)
		Sfx.spiele("fehler")
		return
	s._loslassen(Vector3.ZERO)
	b.freeze = true
	var tw := create_tween()
	tw.tween_property(b, "global_position", Vector3(-2.95, 0.83, -1.2), 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _verkaufe(b, true))


func _verkaufe(b: Behaelter, zurueck: bool) -> void:
	var betrag := b.verkaufswert()
	betrag = Game.verdiene(betrag)
	Sfx.spiele("verkauf")
	Sfx.spiele("glocke", -6.0)
	var pos := b.global_position + Vector3(0, 0.3, 0)
	if b.typ == "glas" and zurueck:
		pos = Vector3(-2.9, 1.1, -1.2)
	Game.verkauft.emit(betrag, pos)
	Effekte.muenzen(self, pos, clampi(int(betrag / 10.0), 6, 30))
	Effekte.funken(self, pos, Color(1.0, 0.85, 0.35), 20, 1.0)
	if b == glas:
		Game.ziel_melden("verkaufen")
	if _klappe and zurueck:
		var tw := create_tween()
		tw.tween_property(_klappe, "rotation_degrees:z", 70.0, 0.15)
		tw.tween_interval(0.35)
		tw.tween_property(_klappe, "rotation_degrees:z", 0.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	b.leeren()
	if zurueck:
		_zurueck(b)


func _zurueck(b: Behaelter) -> void:
	if spieler.gehalten == b:
		spieler._loslassen(Vector3.ZERO)
	b.heimkehren()



func _kompost(body: Node) -> void:
	if body is Item and not body.gehalten and not body.fliegt:
		body.queue_free()


func _pinnwand_zeichnen() -> void:
	for i in _pinn_zettel.size():
		var z: Node3D = _pinn_zettel[i][0]
		var l: Label3D = _pinn_zettel[i][1]
		if i < Game.bestellungen.size():
			var b: Dictionary = Game.bestellungen[i]
			z.visible = true
			l.text = "%s\n\n%d/%d %s-Hälften\n\n%s Münzen\nnoch %d:%02d" % [b.kunde, b.stand, b.menge, Data.NUESSE[b.nuss].name, Data.zahl(b.lohn), int(b.zeit) / 60, int(b.zeit) % 60]
		else:
			z.visible = false


# =============================================================================
# Eichhörnchen
# =============================================================================
func ruhe_vor_eichhoernchen(sekunden: float) -> void:
	_ruhe = sekunden
	for e in get_tree().get_nodes_in_group("eichhoernchen"):
		e.verscheuchen()
	Game.toast.emit("Der König ist bestochen: %d Minuten Ruhe" % int(sekunden / 60), Game.FARBE_GOLD)


func eichhoernchen_am_tisch() -> bool:
	for e in get_tree().get_nodes_in_group("eichhoernchen"):
		if e.zustand != "flucht" and e.global_position.distance_to(glas.global_position) < 1.2:
			return true
	return false


func eichhoernchen_verjagen() -> void:
	for e in get_tree().get_nodes_in_group("eichhoernchen"):
		if e.zustand != "flucht" and e.global_position.distance_to(glas.global_position) < 1.2:
			e.verscheuchen()


func _eichhoernchen_steuern(delta: float) -> void:
	if Game.hat_talent("koenigsbund"):
		hud.zeige_warnung("")
		return
	if _ruhe > 0.0:
		_ruhe -= delta
		hud.zeige_warnung("")
		return
	var vorrat := glas.haelften
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
		if glas.gehalten or glas.haelften <= 0:
			return
		var x := randf_range(0.35, 1.15)
		var e := Eichhoernchen.new()
		e.weg = [Vector3(x, 0.0, -5.5), Vector3(x, FENSTER_Y.x + 0.02, -3.25), Vector3(x, FENSTER_Y.x + 0.02, -2.92), Vector3(x, TISCH_Y, -2.72), glas.global_position]
		e.ziel_behaelter = glas
		e.add_to_group("eichhoernchen")
		add_child(e)


# =============================================================================
# Ären
# =============================================================================
func _aera_erreicht(aera: int, schicht: String) -> void:
	match aera:
		2:
			if _werkstatt_tuer:
				var tuer := _werkstatt_tuer
				_werkstatt_tuer = null
				var tw := create_tween()
				tw.tween_property(tuer, "position:y", -2.6, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tw.tween_callback(tuer.queue_free)
			Game.toast.emit("Neue Bergschicht: %s! Die Werkstatt ist offen, neue Nüsse und Maschinen im Katalog." % schicht, Game.FARBE_GOLD)
		3:
			Game.toast.emit("Neue Bergschicht: %s! Paranüsse und Macadamia tauchen auf." % schicht, Game.FARBE_GOLD)
		_:
			Game.toast.emit("Neue Bergschicht: %s!" % schicht, Game.FARBE_GOLD)
	hud.zeige_banner("Ära %d" % aera, schicht)


# =============================================================================
# Abliefern, Helfer, Außenposten
# =============================================================================
func _silo_aktualisieren() -> void:
	if _silo_fuell:
		var anteil := clampf(float(Game.lager_menge()) / float(max(1, Game.lager_kapazitaet())), 0.0, 1.0)
		_silo_fuell.scale = Vector3(1, max(0.01, anteil), 1)
	if _silo_text:
		_silo_text.text = "Lager %s / %s" % [Data.zahl(Game.lager_menge()), Data.zahl(Game.lager_kapazitaet())]


func _abgaben_pruefen() -> void:
	if _abliefern_laeuft or Game.beutel_menge() <= 0 or spieler == null:
		return
	var p := spieler.global_position
	for a in _abgaben:
		var ap: Vector3 = a.pos
		if Vector2(p.x - ap.x, p.z - ap.z).length() < ABGABE_RADIUS + 0.25 and absf(p.y - ap.y) < 2.0:
			_abliefern(a)
			return


## Der Beutel wird in den Trichter gekippt: Nüsse fliegen sichtbar hinein, dann gibt es Geld.
func _abliefern(a: Dictionary) -> void:
	_abliefern_laeuft = true
	var menge := Game.beutel_menge()
	var arten: Array = Game.beutel.keys()
	var sichtbar: int = min(menge, 28)
	var ziel_pos: Vector3 = a.ziel
	for i in sichtbar:
		get_tree().create_timer(0.025 * i).timeout.connect(func():
			flug.starte(spieler.geraet.beutel_mund(), arten[i % arten.size()], func(): return ziel_pos, 0.45, 0.9))
	Sfx.spiele("rutsch", -2.0)
	get_tree().create_timer(0.55).timeout.connect(func():
		Game.abliefern(ziel_pos)
		if a.has("id"):
			_band_aktiv[a.id] = 6.0
		Sfx.spiele("kasse", -6.0)
		_abliefern_laeuft = false)


func naechste_abgabe(von: Vector3) -> Vector3:
	var best: Vector3 = _abgaben[0].pos
	for a in _abgaben:
		if von.distance_to(a.pos) < von.distance_to(best):
			best = a.pos
	return best


func helfer_abliefern(sorten: Dictionary, pos: Vector3) -> void:
	Game.einlagern(sorten, pos)
	for a in _abgaben:
		if a.has("id") and pos.distance_to(a.pos) < 3.0:
			_band_aktiv[a.id] = 6.0


func _helfer_aufstellen() -> void:
	var sichtbar: int = min(Game.helfer, Data.HELFER_MAX_SICHTBAR)
	while _helfer_knoten.size() < sichtbar:
		var h := SammelHelfer.new()
		h.welt = self
		add_child(h)
		var start: Vector3 = _abgaben[_helfer_knoten.size() % _abgaben.size()].pos
		h.global_position = start + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		_helfer_knoten.append(h)
	for i in _helfer_knoten.size():
		_helfer_knoten[i].vielfach = Game.helfer / max(1, sichtbar) + (1 if i < Game.helfer % max(1, sichtbar) else 0)


func _posten_bauen(id: String) -> void:
	var d: Dictionary = Data.posten(id)
	if d.is_empty():
		return
	var n := Node3D.new()
	n.name = id
	add_child(n)
	var pos: Vector3 = d.pos
	var holz := Look.holz(Look.ALTHOLZ, 9.0, 0.1)
	var dunkel := Look.holz(Look.NUSSBAUM, 6.0, 0.2)
	# Kleines Silo mit Trichter
	Bau.block(n, Vector3(1.2, 1.3, 1.2), pos + Vector3(0, 0.65, 1.6), holz)
	var trichter := CylinderMesh.new()
	trichter.top_radius = 0.8
	trichter.bottom_radius = 0.3
	trichter.height = 0.5
	trichter.cap_top = false
	trichter.radial_segments = 4
	var tm := Look.metall(Color(0.62, 0.65, 0.68), 0.45).duplicate() as StandardMaterial3D
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	Bau.teil(n, trichter, tm, pos + Vector3(0, 1.55, 1.6), Vector3(0, 45, 0))
	# Fahne
	Bau.teil(n, Bau.zylinder_mesh(0.03, 0.03, 3.2, 8), dunkel, pos + Vector3(0.7, 1.6, 2.1))
	Bau.teil(n, Bau.box_mesh(Vector3(0.7, 0.45, 0.02)), Look.stoff(Color(0.9, 0.7, 0.2)), pos + Vector3(1.05, 2.9, 2.1))
	Bau.holzschild(n, d.name.to_upper(), pos + Vector3(0, 1.0, 0.98), Vector2(1.1, 0.2), Vector3.ZERO, 60)
	# Abgabekreis
	var ring := TorusMesh.new()
	ring.inner_radius = ABGABE_RADIUS - 0.08
	ring.outer_radius = ABGABE_RADIUS
	ring.rings = 48
	Bau.teil(n, ring, Look.leuchten(Color(1.0, 0.8, 0.25), 1.5), pos + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.15, 1)).set_meta("ohne_rand", true)
	_abgaben.append({"pos": pos, "name": d.name, "ziel": pos + Vector3(0, 1.7, 1.6), "id": id})
	# Hochförderband zur Hütte
	var punkte: Array = [pos + Vector3(0, 0, 1.6)]
	punkte.append_array(d.weg)
	punkte.append(SILO_POS + Vector3(0, 0, -0.2))
	var band_mat := Look.plastik(Color(0.15, 0.15, 0.16), 0.7)
	var y := 2.6
	for i in punkte.size() - 1:
		var a: Vector3 = punkte[i] + Vector3(0, y, 0)
		var b: Vector3 = punkte[i + 1] + Vector3(0, y, 0)
		var mitte := (a + b) * 0.5
		var laenge := a.distance_to(b)
		var seg := Bau.teil(n, Bau.box_mesh(Vector3(0.5, 0.08, laenge)), band_mat, mitte)
		seg.look_at_from_position(mitte, b, Vector3.UP)
		var rahmen := Bau.teil(n, Bau.box_mesh(Vector3(0.6, 0.12, laenge)), Look.metall(Color(0.85, 0.62, 0.18), 0.4), mitte - Vector3(0, 0.08, 0))
		rahmen.look_at_from_position(mitte - Vector3(0, 0.08, 0), b - Vector3(0, 0.08, 0), Vector3.UP)
		var stuetzen := int(laenge / 3.5) + 1
		for j in stuetzen + 1:
			var sp := a.lerp(b, float(j) / float(stuetzen))
			Bau.teil(n, Bau.zylinder_mesh(0.05, 0.06, y, 8), Look.metall(Color(0.4, 0.4, 0.42), 0.5), Vector3(sp.x, y * 0.5, sp.z))
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Nussmodelle.ganz("wal", 0, 0)
	mmi.multimesh = mm
	mmi.material_override = Look.nuss("wal")
	n.add_child(mmi)
	var linie := PackedVector3Array()
	for pkt in punkte:
		linie.append(pkt + Vector3(0, y + 0.1, 0))
	_band_nuesse[id] = [mmi, linie, 0.0]
	if Game.helfer > 0:
		_helfer_aufstellen()


func _baender_bewegen(delta: float) -> void:
	for id in _band_nuesse:
		var eintrag: Array = _band_nuesse[id]
		var mm: MultiMesh = eintrag[0].multimesh
		var aktiv: float = _band_aktiv.get(id, 0.0)
		if aktiv <= 0.0:
			mm.instance_count = 0
			continue
		_band_aktiv[id] = aktiv - delta
		eintrag[2] = fmod(float(eintrag[2]) + delta * 2.2, 0.8)
		var linie: PackedVector3Array = eintrag[1]
		var gesamt := 0.0
		for i in linie.size() - 1:
			gesamt += linie[i].distance_to(linie[i + 1])
		var anzahl := int(gesamt / 0.8)
		mm.instance_count = anzahl
		for k in anzahl:
			var s: float = k * 0.8 + float(eintrag[2])
			var i := 0
			while i < linie.size() - 2 and s > linie[i].distance_to(linie[i + 1]):
				s -= linie[i].distance_to(linie[i + 1])
				i += 1
			var a := linie[i]
			var b := linie[i + 1]
			var p := a.lerp(b, clampf(s / max(0.01, a.distance_to(b)), 0.0, 1.0))
			mm.set_instance_transform(k, Transform3D(Basis.from_euler(Vector3(k, k * 2.0, 0)).scaled(Vector3.ONE * 2.0), p))
