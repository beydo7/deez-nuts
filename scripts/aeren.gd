class_name Aeren
extends Node3D
## Funde im Berg und Bauten rund um den Berg je Ära (Etappe 6).
## Die Funde liegen von Anfang an im Inneren des Bergs und kommen von selbst zum Vorschein,
## wenn die Nüsse darüber weg sind. Die Bauten erscheinen beim Wechsel in eine neue Ära.
## Ganz unten, wo die Kuppe war, liegt Opas letzter Gruß.

const BRIEF_OPA := """Mein lieber Nachfolger,

wenn du das liest, ist der Berg weg. Respekt. Ich habe 52 Jahre gebraucht, um ihn aufzuschütten.

Angefangen hat alles mit einem einzigen Haselstrauch, genau hier. Der Stumpf neben der Luke ist alles, was von ihm übrig ist.

In der Luke liegt ein Setzling. Pflanz ihn ein. Und dann: sammeln. Nie verkaufen. Na gut, ein paar.

Dein Opa Walter

P. S.: Grüß den König von mir."""

var welt: Node
var berg: Nussberg
var gel: Gelaende
var _auf_berg: Array = []        # [Knoten, x, z] liegen oben auf dem Berg und sinken mit ihm
var _lampen: Array = []          # OmniLight3D, brennen nur nachts
var _birnen: Array = []          # leuchtende Teile, nachts hell
var _gebaut := {}
var _luke: Interaktiv
var _luke_deckel: Node3D
var _takt := 0.0
var _ketten := {}
var _war_nacht := false


func _init(w: Node) -> void:
	welt = w
	name = "Aeren"


func _ready() -> void:
	berg = welt.berg
	gel = welt.gelaende
	_boden_unter_dem_berg()
	_funde_im_berg()
	for a in range(2, Game.aera + 1):
		_bauen(a, false)
	Game.aera_erreicht.connect(func(a: int, _schicht: String): _bauen(a, true))
	Game.posten_gekauft.connect(func(_id: String): _lichterketten())
	_nacht_schalten(Game.ist_nacht())
	_war_nacht = Game.ist_nacht()


func _process(delta: float) -> void:
	_takt -= delta
	if _takt > 0.0:
		return
	_takt = 0.5
	for e in _auf_berg:
		var k: Node3D = e[0]
		var ziel: float = maxf(berg.hoehe_bei(e[1], e[2]), gel.hoehe_bei(e[1], e[2])) + float(e[3])
		k.position.y = lerpf(k.position.y, ziel, 0.5)
	if _luke:
		var frei := berg.hoehe_bei(Nussberg.MITTE.x, Nussberg.MITTE.z) < 0.35
		_luke.collision_layer = Data.L_INTERAKT if frei else 0
	var nacht := Game.ist_nacht()
	if nacht != _war_nacht:
		_war_nacht = nacht
		_nacht_schalten(nacht)


func _nacht_schalten(nacht: bool) -> void:
	for l in _lampen:
		if is_instance_valid(l):
			(l as OmniLight3D).visible = nacht
	for b in _birnen:
		if is_instance_valid(b):
			(b as GeometryInstance3D).material_override = _licht_mat(nacht)


func _licht_mat(an: bool) -> Material:
	return Look.leuchten(Color(1.0, 0.82, 0.45), 3.0) if an else Bau.mat(Color(0.92, 0.86, 0.66), 0.4)


# --- Helfer --------------------------------------------------------------------
func _alt() -> Material:
	return Look.holz(Look.ALTHOLZ, 9.0, 0.0)


func _dunkel() -> Material:
	return Look.holz(Look.NUSSBAUM, 6.0, 0.1)


func _eisen() -> Material:
	return Look.metall(Color(0.3, 0.3, 0.32), 0.55)


func _knoten(n: String, pos: Vector3, dreh := 0.0, eltern: Node3D = null) -> Node3D:
	var k := Node3D.new()
	k.name = n
	k.position = pos
	k.rotation_degrees.y = dreh
	(eltern if eltern else self).add_child(k)
	return k


func _boden(x: float, z: float) -> Vector3:
	return gel.position(x, z)


