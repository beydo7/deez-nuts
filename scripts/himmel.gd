class_name Himmel
extends Node
## Tag-Nacht-Lauf, Wetter und Licht (Etappe 5).
## Zählt Game.tageszeit weiter (Tag 6–20 Uhr = 20 Minuten, Nacht = 4 Minuten), lässt die Sonne
## von Ost über Nord nach West wandern, färbt Himmel, Nebel und Umgebungslicht nach Kurven
## und steuert das Wetter (klar, bewölkt, leichter Regen). Dazu Lampen für die Nacht und
## die Klänge je Tageszeit.
##
## Zum Prüfen:  godot --path . -- --selbsttest --bilder=... --zeit=18.5 --wetter=regen

const TAG_MINUTEN := 20.0
const NACHT_MINUTEN := 4.0
const MOND := Color(0.55, 0.68, 1.0)

# Stützstellen [Stunde, Wert]; dazwischen wird gemischt, über Mitternacht hinweg.
const K_ENERGIE := [[0.0, 0.8], [5.5, 0.8], [6.0, 0.0], [6.6, 0.9], [8.0, 1.9], [10.0, 2.3], [13.0, 2.5], [16.5, 2.3], [18.5, 1.8], [19.5, 0.9], [20.0, 0.0], [20.5, 0.8], [24.0, 0.8]]
const K_SONNE := [[0.0, MOND], [5.99, MOND], [6.0, Color(1.0, 0.55, 0.35)], [7.5, Color(1.0, 0.8, 0.58)], [10.0, Color(1.0, 0.92, 0.78)], [13.0, Color(1.0, 0.95, 0.85)], [16.5, Color(1.0, 0.87, 0.68)], [18.5, Color(1.0, 0.72, 0.48)], [19.99, Color(1.0, 0.46, 0.28)], [20.0, MOND], [24.0, MOND]]
const K_OBEN := [[0.0, Color(0.035, 0.06, 0.15)], [5.2, Color(0.04, 0.07, 0.16)], [6.2, Color(0.2, 0.27, 0.48)], [7.5, Color(0.3, 0.46, 0.72)], [10.0, Color(0.26, 0.47, 0.82)], [16.5, Color(0.27, 0.46, 0.8)], [18.5, Color(0.3, 0.36, 0.62)], [19.6, Color(0.18, 0.19, 0.4)], [20.6, Color(0.04, 0.07, 0.16)], [24.0, Color(0.035, 0.06, 0.15)]]
const K_HORIZONT := [[0.0, Color(0.12, 0.17, 0.32)], [5.2, Color(0.13, 0.18, 0.32)], [6.2, Color(0.92, 0.58, 0.42)], [7.5, Color(0.92, 0.8, 0.64)], [10.0, Color(0.8, 0.83, 0.82)], [13.0, Color(0.76, 0.84, 0.9)], [16.5, Color(0.88, 0.82, 0.7)], [18.5, Color(1.0, 0.73, 0.5)], [19.6, Color(0.74, 0.4, 0.34)], [20.6, Color(0.13, 0.18, 0.32)], [24.0, Color(0.12, 0.17, 0.32)]]
const K_UMGEBUNG := [[0.0, Color(0.38, 0.48, 0.82)], [5.5, Color(0.38, 0.48, 0.8)], [6.5, Color(0.72, 0.62, 0.62)], [8.0, Color(0.8, 0.82, 0.88)], [16.5, Color(0.84, 0.84, 0.88)], [18.5, Color(0.86, 0.75, 0.68)], [19.8, Color(0.55, 0.47, 0.62)], [20.6, Color(0.38, 0.48, 0.82)], [24.0, Color(0.38, 0.48, 0.82)]]
const K_UMGEBUNG_E := [[0.0, 0.9], [5.5, 0.9], [7.0, 0.5], [18.5, 0.5], [20.5, 0.9], [24.0, 0.9]]
const K_NEBEL := [[0.0, 0.0022], [5.5, 0.003], [6.3, 0.0055], [7.5, 0.004], [9.5, 0.0013], [13.0, 0.0009], [16.5, 0.0011], [18.5, 0.0014], [20.5, 0.0022], [24.0, 0.0022]]
const K_BODENNEBEL := [[0.0, 0.008], [5.0, 0.015], [6.3, 0.05], [7.5, 0.035], [9.0, 0.0], [19.5, 0.0], [21.0, 0.008], [24.0, 0.008]]
const K_VOL_DICHTE := [[0.0, 0.0012], [5.5, 0.002], [6.3, 0.0055], [7.5, 0.0038], [9.5, 0.0012], [13.0, 0.0009], [16.5, 0.0012], [18.5, 0.0018], [19.8, 0.002], [20.6, 0.0012], [24.0, 0.0012]]
const K_VOL_SONNE := [[0.0, 0.6], [6.0, 0.6], [6.4, 2.0], [7.5, 1.6], [10.0, 0.8], [13.0, 0.6], [16.5, 0.9], [18.5, 1.4], [19.8, 1.2], [20.5, 0.6], [24.0, 0.6]]
const K_BELICHTUNG := [[0.0, 1.4], [5.5, 1.4], [7.0, 1.08], [18.5, 1.08], [20.5, 1.4], [24.0, 1.4]]
const K_NACHT := [[0.0, 1.0], [5.6, 1.0], [6.6, 0.0], [18.8, 0.0], [20.0, 1.0], [24.0, 1.0]]
const K_VOGEL := [[0.0, 0.0], [5.2, 0.0], [6.3, 1.0], [18.5, 1.0], [20.0, 0.0], [24.0, 0.0]]
const K_GRILLEN := [[0.0, 0.8], [5.0, 0.6], [6.2, 0.0], [17.8, 0.0], [19.3, 1.0], [24.0, 0.8]]

