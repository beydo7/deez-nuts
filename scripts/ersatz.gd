class_name Ersatz
extends RefCounted
## Ersatzmodelle aus Code für die Modellplätze, bis die Blender-Modelle da sind.
## Jedes baut in den übergebenen Knoten, Ursprung am Boden in der Mitte, Front nach +Z.
## Die Maße entsprechen der Modellliste im Weltplan.


## Holzbrücke mit leichtem Bogen. Sie spannt entlang der lokalen X-Achse.
static func bruecke(k: Node3D, laenge: float, breite: float, bogen: float) -> void:
	var holz := Look.holz(Look.ALTHOLZ, 9.0, 0.0)
	var balken := Look.holz(Look.NUSSBAUM, 6.0, 0.0)
	var hoehe := func(x: float) -> float:
		var t := x / (laenge * 0.5)
		return bogen * (1.0 - t * t) + 0.08
	# Bohlen quer zur Laufrichtung, leicht unregelmäßig
	var rng := RandomNumberGenerator.new()
	rng.seed = int(laenge * 100.0)
	var x := -laenge * 0.5 + 0.12
	while x < laenge * 0.5 - 0.1:
		var y: float = hoehe.call(x)
		var steig: float = (float(hoehe.call(x + 0.05)) - float(hoehe.call(x - 0.05))) / 0.1
		var brett := Bau.teil(k, Bau.box_mesh(Vector3(0.21, 0.05, breite + rng.randf_range(-0.06, 0.06))), holz,
			Vector3(x, y, rng.randf_range(-0.03, 0.03)), Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5), rad_to_deg(atan(steig))))
		brett.set_meta("ohne_rand", true)
		x += 0.235
	# Tragbalken und Geländer
	var stuecke := 8
	for seite in [-1.0, 1.0]:
		for i in stuecke:
			var x0 := -laenge * 0.5 + laenge * float(i) / stuecke
			var x1 := -laenge * 0.5 + laenge * float(i + 1) / stuecke
			var y0: float = hoehe.call(x0)
			var y1: float = hoehe.call(x1)
			var mitte := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5 - 0.09, seite * (breite * 0.5 - 0.08))
			var winkel := rad_to_deg(atan2(y1 - y0, x1 - x0))
			var l := Vector2(x1 - x0, y1 - y0).length() + 0.02
			Bau.teil(k, Bau.box_mesh(Vector3(l, 0.14, 0.14)), balken, mitte, Vector3(0, 0, winkel))
			Bau.teil(k, Bau.box_mesh(Vector3(l, 0.07, 0.08)), holz, mitte + Vector3(0, 0.98, seite * 0.02), Vector3(0, 0, winkel))
		for i in stuecke + 1:
			var xp := -laenge * 0.5 + laenge * float(i) / stuecke
			var yp: float = hoehe.call(xp)
			Bau.teil(k, Bau.box_mesh(Vector3(0.09, 1.0, 0.09)), balken, Vector3(xp, yp + 0.45, seite * (breite * 0.5 - 0.06)), Vector3(0, 0, rng.randf_range(-2.0, 2.0)))
	# Kollision: Bogen aus geneigten Platten, dazu Geländer
	var koerper := StaticBody3D.new()
	koerper.collision_layer = Data.L_WELT
	k.add_child(koerper)
	for i in stuecke:
		var x0 := -laenge * 0.5 + laenge * float(i) / stuecke
		var x1 := -laenge * 0.5 + laenge * float(i + 1) / stuecke
		var y0: float = hoehe.call(x0)
		var y1: float = hoehe.call(x1)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(Vector2(x1 - x0, y1 - y0).length() + 0.05, 0.12, breite)
		cs.shape = box
		cs.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5 - 0.035, 0)
		cs.rotation.z = atan2(y1 - y0, x1 - x0)
		koerper.add_child(cs)
	for seite in [-1.0, 1.0]:
		var cs2 := CollisionShape3D.new()
		var box2 := BoxShape3D.new()
		box2.size = Vector3(laenge, 1.2, 0.1)
		cs2.shape = box2
		cs2.position = Vector3(0, bogen + 0.6, seite * (breite * 0.5 - 0.06))
		koerper.add_child(cs2)


# --- Gemeinsame Helfer ---------------------------------------------------------
static func _alt() -> Material:
	return Look.holz(Look.ALTHOLZ, 9.0, 0.0)


static func _dunkel() -> Material:
	return Look.holz(Look.NUSSBAUM, 6.0, 0.1)


static func _stein() -> Material:
	return Look.putz(Color(0.6, 0.57, 0.52), Color(0.46, 0.44, 0.4), 26.0, 0.0, 0.95)


static func _ziegel() -> Material:
	return Look.putz(Color(0.62, 0.24, 0.16), Color(0.5, 0.18, 0.12), 30.0, 0.35, 0.8)


## Unsichtbare Kollisionsbox.
static func _koll(k: Node3D, groesse: Vector3, pos: Vector3, drehung := Vector3.ZERO) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = Data.L_WELT
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = groesse
	cs.shape = form
	sb.add_child(cs)
	sb.position = pos
	sb.rotation_degrees = drehung
	k.add_child(sb)


## Verwitterter Lattenzaun entlang der lokalen X-Achse. luecken = Felder, die fehlen.
static func zaun(k: Node3D, laenge: float, saat := 1, hoehe := 1.0, luecken: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = saat
	var holz := _alt()
	var felder := maxi(1, int(round(laenge / 2.0)))
	var schritt := laenge / felder
	for i in felder + 1:
		var x := -laenge * 0.5 + i * schritt
		Bau.teil(k, Bau.box_mesh(Vector3(0.11, hoehe + 0.25, 0.11)), holz, Vector3(x, hoehe * 0.5 - 0.05, 0),
			Vector3(rng.randf_range(-4, 4), rng.randf_range(0, 40), rng.randf_range(-4, 4)))
	for i in felder:
		if i in luecken:
			continue
		var x := -laenge * 0.5 + (i + 0.5) * schritt
		for y in [hoehe * 0.42, hoehe * 0.85]:
			var schief := rng.randf_range(-2.5, 2.5)
			if rng.randf() < 0.12:
				schief = rng.randf_range(8.0, 14.0)   # eine Latte hängt herunter
			Bau.teil(k, Bau.box_mesh(Vector3(schritt + 0.06, 0.09, 0.035)), holz, Vector3(x, y - absf(schief) * 0.012, rng.randf_range(-0.02, 0.02)), Vector3(0, 0, schief))
		_koll(k, Vector3(schritt, hoehe + 0.4, 0.12), Vector3(x, hoehe * 0.5, 0))


## Holzveranda an der Südseite der Hütte: 10 x 2,5 m, Front nach +Z.
static func veranda(k: Node3D) -> void:
	var dielen := Look.holz(Look.ALTHOLZ, 6.0, 0.0, 0.2, true)
	var holz := _dunkel()
	var deck := 0.2
	Bau.block(k, Vector3(10.0, deck, 2.5), Vector3(0, deck * 0.5, 0), dielen)
	# Treppe (zwei Stufen) mit Rampe als Kollision
	var tx := 1.25
	Bau.teil(k, Bau.box_mesh(Vector3(1.7, 0.1, 0.34)), dielen, Vector3(tx, 0.05, 1.42))
	_koll(k, Vector3(1.7, 0.06, 0.75), Vector3(tx, 0.085, 1.5), Vector3(16, 0, 0))
	# Pfosten, Geländer, Dach
	var pfosten := [-4.9, -2.45, 0.2, 2.3, 4.9]
	for x in pfosten:
		Bau.teil(k, Bau.box_mesh(Vector3(0.13, 2.25, 0.13)), holz, Vector3(x, deck + 1.125, 1.13))
		_koll(k, Vector3(0.14, 2.2, 0.14), Vector3(x, deck + 1.1, 1.13))
	for i in pfosten.size() - 1:
		if i == 2:
			continue   # Lücke für die Treppe
		var a: float = pfosten[i]
		var b: float = pfosten[i + 1]
		Bau.teil(k, Bau.box_mesh(Vector3(b - a, 0.07, 0.09)), holz, Vector3((a + b) * 0.5, deck + 0.92, 1.13))
		var n := int((b - a) / 0.22)
		for j in range(1, n):
			Bau.teil(k, Bau.box_mesh(Vector3(0.035, 0.86, 0.035)), holz, Vector3(a + (b - a) * float(j) / n, deck + 0.47, 1.13))
		_koll(k, Vector3(b - a, 1.0, 0.1), Vector3((a + b) * 0.5, deck + 0.5, 1.13))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.09, 0.07, 2.3)), holz, Vector3(s * 4.9, deck + 0.92, 0.0))
		for j in 9:
			Bau.teil(k, Bau.box_mesh(Vector3(0.035, 0.86, 0.035)), holz, Vector3(s * 4.9, deck + 0.47, -0.95 + j * 0.23))
		_koll(k, Vector3(0.1, 1.0, 2.3), Vector3(s * 4.9, deck + 0.5, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(10.5, 0.08, 2.95)), _ziegel(), Vector3(0, 2.62, 0.12), Vector3(9, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(10.0, 0.12, 0.12)), holz, Vector3(0, deck + 2.25, 1.13))
	# Schaukelstuhl
	var stuhl := Node3D.new()
	stuhl.name = "Schaukelstuhl"
	stuhl.position = Vector3(-3.3, deck, 0.1)
	stuhl.rotation_degrees.y = 18
	k.add_child(stuhl)
	var hell := Look.holz(Look.EICHE, 8.0, 0.2)
	Bau.teil(stuhl, Bau.box_mesh(Vector3(0.52, 0.04, 0.5)), hell, Vector3(0, 0.42, 0), Vector3(-6, 0, 0))
	Bau.teil(stuhl, Bau.box_mesh(Vector3(0.52, 0.04, 0.7)), hell, Vector3(0, 0.78, -0.3), Vector3(-78, 0, 0))
	for s in [-1.0, 1.0]:
		Bau.teil(stuhl, Bau.box_mesh(Vector3(0.04, 0.04, 0.85)), hell, Vector3(s * 0.25, 0.03, 0.0), Vector3(0, 0, 0))
		Bau.teil(stuhl, Bau.box_mesh(Vector3(0.04, 0.04, 0.18)), hell, Vector3(s * 0.25, 0.07, 0.48), Vector3(-28, 0, 0))
		Bau.teil(stuhl, Bau.box_mesh(Vector3(0.04, 0.04, 0.18)), hell, Vector3(s * 0.25, 0.07, -0.48), Vector3(28, 0, 0))
		for z in [-0.2, 0.2]:
			Bau.teil(stuhl, Bau.box_mesh(Vector3(0.04, 0.42, 0.04)), hell, Vector3(s * 0.25, 0.23, z))
		Bau.teil(stuhl, Bau.box_mesh(Vector3(0.05, 0.035, 0.5)), hell, Vector3(s * 0.27, 0.64, 0.0))
	Bau.teil(stuhl, Bau.box_mesh(Vector3(0.4, 0.07, 0.38)), Look.stoff(Color(0.62, 0.22, 0.18)), Vector3(0, 0.47, 0.02), Vector3(-6, 0, 0))
	# Schnitztisch: halb fertiges Eichhörnchen, Messer und Späne
	var tisch := Node3D.new()
	tisch.name = "Schnitztisch"
	tisch.position = Vector3(-2.2, deck, 0.35)
	k.add_child(tisch)
	Bau.teil(tisch, Bau.zylinder_mesh(0.24, 0.27, 0.5, 12), _alt(), Vector3(0, 0.25, 0))
	var roh := Look.holz(Look.KIEFER, 10.0, 0.0)
	Bau.teil(tisch, Bau.box_mesh(Vector3(0.1, 0.12, 0.1)), roh, Vector3(0.02, 0.56, 0), Vector3(0, 20, 0))
	Bau.teil(tisch, Bau.kugel_mesh(0.055, false, 12), roh, Vector3(0.02, 0.66, 0.0), Vector3.ZERO, Vector3(1, 1.15, 1))
	Bau.teil(tisch, Bau.kugel_mesh(0.04, false, 12), roh, Vector3(0.03, 0.75, 0.02))
	for s in [-1.0, 1.0]:
		Bau.teil(tisch, Bau.box_mesh(Vector3(0.012, 0.035, 0.02)), roh, Vector3(0.03 + s * 0.022, 0.795, 0.02))
	Bau.teil(tisch, Bau.box_mesh(Vector3(0.012, 0.004, 0.09)), Look.metall(Color(0.8, 0.8, 0.82), 0.25), Vector3(-0.12, 0.505, 0.08), Vector3(0, 35, 0))
	Bau.teil(tisch, Bau.box_mesh(Vector3(0.018, 0.016, 0.07)), _dunkel(), Vector3(-0.165, 0.508, 0.015), Vector3(0, 35, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	for i in 9:
		Bau.teil(tisch, Bau.box_mesh(Vector3(0.02, 0.003, 0.008)), roh, Vector3(rng.randf_range(-0.18, 0.18), 0.503, rng.randf_range(-0.18, 0.18)), Vector3(0, rng.randf() * 180, rng.randf_range(-20, 20)))
	# Bank an der Wand und Windspiel aus Nussschalen
	Bau.block(k, Vector3(1.8, 0.06, 0.4), Vector3(3.4, deck + 0.44, -0.95), _alt())
	for x in [2.65, 4.15]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.07, 0.44, 0.36)), _alt(), Vector3(x, deck + 0.22, -0.95))
	var spiel := Node3D.new()
	spiel.name = "Windspiel"
	spiel.position = Vector3(3.6, 2.42, 0.85)
	k.add_child(spiel)
	Bau.teil(spiel, Bau.zylinder_mesh(0.09, 0.09, 0.015, 12), _dunkel())
	for i in 5:
		var w := TAU * i / 5.0
		var l := 0.22 + 0.07 * (i % 3)
		var p := Vector3(cos(w) * 0.07, 0, sin(w) * 0.07)
		Bau.teil(spiel, Bau.zylinder_mesh(0.002, 0.002, l, 4), Bau.mat(Color(0.85, 0.8, 0.7)), p + Vector3(0, -l * 0.5, 0))
		Bau.teil(spiel, Bau.kugel_mesh(0.028, true, 10), Look.nuss("wal"), p + Vector3(0, -l, 0), Vector3(180, w * 57.0, 0))