## Laterne an einem Pfahl mit Licht, das nur nachts brennt.
func _laterne(eltern: Node3D, pos: Vector3, hoehe := 2.6) -> void:
	Bau.teil(eltern, Bau.box_mesh(Vector3(0.1, hoehe, 0.1)), _dunkel(), pos + Vector3(0, hoehe * 0.5, 0))
	Bau.teil(eltern, Bau.box_mesh(Vector3(0.5, 0.07, 0.07)), _dunkel(), pos + Vector3(0.2, hoehe - 0.1, 0))
	Bau.teil(eltern, Bau.zylinder_mesh(0.14, 0.06, 0.1, 10), _eisen(), pos + Vector3(0.4, hoehe - 0.2, 0))
	var birne := Bau.teil(eltern, Bau.kugel_mesh(0.07, false, 10), _licht_mat(false), pos + Vector3(0.4, hoehe - 0.3, 0))
	_birnen.append(birne)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0.4, hoehe - 0.35, 0)
	l.light_color = Color(1.0, 0.8, 0.5)
	l.light_energy = 1.6
	l.omni_range = 9.0
	l.shadow_enabled = false
	l.visible = false
	eltern.add_child(l)
	_lampen.append(l)


# --- Der Boden, der 52 Jahre kein Licht gesehen hat --------------------------------
func _boden_unter_dem_berg() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rausch := FastNoiseLite.new()
	rausch.seed = 52
	rausch.frequency = 1.0
	var n := 64
	var rand: Array = []
	for i in n:
		var w := TAU * i / n
		var r := Nussberg.RADIUS + 0.2 + rausch.get_noise_2d(cos(w) * 3.0, sin(w) * 3.0) * 0.9
		rand.append(Vector3(Nussberg.MITTE.x + cos(w) * r, 0.0, Nussberg.MITTE.z + sin(w) * r))
	var mitte := Vector3(Nussberg.MITTE.x, 0.0, Nussberg.MITTE.z)
	for i in n:
		# von oben gesehen im Uhrzeigersinn = Vorderseite nach oben
		st.set_normal(Vector3.UP)
		st.add_vertex(mitte)
		st.set_normal(Vector3.UP)
		st.add_vertex(rand[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(rand[(i + 1) % n])
	var mi := MeshInstance3D.new()
	mi.name = "BlasserBoden"
	mi.mesh = st.commit()
	mi.material_override = Look.putz(Color(0.62, 0.6, 0.36), Color(0.5, 0.45, 0.27), 22.0, 0.0, 0.96)
	mi.position.y = gel.hoehe_bei(Nussberg.MITTE.x, Nussberg.MITTE.z) + 0.012
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Plattgedrückte Schalenreste
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Bau.kugel_mesh(0.05, true, 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5252
	mm.instance_count = 500
	for i in 500:
		var w := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (Nussberg.RADIUS - 1.0)
		var b := Basis.from_euler(Vector3(PI + rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))).scaled(Vector3.ONE * rng.randf_range(0.6, 1.2))
		mm.set_instance_transform(i, Transform3D(b, Vector3(Nussberg.MITTE.x + cos(w) * r, mi.position.y + 0.035, Nussberg.MITTE.z + sin(w) * r)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Look.schale_innen("wal")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# --- Funde im Berg -----------------------------------------------------------------
func _funde_im_berg() -> void:
	var m := Nussberg.MITTE
	# Ära 1: Fahne und Opas erster Sammelkorb liegen oben auf der Kuppe und sinken mit
	var fahne := _knoten("Kuppenfahne", Vector3(m.x + 1.0, 10.0, m.z - 0.8))
	Bau.teil(fahne, Bau.zylinder_mesh(0.03, 0.035, 2.6, 8), _alt(), Vector3(0, 1.0, 0), Vector3(0, 0, 3))
	Bau.teil(fahne, Bau.box_mesh(Vector3(0.8, 0.45, 0.012)), Look.stoff(Color(0.75, 0.16, 0.12)), Vector3(0.46, 2.0, 0), Vector3(0, 0, 3))
	Bau.schrift(fahne, "OPAS\nBERG", Vector3(0.46, 2.0, 0.008), 40, Color(0.98, 0.92, 0.8), Vector3(0, 0, 3))
	Bau.schrift(fahne, "OPAS\nBERG", Vector3(0.46, 2.0, -0.008), 40, Color(0.98, 0.92, 0.8), Vector3(0, 180, -3))
	_auf_berg.append([fahne, m.x + 1.0, m.z - 0.8, -0.3])
	var korb := _knoten("ErsterKorb", Vector3(m.x + 0.9, 10.0, m.z + 0.5), 30.0)
	Bau.teil(korb, Bau.zylinder_mesh(0.3, 0.22, 0.34, 12), Look.holz(Look.KIEFER, 14.0, 0.0), Vector3(0, 0.17, 0))
	Bau.teil(korb, Bau.kugel_mesh(0.27, true, 12), Look.nusshaufen(0.05), Vector3(0, 0.28, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	var henkel := TorusMesh.new()
	henkel.inner_radius = 0.27
	henkel.outer_radius = 0.3
	Bau.teil(korb, henkel, Look.holz(Look.KIEFER, 14.0, 0.0), Vector3(0, 0.34, 0), Vector3(90, 0, 0), Vector3(1, 1, 0.9))
	_auf_berg.append([korb, m.x + 0.9, m.z + 0.5, -0.05])
	# Ära 2: am Südfuß stecken alte Zaunpfähle, eine Schubkarre und Opas Hut
	var rng := RandomNumberGenerator.new()
	rng.seed = 1974
	for i in 5:
		var p := _boden(-7.0 + i * 1.5, m.z + 18.8 - absf(i - 2.0) * 0.25)
		Bau.teil(self, Bau.box_mesh(Vector3(0.11, 1.2, 0.11)), _alt(), p + Vector3(0, 0.55, 0), Vector3(rng.randf_range(-8, 8), rng.randf() * 40.0, rng.randf_range(-8, 8)))
		if i < 4 and i != 1:
			Bau.teil(self, Bau.box_mesh(Vector3(1.55, 0.08, 0.035)), _alt(), p + Vector3(0.75, 0.75, 0), Vector3(0, 0, rng.randf_range(-5, 5)))
	_schubkarre(_knoten("AlteSchubkarre", _boden(6.2, m.z + 17.8), 140.0))
	var hut := _knoten("OpasHut", _boden(0.2, m.z + 18.4) + Vector3(0, 0.02, 0), 20.0)
	var filz := Look.stoff(Color(0.3, 0.24, 0.18))
	Bau.teil(hut, Bau.zylinder_mesh(0.3, 0.32, 0.025, 16), filz, Vector3(0, 0.012, 0))
	Bau.teil(hut, Bau.zylinder_mesh(0.15, 0.17, 0.16, 14), filz, Vector3(0, 0.1, 0))
	Bau.teil(hut, Bau.zylinder_mesh(0.172, 0.175, 0.035, 14), Look.stoff(Color(0.6, 0.5, 0.2)), Vector3(0, 0.04, 0))
	# Ära 3: Opas erste Hütte, tief im Berg
	Modelle.platz(self, "opas_erste_huette", _boden(m.x - 7.0, m.z + 8.5), 160.0, _erste_huette)
	# Ära 4: Dampfmaschine, Fahrrad, die Körbe vom Leiterwagen
	_dampfmaschine(_knoten("Dampfmaschine", _boden(m.x + 8.0, m.z - 4.0), -30.0))
	_fahrrad(_knoten("OpasFahrrad", _boden(m.x - 9.0, m.z - 8.0), 70.0))
	for i in 4:
		var kp := _boden(m.x + 3.0 + i * 0.7, m.z + 9.5 + (i % 2) * 0.6)
		Bau.teil(self, Bau.zylinder_mesh(0.27, 0.2, 0.32, 12), Look.holz(Look.KIEFER, 14.0, 0.0), kp + Vector3(0, 0.16 if i != 2 else 0.2, 0), Vector3(0 if i != 2 else 80, i * 40.0, 0))
	# Ära 5: der allererste Haselstrauch und die Luke
	_letztes_geheimnis(_knoten("LetztesGeheimnis", _boden(m.x, m.z)))


func _schubkarre(k: Node3D) -> void:
	var rost := Look.putz(Color(0.45, 0.3, 0.2), Color(0.32, 0.2, 0.13), 50.0, 0.0, 0.9)
	Bau.teil(k, Bau.box_mesh(Vector3(0.6, 0.3, 0.85)), rost, Vector3(0, 0.45, 0), Vector3(-8, 0, 0))
	Bau.teil(k, Bau.zylinder_mesh(0.2, 0.2, 0.07, 12), Bau.mat(Color(0.08, 0.08, 0.08), 0.9), Vector3(0, 0.2, 0.62), Vector3(0, 0, 90))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.04, 0.04, 1.7)), _alt(), Vector3(s * 0.28, 0.36, -0.2), Vector3(-10, 0, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.04, 0.34, 0.04)), _alt(), Vector3(s * 0.26, 0.17, -0.45))
	Bau.teil(k, Bau.kugel_mesh(0.3, true, 10), Look.nusshaufen(0.05), Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(0.9, 0.5, 1.2))


## Ersatzmodell für den Modellplatz opas_erste_huette: 3 x 3 x 3 m, Tür an der Front (+Z).
func _erste_huette(k: Node3D) -> void:
	var holz := Look.holz(Look.ALTHOLZ, 5.0, 0.0, 0.2, false)
	Bau.block(k, Vector3(3.0, 2.0, 3.0), Vector3(0, 1.0, 0), holz)
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(3.4, 0.09, 2.1)), Look.putz(Color(0.36, 0.3, 0.26), Color(0.26, 0.22, 0.2), 30.0, 0.35, 0.9), Vector3(0, 2.5, s * 0.85), Vector3(s * 33.0, 0, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.05, 1.0, 3.0)), holz, Vector3(s * 1.5, 2.2, 0), Vector3.ZERO, Vector3(1, 1, 1))
	Bau.teil(k, Bau.box_mesh(Vector3(0.85, 1.7, 0.06)), _dunkel(), Vector3(-0.5, 0.85, 1.51))
	Bau.teil(k, Bau.kugel_mesh(0.03, false, 8), Look.metall(Color(0.8, 0.65, 0.3)), Vector3(-0.2, 0.85, 1.56))
	# Fenster mit Gardine
	Bau.teil(k, Bau.box_mesh(Vector3(0.75, 0.65, 0.04)), Bau.mat(Color(0.1, 0.12, 0.14), 0.2), Vector3(0.75, 1.25, 1.5))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.24, 0.6, 0.02)), Look.stoff(Color(0.85, 0.8, 0.68)), Vector3(0.75 + s * 0.24, 1.25, 1.53))
	Bau.teil(k, Bau.box_mesh(Vector3(0.85, 0.06, 0.08)), _dunkel(), Vector3(0.75, 0.9, 1.54))
	Bau.block(k, Vector3(0.5, 3.3, 0.5), Vector3(1.0, 1.65, -0.9), Look.putz(Color(0.55, 0.3, 0.22), Color(0.45, 0.24, 0.18), 20.0, 0.12, 0.9))
	Bau.holzschild(k, "Walter", Vector3(-0.5, 1.9, 1.54), Vector2(0.6, 0.16), Vector3(0, 0, -5), 60)
	# Der Haselstrauch-Kranz an der Tür: getrocknete Nüsse
	for i in 8:
		var w := TAU * i / 8.0
		Bau.teil(k, Bau.kugel_mesh(0.035, false, 8), Look.nuss("hasel"), Vector3(-0.5 + cos(w) * 0.16, 1.35 + sin(w) * 0.16, 1.55))