var welt: Node
var bewoelkung := 0.0        # 0 klar .. 1 Regenwolken (läuft weich nach)
var regen := 0.0             # 0 trocken .. 1 es regnet
var nacht := 0.0             # 0 Tag .. 1 Nacht (für Lampen, Glühwürmchen)
var drinnen := 0.0           # 0 draußen .. 1 in der Hütte

var _himmel_mat: ProceduralSkyMaterial
var _akt := 0.0
var _wetter_timer := 300.0
var _regen_teilchen: GPUParticles3D
var _lampen: Array = []      # [OmniLight3D, volle Energie]
var _lampen_mat: StandardMaterial3D
var _kauz_timer := 20.0
var _ast_timer := 25.0
var _rng := RandomNumberGenerator.new()


func _init(w: Node) -> void:
	welt = w
	name = "Himmel"


func _ready() -> void:
	_rng.randomize()
	var env: Environment = welt.umwelt
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		_himmel_mat = env.sky.sky_material
		env.sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.fog_height = 0.9
	env.volumetric_fog_anisotropy = 0.4
	_lampen_bauen()
	_regen_bauen()
	_klangzonen()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zeit="):
			Game.tageszeit = fposmod(float(a.substr(7)), 24.0)
		if a.begins_with("--wetter="):
			Game.wetter = a.substr(9)
	setze_wetter(Game.wetter, true)
	setze_zeit(Game.tageszeit)
	_wetter_timer = _rng.randf_range(240.0, 480.0)


# --- Öffentlich ----------------------------------------------------------------
## Stellt die Uhr (0..24) und passt Licht, Himmel und Klang sofort an.
func setze_zeit(stunde: float) -> void:
	Game.tageszeit = fposmod(stunde, 24.0)
	_anwenden()


## art: "klar", "bewoelkt" oder "regen". sofort = ohne weichen Übergang.
func setze_wetter(art: String, sofort := false) -> void:
	if not art in ["klar", "bewoelkt", "regen"]:
		art = "klar"
	Game.wetter = art
	if sofort:
		bewoelkung = _ziel_bewoelkung()
		regen = 1.0 if art == "regen" else 0.0
		_anwenden()


## Sonne plus Umgebungslicht, zum Vergleichen von Tag und Nacht.
func helligkeit() -> float:
	return welt.sonne.light_energy + welt.umwelt.ambient_light_energy