## Ziehbrunnen mit Dach, Kurbel und Eimer.
static func brunnen(k: Node3D) -> void:
	var stein := _stein()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for reihe in 3:
		for i in 11:
			var w := TAU * (i + 0.5 * (reihe % 2)) / 11.0
			Bau.teil(k, Bau.box_mesh(Vector3(0.4, 0.27, 0.24)), stein, Vector3(cos(w) * 0.68, 0.13 + reihe * 0.265 + rng.randf_range(-0.01, 0.01), sin(w) * 0.68),
				Vector3(rng.randf_range(-3, 3), -rad_to_deg(w) + 90.0 + rng.randf_range(-5, 5), 0))
	Bau.teil(k, Bau.zylinder_mesh(0.6, 0.6, 0.02, 20), Bau.mat(Color(0.05, 0.12, 0.14), 0.08), Vector3(0, 0.4, 0))
	var holz := _dunkel()
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.12, 2.2, 0.12)), holz, Vector3(s * 0.86, 1.1, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(2.2, 0.06, 0.85)), _ziegel(), Vector3(0, 2.38, s * 0.33), Vector3(s * 32.0, 0, 0))
	var kurbel := Node3D.new()
	kurbel.name = "Kurbel"
	kurbel.position = Vector3(0, 1.75, 0)
	k.add_child(kurbel)
	Bau.teil(kurbel, Bau.zylinder_mesh(0.06, 0.06, 1.75, 10), holz, Vector3.ZERO, Vector3(0, 0, 90))
	Bau.teil(kurbel, Bau.box_mesh(Vector3(0.03, 0.3, 0.03)), Look.metall(Color(0.3, 0.3, 0.32), 0.5), Vector3(0.98, -0.13, 0))
	Bau.teil(kurbel, Bau.zylinder_mesh(0.02, 0.02, 0.16, 8), holz, Vector3(1.06, -0.28, 0), Vector3(0, 0, 90))
	Bau.teil(k, Bau.zylinder_mesh(0.008, 0.008, 0.75, 5), Bau.mat(Color(0.75, 0.68, 0.5)), Vector3(0.1, 1.37, 0))
	var eimer := Node3D.new()
	eimer.name = "Eimer"
	eimer.position = Vector3(0.1, 0.9, 0)
	k.add_child(eimer)
	Bau.teil(eimer, Bau.zylinder_mesh(0.15, 0.12, 0.24, 12), _alt())
	Bau.teil(eimer, Bau.zylinder_mesh(0.155, 0.155, 0.025, 12), Look.metall(Color(0.35, 0.35, 0.37), 0.5), Vector3(0, 0.07, 0))
	var sb := StaticBody3D.new()
	sb.collision_layer = Data.L_WELT
	var cs := CollisionShape3D.new()
	var z := CylinderShape3D.new()
	z.radius = 0.9
	z.height = 1.0
	cs.shape = z
	cs.position = Vector3(0, 0.5, 0)
	sb.add_child(cs)
	k.add_child(sb)


## Kleines Gewächshaus, 3 x 2 x 2,4 m, Tür an der Front (+Z).
static func gewaechshaus(k: Node3D) -> void:
	var weiss := Look.lackiert(Color(0.86, 0.88, 0.82), 0.3)
	var glas := Look.glas(Color(0.82, 0.95, 0.9))
	Bau.teil(k, Bau.box_mesh(Vector3(3.0, 0.35, 2.0)), _ziegel(), Vector3(0, 0.175, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(2.8, 0.04, 1.8)), Look.putz(Color(0.3, 0.22, 0.14), Color(0.22, 0.16, 0.1), 40.0), Vector3(0, 0.36, 0))
	for x in [-1.47, -0.5, 0.5, 1.47]:
		for z in [-0.97, 0.97]:
			Bau.teil(k, Bau.box_mesh(Vector3(0.06, 1.3, 0.06)), weiss, Vector3(x, 1.0, z))
	for z in [-0.97, 0.97]:
		Bau.teil(k, Bau.box_mesh(Vector3(3.0, 0.06, 0.06)), weiss, Vector3(0, 1.65, z))
		Bau.teil(k, Bau.box_mesh(Vector3(2.9, 1.24, 0.015)), glas, Vector3(0, 1.0, z))
	for x in [-1.47, 1.47]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.015, 1.24, 1.9)), glas, Vector3(x, 1.0, 0))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(3.0, 0.015, 1.28)), glas, Vector3(0, 2.0, s * 0.5), Vector3(s * 36.0, 0, 0))
		for x in [-1.47, -0.5, 0.5, 1.47]:
			Bau.teil(k, Bau.box_mesh(Vector3(0.05, 0.05, 1.28)), weiss, Vector3(x, 2.0, s * 0.5), Vector3(s * 36.0, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(3.05, 0.07, 0.07)), weiss, Vector3(0, 2.38, 0))
	var tuer := Node3D.new()
	tuer.name = "Tuer"
	tuer.position = Vector3(-0.48, 0.36, 1.0)
	tuer.rotation_degrees.y = -35
	k.add_child(tuer)
	Bau.teil(tuer, Bau.box_mesh(Vector3(0.94, 1.26, 0.04)), weiss, Vector3(0.47, 0.64, 0))
	Bau.teil(tuer, Bau.box_mesh(Vector3(0.8, 1.1, 0.045)), glas, Vector3(0.47, 0.64, 0))
	for i in 5:
		Modelle.setze(k, "natur/pot_small.glb", Vector3(-1.15 + i * 0.55, 0.38, -0.6), i * 70.0, 1.1)
		Modelle.setze(k, "natur/plant_flatTall.glb" if i % 2 == 0 else "natur/crops_leafsStageB.glb", Vector3(-1.15 + i * 0.55, 0.6, -0.6), i * 40.0, 1.0)
	Modelle.setze(k, "natur/crops_cornStageB.glb", Vector3(1.0, 0.38, 0.4), 0.0, 1.0)
	Modelle.setze(k, "natur/crops_leafsStageB.glb", Vector3(0.9, 0.38, -0.1), 50.0, 1.2)
	_koll(k, Vector3(3.0, 2.3, 2.0), Vector3(0, 1.15, 0))


