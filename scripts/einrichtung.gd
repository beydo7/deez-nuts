class_name Einrichtung
extends RefCounted
## Möbel und Deko, die nur gut aussehen sollen (Platzhalter, bis Blender-Modelle kommen).


## Rohr (Zylinder) zwischen zwei Punkten.
static func rohr(eltern: Node3D, von: Vector3, bis: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mitte := (von + bis) * 0.5
	var laenge := von.distance_to(bis)
	var mi := Bau.mesh_instanz(Bau.zylinder_mesh(radius, radius, laenge, 16), material)
	eltern.add_child(mi)
	mi.global_position = mitte
	var richtung := (bis - von).normalized()
	var achse := Vector3.UP.cross(richtung)
	if achse.length() > 0.0001:
		mi.global_basis = Basis(achse.normalized(), Vector3.UP.angle_to(richtung))
	return mi


static func tisch(eltern: Node3D, pos: Vector3, groesse: Vector3) -> void:
	var platte := Look.holz(Look.EICHE, 5.0, 0.35)
	var dunkel := Look.holz(Look.NUSSBAUM, 6.0, 0.2)
	Bau.block(eltern, Vector3(groesse.x, 0.06, groesse.z), pos + Vector3(0, groesse.y - 0.03, 0), platte)
	Bau.block(eltern, Vector3(groesse.x - 0.12, 0.09, groesse.z - 0.12), pos + Vector3(0, groesse.y - 0.105, 0), dunkel, false)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var p := pos + Vector3(sx * (groesse.x * 0.5 - 0.09), (groesse.y - 0.06) * 0.5, sz * (groesse.z * 0.5 - 0.09))
			var bein := Node3D.new()
			bein.position = p
			eltern.add_child(bein)
			Bau.teil(bein, Bau.zylinder_mesh(0.04, 0.03, groesse.y - 0.06, 12), dunkel)
			Bau.teil(bein, Bau.kugel_mesh(0.045, false, 12), dunkel, Vector3(0, (groesse.y - 0.06) * 0.25, 0))
	var sb := StaticBody3D.new()
	sb.collision_layer = Data.L_WELT
	sb.position = pos + Vector3(0, (groesse.y - 0.06) * 0.5, 0)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(groesse.x - 0.2, groesse.y - 0.06, groesse.z - 0.2)
	cs.shape = b
	sb.add_child(cs)
	eltern.add_child(sb)


static func hocker(eltern: Node3D, pos: Vector3) -> void:
	var holz := Look.holz(Look.KIEFER, 8.0, 0.25)
	var n := Node3D.new()
	n.position = pos
	eltern.add_child(n)
	Bau.teil(n, Bau.zylinder_mesh(0.17, 0.16, 0.045, 24), holz, Vector3(0, 0.55, 0))
	for i in 3:
		var w := TAU * i / 3.0
		var bein := Bau.teil(n, Bau.zylinder_mesh(0.02, 0.025, 0.56, 8), holz, Vector3(cos(w) * 0.12, 0.27, sin(w) * 0.12))
		bein.rotation = Vector3(sin(w) * 0.12, 0, -cos(w) * 0.12)


static func sack(eltern: Node3D, pos: Vector3, drehung := 0.0, nuss := "wal") -> void:
	var jute := Look.putz(Color(0.72, 0.6, 0.42), Color(0.6, 0.48, 0.32), 260.0, 0.0, 1.0)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = drehung
	eltern.add_child(n)
	Bau.teil(n, Bau.kugel_mesh(1.0, false, 20), jute, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(0.28, 0.32, 0.24))
	Bau.teil(n, Bau.zylinder_mesh(0.07, 0.16, 0.14, 14), jute, Vector3(0, 0.6, 0))
	Bau.teil(n, Bau.zylinder_mesh(0.075, 0.075, 0.025, 14), Look.stoff(Color(0.5, 0.35, 0.2)), Vector3(0, 0.62, 0))
	Bau.schrift(n, "NÜSSE", Vector3(0, 0.34, 0.245), 90, Color(0.3, 0.18, 0.1, 0.85), Vector3(-8, 0, 0))
	for i in 4:
		var mi := Bau.teil(n, Nussmodelle.ganz(nuss, i % 3, 1), Look.nuss(nuss), Vector3(randf_range(-0.25, 0.25), 0.04, 0.3 + randf_range(0, 0.15)), Vector3(randf() * 360, randf() * 360, 0))
		mi.set_meta("ohne_rand", true)


static func haengelampe(eltern: Node3D, pos: Vector3, energie := 1.6) -> OmniLight3D:
	var schirm := Look.metall(Color(0.18, 0.36, 0.28), 0.5)
	var kabel_l := 3.0 - pos.y - 0.2
	Bau.teil(eltern, Bau.zylinder_mesh(0.004, 0.004, kabel_l, 6), Look.plastik(Color(0.1, 0.1, 0.1)), pos + Vector3(0, 0.2 + kabel_l * 0.5, 0))
	var s := CylinderMesh.new()
	s.top_radius = 0.05
	s.bottom_radius = 0.22
	s.height = 0.16
	s.cap_bottom = false
	s.radial_segments = 24
	var m := schirm.duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	Bau.teil(eltern, s, m, pos + Vector3(0, 0.12, 0))
	Bau.teil(eltern, Bau.kugel_mesh(0.045, false, 12), Look.leuchten(Color(1.0, 0.85, 0.6), 6.0), pos + Vector3(0, 0.05, 0))
	var licht := OmniLight3D.new()
	licht.position = pos
	licht.light_color = Color(1.0, 0.78, 0.52)
	licht.light_energy = energie
	licht.omni_range = 7.5
	licht.omni_attenuation = 1.2
	licht.shadow_enabled = true
	licht.light_volumetric_fog_energy = 0.4
	eltern.add_child(licht)
	return licht


## Wanduhr. Gibt den Knoten mit den Zeigern zurück (minute, stunde).
static func uhr(eltern: Node3D, pos: Vector3, drehung_y: float) -> Array:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = drehung_y
	eltern.add_child(n)
	Bau.teil(n, Bau.zylinder_mesh(0.19, 0.19, 0.04, 32), Look.holz(Look.NUSSBAUM, 4.0, 0.5), Vector3.ZERO, Vector3(90, 0, 0))
	Bau.teil(n, Bau.zylinder_mesh(0.165, 0.165, 0.005, 32), Look.plastik(Color(0.96, 0.93, 0.85), 0.3), Vector3(0, 0, 0.021), Vector3(90, 0, 0))
	for i in 12:
		var w := TAU * i / 12.0
		var gross := i % 3 == 0
		Bau.teil(n, Bau.box_mesh(Vector3(0.008, 0.03 if gross else 0.016, 0.003)), Look.plastik(Color(0.15, 0.1, 0.08)), Vector3(sin(w) * 0.14, cos(w) * 0.14, 0.025), Vector3(0, 0, -rad_to_deg(w)))
	var minute := Node3D.new()
	minute.position.z = 0.03
	n.add_child(minute)
	Bau.teil(minute, Bau.box_mesh(Vector3(0.008, 0.13, 0.003)), Look.plastik(Color(0.1, 0.08, 0.06)), Vector3(0, 0.055, 0))
	var stunde := Node3D.new()
	stunde.position.z = 0.033
	n.add_child(stunde)
	Bau.teil(stunde, Bau.box_mesh(Vector3(0.012, 0.085, 0.003)), Look.plastik(Color(0.1, 0.08, 0.06)), Vector3(0, 0.035, 0))
	Bau.teil(n, Bau.zylinder_mesh(0.012, 0.012, 0.01, 12), Look.metall(Color(0.8, 0.65, 0.3)), Vector3(0, 0, 0.036), Vector3(90, 0, 0))
	return [minute, stunde]


static func telefon(eltern: Node3D, pos: Vector3, drehung_y: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = drehung_y
	eltern.add_child(n)
	var rot := Look.plastik(Color(0.72, 0.1, 0.08), 0.25)
	Bau.teil(n, Bau.box_mesh(Vector3(0.34, 0.03, 0.2)), Look.holz(Look.NUSSBAUM, 5.0, 0.3), Vector3(0, -0.015, 0.06))
	Bau.teil(n, Bau.kugel_mesh(1.0, true, 20), rot, Vector3(0, 0.0, 0.07), Vector3.ZERO, Vector3(0.12, 0.11, 0.1))
	Bau.teil(n, Bau.zylinder_mesh(0.055, 0.055, 0.012, 24), Look.plastik(Color(0.95, 0.92, 0.85), 0.3), Vector3(0, 0.07, 0.12), Vector3(55, 0, 0))
	var hoerer := Node3D.new()
	hoerer.position = Vector3(0, 0.1, 0.05)
	n.add_child(hoerer)
	Bau.teil(hoerer, Bau.zylinder_mesh(0.016, 0.016, 0.2, 10), rot, Vector3.ZERO, Vector3(0, 0, 90))
	for s in [-1, 1]:
		Bau.teil(hoerer, Bau.zylinder_mesh(0.032, 0.026, 0.04, 14), rot, Vector3(s * 0.1, -0.012, 0))
	return n


static func pflanze(eltern: Node3D, pos: Vector3, groesse := 1.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * groesse
	eltern.add_child(n)
	Bau.teil(n, Bau.zylinder_mesh(0.08, 0.06, 0.13, 18), Look.putz(Color(0.78, 0.42, 0.25), Color(0.65, 0.33, 0.2), 120.0, 0.0, 0.8), Vector3(0, 0.065, 0))
	Bau.teil(n, Bau.zylinder_mesh(0.072, 0.072, 0.01, 18), Look.putz(Color(0.3, 0.2, 0.12)), Vector3(0, 0.125, 0))
	var gruen := Look.laub(Color(0.35, 0.55, 0.2), Color(0.18, 0.35, 0.12))
	for i in 5:
		var w := TAU * i / 5.0
		Bau.teil(n, Bau.kugel_mesh(0.07, false, 12), gruen, Vector3(cos(w) * 0.05, 0.2 + (i % 2) * 0.05, sin(w) * 0.05))


static func vorhang(eltern: Node3D, pos: Vector3, hoehe: float, farbe: Color) -> void:
	var stoff := Look.stoff(farbe)
	var n := Node3D.new()
	n.position = pos
	eltern.add_child(n)
	for i in 5:
		Bau.teil(n, Bau.zylinder_mesh(0.035, 0.05, hoehe, 10), stoff, Vector3((i - 2) * 0.05, -hoehe * 0.5, (i % 2) * 0.02))


static func regal(eltern: Node3D, pos: Vector3, breite: float, faecher: int, drehung_y := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = drehung_y
	eltern.add_child(n)
	var holz := Look.holz(Look.NUSSBAUM, 6.0, 0.3)
	for i in faecher:
		Bau.teil(n, Bau.box_mesh(Vector3(breite, 0.025, 0.24)), holz, Vector3(0, i * 0.4, 0.12))
		for s in [-1, 1]:
			Bau.teil(n, Bau.box_mesh(Vector3(0.025, 0.06, 0.2)), holz, Vector3(s * (breite * 0.5 - 0.05), i * 0.4 - 0.04, 0.12), Vector3(0, 0, 0))
	return n


## Ein Einmachglas voller Kerne (nur Deko).
static func vorratsglas(eltern: Node3D, pos: Vector3, nuss: String, fuell := 0.8, hoehe := 0.2) -> void:
	var n := Node3D.new()
	n.position = pos
	eltern.add_child(n)
	var r := 0.065
	var g := CylinderMesh.new()
	g.top_radius = r
	g.bottom_radius = r
	g.height = hoehe
	g.radial_segments = 20
	Bau.teil(n, g, Look.glas(), Vector3(0, hoehe * 0.5, 0))
	var deckel_farben := [Color(0.75, 0.15, 0.1), Color(0.85, 0.65, 0.2), Color(0.2, 0.45, 0.3), Color(0.25, 0.35, 0.6)]
	Bau.teil(n, Bau.zylinder_mesh(r + 0.006, r + 0.006, 0.02, 20), Look.metall(deckel_farben[hash(pos) % 4], 0.4), Vector3(0, hoehe + 0.01, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos)
	var anzahl := int(14 * fuell * hoehe / 0.2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Nussmodelle.kernhaelfte(nuss, 0)
	mm.instance_count = anzahl
	for i in anzahl:
		var w := rng.randf() * TAU
		var rr := rng.randf_range(0.0, r - 0.025)
		mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-1, 1), rng.randf() * TAU, rng.randf_range(-1, 1))), Vector3(cos(w) * rr, 0.02 + i * (hoehe * fuell - 0.02) / anzahl, sin(w) * rr)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Look.kern(nuss)
	n.add_child(mmi)


static func baum(eltern: Node3D, pos: Vector3, hoehe: float, farbe: Color, farbe2: Color, rng: RandomNumberGenerator) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rng.randf() * TAU
	eltern.add_child(n)
	var rinde := Look.holz([Color(0.36, 0.27, 0.2), Color(0.2, 0.14, 0.1)], 14.0, 0.0)
	Bau.teil(n, Bau.zylinder_mesh(0.14 * hoehe / 5.0, 0.24 * hoehe / 5.0, hoehe * 0.55, 10), rinde, Vector3(0, hoehe * 0.275, 0))
	var laub := Look.laub(farbe, farbe2)
	var r := hoehe * 0.3
	for i in 5:
		var off := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.6, 0.6)) * r
		var k := Bau.kugel_mesh(r * rng.randf_range(0.7, 1.0), false, 18)
		Bau.teil(n, k, laub, Vector3(0, hoehe * 0.62, 0) + off)


static func tanne(eltern: Node3D, pos: Vector3, hoehe: float) -> void:
	var n := Node3D.new()
	n.position = pos
	eltern.add_child(n)
	var gruen := Look.laub(Color(0.16, 0.3, 0.15), Color(0.08, 0.18, 0.1))
	Bau.teil(n, Bau.zylinder_mesh(0.1, 0.15, hoehe * 0.3, 8), Look.holz(Look.NUSSBAUM), Vector3(0, hoehe * 0.15, 0))
	for i in 3:
		var h := hoehe * (0.55 - i * 0.12)
		Bau.teil(n, Bau.zylinder_mesh(0.0, hoehe * (0.28 - i * 0.06), h, 10), gruen, Vector3(0, hoehe * (0.35 + i * 0.2) + h * 0.3, 0))


static func sessel(eltern: Node3D, pos: Vector3, drehung_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = drehung_y
	eltern.add_child(n)
	var bezug := Look.stoff(Color(0.42, 0.52, 0.32))
	var holz := Look.holz(Look.NUSSBAUM, 6.0, 0.4)
	Bau.teil(n, Bau.box_mesh(Vector3(0.7, 0.18, 0.65)), bezug, Vector3(0, 0.36, 0))
	Bau.teil(n, Bau.box_mesh(Vector3(0.7, 0.62, 0.16)), bezug, Vector3(0, 0.72, -0.27), Vector3(-8, 0, 0))
	for s in [-1, 1]:
		Bau.teil(n, Bau.box_mesh(Vector3(0.12, 0.26, 0.62)), bezug, Vector3(s * 0.33, 0.55, 0))
		for v in [-1, 1]:
			Bau.teil(n, Bau.zylinder_mesh(0.025, 0.02, 0.27, 8), holz, Vector3(s * 0.3, 0.135, v * 0.26))
	Bau.teil(n, Bau.box_mesh(Vector3(0.44, 0.1, 0.4)), Look.stoff(Color(0.85, 0.75, 0.55)), Vector3(0, 0.5, 0.05), Vector3(-6, 0, 0))


static func teppich(eltern: Node3D, pos: Vector3, groesse: Vector2, farbe: Color, farbe2: Color) -> void:
	var t := Bau.teil(eltern, Bau.box_mesh(Vector3(groesse.x, 0.008, groesse.y)), Look.putz(farbe, farbe2, 300.0, 0.25, 1.0), pos + Vector3(0, 0.004, 0))
	t.set_meta("ohne_rand", true)