func ist_drinnen(p: Vector3) -> bool:
	return p.x > -3.1 and p.x < 10.1 and p.z > -3.1 and p.z < 3.1 and p.y < 3.2


func uhrzeit_text() -> String:
	var h := int(Game.tageszeit)
	var m := int((Game.tageszeit - h) * 60.0)
	return "%02d:%02d" % [h, m - m % 5]


# --- Ablauf ----------------------------------------------------------------------
func _process(delta: float) -> void:
	var laeuft := not bool(Game.einstellungen.get("zeit_fest", false)) and (not Game.selbsttest or has_meta("zeit_laeuft"))
	if laeuft:
		var tempo := 14.0 / (TAG_MINUTEN * 60.0) if not Game.ist_nacht() else 10.0 / (NACHT_MINUTEN * 60.0)
		Game.tageszeit = fposmod(Game.tageszeit + tempo * delta, 24.0)
		if not Game.selbsttest:
			_wetter_wuerfeln(delta)
	# Wetter läuft weich nach
	bewoelkung = move_toward(bewoelkung, _ziel_bewoelkung(), delta * 0.12)
	regen = move_toward(regen, 1.0 if Game.wetter == "regen" else 0.0, delta * 0.2)
	var sp: Node3D = welt.get("spieler")
	if sp:
		drinnen = move_toward(drinnen, 1.0 if ist_drinnen(sp.global_position) else 0.0, delta * 2.5)
		_regen_teilchen.global_position = sp.global_position + Vector3(0, 7.0, 0)
		_regen_teilchen.emitting = regen > 0.3 and drinnen < 0.5
		_einzelklaenge(delta, sp.global_position)
	Sfx.draussen_daempfen(drinnen)
	_akt -= delta
	if _akt <= 0.0:
		_akt = 0.1
		_anwenden()


func _ziel_bewoelkung() -> float:
	match Game.wetter:
		"bewoelkt":
			return 0.65
		"regen":
			return 1.0
	return 0.0


func _wetter_wuerfeln(delta: float) -> void:
	_wetter_timer -= delta
	if _wetter_timer > 0.0:
		return
	if Game.wetter == "regen":
		setze_wetter("bewoelkt" if _rng.randf() < 0.4 else "klar")
		_wetter_timer = _rng.randf_range(240.0, 480.0)
		return
	var w := _rng.randf()
	if w < 0.7:
		setze_wetter("klar")
		_wetter_timer = _rng.randf_range(240.0, 480.0)
	elif w < 0.9:
		setze_wetter("bewoelkt")
		_wetter_timer = _rng.randf_range(180.0, 360.0)
	else:
		setze_wetter("regen")
		_wetter_timer = _rng.randf_range(90.0, 150.0)


