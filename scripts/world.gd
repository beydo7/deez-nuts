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
var _berg_text: Label3D
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
var _sonne: DirectionalLight3D

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
	Game.berg_leer.connect(func(): _menue(menues.zeige_ende))
	station.geknackt.connect(_knack_effekt)
	for id in Game.maschinen:
		_maschine_aufstellen(id, false)
	_berg_aktualisieren()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	elif event.is_action_pressed("hebel") and not spieler.sitzt:
		hebel_ziehen()
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
	_sonne = DirectionalLight3D.new()
	_sonne.rotation_degrees = Vector3(-30, 160, 0)
	_sonne.light_color = Color(1.0, 0.86, 0.68)
	_sonne.light_energy = 2.4
	_sonne.shadow_enabled = true
	_sonne.shadow_blur = 1.5
	_sonne.directional_shadow_max_distance = 45.0
	_sonne.light_volumetric_fog_energy = 2.5
	add_child(_sonne)


# =============================================================================
# Hof und Nussberg
# =============================================================================
func _hof_und_berg() -> void:
	var hof := Node3D.new()
	hof.name = "Hof"
	add_child(hof)
	# Boden
	var boden := PlaneMesh.new()
	boden.size = Vector2(220, 220)
	Bau.teil(hof, boden, Look.gras(), Vector3(0, -0.025, -20))
	var bk := StaticBody3D.new()
	bk.collision_layer = Data.L_WELT
	var bcs := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = Vector3(220, 0.2, 220)
	bcs.shape = bb
	bcs.position = Vector3(0, -0.125, -20)
	bk.add_child(bcs)
	hof.add_child(bk)
	_grashalme(hof)
	# Bäume, Zaun, Hügel
	var farben := [[Color(0.86, 0.48, 0.12), Color(0.6, 0.3, 0.08)], [Color(0.92, 0.7, 0.2), Color(0.6, 0.45, 0.12)],
		[Color(0.7, 0.22, 0.1), Color(0.45, 0.15, 0.08)], [Color(0.5, 0.58, 0.2), Color(0.3, 0.4, 0.12)]]
	var baum_pos := [Vector3(-11, 0, -12), Vector3(-15, 0, -22), Vector3(12, 0, -11), Vector3(16, 0, -23), Vector3(-6, 0, -31),
		Vector3(9, 0, -33), Vector3(-19, 0, -6), Vector3(19, 0, -5), Vector3(-3, 0, -38), Vector3(24, 0, -16), Vector3(-25, 0, -15)]
	for i in baum_pos.size():
		var f: Array = farben[i % farben.size()]
		Einrichtung.baum(hof, baum_pos[i], _rng.randf_range(5.0, 8.0), f[0], f[1], _rng)
	for i in 22:
		Einrichtung.tanne(hof, Vector3(-55 + i * 5.2 + _rng.randf_range(-1, 1), 0, -58 + _rng.randf_range(-4, 4)), _rng.randf_range(7, 12))
	var huegel := Look.gras()
	for h in [[Vector3(-40, -8, -75), Vector3(40, 18, 20)], [Vector3(25, -10, -85), Vector3(55, 22, 25)], [Vector3(70, -6, -50), Vector3(30, 14, 30)]]:
		Bau.teil(hof, Bau.kugel_mesh(1.0, false, 24), huegel, h[0], Vector3.ZERO, h[1])
	var zaunholz := Look.holz(Look.ALTHOLZ, 10.0, 0.0)
	for i in 36:
		var x := -18.0 + i
		Bau.teil(hof, Bau.box_mesh(Vector3(0.09, 1.0, 0.05)), zaunholz, Vector3(x, 0.5, -30), Vector3(0, 0, _rng.randf_range(-3, 3)))
	for y in [0.35, 0.8]:
		Bau.teil(hof, Bau.box_mesh(Vector3(36, 0.08, 0.04)), zaunholz, Vector3(0, y, -29.96))
	# Der Nussberg
	_berg = Node3D.new()
	_berg.position = Vector3(0.8, 0, -17)
	hof.add_child(_berg)
	var huegelmesh := Bau.kugel_mesh(1.0, true, 48)
	Bau.teil(_berg, huegelmesh, Look.nusshaufen(0.2), Vector3.ZERO, Vector3.ZERO, Vector3(6.95, 4.95, 6.95)).layers = 2
	# Eigenes, schattenloses Licht von vorn, damit der Berg nicht im Gegenlicht versinkt
	var berglicht := DirectionalLight3D.new()
	berglicht.rotation_degrees = Vector3(-35, 20, 0)
	berglicht.light_color = Color(1.0, 0.9, 0.75)
	berglicht.light_energy = 1.0
	berglicht.light_cull_mask = 2
	berglicht.light_volumetric_fog_energy = 0.0
	add_child(berglicht)
	for paar in [["wal", 5200, 3.0], ["hasel", 3000, 3.4]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Nussmodelle.ganz(paar[0], 0, 0)
		mm.instance_count = paar[1]
		for i in mm.instance_count:
			var theta := _rng.randf() * TAU
			var phi := acos(sqrt(_rng.randf()))
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var p := Vector3(d.x * 7.0, d.y * 5.0, d.z * 7.0) + d * _rng.randf_range(-0.02, 0.1)
			var basis := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)).scaled(Vector3.ONE * paar[2] * _rng.randf_range(0.8, 1.2))
			mm.set_instance_transform(i, Transform3D(basis, p))
			var hell := _rng.randf_range(0.8, 1.15)
			mm.set_instance_color(i, Color(hell, hell * _rng.randf_range(0.95, 1.02), hell * _rng.randf_range(0.9, 1.0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Look.nuss(paar[0], false, false, false, true)
		mmi.layers = 2
		_berg.add_child(mmi)
	var schild := Bau.holzschild(hof, "NUSSBERG", Vector3(-5.6, 1.4, -10.5), Vector2(1.6, 0.8), Vector3(0, 25, 0), 150)
	Bau.teil(hof, Bau.box_mesh(Vector3(0.1, 1.4, 0.1)), Look.holz(Look.ALTHOLZ), Vector3(-5.6, 0.7, -10.55))
	_berg_text = Bau.schrift(schild, "", Vector3(0, -0.18, 0.0135), 110, Color(0.35, 0.15, 0.05))
	# Kompost unter dem Fenster (draußen)
	var kompost := Area3D.new()
	kompost.collision_layer = 0
	kompost.collision_mask = Data.L_ITEM | Data.L_BEHAELTER
	kompost.position = Vector3(0.55, 0.6, -4.6)
	var kc := CollisionShape3D.new()
	var kb := BoxShape3D.new()
	kb.size = Vector3(8, 2.5, 3)
	kc.shape = kb
	kompost.add_child(kc)
	add_child(kompost)
	kompost.body_entered.connect(_kompost)
	var kiste_holz := Look.holz(Look.ALTHOLZ, 9.0, 0.0)
	for s in [[Vector3(1.6, 0.45, 0.05), Vector3(0, 0.225, -0.5)], [Vector3(1.6, 0.45, 0.05), Vector3(0, 0.225, 0.5)],
			[Vector3(0.05, 0.45, 1.0), Vector3(-0.8, 0.225, 0)], [Vector3(0.05, 0.45, 1.0), Vector3(0.8, 0.225, 0)]]:
		Bau.block(self, s[0], Vector3(0.55, 0, -4.4) + s[1], kiste_holz, true)
	Bau.teil(self, Bau.box_mesh(Vector3(1.55, 0.05, 0.95)), Look.putz(Color(0.25, 0.17, 0.1), Color(0.2, 0.13, 0.08), 40.0), Vector3(0.55, 0.38, -4.4))


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
	while liste.size() < 14000:
		var p := Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-3.4, -28))
		var zum_berg := Vector2(p.x - 0.8, p.z + 17).length()
		if zum_berg < 7.3 or (absf(p.x - 0.55) < 0.95 and p.z > -5.0):
			continue
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
	if _berg == null:
		return
	var rest := float(Game.berg_rest()) / Data.BERG_GROESSE
	var s := 0.18 + 0.82 * pow(rest, 1.0 / 3.0)
	_berg.scale = Vector3(s, s, s)
	_berg.visible = rest > 0.0
	_berg_text.text = Data.zahl(Game.berg_rest())


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
	_wand(k, Vector3(FENSTER_X.y, 0, -3.1), Vector3(3.1, 3, -2.9), wand)
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
	Bau.block(k, Vector3(1.6, 0.95, 0.03), Vector3(2.15, 0.475, -2.885), holz_wand, false)
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
	var tt := Interaktiv.erzeuge(tafel, Vector3(1.3, 0.95, 0.2), Vector3.ZERO, "Opas Talentbaum ansehen", func(_s): _menue(menues.zeige_talente))
	tt.info = func(): return "%d Meisterpunkte zu vergeben" % Game.mp
	# Deko
	_uhr_zeiger = Einrichtung.uhr(k, Vector3(2.88, 2.68, 0.0), -90)
	var regal := Einrichtung.regal(k, Vector3(2.1, 1.45, -2.9), 1.3, 2)
	var sorten := ["wal", "hasel", "mandel", "wal", "pekan", "hasel"]
	for i in 6:
		Einrichtung.vorratsglas(regal, Vector3(-0.45 + (i % 3) * 0.42, (i / 3) * 0.4 + 0.013, 0.12), sorten[i], _rng.randf_range(0.4, 0.95), 0.2 + (i % 2) * 0.05)
	Einrichtung.sack(k, Vector3(-2.45, 0, -2.45), 0.6)
	Einrichtung.sack(k, Vector3(-2.0, 0, -2.6), -0.3, "hasel")
	Einrichtung.sack(k, Vector3(-2.5, 0, -1.95), 1.4)
	Einrichtung.sessel(k, Vector3(-2.2, 0, 2.2), 135)
	Einrichtung.teppich(k, Vector3(-1.9, 0, 1.9), Vector2(1.5, 1.5), Color(0.3, 0.42, 0.55), Color(0.22, 0.32, 0.45))
	Einrichtung.pflanze(k, Vector3(2.55, 0, 2.55), 2.2)
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


# =============================================================================
# Behälter
# =============================================================================
func _behaelter_anlegen() -> void:
	glas = _neuer_behaelter("glas", GLAS_POS, Game.hat_maschine("grosses_glas"))
	bruchschale = _neuer_behaelter("bruch", BRUCH_POS)
	eimer = _neuer_behaelter("eimer", EIMER_POS)
	kiste = _neuer_behaelter("kiste", Vector3(7.4, 0.0, -1.4))
	glas.setze_deckel(Game.hat_maschine("deckel"))
	var gespeichert: Dictionary = Game.behaelter
	for paar in [["glas", glas], ["eimer", eimer], ["bruch", bruchschale], ["kiste", kiste]]:
		if gespeichert.has(paar[0]):
			paar[1].aus_dict(gespeichert[paar[0]])
	glas.geaendert.connect(_glas_geaendert)


func _neuer_behaelter(typ: String, pos: Vector3, gross := false) -> Behaelter:
	var b := Behaelter.erzeuge(typ, gross)
	b.position = pos + Vector3(0, 0.005, 0)
	add_child(b)
	b.heim = b.global_transform
	return b


func behaelter_speichern() -> Dictionary:
	return {"glas": glas.als_dict(), "eimer": eimer.als_dict(), "bruch": bruchschale.als_dict(), "kiste": kiste.als_dict()}


func _glas_geaendert() -> void:
	if glas.voll() and not _glas_war_voll:
		_glas_war_voll = true
		Game.ziel_melden("glas_voll")
		if not Game.hat_maschine("rohrpost"):
			Game.toast.emit("Das Glas ist voll! Bring es zur Verkaufsklappe.", Game.FARBE_INFO)
			Sfx.spiele("voll", -4.0)
	elif not glas.voll():
		_glas_war_voll = false


# =============================================================================
# Maschinen
# =============================================================================
func _maschine_aufstellen(id: String, neu := true) -> void:
	match id:
		"deckel":
			glas.setze_deckel(true)
		"grosses_glas":
			var gespeichert := glas.als_dict()
			glas.setze_gross(true)
			glas.aus_dict(gespeichert)
		"rutsche":
			var r := Node3D.new()
			add_child(r)
			var blech := Look.metall(Color(0.72, 0.74, 0.77), 0.3)
			var gelb := Look.lackiert(Color(0.85, 0.62, 0.15), 0.5)
			# kleine Blechrinne von der Schale zum Brett und ein Motorkästchen am Rohr
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
		"rohrpost":
			var rp := Node3D.new()
			add_child(rp)
			var messing := Look.metall(Color(0.85, 0.66, 0.32), 0.25)
			var oben := GLAS_POS + Vector3(0, 0.62, 0)
			Bau.teil(rp, Bau.zylinder_mesh(0.07, 0.07, 3.0 - oben.y, 20), messing, Vector3(oben.x, (3.0 + oben.y) * 0.5, oben.z))
			var glocke := CylinderMesh.new()
			glocke.top_radius = 0.07
			glocke.bottom_radius = 0.16
			glocke.height = 0.14
			glocke.cap_bottom = false
			var gm := messing.duplicate() as StandardMaterial3D
			gm.cull_mode = BaseMaterial3D.CULL_DISABLED
			Bau.teil(rp, glocke, gm, oben + Vector3(0, -0.05, 0))
			_maschinen[id] = rp
		"sieb":
			var s := Node3D.new()
			s.position = station.global_position + Vector3(0.33, 0.0, 0.1)
			add_child(s)
			var stahl := Look.metall(Color(0.72, 0.74, 0.77), 0.3)
			Bau.teil(s, Bau.box_mesh(Vector3(0.13, 0.008, 0.13)), stahl, Vector3(0, 0.004, 0))
			for i in 6:
				Bau.teil(s, Bau.box_mesh(Vector3(0.004, 0.012, 0.13)), Look.metall(Color(0.35, 0.35, 0.37)), Vector3(-0.055 + i * 0.022, 0.01, 0))
			_maschinen[id] = s
		"ofen":
			var o := Node3D.new()
			o.position = Vector3(4.3, 0, -2.3)
			add_child(o)
			var guss := Look.metall(Color(0.16, 0.15, 0.15), 0.6)
			Bau.block(o, Vector3(1.0, 0.95, 0.8), Vector3(0, 0.5, 0), guss)
			Bau.teil(o, Bau.box_mesh(Vector3(0.5, 0.3, 0.02)), Look.leuchten(Color(1.0, 0.45, 0.1), 3.0), Vector3(0, 0.45, 0.41))
			Bau.teil(o, Bau.zylinder_mesh(0.12, 0.12, 2.0, 16), guss, Vector3(0, 2.0, -0.2))
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
			Bau.holzschild(o, "SCHALENOFEN", Vector3(0, 1.15, 0.42), Vector2(0.6, 0.15), Vector3.ZERO, 60)
			_maschinen[id] = o
		"walze":
			var wz := Node3D.new()
			wz.position = Vector3(6.4, 0, -2.4)
			add_child(wz)
			var blau := Look.lackiert(Color(0.25, 0.4, 0.58), 0.6)
			var stahl := Look.metall(Color(0.7, 0.72, 0.75), 0.3)
			Bau.block(wz, Vector3(1.0, 0.8, 0.7), Vector3(0, 0.4, 0), blau)
			Bau.teil(wz, Bau.zylinder_mesh(0.35, 0.12, 0.4, 4), stahl, Vector3(0, 1.0, 0), Vector3(0, 45, 0))
			Bau.teil(wz, Bau.zylinder_mesh(0.08, 0.08, 1.6, 12), stahl, Vector3(0, 1.75, -0.4), Vector3(30, 0, 0))
			_walzen_rollen.clear()
			for x in [-0.12, 0.12]:
				var rolle := Bau.teil(wz, Bau.zylinder_mesh(0.1, 0.1, 0.6, 16), stahl, Vector3(x, 0.85, 0.0), Vector3(0, 0, 90))
				_walzen_rollen.append(rolle)
			_walzen_status = Bau.schild(wz, "", Vector3(0, 1.45, 0.4), 40, Color(1, 0.95, 0.8), true)
			_walzen_status.font = Look.schrift(500)
			_maschinen[id] = wz
		"band":
			var bd := Node3D.new()
			add_child(bd)
			Bau.teil(bd, Bau.box_mesh(Vector3(2.3, 0.06, 0.5)), Look.plastik(Color(0.12, 0.12, 0.13), 0.7), Vector3(8.75, 0.85, -1.8))
			for x in 6:
				Bau.teil(bd, Bau.box_mesh(Vector3(0.05, 0.82, 0.05)), Look.metall(Color(0.4, 0.4, 0.42)), Vector3(7.7 + x * 0.42, 0.41, -1.8))
			_maschinen[id] = bd
		"laufrad":
			var lr := Node3D.new()
			lr.position = Vector3(8.5, 0, 1.8)
			add_child(lr)
			Bau.block(lr, Vector3(0.1, 1.0, 0.1), Vector3(0, 0.5, -0.25), Look.holz(Look.NUSSBAUM))
			_laufrad_rad = Node3D.new()
			_laufrad_rad.position = Vector3(0, 0.6, 0)
			lr.add_child(_laufrad_rad)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.42
			torus.outer_radius = 0.48
			Bau.teil(_laufrad_rad, torus, Look.holz(Look.EICHE), Vector3.ZERO, Vector3(90, 0, 0))
			for i in 6:
				Bau.teil(_laufrad_rad, Bau.box_mesh(Vector3(0.02, 0.9, 0.02)), Look.holz(Look.KIEFER), Vector3.ZERO, Vector3(0, 0, i * 30.0))
			var tier := Eichhoernchen.new()
			tier.set_process(false)
			tier.position = Vector3(0, -0.45, 0)
			lr.add_child(tier)
			tier.remove_from_group("eichhoernchen")
			Bau.holzschild(lr, "LAUFRAD", Vector3(0, 1.3, 0), Vector2(0.5, 0.15), Vector3.ZERO, 60)
			_maschinen[id] = lr


func _process(delta: float) -> void:
	if _hebel_sperre > 0.0:
		_hebel_sperre -= delta
	_rutsche(delta)
	_walze(delta)
	_band(delta)
	_rohrpost()
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
		_uhr_stellen()
		_ziele_pruefen()
	_aufraeumen()


## Ziele, deren Bedingung schon erfüllt ist, gelten als geschafft (Reihenfolge egal).
func _ziele_pruefen() -> void:
	var z := Game.ziel_aktuell()
	if z.is_empty():
		return
	match z.id:
		"hinsetzen":
			if spieler.sitzt:
				Game.ziel_melden("hinsetzen")
		"hebel":
			if _nuesse_in_schale() > 0 or station.geladen:
				Game.ziel_melden("hebel")
		"glas_voll":
			if glas.voll():
				Game.ziel_melden("glas_voll")
		"kaufen":
			if Game.werkzeuge.size() > 1:
				Game.ziel_melden("kaufen")


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
	_rutsche_timer = 2.0 / ((1.0 + 0.25 * stufe) * Game.maschinen_tempo())
	if _nuesse_in_schale() < 4 and _hebel_sperre <= 0.0:
		hebel_ziehen(true)
	elif station.kann_laden() and not station.drueckt and not spieler.sitzt:
		nuss_nachlegen(station)


func _rohrpost() -> void:
	if not Game.hat_maschine("rohrpost") or _rohrpost_laeuft:
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
					kiste.fuelle("haelfte", 2, einzel, nuss)
					Game.melde_knack(nuss, "perfekt", false, 2)
				elif r < p + (1.0 - p) * 0.7:
					kiste.fuelle("bruch", 3, float(info.wert) * 0.2, nuss)
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
			r.rotate_y(delta * 12.0)
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
		var vis := Bau.mesh_instanz(Bau.box_mesh(Vector3(0.3, 0.2, 0.25)), Look.holz(Look.KIEFER), Vector3(7.7, 1.0, -1.8))
		add_child(vis)
		_band_kisten.append(vis)
		_verkaufe(kiste, false)
		Sfx.spiele("maschine", -6.0)


# =============================================================================
# Nüsse holen, nachlegen, sortieren
# =============================================================================
func _hebel_ziehen(_s) -> void:
	hebel_ziehen()


func hebel_ziehen(leise := false) -> bool:
	if _hebel_sperre > 0.0:
		return false
	_hebel_sperre = 0.8
	if Game.berg_rest() <= 0:
		Game.toast.emit("Der Berg ist leer!", Game.FARBE_INFO)
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
	Game.ziel_melden("hebel")
	return true


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
	var richtung := (ROHR_UNTEN - ROHR_OBEN).normalized()
	for i in n:
		var daten := _neue_nuss_daten()
		get_tree().create_timer(0.09 * i).timeout.connect(func():
			var pos := ROHR_UNTEN + richtung * 0.05 + Vector3(randf_range(-0.01, 0.01), 0, 0)
			item_spawnen(daten, pos, richtung * 1.1 + Vector3(randf_range(-0.12, 0.12), 0, randf_range(0.05, 0.2)))
			Sfx.spiele("rollen", -12.0, randf_range(0.9, 1.2)))
	if mit_ton and n > 0:
		Sfx.spiele("rutsch", -6.0)


## Legt die nächste Nuss aus der Schale in den Knacker (mit kleiner Flugbahn).
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
	if body is Item and not body.gehalten and not body.fliegt:
		if body.faul or body.art == "wurm":
			var lohn := 2.0 if body.art == "wurm" else 1.0
			Game.verdiene(lohn, false)
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
			var x := randf_range(0.35, 1.15)
			weg = [Vector3(x, 0.0, -5.5), Vector3(x, FENSTER_Y.x + 0.02, -3.25), Vector3(x, FENSTER_Y.x + 0.02, -2.92), Vector3(x, TISCH_Y, -2.72), glas.global_position]
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