## Hühnerstall auf Stelzen mit Leiter und Auslauf, 3 x 2 x 2,2 m.
static func huehnerstall(k: Node3D) -> void:
	var holz := _alt()
	var dunkel := _dunkel()
	for x in [-1.4, -0.3]:
		for z in [-0.6, 0.6]:
			Bau.teil(k, Bau.box_mesh(Vector3(0.09, 0.6, 0.09)), dunkel, Vector3(x, 0.3, z))
	Bau.teil(k, Bau.box_mesh(Vector3(1.3, 1.0, 1.4)), holz, Vector3(-0.85, 1.1, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(1.55, 0.07, 1.0)), _ziegel(), Vector3(-0.85, 1.85, 0.42), Vector3(30, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(1.55, 0.07, 1.0)), _ziegel(), Vector3(-0.85, 1.85, -0.42), Vector3(-30, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.02, 0.36, 0.3)), Bau.mat(Color(0.08, 0.06, 0.05)), Vector3(-0.195, 0.86, 0.2))
	var klappe := Node3D.new()
	klappe.name = "Klappe"
	klappe.position = Vector3(-0.19, 1.05, 0.2)
	k.add_child(klappe)
	Bau.teil(klappe, Bau.box_mesh(Vector3(0.03, 0.4, 0.34)), dunkel, Vector3(0.0, 0.2, 0))
	# Hühnerleiter
	Bau.teil(k, Bau.box_mesh(Vector3(1.0, 0.03, 0.26)), holz, Vector3(0.25, 0.34, 0.2), Vector3(0, 0, -34))
	for i in 5:
		Bau.teil(k, Bau.box_mesh(Vector3(0.03, 0.025, 0.26)), dunkel, Vector3(-0.1 + i * 0.17, 0.59 - i * 0.115, 0.2), Vector3(0, 0, -34))
	# Auslauf mit Maschendraht (angedeutet durch dünne Latten)
	var draht := Look.metall(Color(0.55, 0.56, 0.55), 0.6)
	for p in [Vector3(-0.2, 0, 0.98), Vector3(1.48, 0, 0.98), Vector3(1.48, 0, -0.98), Vector3(-0.2, 0, -0.98)]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.07, 1.1, 0.07)), dunkel, p + Vector3(0, 0.55, 0))
	for z in [-0.98, 0.98]:
		for y in [0.25, 0.6, 1.0]:
			Bau.teil(k, Bau.box_mesh(Vector3(1.68, 0.02, 0.02)), draht, Vector3(0.64, y, z))
		for i in 8:
			Bau.teil(k, Bau.box_mesh(Vector3(0.012, 1.0, 0.012)), draht, Vector3(-0.1 + i * 0.21, 0.5, z))
		_koll(k, Vector3(1.7, 1.1, 0.08), Vector3(0.64, 0.55, z))
	for y in [0.25, 0.6, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.02, 0.02, 1.96)), draht, Vector3(1.48, y, 0))
	for i in 9:
		Bau.teil(k, Bau.box_mesh(Vector3(0.012, 1.0, 0.012)), draht, Vector3(1.48, 0.5, -0.9 + i * 0.225))
	_koll(k, Vector3(0.08, 1.1, 1.96), Vector3(1.48, 0.55, 0))
	_koll(k, Vector3(1.3, 1.9, 1.4), Vector3(-0.85, 0.95, 0))
	# Futternapf und Stroh
	Bau.teil(k, Bau.zylinder_mesh(0.16, 0.13, 0.06, 12), Look.metall(Color(0.6, 0.6, 0.62), 0.4), Vector3(0.9, 0.03, -0.4))
	Bau.teil(k, Bau.zylinder_mesh(0.12, 0.12, 0.02, 12), Look.nusshaufen(0.03), Vector3(0.9, 0.055, -0.4))


## Überdachtes Holzlager mit Hackklotz, 3 x 1,2 x 2 m.
static func holzlager(k: Node3D) -> void:
	var dunkel := _dunkel()
	for x in [-1.42, 1.42]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.1, 2.0, 0.1)), dunkel, Vector3(x, 1.0, -0.5))
		Bau.teil(k, Bau.box_mesh(Vector3(0.1, 1.7, 0.1)), dunkel, Vector3(x, 0.85, 0.5))
	Bau.teil(k, Bau.box_mesh(Vector3(3.3, 0.06, 1.5)), _ziegel(), Vector3(0, 1.9, 0.0), Vector3(16, 0, 0))
	Modelle.setze(k, "rohstoffe/Wood_Log_Stack.gltf", Vector3(-0.7, 0, 0), 0.0, 0.78)
	Modelle.setze(k, "rohstoffe/Wood_Log_Stack.gltf", Vector3(0.68, 0, 0.02), 180.0, 0.74)
	_koll(k, Vector3(3.0, 1.5, 1.2), Vector3(0, 0.75, 0))
	# Hackklotz mit Axt
	stumpf(k, Vector3(2.3, 0, 0.9), 0.3, 0.46)
	_koll(k, Vector3(0.6, 0.5, 0.6), Vector3(2.3, 0.25, 0.9))
	var axt := Node3D.new()
	axt.position = Vector3(2.3, 0.46, 0.9)
	axt.rotation_degrees = Vector3(0, 40, -32)
	k.add_child(axt)
	Bau.teil(axt, Bau.box_mesh(Vector3(0.035, 0.7, 0.045)), Look.holz(Look.EICHE, 9.0, 0.2), Vector3(0, 0.38, 0))
	Bau.teil(axt, Bau.box_mesh(Vector3(0.2, 0.11, 0.03)), Look.metall(Color(0.42, 0.43, 0.46), 0.4), Vector3(0.06, 0.06, 0))
	var scheit := Look.holz(Look.KIEFER, 12.0, 0.0)
	for i in 5:
		Bau.teil(k, Bau.box_mesh(Vector3(0.1, 0.09, 0.36)), scheit, Vector3(1.85 + (i % 3) * 0.32, 0.05, 1.45 + (i / 3) * 0.3), Vector3(0, 20.0 + i * 47.0, 8.0 * (i % 2)))


## Briefkasten auf einem Pfahl, Front nach +Z.
static func briefkasten(k: Node3D) -> void:
	var lack := Look.lackiert(Color(0.78, 0.6, 0.16), 0.35)
	Bau.teil(k, Bau.box_mesh(Vector3(0.1, 1.05, 0.1)), _dunkel(), Vector3(0, 0.52, 0), Vector3(0, 0, 3))
	Bau.teil(k, Bau.box_mesh(Vector3(0.3, 0.2, 0.46)), lack, Vector3(0.03, 1.13, 0))
	Bau.teil(k, Bau.zylinder_mesh(0.15, 0.15, 0.46, 14), lack, Vector3(0.03, 1.23, 0), Vector3(90, 0, 0))
	var deckel := Node3D.new()
	deckel.name = "Deckel"
	deckel.position = Vector3(0.03, 1.04, 0.235)
	deckel.rotation_degrees.x = 55
	k.add_child(deckel)
	Bau.teil(deckel, Bau.box_mesh(Vector3(0.28, 0.3, 0.015)), lack, Vector3(0, 0.15, 0))
	var fahne := Node3D.new()
	fahne.name = "Fahne"
	fahne.position = Vector3(0.19, 1.12, 0.1)
	k.add_child(fahne)
	Bau.teil(fahne, Bau.box_mesh(Vector3(0.012, 0.26, 0.02)), Look.metall(Color(0.3, 0.3, 0.3), 0.5), Vector3(0, 0.13, 0))
	Bau.teil(fahne, Bau.kugel_mesh(0.035, false, 10), Look.nuss("hasel"), Vector3(0, 0.27, 0))
	for i in 3:
		Bau.teil(k, Bau.box_mesh(Vector3(0.2, 0.004, 0.12)), Bau.mat(Color(0.93, 0.9, 0.82)), Vector3(0.03, 1.06 + i * 0.006, 0.2 + i * 0.012), Vector3(0, i * 9.0 - 8.0, 0))
	Bau.schrift(k, "OPA", Vector3(-0.123, 1.14, 0), 44, Color(0.2, 0.12, 0.05), Vector3(0, -90, 0))
	_koll(k, Vector3(0.3, 1.4, 0.46), Vector3(0, 0.7, 0))


## Hoftor: zwei Pfosten mit Querbalken und Schild, ein Torflügel hängt offen. Durchfahrt 3,4 m.
static func hoftor(k: Node3D) -> void:
	var dunkel := _dunkel()
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.24, 3.0, 0.24)), dunkel, Vector3(s * 1.85, 1.5, 0), Vector3(0, 0, s * -1.5))
		_koll(k, Vector3(0.26, 3.0, 0.26), Vector3(s * 1.85, 1.5, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.7, 0.1, 0.1)), dunkel, Vector3(s * 1.55, 2.62, 0), Vector3(0, 0, s * 45.0))
	Bau.teil(k, Bau.box_mesh(Vector3(4.3, 0.2, 0.2)), dunkel, Vector3(0, 2.95, 0), Vector3(0, 0, 1.2))
	var schild := Bau.holzschild(k, "HASELGRUND", Vector3(0, 2.52, 0.03), Vector2(1.9, 0.42), Vector3(0, 0, -2), 110)
	schild.name = "Schild"
	Bau.holzschild(k, "seit 1974", Vector3(0, 2.52, -0.03), Vector2(1.9, 0.42), Vector3(0, 180, 2), 90)
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.zylinder_mesh(0.006, 0.006, 0.22, 4), Look.metall(Color(0.3, 0.3, 0.3), 0.5), Vector3(s * 0.8, 2.79, 0))
	Bau.teil(k, Bau.kugel_mesh(0.16, false, 14), Look.nuss("hasel"), Vector3(-1.85, 3.12, 0), Vector3.ZERO, Vector3(1, 1.1, 1))
	Bau.teil(k, Bau.kugel_mesh(0.16, false, 14), Look.nuss("wal"), Vector3(1.85, 3.12, 0), Vector3.ZERO, Vector3(1, 1.1, 1))
	# Torflügel, weit offen und etwas abgesackt
	var fluegel := Node3D.new()
	fluegel.name = "Torfluegel"
	fluegel.position = Vector3(-1.72, 0.12, 0.05)
	fluegel.rotation_degrees = Vector3(0, -108, -3)
	k.add_child(fluegel)
	var holz := _alt()
	for y in [0.2, 0.95]:
		Bau.teil(fluegel, Bau.box_mesh(Vector3(1.65, 0.09, 0.05)), holz, Vector3(0.83, y, 0))
	Bau.teil(fluegel, Bau.box_mesh(Vector3(1.8, 0.08, 0.04)), holz, Vector3(0.83, 0.58, 0.03), Vector3(0, 0, 24))
	for i in 7:
		Bau.teil(fluegel, Bau.box_mesh(Vector3(0.11, 1.15 - 0.03 * (i % 2), 0.035)), holz, Vector3(0.1 + i * 0.245, 0.58, -0.035))
	_koll(fluegel, Vector3(1.7, 1.2, 0.1), Vector3(0.83, 0.58, 0))


