class_name Item
extends RigidBody3D
## Alles Kleine, das man greifen kann: ganze Nüsse, Kernhälften, Bruch, Schalen, Würmer.

const MAX_STAPEL := {"nuss": 4, "haelfte": 6, "bruch": 8, "schale": 8, "wurm": 1}
const ART_NAMEN := {"nuss": "Nuss", "haelfte": "Kernhälfte", "bruch": "Bruch", "schale": "Schale", "wurm": "Wurm"}

var art := "nuss"            # nuss | haelfte | bruch | schale | wurm
var nuss := "wal"
var wert := 0.0              # Münzwert (bei Hälften und Bruch)
var gold := false
var faul := false
var wurm := false
var doppel := false
var angeknackst := false
var gehalten := false
var _alter := 0.0
var _meshknoten: Node3D


static func erzeuge(daten: Dictionary) -> Item:
	var it := Item.new()
	it.art = daten.get("art", "nuss")
	it.nuss = daten.get("nuss", "wal")
	it.wert = float(daten.get("wert", 0.0))
	it.gold = bool(daten.get("gold", false))
	it.faul = bool(daten.get("faul", false))
	it.wurm = bool(daten.get("wurm", false))
	it.doppel = bool(daten.get("doppel", false))
	it.angeknackst = bool(daten.get("angeknackst", false))
	it._aufbauen()
	return it


func daten() -> Dictionary:
	return {"art": art, "nuss": nuss, "wert": wert, "gold": gold, "faul": faul, "wurm": wurm,
		"doppel": doppel, "angeknackst": angeknackst}


func anzeige_name() -> String:
	var n: String = Data.NUESSE[nuss].name
	match art:
		"nuss":
			if gold:
				return "Goldene " + n
			if faul:
				return "Faule " + n
			return n + (" (angeknackst)" if angeknackst else "")
		"haelfte":
			return "%s-Kernhälfte" % n
		"bruch":
			return "%s-Bruch" % n
		"schale":
			return "Schale"
	return ART_NAMEN.get(art, art)


func _aufbauen() -> void:
	collision_layer = Data.L_ITEM
	collision_mask = Data.L_WELT | Data.L_ITEM | Data.L_BEHAELTER
	continuous_cd = true
	can_sleep = true
	var info: Dictionary = Data.NUESSE[nuss]
	var r: float = info.groesse
	var form: Vector3 = info.form
	var farbe: Color = info.farbe
	var kernfarbe: Color = info.kern
	if faul:
		farbe = Color(0.26, 0.3, 0.16)
	_meshknoten = Node3D.new()
	add_child(_meshknoten)
	var cs := CollisionShape3D.new()
	match art:
		"nuss":
			mass = 0.05
			var m: Material
			if gold:
				m = Bau.mat(Color(1.0, 0.78, 0.2), 0.25, 0.9)
			else:
				m = Bau.mat(farbe, 0.75)
			var kugel := Bau.mesh_instanz(Bau.kugel_mesh(r, false, 18), m)
			kugel.scale = form
			_meshknoten.add_child(kugel)
			# Naht der Nuss
			var naht := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = r * 0.96
			torus.outer_radius = r * 1.04
			torus.rings = 24
			torus.ring_segments = 6
			naht.mesh = torus
			naht.material_override = Bau.mat(farbe.darkened(0.3), 0.8)
			naht.rotation_degrees = Vector3(0, 0, 90)
			naht.scale = Vector3(form.y, 1.0, form.z)
			_meshknoten.add_child(naht)
			if angeknackst:
				var riss := Bau.mesh_instanz(Bau.box_mesh(Vector3(r * 0.15, r * 1.6, r * 0.15)), Bau.mat(Color(0.15, 0.1, 0.05)))
				riss.position = Vector3(r * 0.7 * form.x, 0, 0)
				_meshknoten.add_child(riss)
			var s := SphereShape3D.new()
			s.radius = r * max(form.x, form.y, form.z) * 0.85
			cs.shape = s
		"haelfte":
			mass = 0.02
			var halb := Bau.mesh_instanz(Bau.kugel_mesh(r * 0.82, true, 14), Bau.mat(kernfarbe if not gold else Color(1, 0.85, 0.35), 0.6, 0.6 if gold else 0.0))
			halb.scale = Vector3(form.x, form.y * 0.9, form.z)
			_meshknoten.add_child(halb)
			var b := BoxShape3D.new()
			b.size = Vector3(r * 1.5 * form.x, r * 0.8, r * 1.5 * form.z)
			cs.shape = b
			cs.position = Vector3(0, r * 0.35, 0)
		"bruch":
			mass = 0.01
			var g := Vector3(randf_range(0.5, 0.8), randf_range(0.35, 0.6), randf_range(0.5, 0.8)) * r
			var stueck := Bau.mesh_instanz(Bau.box_mesh(g), Bau.mat(kernfarbe.darkened(0.08), 0.7))
			stueck.rotation = Vector3(randf(), randf(), randf())
			_meshknoten.add_child(stueck)
			var b2 := BoxShape3D.new()
			b2.size = g
			cs.shape = b2
		"schale":
			mass = 0.01
			var schale := Bau.mesh_instanz(Bau.kugel_mesh(r * 0.9, true, 12), Bau.mat(farbe.darkened(0.1), 0.9))
			schale.scale = Vector3(form.x * 0.9, form.y * 0.45, form.z * 0.9)
			schale.rotation_degrees.x = 180
			_meshknoten.add_child(schale)
			var b3 := BoxShape3D.new()
			b3.size = Vector3(r * 1.4, r * 0.3, r * 1.4)
			cs.shape = b3
		"wurm":
			mass = 0.005
			var kapsel := CapsuleMesh.new()
			kapsel.radius = 0.008
			kapsel.height = 0.06
			var w := Bau.mesh_instanz(kapsel, Bau.mat(Color(0.95, 0.6, 0.65), 0.5))
			w.rotation_degrees.z = 90
			_meshknoten.add_child(w)
			var b4 := BoxShape3D.new()
			b4.size = Vector3(0.06, 0.02, 0.02)
			cs.shape = b4
	add_child(cs)
	linear_damp = 0.4
	angular_damp = 1.5


func _physics_process(delta: float) -> void:
	if global_position.y < -5.0:
		queue_free()
		return
	if gehalten:
		return
	_alter += delta
	# Schalen und Bruch auf dem Boden verschwinden nach einer Weile (Leistung).
	if (art == "schale" or art == "bruch") and _alter > 60.0 and global_position.y < 0.3:
		queue_free()
	# Würmer kriechen langsam Richtung Glas.
	if art == "wurm" and _alter > 1.5 and sleeping == false and linear_velocity.length() < 0.2:
		var welt := get_tree().current_scene
		if welt and welt.has_method("glas_position"):
			var ziel: Vector3 = welt.glas_position()
			var richtung := ziel - global_position
			richtung.y = 0
			if richtung.length() > 0.05:
				apply_central_force(richtung.normalized() * 0.03)
	elif art == "wurm" and sleeping:
		sleeping = false
