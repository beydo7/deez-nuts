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