## Kaputter Traktor, 3,2 m lang, Front nach +Z.
static func traktor(k: Node3D) -> void:
	var rot := Look.lackiert(Color(0.56, 0.2, 0.13), 0.15)
	var rost := Look.putz(Color(0.45, 0.24, 0.13), Color(0.3, 0.16, 0.1), 50.0, 0.0, 0.9)
	var gummi := Bau.mat(Color(0.07, 0.07, 0.075), 0.9)
	var eisen := Look.metall(Color(0.3, 0.3, 0.32), 0.55)
	Bau.teil(k, Bau.box_mesh(Vector3(0.62, 0.3, 2.7)), eisen, Vector3(0, 0.62, 0.1))
	Bau.teil(k, Bau.box_mesh(Vector3(0.74, 0.56, 1.35)), rot, Vector3(0, 1.02, 0.78))
	Bau.teil(k, Bau.box_mesh(Vector3(0.7, 0.5, 0.05)), rost, Vector3(0, 1.0, 1.47))
	for i in 5:
		Bau.teil(k, Bau.box_mesh(Vector3(0.6, 0.02, 0.02)), eisen, Vector3(0, 0.84 + i * 0.08, 1.5))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.zylinder_mesh(0.68, 0.68, 0.36, 18), gummi, Vector3(s * 0.74, 0.68, -0.72), Vector3(0, 0, 90))
		Bau.teil(k, Bau.zylinder_mesh(0.34, 0.34, 0.37, 12), rot, Vector3(s * 0.74, 0.68, -0.72), Vector3(0, 0, 90))
		Bau.teil(k, Bau.box_mesh(Vector3(0.46, 0.05, 1.1)), rot, Vector3(s * 0.74, 1.42, -0.72), Vector3(-4, 0, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.46, 0.5, 0.05)), rot, Vector3(s * 0.74, 1.17, -1.26))
	# Vorderräder, eins ist platt und steht schief
	Bau.teil(k, Bau.zylinder_mesh(0.36, 0.36, 0.2, 14), gummi, Vector3(-0.6, 0.36, 1.12), Vector3(0, 12, 90))
	Bau.teil(k, Bau.zylinder_mesh(0.36, 0.36, 0.2, 14), gummi, Vector3(0.63, 0.3, 1.1), Vector3(14, -20, 90), Vector3(1, 1, 0.82))
	Bau.teil(k, Bau.box_mesh(Vector3(1.25, 0.08, 0.08)), eisen, Vector3(0, 0.4, 1.12))
	# Sitz voller Nüsse, Lenkrad, Auspuff
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.08, 0.46)), rost, Vector3(0, 1.08, -0.62))
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.42, 0.07)), rost, Vector3(0, 1.3, -0.86), Vector3(-10, 0, 0))
	Bau.teil(k, Bau.kugel_mesh(0.26, true, 14), Look.nusshaufen(0.06), Vector3(0, 1.11, -0.6), Vector3.ZERO, Vector3(0.9, 0.7, 0.8))
	Bau.teil(k, Bau.zylinder_mesh(0.02, 0.02, 0.6, 8), eisen, Vector3(0, 1.45, -0.05), Vector3(-50, 0, 0))
	var rad := TorusMesh.new()
	rad.inner_radius = 0.17
	rad.outer_radius = 0.2
	Bau.teil(k, rad, gummi, Vector3(0, 1.65, -0.28), Vector3(40, 0, 0))
	Bau.teil(k, Bau.zylinder_mesh(0.035, 0.035, 0.9, 8), eisen, Vector3(0.24, 1.7, 1.0), Vector3(0, 0, -4))
	Bau.teil(k, Bau.zylinder_mesh(0.06, 0.035, 0.12, 8), eisen, Vector3(0.21, 2.18, 1.0), Vector3(0, 0, -4))
	_koll(k, Vector3(1.9, 1.5, 3.1), Vector3(0, 0.75, 0.05))


## Opas Stuhl mit Decke, daneben ein Stumpf mit Tasse. Blick nach +Z.
static func opas_stuhl(k: Node3D) -> void:
	var holz := Look.holz(Look.EICHE, 8.0, 0.1)
	Bau.teil(k, Bau.box_mesh(Vector3(0.54, 0.05, 0.52)), holz, Vector3(0, 0.44, 0))
	for x in [-0.23, 0.23]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.055, 0.44, 0.055)), holz, Vector3(x, 0.22, 0.22))
		Bau.teil(k, Bau.box_mesh(Vector3(0.055, 1.08, 0.055)), holz, Vector3(x, 0.54, -0.25), Vector3(-7, 0, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.06, 0.04, 0.5)), holz, Vector3(x * 1.1, 0.68, 0.0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.05, 0.24, 0.05)), holz, Vector3(x * 1.1, 0.56, 0.22))
	for i in 4:
		Bau.teil(k, Bau.box_mesh(Vector3(0.07, 0.5, 0.025)), holz, Vector3(-0.16 + i * 0.107, 0.78, -0.29), Vector3(-7, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.52, 0.06, 0.06)), holz, Vector3(0, 1.06, -0.315))
	var decke := Look.stoff(Color(0.25, 0.4, 0.3))
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.42, 0.03)), decke, Vector3(0.02, 0.87, -0.345), Vector3(-7, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.03, 0.14)), decke, Vector3(0.02, 1.1, -0.31))
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.26, 0.03)), decke, Vector3(0.02, 0.97, -0.265), Vector3(-7, 0, 0))
	stumpf(k, Vector3(0.68, 0, 0.1), 0.2, 0.42)
	Modelle.setze(k, "kueche/mug.glb", Vector3(0.66, 0.42, 0.1), 60.0, 0.36)
	_koll(k, Vector3(0.56, 0.9, 0.56), Vector3(0, 0.45, 0))


## Feuerstelle: Steinkreis mit verkohlten Scheiten, daneben ein Stamm als Bank.
static func feuerstelle(k: Node3D) -> void:
	var stein := _stein()
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in 11:
		var w := TAU * i / 11.0
		var g := rng.randf_range(0.15, 0.22)
		Bau.teil(k, Bau.kugel_mesh(1.0, false, 8), stein, Vector3(cos(w) * 0.68, g * 0.4, sin(w) * 0.68), Vector3(0, rng.randf() * 360, 0), Vector3(g * 1.2, g * 0.8, g))
	Bau.teil(k, Bau.zylinder_mesh(0.6, 0.6, 0.03, 16), Bau.mat(Color(0.1, 0.09, 0.085), 1.0), Vector3(0, 0.015, 0))
	var kohle := Look.putz(Color(0.12, 0.1, 0.09), Color(0.3, 0.28, 0.26), 60.0, 0.0, 1.0)
	for i in 4:
		Bau.teil(k, Bau.zylinder_mesh(0.055, 0.065, 0.75, 8), kohle, Vector3(0, 0.1 + i * 0.03, 0), Vector3(78, i * 47.0, 0))
	var rinde := Look.holz([Color(0.36, 0.27, 0.2), Color(0.2, 0.14, 0.1)], 14.0, 0.0)
	Bau.teil(k, Bau.zylinder_mesh(0.24, 0.27, 2.1, 12), rinde, Vector3(-1.5, 0.24, 0.6), Vector3(90, -20, 0))
	for e in [-1.0, 1.0]:
		Bau.teil(k, Bau.zylinder_mesh(0.2, 0.2, 0.01, 12), Look.holz(Look.KIEFER, 16.0, 0.0), Vector3(-1.5, 0.24, 0.6) + Vector3(sin(deg_to_rad(-20.0)), 0, cos(deg_to_rad(-20.0))) * e * 1.05, Vector3(90, -20, 0))
	_koll(k, Vector3(0.9, 0.6, 2.2), Vector3(-1.5, 0.3, 0.6), Vector3(0, -20, 0))


## Vogelscheuche mit Opas Hut.
static func vogelscheuche(k: Node3D) -> void:
	var holz := _alt()
	Bau.teil(k, Bau.box_mesh(Vector3(0.07, 2.0, 0.07)), holz, Vector3(0, 1.0, 0), Vector3(0, 0, 3))
	Bau.teil(k, Bau.box_mesh(Vector3(1.5, 0.06, 0.06)), holz, Vector3(0, 1.45, 0), Vector3(0, 0, -4))
	var hemd := Look.stoff(Color(0.7, 0.25, 0.2))
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.62, 0.2)), hemd, Vector3(0, 1.25, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(1.2, 0.17, 0.16)), hemd, Vector3(0, 1.45, 0), Vector3(0, 0, -4))
	Bau.teil(k, Bau.kugel_mesh(0.17, false, 12), Look.stoff(Color(0.82, 0.72, 0.5)), Vector3(0.02, 1.76, 0))
	var filz := Look.stoff(Color(0.3, 0.24, 0.18))
	Bau.teil(k, Bau.zylinder_mesh(0.3, 0.32, 0.025, 16), filz, Vector3(0.02, 1.88, 0), Vector3(6, 0, 4))
	Bau.teil(k, Bau.zylinder_mesh(0.15, 0.17, 0.17, 14), filz, Vector3(0.02, 1.96, 0), Vector3(6, 0, 4))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.kugel_mesh(0.02, false, 6), Bau.mat(Color(0.05, 0.05, 0.05)), Vector3(0.02 + s * 0.06, 1.79, 0.155))
		Bau.teil(k, Bau.zylinder_mesh(0.05, 0.0, 0.2, 6), Look.halm(), Vector3(s * 0.68, 1.42 - s * 0.05, 0), Vector3(0, 0, s * 90.0))


## Leiter mit zwei gebrochenen Sprossen, zum Anlehnen (oben nach -Z geneigt).
static func leiter(k: Node3D) -> void:
	var holz := _alt()
	var l := Node3D.new()
	l.rotation_degrees.x = -16
	k.add_child(l)
	for s in [-1.0, 1.0]:
		Bau.teil(l, Bau.box_mesh(Vector3(0.05, 3.0, 0.06)), holz, Vector3(s * 0.22, 1.5, 0))
	for i in 9:
		if i == 3:
			Bau.teil(l, Bau.box_mesh(Vector3(0.2, 0.035, 0.035)), holz, Vector3(-0.12, 0.3 + i * 0.3 - 0.04, 0), Vector3(0, 0, -25))
			continue
		if i == 4:
			continue
		Bau.teil(l, Bau.box_mesh(Vector3(0.44, 0.035, 0.035)), holz, Vector3(0, 0.3 + i * 0.3, 0))
	# Korb mit Nüssen
	Bau.teil(k, Bau.zylinder_mesh(0.24, 0.18, 0.24, 12), Look.holz(Look.KIEFER, 14.0, 0.0), Vector3(0.6, 0.12, 0.35))
	Bau.teil(k, Bau.kugel_mesh(0.22, true, 12), Look.nusshaufen(0.05), Vector3(0.6, 0.2, 0.35), Vector3.ZERO, Vector3(1, 0.5, 1))


## Baumstumpf mit Jahresringen obendrauf.
static func stumpf(k: Node3D, pos: Vector3, radius: float, hoehe: float) -> void:
	var rinde := Look.holz([Color(0.36, 0.27, 0.2), Color(0.2, 0.14, 0.1)], 14.0, 0.0)
	Bau.teil(k, Bau.zylinder_mesh(radius * 0.92, radius * 1.12, hoehe, 12), rinde, pos + Vector3(0, hoehe * 0.5, 0))
	Bau.teil(k, Bau.zylinder_mesh(radius * 0.84, radius * 0.84, 0.01, 12), Look.holz(Look.KIEFER, 16.0, 0.0), pos + Vector3(0, hoehe + 0.002, 0))