func _dampfmaschine(k: Node3D) -> void:
	var kessel := Look.putz(Color(0.2, 0.22, 0.2), Color(0.34, 0.2, 0.12), 40.0, 0.0, 0.8)
	var messing := Look.metall(Color(0.75, 0.6, 0.25), 0.35)
	Bau.teil(k, Bau.zylinder_mesh(0.7, 0.7, 2.4, 18), kessel, Vector3(0, 1.1, 0), Vector3(90, 0, 0))
	for z in [-1.0, 0.0, 1.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.7
		ring.outer_radius = 0.75
		Bau.teil(k, ring, messing, Vector3(0, 1.1, z), Vector3(90, 0, 0))
	Bau.teil(k, Bau.zylinder_mesh(0.16, 0.22, 1.6, 12), kessel, Vector3(0, 2.4, 0.8))
	Bau.teil(k, Bau.zylinder_mesh(0.24, 0.16, 0.2, 12), messing, Vector3(0, 3.25, 0.8))
	var rad := TorusMesh.new()
	rad.inner_radius = 0.75
	rad.outer_radius = 0.85
	Bau.teil(k, rad, _eisen(), Vector3(0.95, 1.1, -0.6), Vector3(0, 0, 90))
	for i in 3:
		Bau.teil(k, Bau.box_mesh(Vector3(0.05, 1.6, 0.07)), _eisen(), Vector3(0.95, 1.1, -0.6), Vector3(i * 60.0, 0, 0))
	for sx in [-0.5, 0.5]:
		for sz in [-0.9, 0.9]:
			Bau.teil(k, Bau.box_mesh(Vector3(0.18, 0.45, 0.18)), _eisen(), Vector3(sx, 0.22, sz))
	Bau.teil(k, Bau.zylinder_mesh(0.1, 0.1, 0.03, 12), messing, Vector3(-0.72, 1.4, 0.3), Vector3(0, 0, 90))
	Bau.holzschild(k, "Knack-o-Mat 1.0\n(zu laut)", Vector3(-0.74, 0.9, -0.3), Vector2(0.7, 0.3), Vector3(0, -90, 0), 46)
	var sb := StaticBody3D.new()
	sb.collision_layer = Data.L_WELT
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.9, 2.6)
	cs.shape = box
	cs.position = Vector3(0.15, 0.95, 0)
	sb.add_child(cs)
	k.add_child(sb)