static func kurve(punkte: Array, h: float) -> Variant:
	for i in punkte.size() - 1:
		var a: Array = punkte[i]
		var b: Array = punkte[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var t := (h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			if a[1] is Color:
				return (a[1] as Color).lerp(b[1], t)
			return lerpf(float(a[1]), float(b[1]), t)
	return punkte[-1][1]


## Richtung, aus der Sonne oder Mond scheinen (Einheitsvektor zum Gestirn).
func gestirn_richtung(h: float) -> Vector3:
	var tag := h >= 6.0 and h < 20.0
	var t := (h - 6.0) / 14.0 if tag else fposmod(h - 20.0, 24.0) / 10.0
	var hoehe := deg_to_rad((62.0 if tag else 48.0) * sin(PI * t)) + deg_to_rad(4.0)
	var az := PI * t
	# Tag: Ost (+x) -> Nord (-z) -> West. Nacht: der Mond zieht über den Süden.
	var nord := -1.0 if tag else 1.0
	return Vector3(cos(az) * cos(hoehe), sin(hoehe), nord * sin(az) * cos(hoehe)).normalized()


func _anwenden() -> void:
	var h := Game.tageszeit
	var env: Environment = welt.umwelt
	var sonne: DirectionalLight3D = welt.sonne
	var b := bewoelkung
	nacht = float(kurve(K_NACHT, h))
	var energie := float(kurve(K_ENERGIE, h))
	var tag_anteil := clampf(energie / 2.3, 0.0, 1.0) * (1.0 - nacht)
	# Gestirn
	var richtung := gestirn_richtung(h)
	sonne.look_at_from_position(Vector3.ZERO, -richtung, Vector3.UP)
	sonne.light_energy = energie * (1.0 - 0.6 * b)
	sonne.light_color = (kurve(K_SONNE, h) as Color).lerp(Color(0.8, 0.83, 0.87), 0.5 * b * (1.0 - nacht))
	sonne.light_volumetric_fog_energy = float(kurve(K_VOL_SONNE, h)) * (1.0 - 0.7 * b)
	# Himmel
	var grau := lerpf(0.1, 1.0, tag_anteil)
	var oben := (kurve(K_OBEN, h) as Color).lerp(Color(0.42, 0.46, 0.52) * grau, 0.85 * b)
	var horizont := (kurve(K_HORIZONT, h) as Color).lerp(Color(0.63, 0.65, 0.67) * grau, 0.8 * b)
	if _himmel_mat:
		_himmel_mat.sky_top_color = oben
		_himmel_mat.sky_horizon_color = horizont
		_himmel_mat.ground_horizon_color = horizont * 0.85
		_himmel_mat.ground_bottom_color = horizont * 0.35
	# Nebel und Dunst
	env.fog_light_color = horizont.lerp(Color(0.92, 0.92, 0.95) * lerpf(0.12, 1.0, clampf(energie / 1.2, 0.0, 1.0) * (1.0 - nacht)), 0.5)
	env.fog_density = float(kurve(K_NEBEL, h)) * (1.0 + 1.3 * b)
	env.fog_height_density = float(kurve(K_BODENNEBEL, h))
	env.volumetric_fog_density = float(kurve(K_VOL_DICHTE, h)) * (1.0 + 0.6 * b)
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.88).lerp(Color(0.75, 0.82, 1.0), nacht)
	# Umgebungslicht
	env.ambient_light_color = (kurve(K_UMGEBUNG, h) as Color).lerp(Color(0.7, 0.73, 0.78), 0.5 * b * (1.0 - nacht))
	env.ambient_light_energy = float(kurve(K_UMGEBUNG_E, h)) * (1.0 + 0.35 * b * (1.0 - nacht))
	env.tonemap_exposure = float(kurve(K_BELICHTUNG, h))
	# Lampen
	for l in _lampen:
		(l[0] as OmniLight3D).light_energy = float(l[1]) * nacht
		(l[0] as OmniLight3D).visible = nacht > 0.02
	if _lampen_mat:
		_lampen_mat.emission_energy_multiplier = 0.3 + 5.0 * nacht
	# Regen
	if regen > 0.5:
		Game.letzter_regen = Game.spielzeit
	var gel: Gelaende = welt.get("gelaende")
	if gel and gel.material:
		gel.material.set_shader_parameter("nass", regen)
	# Klang je Tageszeit
	Sfx.tagesklang(float(kurve(K_VOGEL, h)) * (1.0 - 0.8 * regen), float(kurve(K_GRILLEN, h)) * (1.0 - regen), regen)


# --- Lampen für die Nacht -------------------------------------------------------
func _lampen_bauen() -> void:
	_lampen_mat = StandardMaterial3D.new()
	_lampen_mat.albedo_color = Color(1.0, 0.85, 0.6)
	_lampen_mat.emission_enabled = true
	_lampen_mat.emission = Color(1.0, 0.72, 0.4)
	_lampen_mat.emission_energy_multiplier = 0.3
	var eisen := Look.metall(Color(0.16, 0.16, 0.17), 0.6)
	var gel: Gelaende = welt.get("gelaende")
	var tor_y := gel.hoehe_bei(1.7, 21.3) if gel else 0.0
	# [Position, Lichtweite, Energie, hängt (true) oder steht an der Wand (false)]
	var orte := [
		[Vector3(3.15, 2.2, -3.32), 8.0, 1.5, false],          # neben der Haustür
		[Vector3(-0.6, 2.2, 5.0), 8.0, 1.3, true],             # Veranda
		[Vector3(5.2, 2.2, 5.0), 7.0, 1.1, true],              # Veranda, Werkstattseite
		[Vector3(-0.45, tor_y + 2.3, 21.45), 9.0, 1.4, true],  # Hoftor
		[Vector3(-1.15, 2.6, -4.95), 7.0, 1.2, false],         # am Silo über der Abgabe
	]
	for o in orte:
		var k := Node3D.new()
		k.name = "Laterne"
		k.position = o[0]
		welt.add_child(k)
		if o[3]:
			Bau.teil(k, Bau.zylinder_mesh(0.004, 0.004, 0.22, 4), eisen, Vector3(0, 0.2, 0))
		else:
			Bau.teil(k, Bau.box_mesh(Vector3(0.03, 0.03, 0.22)), eisen, Vector3(0, 0.13, 0.1))
		Bau.teil(k, Bau.zylinder_mesh(0.05, 0.09, 0.04, 6), eisen, Vector3(0, 0.1, 0))
		Bau.teil(k, Bau.zylinder_mesh(0.07, 0.06, 0.16, 6), _lampen_mat, Vector3.ZERO)
		Bau.teil(k, Bau.zylinder_mesh(0.075, 0.075, 0.02, 6), eisen, Vector3(0, -0.09, 0))
		var licht := OmniLight3D.new()
		licht.light_color = Color(1.0, 0.72, 0.42)
		licht.omni_range = float(o[1])
		licht.omni_attenuation = 1.3
		licht.shadow_enabled = false
		licht.light_volumetric_fog_energy = 0.3
		licht.position = Vector3(0, -0.15, 0)
		k.add_child(licht)
		_lampen.append([licht, float(o[2])])


# --- Regen -------------------------------------------------------------------------
func _regen_bauen() -> void:
	var p := GPUParticles3D.new()
	p.name = "Regen"
	p.amount = 1300
	p.lifetime = 0.9
	p.preprocess = 0.8
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-14, -12, -14), Vector3(28, 16, 28))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 0.5, 9)
	pm.direction = Vector3(0.08, -1, 0.03)
	pm.spread = 2.0
	pm.initial_velocity_min = 9.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, -3.0, 0)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.94, 1.0, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	quad.material = m
	p.draw_pass_1 = quad
	welt.add_child(p)
	_regen_teilchen = p