# --- Etappe 3: Siedlung und Aussicht -------------------------------------------
static func _heu() -> Material:
	return Look.putz(Color(0.82, 0.68, 0.3), Color(0.64, 0.5, 0.2), 90.0, 0.0, 1.0)


static func _moos() -> Material:
	return Look.putz(Color(0.3, 0.4, 0.16), Color(0.2, 0.3, 0.12), 60.0, 0.0, 1.0)


## Opas Hochsitz: Plattform auf 3,6 m mit Geländer, Dach und Leiter an der Front (+Z).
static func hochsitz(k: Node3D) -> void:
	var holz := _alt()
	var dunkel := _dunkel()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Bau.teil(k, Bau.box_mesh(Vector3(0.16, 3.8, 0.16)), dunkel, Vector3(sx * 1.05, 1.8, sz * 1.05), Vector3(sz * -5.0, 0, sx * 5.0))
			_koll(k, Vector3(0.2, 3.6, 0.2), Vector3(sx * 1.05, 1.8, sz * 1.05))
			Bau.teil(k, Bau.box_mesh(Vector3(0.1, 2.2, 0.1)), dunkel, Vector3(sx * 0.98, 4.75, sz * 0.98))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.07, 3.1, 0.07)), holz, Vector3(s * 1.0, 1.9, 0), Vector3(40.0 * s, 0, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.07, 3.1, 0.07)), holz, Vector3(0, 1.9, s * 1.0), Vector3(0, 0, 40.0 * s))
	Bau.block(k, Vector3(2.3, 0.12, 2.3), Vector3(0, 3.6, 0), Look.holz(Look.ALTHOLZ, 6.0, 0.0, 0.2, true))
	# Geländer an drei Seiten, vorn eine Lücke für die Leiter
	for seite in [[Vector3(-1.08, 0, 0), Vector3(0.07, 0.07, 2.2)], [Vector3(1.08, 0, 0), Vector3(0.07, 0.07, 2.2)], [Vector3(0, 0, -1.08), Vector3(2.2, 0.07, 0.07)]]:
		var p: Vector3 = seite[0]
		var g: Vector3 = seite[1]
		Bau.teil(k, Bau.box_mesh(g), holz, p + Vector3(0, 4.6, 0))
		Bau.teil(k, Bau.box_mesh(g), holz, p + Vector3(0, 4.15, 0))
		_koll(k, Vector3(maxf(g.x, 0.1), 1.1, maxf(g.z, 0.1)), p + Vector3(0, 4.2, 0))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.7, 0.07, 0.07)), holz, Vector3(s * 0.73, 4.6, 1.08))
		_koll(k, Vector3(0.7, 1.1, 0.1), Vector3(s * 0.73, 4.2, 1.08))
	Bau.teil(k, Bau.box_mesh(Vector3(2.8, 0.07, 1.6)), _ziegel(), Vector3(0, 6.05, 0.62), Vector3(24, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(2.8, 0.07, 1.6)), _ziegel(), Vector3(0, 6.05, -0.62), Vector3(-24, 0, 0))
	# Leiter
	var leiter_k := Node3D.new()
	leiter_k.name = "Leiter"
	leiter_k.position = Vector3(0, 0, 1.75)
	leiter_k.rotation_degrees.x = -9
	k.add_child(leiter_k)
	for s in [-1.0, 1.0]:
		Bau.teil(leiter_k, Bau.box_mesh(Vector3(0.06, 4.3, 0.07)), holz, Vector3(s * 0.26, 2.15, 0))
	for i in 12:
		Bau.teil(leiter_k, Bau.box_mesh(Vector3(0.52, 0.045, 0.045)), holz, Vector3(0, 0.3 + i * 0.32, 0))
	# Opas Fernglas-Hocker und eine Thermoskanne
	stumpf(k, Vector3(-0.6, 3.66, -0.6), 0.2, 0.4)
	Bau.teil(k, Bau.zylinder_mesh(0.045, 0.05, 0.26, 10), Look.lackiert(Color(0.2, 0.36, 0.28), 0.5), Vector3(0.75, 3.79, -0.8))


## Eingefallene Köhlerhütte, 5 x 4 m. Tür an der Front (+Z).
static func koehlerhuette(k: Node3D) -> void:
	var stein := _stein()
	var holz := _alt()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1903
	# Mauern in Stücken unterschiedlicher Höhe (hinten und links hoch, rechts eingestürzt)
	var stuecke := [
		[Vector3(-2.4, 0, 0), Vector3(0.35, 2.2, 4.0)], [Vector3(-1.2, 0, -1.85), Vector3(2.2, 2.4, 0.35)], [Vector3(1.2, 0, -1.85), Vector3(2.2, 1.5, 0.35)],
		[Vector3(2.4, 0, -1.0), Vector3(0.35, 0.9, 1.9)], [Vector3(2.4, 0, 1.2), Vector3(0.35, 0.45, 1.4)],
		[Vector3(-1.6, 0, 1.85), Vector3(1.5, 1.9, 0.35)], [Vector3(1.5, 0, 1.85), Vector3(1.6, 1.1, 0.35)]]
	for st in stuecke:
		var g: Vector3 = st[1]
		var p: Vector3 = st[0]
		Bau.block(k, g, p + Vector3(0, g.y * 0.5, 0), stein)
		Bau.teil(k, Bau.box_mesh(Vector3(g.x + 0.04, 0.1, g.z + 0.04)), _moos(), p + Vector3(0, g.y + 0.03, 0))
	# Türrahmen steht noch
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.14, 2.0, 0.14)), holz, Vector3(-0.35 + s * 0.5, 1.0, 1.85), Vector3(0, 0, s * 2.0))
	Bau.teil(k, Bau.box_mesh(Vector3(1.25, 0.14, 0.16)), holz, Vector3(-0.35, 2.05, 1.85), Vector3(0, 0, -3))
	# Halbes Dach: links liegt es noch auf, rechts ist es heruntergerutscht
	Bau.teil(k, Bau.box_mesh(Vector3(2.9, 0.1, 4.4)), _ziegel(), Vector3(-1.1, 2.75, 0), Vector3(0, 0, 24))
	Bau.teil(k, Bau.box_mesh(Vector3(2.6, 0.1, 3.4)), _ziegel(), Vector3(1.9, 0.75, 0.2), Vector3(6, 8, -32))
	for i in 4:
		Bau.teil(k, Bau.box_mesh(Vector3(0.12, 0.12, 3.4)), holz, Vector3(-2.0 + i * 0.75, 2.3 + i * 0.3, 0), Vector3(rng.randf_range(-3, 3), 0, 24))
	Bau.teil(k, Bau.box_mesh(Vector3(0.12, 0.12, 2.6)), holz, Vector3(0.6, 0.35, 0.4), Vector3(14, 50, 0))
	# Schornstein und Ofen
	Bau.block(k, Vector3(0.7, 3.3, 0.7), Vector3(-1.9, 1.65, -1.4), stein)
	Bau.teil(k, Bau.zylinder_mesh(0.3, 0.34, 0.7, 12), Look.metall(Color(0.22, 0.2, 0.19), 0.7), Vector3(-1.1, 0.35, -1.2))
	Bau.teil(k, Bau.zylinder_mesh(0.07, 0.07, 1.1, 8), Look.metall(Color(0.22, 0.2, 0.19), 0.7), Vector3(-1.1, 1.2, -1.2), Vector3(0, 0, 12))
	# Bewuchs innen
	for i in 6:
		Modelle.setze(k, "wald/Grass_1_C_Color1.gltf", Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.3, 1.3)), rng.randf() * 360.0, rng.randf_range(0.7, 1.1))
	Modelle.setze(k, "wald/Bush_1_C_Color1.gltf", Vector3(1.3, 0, -1.0), 0.0, 1.0)
	Modelle.setze(k, "natur/mushroom_tanGroup.glb", Vector3(-1.8, 0, 0.9), 40.0, 1.6)


## Verfallener Schuppen, 4 x 3 m, windschief.
static func schuppen(k: Node3D) -> void:
	var holz := _alt()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	var schief := Node3D.new()
	schief.rotation_degrees = Vector3(0, 0, 7)
	k.add_child(schief)
	for sx in [-1.9, 1.9]:
		for sz in [-1.4, 1.4]:
			Bau.teil(schief, Bau.box_mesh(Vector3(0.14, 2.6, 0.14)), _dunkel(), Vector3(sx, 1.3, sz))
	for i in 16:
		if i in [3, 4, 9, 13]:
			continue
		var x := -1.8 + i * 0.24
		Bau.teil(schief, Bau.box_mesh(Vector3(0.2, 2.3 - rng.randf() * 0.3, 0.03)), holz, Vector3(x, 1.15, -1.4), Vector3(0, 0, rng.randf_range(-3, 3)))
	for i in 12:
		if i in [2, 7, 8]:
			continue
		for sx in [-1.9, 1.9]:
			if sx > 0 and i > 8:
				continue
			Bau.teil(schief, Bau.box_mesh(Vector3(0.03, 2.3 - rng.randf() * 0.4, 0.2)), holz, Vector3(sx, 1.15, -1.3 + i * 0.24), Vector3(rng.randf_range(-3, 3), 0, 0))
	Bau.teil(schief, Bau.box_mesh(Vector3(4.4, 0.08, 3.4)), holz, Vector3(0, 2.62, 0), Vector3(-10, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.2, 2.1, 0.03)), holz, Vector3(1.2, 0.03, 1.9), Vector3(88, 20, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.2, 1.8, 0.03)), holz, Vector3(0.4, 0.05, 2.2), Vector3(90, -35, 0))
	_koll(k, Vector3(4.0, 2.4, 0.15), Vector3(0.15, 1.2, -1.4))
	_koll(k, Vector3(0.15, 2.4, 3.0), Vector3(-1.75, 1.2, 0))
	_koll(k, Vector3(0.15, 2.4, 2.0), Vector3(2.05, 1.2, -0.5))
	# Was noch drin steht: ein Fass, Kisten, Spinnweben ohne Spinnen
	Modelle.setze(k, "kueche/barrel.glb", Vector3(-1.1, 0, -0.7), 0.0, 1.2)
	Bau.teil(k, Bau.box_mesh(Vector3(0.6, 0.45, 0.5)), Look.holz(Look.KIEFER, 8.0, 0.0), Vector3(0.6, 0.23, -0.9), Vector3(0, 15, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.35, 0.45)), Look.holz(Look.KIEFER, 8.0, 0.0), Vector3(0.65, 0.62, -0.92), Vector3(0, -10, 0))