func _fahrrad(k: Node3D) -> void:
	var lack := Look.lackiert(Color(0.2, 0.36, 0.3), 0.3)
	var gummi := Bau.mat(Color(0.07, 0.07, 0.075), 0.9)
	k.rotation_degrees.z = 74.0
	k.position.y += 0.08
	for z in [-0.55, 0.55]:
		var reif := TorusMesh.new()
		reif.inner_radius = 0.3
		reif.outer_radius = 0.34
		Bau.teil(k, reif, gummi, Vector3(0, 0.34, z), Vector3(0, 0, 90))
	Bau.teil(k, Bau.box_mesh(Vector3(0.035, 0.035, 0.75)), lack, Vector3(0, 0.62, -0.05), Vector3(-8, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.035, 0.035, 0.7)), lack, Vector3(0, 0.45, 0.15), Vector3(34, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.035, 0.6, 0.035)), lack, Vector3(0, 0.6, -0.3), Vector3(-14, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.035, 0.65, 0.035)), lack, Vector3(0, 0.62, 0.48), Vector3(18, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.03, 0.03)), _eisen(), Vector3(0, 0.95, 0.4))
	Bau.teil(k, Bau.box_mesh(Vector3(0.14, 0.05, 0.26)), Look.stoff(Color(0.25, 0.15, 0.1)), Vector3(0, 0.92, -0.38))
	Bau.teil(k, Bau.box_mesh(Vector3(0.3, 0.2, 0.3)), Look.holz(Look.KIEFER, 14.0, 0.0), Vector3(0, 0.85, 0.72))