# --- Klang -------------------------------------------------------------------------
func _klangzonen() -> void:
	# Werkstatt: leises Brummen und Ticken, nur in der Nähe zu hören
	var pfad := "res://sounds/werkstatt.wav"
	if ResourceLoader.exists(pfad):
		var a := AudioStreamPlayer3D.new()
		a.name = "KlangWerkstatt"
		a.stream = load(pfad)
		a.volume_db = -16.0
		a.max_distance = 9.0
		a.unit_size = 2.2
		a.position = Vector3(8.6, 1.2, 1.8)
		a.autoplay = true
		a.finished.connect(a.play)
		welt.add_child(a)


## Ab und zu: nachts ein Kauz, im Wald ein knackender Ast.
func _einzelklaenge(delta: float, p: Vector3) -> void:
	if Game.selbsttest:
		return
	if nacht > 0.8 and regen < 0.3:
		_kauz_timer -= delta
		if _kauz_timer <= 0.0:
			_kauz_timer = _rng.randf_range(25.0, 70.0)
			Sfx.spiele_draussen("kauz", _rng.randf_range(-22.0, -15.0), _rng.randf_range(0.92, 1.05))
	if WeltPlan.tal_r(p.x, p.z) > 0.88:
		_ast_timer -= delta
		if _ast_timer <= 0.0:
			_ast_timer = _rng.randf_range(14.0, 40.0)
			Sfx.spiele_draussen("impactWood_light", _rng.randf_range(-24.0, -17.0), _rng.randf_range(0.5, 0.75))