## Kleines altes Lagerhaus, 4 x 3 x 3,2 m, Tür vernagelt. An der rechten Seite sitzt ein loses Brett.
static func lagerhaus(k: Node3D) -> void:
	var holz := _alt()
	var dunkel := _dunkel()
	Bau.block(k, Vector3(4.0, 2.4, 3.0), Vector3(0, 1.2, 0), Look.holz(Look.ALTHOLZ, 5.0, 0.0, 0.22, false))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(4.5, 0.09, 2.1)), _ziegel(), Vector3(0, 2.85, s * 0.85), Vector3(s * 30.0, 0, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.16, 2.5, 0.16)), dunkel, Vector3(s * 2.0, 1.25, 1.5))
		Bau.teil(k, Bau.box_mesh(Vector3(0.16, 2.5, 0.16)), dunkel, Vector3(s * 2.0, 1.25, -1.5))
	Bau.teil(k, Bau.box_mesh(Vector3(4.0, 0.9, 0.08)), holz, Vector3(0, 2.8, 1.46), Vector3.ZERO, Vector3(1, 1, 1))
	Bau.teil(k, Bau.box_mesh(Vector3(4.0, 0.9, 0.08)), holz, Vector3(0, 2.8, -1.46))
	# Vernagelte Tür
	Bau.teil(k, Bau.box_mesh(Vector3(1.1, 1.9, 0.06)), dunkel, Vector3(0, 0.95, 1.51))
	Bau.teil(k, Bau.box_mesh(Vector3(1.5, 0.14, 0.04)), holz, Vector3(0, 1.0, 1.56), Vector3(0, 0, 32))
	Bau.teil(k, Bau.box_mesh(Vector3(1.5, 0.14, 0.04)), holz, Vector3(0, 1.0, 1.57), Vector3(0, 0, -30))
	Bau.holzschild(k, "LAGER 3", Vector3(0, 2.15, 1.53), Vector2(0.8, 0.2), Vector3(0, 0, -4), 70)
	# Nische hinter dem losen Brett (rechte Seite, +X)
	Bau.teil(k, Bau.box_mesh(Vector3(0.04, 0.7, 0.5)), Bau.mat(Color(0.04, 0.03, 0.03)), Vector3(2.0, 0.55, -0.4))
	var brett := Node3D.new()
	brett.name = "Loses_Brett"
	brett.position = Vector3(2.04, 1.0, -0.4)
	brett.rotation_degrees.x = 4
	k.add_child(brett)
	Bau.teil(brett, Bau.box_mesh(Vector3(0.04, 1.3, 0.56)), Look.holz(Look.KIEFER, 7.0, 0.0), Vector3(0, -0.5, 0))
	Bau.teil(brett, Bau.kugel_mesh(0.018, false, 6), Look.metall(Color(0.3, 0.3, 0.3), 0.5), Vector3(0.025, -0.03, 0))


## Leiterwagen mit gebrochener Achse und leeren Körben.
static func holzwagen(k: Node3D) -> void:
	var holz := _alt()
	var dunkel := _dunkel()
	var wagen := Node3D.new()
	wagen.rotation_degrees = Vector3(0, 0, -11)
	wagen.position = Vector3(0, 0.05, 0)
	k.add_child(wagen)
	Bau.teil(wagen, Bau.box_mesh(Vector3(1.3, 0.08, 2.8)), holz, Vector3(0, 0.7, 0))
	for s in [-1.0, 1.0]:
		Bau.teil(wagen, Bau.box_mesh(Vector3(0.06, 0.06, 2.9)), dunkel, Vector3(s * 0.66, 1.2, 0))
		for i in 7:
			Bau.teil(wagen, Bau.box_mesh(Vector3(0.04, 0.5, 0.04)), holz, Vector3(s * 0.66, 0.95, -1.3 + i * 0.43), Vector3(0, 0, s * -8.0))
	Bau.teil(wagen, Bau.box_mesh(Vector3(0.07, 0.07, 1.9)), dunkel, Vector3(0, 0.62, 2.2), Vector3(-14, 0, 0))
	var rad := func(pos: Vector3, dreh: Vector3, eltern: Node3D) -> void:
		var r := Node3D.new()
		r.position = pos
		r.rotation_degrees = dreh
		eltern.add_child(r)
		var reif := TorusMesh.new()
		reif.inner_radius = 0.43
		reif.outer_radius = 0.5
		Bau.teil(r, reif, dunkel, Vector3.ZERO, Vector3(0, 0, 90))
		for j in 4:
			Bau.teil(r, Bau.box_mesh(Vector3(0.04, 0.9, 0.05)), holz, Vector3.ZERO, Vector3(j * 45.0, 0, 0))
	rad.call(Vector3(-0.8, 0.52, -0.9), Vector3.ZERO, wagen)
	rad.call(Vector3(-0.8, 0.52, 0.9), Vector3.ZERO, wagen)
	rad.call(Vector3(0.8, 0.52, -0.9), Vector3.ZERO, wagen)
	rad.call(Vector3(1.5, 0.08, 1.3), Vector3(0, 30, 82), k)
	var korb := Look.holz(Look.KIEFER, 14.0, 0.0)
	for kp in [Vector3(-0.25, 0.9, -0.8), Vector3(0.3, 0.9, -0.2), Vector3(-0.2, 0.9, 0.5)]:
		Bau.teil(wagen, Bau.zylinder_mesh(0.27, 0.2, 0.32, 12), korb, kp)
		Bau.teil(wagen, Bau.zylinder_mesh(0.24, 0.24, 0.01, 12), Bau.mat(Color(0.12, 0.08, 0.05)), kp + Vector3(0, 0.15, 0))
	Bau.teil(k, Bau.zylinder_mesh(0.27, 0.2, 0.32, 12), korb, Vector3(1.3, 0.14, -0.5), Vector3(80, 30, 0))
	_koll(k, Vector3(1.5, 1.2, 2.9), Vector3(0, 0.6, 0))


## Wegweiser mit drei Schildern. texte = [[Text, Drehung in Grad], ...]
static func wegweiser(k: Node3D, texte: Array) -> void:
	Bau.teil(k, Bau.box_mesh(Vector3(0.12, 2.5, 0.12)), _dunkel(), Vector3(0, 1.25, 0), Vector3(0, 0, -3))
	for i in texte.size():
		var s := Bau.holzschild(k, str(texte[i][0]), Vector3(0, 2.25 - i * 0.36, 0), Vector2(1.25, 0.26), Vector3(0, float(texte[i][1]), (i - 1) * 3.0), 62)
		s.position += s.transform.basis.x * 0.45 + s.transform.basis.z * 0.07
	_koll(k, Vector3(0.16, 2.4, 0.16), Vector3(0, 1.2, 0))


## Heuschober: Dach auf sechs Pfosten über einem großen Heuhaufen, Rückwand (-Z) aus Brettern mit Spalt.
static func heuschober(k: Node3D) -> void:
	var dunkel := _dunkel()
	var holz := _alt()
	for sx in [-2.4, 0.0, 2.4]:
		for sz in [-1.9, 1.9]:
			Bau.teil(k, Bau.box_mesh(Vector3(0.18, 3.0, 0.18)), dunkel, Vector3(sx, 1.5, sz))
			_koll(k, Vector3(0.2, 3.0, 0.2), Vector3(sx, 1.5, sz))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(5.6, 0.1, 2.7)), _heu(), Vector3(0, 3.55, s * 1.1), Vector3(s * 28.0, 0, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(5.2, 0.14, 0.14)), dunkel, Vector3(0, 2.95, s * 1.9))
	Bau.teil(k, Bau.box_mesh(Vector3(5.7, 0.12, 0.12)), dunkel, Vector3(0, 4.16, 0))
	# Bretterwand hinten, das dritte Brett von links fehlt halb: dort fällt abends Licht herein
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 20:
		var x := -2.3 + i * 0.242
		if i == 13:
			Bau.teil(k, Bau.box_mesh(Vector3(0.22, 1.1, 0.03)), holz, Vector3(x, 0.55, -1.95))
			continue
		Bau.teil(k, Bau.box_mesh(Vector3(0.22, 2.7 - rng.randf() * 0.25, 0.03)), holz, Vector3(x, 1.35, -1.95), Vector3(0, 0, rng.randf_range(-1.5, 1.5)))
	_koll(k, Vector3(5.0, 2.8, 0.1), Vector3(0, 1.4, -1.95))
	# Der Heuhaufen
	var heu := _heu()
	for h in [[Vector3(0, 0, -0.2), Vector3(2.1, 1.7, 1.5)], [Vector3(-1.1, 0, 0.3), Vector3(1.3, 1.1, 1.2)], [Vector3(1.2, 0, 0.2), Vector3(1.2, 1.25, 1.1)], [Vector3(0.2, 0, 0.9), Vector3(1.4, 0.7, 0.9)]]:
		Bau.teil(k, Bau.kugel_mesh(1.0, true, 16), heu, h[0], Vector3(0, rng.randf() * 90.0, 0), h[1])
	_koll(k, Vector3(3.4, 1.2, 2.2), Vector3(0, 0.6, 0.0))
	# Heugabel und ein vergessener Rechen
	var gabel := Node3D.new()
	gabel.position = Vector3(2.15, 0, 1.2)
	gabel.rotation_degrees = Vector3(-14, 0, 10)
	k.add_child(gabel)
	Bau.teil(gabel, Bau.zylinder_mesh(0.022, 0.022, 1.7, 8), Look.holz(Look.EICHE, 9.0, 0.1), Vector3(0, 0.85, 0))
	for i in 3:
		Bau.teil(gabel, Bau.zylinder_mesh(0.008, 0.008, 0.32, 6), Look.metall(Color(0.35, 0.35, 0.37), 0.5), Vector3(-0.07 + i * 0.07, 1.85, 0))
	Bau.teil(gabel, Bau.box_mesh(Vector3(0.18, 0.02, 0.02)), Look.metall(Color(0.35, 0.35, 0.37), 0.5), Vector3(0, 1.7, 0))