# --- Das letzte Geheimnis ----------------------------------------------------------
func _letztes_geheimnis(k: Node3D) -> void:
	# Opas allererster Haselstrauch: ein knorriger Stumpf mit einem einzigen trockenen Zweig
	var rinde := Look.holz([Color(0.36, 0.27, 0.2), Color(0.2, 0.14, 0.1)], 14.0, 0.0)
	var stumpf := _knoten("Haselstumpf", Vector3(-1.1, 0, 0.3), 0.0, k)
	Bau.teil(stumpf, Bau.zylinder_mesh(0.3, 0.42, 0.5, 9), rinde, Vector3(0, 0.25, 0))
	Bau.teil(stumpf, Bau.zylinder_mesh(0.26, 0.26, 0.01, 9), Look.holz(Look.KIEFER, 22.0, 0.0), Vector3(0, 0.503, 0))
	for i in 5:
		Bau.teil(stumpf, Bau.zylinder_mesh(0.07, 0.12, 0.6, 6), rinde, Vector3(cos(i * 1.3) * 0.38, 0.06, sin(i * 1.3) * 0.38), Vector3(70, -rad_to_deg(i * 1.3) + 90.0, 0))
	Bau.teil(stumpf, Bau.zylinder_mesh(0.012, 0.03, 0.9, 5), rinde, Vector3(0.2, 0.9, 0.05), Vector3(8, 0, -14))
	# Die Luke
	Bau.teil(k, Bau.box_mesh(Vector3(1.15, 0.08, 1.15)), _dunkel(), Vector3(0, 0.03, 0))
	_luke_deckel = _knoten("Lukendeckel", Vector3(0, 0.075, -0.5), 0.0, k)
	Bau.teil(_luke_deckel, Bau.box_mesh(Vector3(1.0, 0.06, 1.0)), Look.holz(Look.ALTHOLZ, 6.0, 0.0, 0.2, false), Vector3(0, 0, 0.5))
	for x in [-0.3, 0.3]:
		Bau.teil(_luke_deckel, Bau.box_mesh(Vector3(0.08, 0.02, 0.95)), _eisen(), Vector3(x, 0.035, 0.5))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.06
	ring.outer_radius = 0.08
	Bau.teil(_luke_deckel, ring, _eisen(), Vector3(0, 0.05, 0.85))
	Bau.teil(k, Bau.box_mesh(Vector3(0.96, 0.02, 0.96)), Bau.mat(Color(0.03, 0.02, 0.02)), Vector3(0, 0.072, 0))
	# Der Setzling liegt in der Luke und wird sichtbar, wenn sie offen ist
	var setzling := _knoten("Setzling", Vector3(0.1, 0.08, 0.05), 0.0, k)
	Bau.teil(setzling, Bau.zylinder_mesh(0.09, 0.07, 0.1, 10), Look.putz(Color(0.62, 0.34, 0.2), Color(0.5, 0.26, 0.16), 40.0), Vector3(0, 0.05, 0))
	Bau.teil(setzling, Bau.zylinder_mesh(0.006, 0.01, 0.22, 5), Bau.mat(Color(0.3, 0.42, 0.16)), Vector3(0, 0.2, 0))
	for s in [-1.0, 1.0]:
		Bau.teil(setzling, Bau.kugel_mesh(0.05, false, 8), Bau.mat(Color(0.36, 0.56, 0.2)), Vector3(s * 0.05, 0.3, 0), Vector3(0, 0, s * 30.0), Vector3(1, 0.25, 0.7))
	setzling.visible = false
	_luke = Interaktiv.erzeuge(k, Vector3(1.2, 0.5, 1.2), Vector3(0, 0.25, 0), "Luke öffnen", func(_s): luke_oeffnen())
	_luke.collision_layer = 0