## Picknickplatz: Tisch mit Bänken, gedeckt für vier und vor langer Zeit verlassen.
static func picknick(k: Node3D) -> void:
	var holz := _alt()
	Bau.block(k, Vector3(1.9, 0.07, 0.85), Vector3(0, 0.76, 0), holz)
	for s in [-1.0, 1.0]:
		Bau.block(k, Vector3(1.9, 0.06, 0.3), Vector3(0, 0.45, s * 0.75), holz)
		for x in [-0.75, 0.75]:
			Bau.teil(k, Bau.box_mesh(Vector3(0.08, 0.95, 0.08)), _dunkel(), Vector3(x, 0.4, s * 0.42), Vector3(s * 32.0, 0, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(1.3, 0.012, 0.7)), Look.stoff(Color(0.7, 0.2, 0.18)), Vector3(-0.1, 0.801, 0), Vector3(0, 4, 0))
	for p in [Vector3(-0.55, 0.81, 0.2), Vector3(0.3, 0.81, 0.22), Vector3(-0.5, 0.81, -0.22), Vector3(0.35, 0.81, -0.2)]:
		Modelle.setze(k, "kueche/plate.glb", p, 0.0, 0.26)
	var becher := Modelle.setze(k, "kueche/mug.glb", Vector3(0.05, 0.84, 0.05), 40.0, 0.3)
	becher.rotation_degrees.z = 90
	Modelle.setze(k, "kueche/mug.glb", Vector3(-0.75, 0.8, 0.0), 0.0, 0.3)
	# Hut auf der Bank, Korb im Gras
	var filz := Look.stoff(Color(0.82, 0.74, 0.5))
	Bau.teil(k, Bau.zylinder_mesh(0.2, 0.21, 0.02, 14), filz, Vector3(0.6, 0.49, 0.75))
	Bau.teil(k, Bau.zylinder_mesh(0.1, 0.11, 0.1, 12), filz, Vector3(0.6, 0.55, 0.75))
	Bau.teil(k, Bau.zylinder_mesh(0.105, 0.115, 0.03, 12), Look.stoff(Color(0.5, 0.15, 0.12)), Vector3(0.6, 0.515, 0.75))
	Bau.teil(k, Bau.zylinder_mesh(0.26, 0.2, 0.28, 12), Look.holz(Look.KIEFER, 14.0, 0.0), Vector3(-1.3, 0.14, 0.9), Vector3(70, 20, 0))
	# Krümelspur: jemand Kleines hat den Kuchen gestohlen
	var kruemel := Bau.mat(Color(0.86, 0.72, 0.45))
	for i in 14:
		Bau.teil(k, Bau.kugel_mesh(0.018, false, 5), kruemel, Vector3(0.9 + i * 0.42, 0.015, -0.3 - i * 0.33 + sin(i * 1.3) * 0.15))


## Angelplatz: kurzer Steg (nach +Z ins Wasser), Opas Angelstuhl, Eimer und Rute.
static func angelplatz(k: Node3D) -> void:
	var holz := _alt()
	var dunkel := _dunkel()
	for i in 12:
		Bau.teil(k, Bau.box_mesh(Vector3(1.3, 0.05, 0.2)), holz, Vector3(0, 0.22, -0.2 + i * 0.235), Vector3(0, (i % 3 - 1) * 1.5, 0))
	_koll(k, Vector3(1.3, 0.1, 2.9), Vector3(0, 0.2, 1.1))
	for s in [-1.0, 1.0]:
		for z in [0.9, 2.4]:
			Bau.teil(k, Bau.zylinder_mesh(0.06, 0.07, 1.6, 8), dunkel, Vector3(s * 0.62, -0.3, z))
	# Klappstuhl
	var stuhl := Node3D.new()
	stuhl.position = Vector3(-0.2, 0.25, 1.6)
	stuhl.rotation_degrees.y = -12
	k.add_child(stuhl)
	var tuch := Look.stoff(Color(0.2, 0.36, 0.5))
	Bau.teil(stuhl, Bau.box_mesh(Vector3(0.45, 0.02, 0.4)), tuch, Vector3(0, 0.4, 0))
	Bau.teil(stuhl, Bau.box_mesh(Vector3(0.45, 0.36, 0.02)), tuch, Vector3(0, 0.68, -0.22), Vector3(-10, 0, 0))
	for s in [-1.0, 1.0]:
		Bau.teil(stuhl, Bau.box_mesh(Vector3(0.03, 0.6, 0.03)), dunkel, Vector3(s * 0.22, 0.22, 0), Vector3(24, 0, 0))
		Bau.teil(stuhl, Bau.box_mesh(Vector3(0.03, 0.95, 0.03)), dunkel, Vector3(s * 0.22, 0.42, -0.05), Vector3(-22, 0, 0))
	# Eimer, Rute auf Astgabel
	Bau.teil(k, Bau.zylinder_mesh(0.15, 0.12, 0.25, 12), Look.metall(Color(0.55, 0.57, 0.6), 0.45), Vector3(0.4, 0.37, 1.4))
	Bau.teil(k, Bau.zylinder_mesh(0.13, 0.13, 0.01, 12), Bau.mat(Color(0.08, 0.16, 0.18), 0.1), Vector3(0.4, 0.46, 1.4))
	Bau.teil(k, Bau.box_mesh(Vector3(0.04, 0.7, 0.04)), dunkel, Vector3(0.25, 0.55, 2.45))
	Bau.teil(k, Bau.zylinder_mesh(0.008, 0.016, 2.6, 6), Look.holz(Look.KIEFER, 12.0, 0.2), Vector3(0.25, 1.25, 3.1), Vector3(62, 0, 0))
	Bau.teil(k, Bau.zylinder_mesh(0.002, 0.002, 2.3, 4), Bau.mat(Color(0.9, 0.9, 0.9)), Vector3(0.25, 0.72, 4.25))
	Bau.teil(k, Bau.kugel_mesh(0.035, false, 8), Look.lackiert(Color(0.85, 0.15, 0.1), 0.6), Vector3(0.25, -0.4, 4.25))
	for i in 5:
		Modelle.setze(k, "wald/Grass_2_C_Color1.gltf", Vector3(-1.2 + (i % 2) * 2.3, -0.1, 1.4 + i * 0.5), i * 70.0, 1.2)


## Der Südausgang ist gesperrt: Schild, dahinter ein umgestürzter Baum quer über dem Weg.
static func sperre(k: Node3D) -> void:
	var dunkel := _dunkel()
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.1, 1.5, 0.1)), dunkel, Vector3(s * 0.8, 0.75, -1.6), Vector3(0, 0, s * 3.0))
	var schild := Bau.holzschild(k, "GESPERRT", Vector3(0, 1.2, -1.62), Vector2(1.8, 0.4), Vector3(0, 180, -2), 120)
	schild.name = "Schild"
	Bau.holzschild(k, "Baum liegt quer. Seit 2011. – Opa", Vector3(0, 0.8, -1.62), Vector2(1.8, 0.2), Vector3(0, 180, 1), 48)
	var rinde := Look.holz([Color(0.36, 0.27, 0.2), Color(0.2, 0.14, 0.1)], 14.0, 0.0)
	Bau.teil(k, Bau.zylinder_mesh(0.42, 0.55, 9.0, 14), rinde, Vector3(0.3, 0.5, 0.4), Vector3(0, 12, 86))
	_koll(k, Vector3(9.0, 1.2, 1.0), Vector3(0.3, 0.6, 0.4), Vector3(0, 12, 0))
	Bau.teil(k, Bau.kugel_mesh(1.0, false, 12), Look.putz(Color(0.3, 0.22, 0.15), Color(0.2, 0.15, 0.1), 30.0), Vector3(4.9, 0.6, -0.55), Vector3.ZERO, Vector3(0.5, 1.5, 1.5))
	for i in 3:
		Bau.teil(k, Bau.zylinder_mesh(0.05, 0.12, 2.2, 8), rinde, Vector3(-2.0 - i * 0.9, 1.2, 0.9 + i * 0.1), Vector3(30 + i * 15, 12, 30))
	Bau.teil(k, _moos_fleck(), _moos(), Vector3(0.3, 0.86, 0.4), Vector3(0, 12, 0), Vector3(1.6, 0.12, 0.4))
	# Eichhörnchen-Nest in der Astgabel
	Bau.teil(k, Bau.kugel_mesh(0.3, false, 10), Look.putz(Color(0.45, 0.34, 0.2), Color(0.3, 0.22, 0.12), 120.0), Vector3(-2.3, 1.0, 0.9), Vector3.ZERO, Vector3(1, 0.7, 1))
	Bau.teil(k, Bau.kugel_mesh(0.12, false, 8), Bau.mat(Color(0.05, 0.04, 0.03)), Vector3(-2.3, 1.02, 1.12))


static func _moos_fleck() -> Mesh:
	return Bau.kugel_mesh(1.0, false, 10)


# --- Etappe 4: Geheimnisse -----------------------------------------------------
## Opas Mondsiebmaschine, 2,5 x 1,5 x 2,5 m, Auswurf an der Front (+Z).
## Bewegliche Teile: Trichter, Rad, Klappe.
static func mondmaschine(k: Node3D) -> void:
	var rost := Look.putz(Color(0.48, 0.27, 0.15), Color(0.32, 0.18, 0.11), 55.0, 0.0, 0.9)
	var blech := Look.metall(Color(0.42, 0.44, 0.46), 0.55)
	var gruen := Look.lackiert(Color(0.3, 0.42, 0.36), 0.2)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Bau.teil(k, Bau.box_mesh(Vector3(0.12, 0.6, 0.12)), blech, Vector3(sx * 1.05, 0.3, sz * 0.55), Vector3(sz * 6.0, 0, sx * -6.0))
	Bau.teil(k, Bau.box_mesh(Vector3(2.3, 1.0, 1.3)), gruen, Vector3(0, 1.05, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(2.34, 0.12, 1.34)), rost, Vector3(0, 0.6, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(2.34, 0.1, 1.34)), rost, Vector3(0, 1.56, 0))
	for i in 7:
		Bau.teil(k, Bau.kugel_mesh(0.03, false, 6), blech, Vector3(-0.95 + i * 0.32, 1.45, 0.66))
	# Trichter oben
	var trichter := Node3D.new()
	trichter.name = "Trichter"
	trichter.position = Vector3(-0.5, 1.6, 0)
	k.add_child(trichter)
	var tm := CylinderMesh.new()
	tm.top_radius = 0.62
	tm.bottom_radius = 0.2
	tm.height = 0.75
	tm.radial_segments = 12
	Bau.teil(trichter, tm, rost, Vector3(0, 0.38, 0))
	Bau.teil(trichter, Bau.zylinder_mesh(0.56, 0.56, 0.02, 12), Bau.mat(Color(0.08, 0.07, 0.07)), Vector3(0, 0.76, 0))
	# Siebtrommel und Schornstein
	Bau.teil(k, Bau.zylinder_mesh(0.42, 0.42, 0.9, 14), blech, Vector3(0.6, 1.85, 0), Vector3(0, 0, 90))
	Bau.teil(k, Bau.zylinder_mesh(0.09, 0.09, 0.9, 8), rost, Vector3(0.95, 2.05, -0.4))
	Bau.teil(k, Bau.zylinder_mesh(0.13, 0.09, 0.14, 8), rost, Vector3(0.95, 2.5, -0.4))
	# Schwungrad an der Seite
	var rad := Node3D.new()
	rad.name = "Rad"
	rad.position = Vector3(1.24, 1.1, 0)
	k.add_child(rad)
	var reif := TorusMesh.new()
	reif.inner_radius = 0.5
	reif.outer_radius = 0.6
	Bau.teil(rad, reif, rost, Vector3.ZERO, Vector3(0, 0, 90))
	for j in 3:
		Bau.teil(rad, Bau.box_mesh(Vector3(0.05, 1.05, 0.07)), blech, Vector3.ZERO, Vector3(j * 60.0, 0, 0))
	# Auswurf mit Klappe und Schale
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.36, 0.1)), Bau.mat(Color(0.06, 0.05, 0.05)), Vector3(0, 0.95, 0.63))
	var klappe := Node3D.new()
	klappe.name = "Klappe"
	klappe.position = Vector3(0, 1.14, 0.69)
	k.add_child(klappe)
	Bau.teil(klappe, Bau.box_mesh(Vector3(0.54, 0.4, 0.03)), blech, Vector3(0, -0.2, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.6, 0.04, 0.45)), blech, Vector3(0, 0.72, 0.9))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.03, 0.1, 0.45)), blech, Vector3(s * 0.3, 0.77, 0.9))
	Bau.teil(k, Bau.box_mesh(Vector3(0.6, 0.1, 0.03)), blech, Vector3(0, 0.77, 1.12))
	# Amtsschild auf zwei Pfosten neben der Maschine
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.07, 1.5, 0.07)), _dunkel(), Vector3(-2.3 + s * 0.55, 0.75, 0.5), Vector3(0, 0, s * 2.0))
	Bau.holzschild(k, "Mondstaubamt Haselgrund", Vector3(-2.3, 1.3, 0.55), Vector2(1.5, 0.3), Vector3(0, 0, -2), 66)
	Bau.holzschild(k, "– Außenstelle –", Vector3(-2.3, 0.98, 0.55), Vector2(1.1, 0.22), Vector3(0, 0, 1.5), 58)
	_koll(k, Vector3(2.5, 2.2, 1.4), Vector3(0, 1.1, 0))


## Die Königseiche: riesiger hohler Stamm (Öffnung an der Front, +Z), Krone, Mini-Häuser, winziger Thron.
## Etwa 8 x 8 x 14 m.
static func koenigseiche(k: Node3D) -> void:
	var rinde := Look.holz([Color(0.46, 0.34, 0.24), Color(0.28, 0.2, 0.13)], 16.0, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701
	var radius := 2.0
	var n := 14
	for i in n:
		var a := (i + 0.5) * TAU / n
		var pos := Vector3(sin(a) * radius, 0, cos(a) * radius)
		if i == 0 or i == n - 1:
			continue   # die Öffnung
		var h := 7.0 + rng.randf_range(-0.3, 0.5)
		Bau.teil(k, Bau.box_mesh(Vector3(1.02, h, 0.5 + rng.randf_range(0.0, 0.18))), rinde, pos + Vector3(0, h * 0.5, 0), Vector3(rng.randf_range(-2, 2), rad_to_deg(a), 0))
		_koll(k, Vector3(1.0, 7.0, 0.5), pos + Vector3(0, 3.5, 0), Vector3(0, rad_to_deg(a), 0))
		# Wurzelansatz
		Bau.teil(k, Bau.box_mesh(Vector3(0.7, 1.6, 0.9)), rinde, pos * 1.22 + Vector3(0, 0.45, 0), Vector3(-28.0, rad_to_deg(a), 0))
	# Sturz über der Öffnung und Wülste links und rechts
	Bau.teil(k, Bau.box_mesh(Vector3(2.0, 4.6, 0.55)), rinde, Vector3(0, 4.9, radius - 0.02))
	Bau.teil(k, Bau.kugel_mesh(1.0, false, 10), rinde, Vector3(0, 2.6, radius), Vector3.ZERO, Vector3(1.05, 0.35, 0.34))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.6, 1.3, 0.8)), rinde, Vector3(s * 1.25, 0.4, radius + 0.45), Vector3(-30, s * 25.0, 0))
	# Innen: dunkler Boden und dunkle Decke
	Bau.teil(k, Bau.zylinder_mesh(1.9, 1.9, 0.02, 14), Look.putz(Color(0.2, 0.15, 0.1), Color(0.13, 0.1, 0.07), 40.0), Vector3(0, 0.02, 0))
	Bau.teil(k, Bau.zylinder_mesh(2.1, 2.1, 0.3, 14), rinde, Vector3(0, 7.1, 0))
	# Äste und Krone
	var laub_a := Look.laub(Color(0.86, 0.5, 0.14), Color(0.6, 0.3, 0.08))
	var laub_b := Look.laub(Color(0.92, 0.7, 0.2), Color(0.62, 0.44, 0.12))
	for i in 5:
		var a := i * TAU / 5.0 + 0.4
		var richtung := Vector3(sin(a), 0, cos(a))
		Bau.teil(k, Bau.zylinder_mesh(0.22, 0.42, 4.2, 8), rinde, richtung * 2.6 + Vector3(0, 7.9, 0), Vector3(-55.0, rad_to_deg(a), 0))
		Bau.teil(k, Bau.kugel_mesh(1.0, false, 12), laub_a if i % 2 == 0 else laub_b, richtung * 4.3 + Vector3(0, 9.6 + (i % 2) * 0.8, 0), Vector3.ZERO, Vector3.ONE * rng.randf_range(2.6, 3.3))
	Bau.teil(k, Bau.kugel_mesh(1.0, false, 14), laub_b, Vector3(0, 11.2, 0), Vector3.ZERO, Vector3(4.2, 3.0, 4.2))
	Bau.teil(k, Bau.kugel_mesh(1.0, false, 12), laub_a, Vector3(1.0, 9.2, -0.6), Vector3.ZERO, Vector3(3.2, 2.2, 3.2))
	# Mini-Häuser der Eichhörnchen außen am Stamm
	var huette := Look.holz(Look.KIEFER, 10.0, 0.0)
	for hp in [[Vector3(-1.9, 2.9, 1.5), -50.0], [Vector3(2.3, 3.8, 0.4), 80.0], [Vector3(-2.2, 4.6, -0.9), -110.0], [Vector3(1.4, 2.4, 1.9), 35.0]]:
		var haus := Node3D.new()
		haus.position = hp[0]
		haus.rotation_degrees.y = hp[1]
		k.add_child(haus)
		Bau.teil(haus, Bau.box_mesh(Vector3(0.5, 0.04, 0.4)), huette, Vector3(0, 0, 0.25))
		Bau.teil(haus, Bau.box_mesh(Vector3(0.34, 0.3, 0.3)), huette, Vector3(0, 0.17, 0.25))
		for s in [-1.0, 1.0]:
			Bau.teil(haus, Bau.box_mesh(Vector3(0.27, 0.03, 0.38)), _ziegel(), Vector3(s * 0.095, 0.39, 0.25), Vector3(0, 0, s * -40.0))
		Bau.teil(haus, Bau.zylinder_mesh(0.055, 0.055, 0.01, 10), Bau.mat(Color(0.05, 0.04, 0.03)), Vector3(0, 0.17, 0.403), Vector3(90, 0, 0))
		Bau.teil(haus, Bau.kugel_mesh(0.012, false, 6), Look.leuchten(Color(1.0, 0.8, 0.4), 1.5), Vector3(0.12, 0.27, 0.41))
	# Der winzige Thron auf einem Wurzelsockel
	stumpf(k, Vector3(0, 0, -1.15), 0.34, 0.55)
	var thron := Node3D.new()
	thron.name = "Thron"
	thron.position = Vector3(0, 0.56, -1.2)
	k.add_child(thron)
	var gold := Look.metall(Color(0.95, 0.75, 0.25), 0.3)
	var samt := Look.stoff(Color(0.55, 0.1, 0.12))
	Bau.teil(thron, Bau.box_mesh(Vector3(0.24, 0.05, 0.22)), samt, Vector3(0, 0.07, 0.02))
	Bau.teil(thron, Bau.box_mesh(Vector3(0.26, 0.42, 0.04)), gold, Vector3(0, 0.25, -0.1))
	Bau.teil(thron, Bau.box_mesh(Vector3(0.2, 0.3, 0.02)), samt, Vector3(0, 0.25, -0.078))
	for s in [-1.0, 1.0]:
		Bau.teil(thron, Bau.box_mesh(Vector3(0.035, 0.14, 0.22)), gold, Vector3(s * 0.125, 0.12, 0.02))
		Bau.teil(thron, Bau.kugel_mesh(0.025, false, 8), gold, Vector3(s * 0.11, 0.48, -0.1))
	Bau.teil(thron, Bau.kugel_mesh(0.035, false, 8), Look.nuss("hasel"), Vector3(0, 0.5, -0.1))


## Opas geschnitzte Nussknacker-Figur, 30 cm hoch.
static func nussknacker_figur(k: Node3D) -> void:
	var rot := Look.lackiert(Color(0.72, 0.14, 0.12), 0.45)
	var blau := Look.lackiert(Color(0.15, 0.22, 0.45), 0.45)
	var haut := Look.lackiert(Color(0.93, 0.76, 0.62), 0.3)
	var schwarz := Look.lackiert(Color(0.08, 0.07, 0.07), 0.5)
	var gold := Look.metall(Color(0.95, 0.75, 0.25), 0.3)
	Bau.teil(k, Bau.box_mesh(Vector3(0.11, 0.015, 0.09)), schwarz, Vector3(0, 0.008, 0))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.035, 0.09, 0.04)), blau, Vector3(s * 0.024, 0.06, 0))
		Bau.teil(k, Bau.box_mesh(Vector3(0.025, 0.085, 0.03)), rot, Vector3(s * 0.056, 0.15, 0))
		Bau.teil(k, Bau.kugel_mesh(0.012, false, 6), gold, Vector3(s * 0.056, 0.2, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.085, 0.1, 0.055)), rot, Vector3(0, 0.155, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.09, 0.012, 0.06)), schwarz, Vector3(0, 0.11, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.07, 0.065, 0.06)), haut, Vector3(0, 0.24, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.05, 0.02, 0.012)), Bau.mat(Color(0.95, 0.95, 0.92)), Vector3(0, 0.222, 0.032))
	Bau.teil(k, Bau.box_mesh(Vector3(0.076, 0.012, 0.066)), schwarz, Vector3(0, 0.275, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.06, 0.05, 0.05)), schwarz, Vector3(0, 0.305, 0))
	Bau.teil(k, Bau.box_mesh(Vector3(0.062, 0.008, 0.052)), gold, Vector3(0, 0.29, 0))
	for s in [-1.0, 1.0]:
		Bau.teil(k, Bau.kugel_mesh(0.006, false, 5), schwarz, Vector3(s * 0.017, 0.252, 0.031))
	Bau.teil(k, Bau.box_mesh(Vector3(0.012, 0.11, 0.012)), haut, Vector3(0, 0.2, -0.04), Vector3(25, 0, 0))