## Öffnet die Luke: Opas Brief, danach der Abspann.
func luke_oeffnen() -> void:
	var setzling: Node3D = find_child("Setzling", true, false)
	if setzling:
		setzling.visible = true
	if _luke_deckel and _luke_deckel.rotation_degrees.x > -10.0:
		Sfx.spiele("knarzen", -4.0, 0.7)
		var tw := create_tween()
		tw.tween_property(_luke_deckel, "rotation_degrees:x", -105.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Game.extra["luke_offen"] = true
	_luke.text = "Opas Brief noch einmal lesen"
	welt._menue(welt.menues.zeige_ende.bind(BRIEF_OPA))


# --- Bauten rund um den Berg -----------------------------------------------------------
func _bauen(aera: int, neu: bool) -> void:
	if _gebaut.has(aera):
		return
	var k := _knoten("Aera%d" % aera, Vector3.ZERO)
	_gebaut[aera] = k
	var text := ""
	match aera:
		2:
			_aera_hang(k)
			text = "Am Berg stehen jetzt Arbeitslampen und ein Bretterweg."
		3:
			_aera_kern(k)
			text = "Der Hof wird zum Betrieb: Gerüst, Seilwinde und Lagerzelte."
		4:
			_aera_fuss(k)
			text = "Lichterketten an den Förderbändern, Laternen an den Posten, ein Hochsilo."
		_:
			return
	_nacht_schalten(Game.ist_nacht())
	if neu:
		Sfx.spiele("glocke", -4.0)
		Game.toast.emit(text, Game.FARBE_INFO)
		for c in k.get_children():
			if c is Node3D:
				var ziel: Vector3 = (c as Node3D).scale
				(c as Node3D).scale = ziel * 0.01
				var tw := create_tween()
				tw.tween_interval(randf_range(0.0, 0.8))
				tw.tween_property(c, "scale", ziel, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ära 2: Arbeitslampen, Bretterweg zum Berg, Werkzeugkiste.
func _aera_hang(k: Node3D) -> void:
	for p in [Vector2(-7.5, -11.6), Vector2(9.2, -11.4), Vector2(-17.5, -17.0), Vector2(20.0, -18.5)]:
		var l := _knoten("Arbeitslampe", _boden(p.x, p.y), rad_to_deg(atan2(Nussberg.MITTE.x - p.x, Nussberg.MITTE.z - p.y)) - 90.0, k)
		_laterne(l, Vector3.ZERO, 3.0)
	var weg := _knoten("Bretterweg", _boden(1.0, -11.2), 0.0, k)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in 9:
		var b := Bau.teil(weg, Bau.box_mesh(Vector3(1.3, 0.04, 0.24)), _alt(), Vector3(rng.randf_range(-0.05, 0.05), 0.03, -i * 0.27), Vector3(0, rng.randf_range(-4, 4), 0))
		b.set_meta("ohne_rand", true)
	var kiste := _knoten("Werkzeugkiste", _boden(4.6, -9.6), 25.0, k)
	Bau.block(kiste, Vector3(0.9, 0.45, 0.5), Vector3(0, 0.225, 0), Look.lackiert(Color(0.2, 0.36, 0.5), 0.4))
	Bau.teil(kiste, Bau.box_mesh(Vector3(0.94, 0.06, 0.54)), _eisen(), Vector3(0, 0.47, 0))
	Bau.teil(kiste, Bau.box_mesh(Vector3(0.035, 0.9, 0.045)), Look.holz(Look.EICHE, 9.0, 0.2), Vector3(0.6, 0.42, 0.1), Vector3(0, 0, 22))
	Bau.teil(kiste, Bau.box_mesh(Vector3(0.22, 0.012, 0.26)), _eisen(), Vector3(0.78, 0.04, 0.1), Vector3(0, 0, 22))


## Ära 3: Gerüst, Seilwinde, Betriebsschild, Lagerzelte.
func _aera_kern(k: Node3D) -> void:
	var ger := _knoten("Geruest", _boden(11.5, -12.8), 20.0, k)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Bau.teil(ger, Bau.zylinder_mesh(0.04, 0.04, 4.2, 8), _eisen(), Vector3(sx, 2.1, sz * 0.7))
	for y in [1.4, 2.8, 4.1]:
		Bau.block(ger, Vector3(2.2, 0.06, 1.5), Vector3(0, y, 0), _alt(), false)
		for sz in [-0.7, 0.7]:
			Bau.teil(ger, Bau.zylinder_mesh(0.025, 0.025, 2.0, 6), _eisen(), Vector3(0, y + 0.5, sz), Vector3(0, 0, 90))
	Bau.teil(ger, Bau.zylinder_mesh(0.025, 0.025, 3.2, 6), _eisen(), Vector3(-1.0, 1.4, 0), Vector3(55, 0, 0))
	Bau.teil(ger, Bau.zylinder_mesh(0.025, 0.025, 3.2, 6), _eisen(), Vector3(1.0, 2.7, 0), Vector3(-55, 0, 0))
	var winde := _knoten("Seilwinde", _boden(-10.5, -13.5), -30.0, k)
	for i in 3:
		var w := TAU * i / 3.0
		Bau.teil(winde, Bau.zylinder_mesh(0.05, 0.06, 3.3, 8), _dunkel(), Vector3(cos(w) * 0.6, 1.5, sin(w) * 0.6), Vector3(sin(w) * -22.0, 0, cos(w) * 22.0))
	Bau.teil(winde, Bau.zylinder_mesh(0.16, 0.16, 0.1, 12), _eisen(), Vector3(0, 2.75, 0), Vector3(0, 0, 90))
	Bau.teil(winde, Bau.zylinder_mesh(0.01, 0.01, 2.2, 4), Bau.mat(Color(0.75, 0.68, 0.5)), Vector3(0, 1.6, 0))
	Bau.teil(winde, Bau.zylinder_mesh(0.3, 0.24, 0.36, 12), Look.holz(Look.KIEFER, 14.0, 0.0), Vector3(0, 0.4, 0))
	Bau.teil(winde, Bau.kugel_mesh(0.27, true, 10), Look.nusshaufen(0.05), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	var schild := _knoten("Betriebsschild", _boden(3.4, -10.4), -20.0, k)
	Bau.teil(schild, Bau.box_mesh(Vector3(0.09, 1.7, 0.09)), _dunkel(), Vector3(0, 0.85, 0))
	Bau.holzschild(schild, "BETRIEBSGELÄNDE\nBetreten auf eigene Nuss", Vector3(0, 1.45, 0.06), Vector2(1.5, 0.5), Vector3(0, 0, 2), 58)
	for z in [[Vector2(-17.0, -8.0), 35.0, Color(0.78, 0.7, 0.5)], [Vector2(-19.8, -10.6), 60.0, Color(0.5, 0.56, 0.4)]]:
		var p: Vector2 = z[0]
		var zelt := _knoten("Lagerzelt", _boden(p.x, p.y), z[1], k)
		var tuch := Look.stoff(z[2])
		for s in [-1.0, 1.0]:
			Bau.teil(zelt, Bau.box_mesh(Vector3(2.6, 0.03, 1.9)), tuch, Vector3(0, 0.82, s * 0.62), Vector3(s * 52.0, 0, 0))
			Bau.teil(zelt, Bau.zylinder_mesh(0.03, 0.03, 1.7, 6), _dunkel(), Vector3(s * 1.3, 0.8, 0))
		Bau.teil(zelt, Bau.zylinder_mesh(0.025, 0.025, 2.7, 6), _dunkel(), Vector3(0, 1.42, 0), Vector3(0, 0, 90))
		Einrichtung.sack(zelt, Vector3(-0.5, 0, 0.1), 20.0, "wal")
		Einrichtung.sack(zelt, Vector3(0.3, 0, -0.1), 70.0, "hasel")


## Ära 4: Lichterketten an den Förderbändern, Laternen an den Posten, Hochsilo.
func _aera_fuss(k: Node3D) -> void:
	for po in Data.POSTEN:
		var p: Vector3 = po.pos
		var zum_berg := Vector2(Nussberg.MITTE.x - p.x, Nussberg.MITTE.z - p.z).normalized()
		var lp := Vector2(p.x, p.z) - zum_berg.orthogonal() * 2.6
		_laterne(_knoten("Postenlaterne", _boden(lp.x, lp.y), 0.0, k), Vector3.ZERO, 3.2)
	var silo := _knoten("Hochsilo", _boden(-9.6, -3.0), 0.0, k)
	var blech := Look.metall(Color(0.62, 0.65, 0.68), 0.45)
	for sx in [-0.8, 0.8]:
		for sz in [-0.8, 0.8]:
			Bau.teil(silo, Bau.box_mesh(Vector3(0.12, 2.4, 0.12)), _eisen(), Vector3(sx, 1.2, sz), Vector3(sz * 5.0, 0, sx * -5.0))
	Bau.teil(silo, Bau.zylinder_mesh(1.25, 1.25, 4.2, 20), blech, Vector3(0, 4.3, 0))
	Bau.teil(silo, Bau.zylinder_mesh(0.3, 1.25, 0.9, 20), blech, Vector3(0, 1.75, 0))
	Bau.teil(silo, Bau.zylinder_mesh(0.1, 1.3, 0.8, 20), Look.putz(Color(0.62, 0.24, 0.16), Color(0.5, 0.18, 0.12), 30.0, 0.0, 0.8), Vector3(0, 6.8, 0))
	for y in [2.6, 4.3, 6.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = 1.25
		ring.outer_radius = 1.29
		Bau.teil(silo, ring, _eisen(), Vector3(0, y, 0))
	Bau.schrift(silo, "NUSS", Vector3(0, 4.6, 1.26), 220, Color(0.55, 0.2, 0.12))
	var sb := StaticBody3D.new()
	sb.collision_layer = Data.L_WELT
	var cs := CollisionShape3D.new()
	var zyl := CylinderShape3D.new()
	zyl.radius = 1.0
	zyl.height = 3.0
	cs.shape = zyl
	cs.position = Vector3(0, 1.5, 0)
	sb.add_child(cs)
	silo.add_child(sb)
	_lichterketten()


## Lichterketten entlang aller gebauten Förderbänder (erst ab Ära 4).
func _lichterketten() -> void:
	if not _gebaut.has(4):
		return
	for po in Data.POSTEN:
		if not Game.posten.has(po.id) or _ketten.has(po.id):
			continue
		var punkte: Array = [po.pos] + po.weg
		var lagen: Array = []
		for i in punkte.size() - 1:
			var a: Vector3 = punkte[i]
			var b: Vector3 = punkte[i + 1]
			var n := maxi(2, int(a.distance_to(b) / 0.9))
			for j in n:
				var t := float(j) / n
				var p := a.lerp(b, t)
				var durchhang := sin(fmod(t * a.distance_to(b), 4.0) / 4.0 * PI) * 0.28
				lagen.append(Transform3D(Basis(), Vector3(p.x + 0.42, 3.05 - durchhang, p.z)))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Bau.kugel_mesh(0.055, false, 6)
		mm.instance_count = lagen.size()
		for i in lagen.size():
			mm.set_instance_transform(i, lagen[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Lichterkette_" + str(po.id)
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.material_override = _licht_mat(Game.ist_nacht())
		(_gebaut[4] as Node3D).add_child(mmi)
		_birnen.append(mmi)
		_ketten[po.id] = mmi
