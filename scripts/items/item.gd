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
var fliegt := false             # wird gerade per Flugbahn in einen Behälter gelenkt
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
	_meshknoten = Node3D.new()
	add_child(_meshknoten)
	var cs := CollisionShape3D.new()
	var variante := randi() % 3
	match art:
		"nuss":
			mass = 0.05
			var mi := Bau.mesh_instanz(Nussmodelle.ganz(nuss, variante, 1), Look.nuss(nuss, gold, faul))
			_meshknoten.add_child(mi)
			if angeknackst:
				var m := Look.nuss(nuss, gold, faul, true)
				m.set_shader_parameter("riss", 0.35)
				mi.material_override = m
			var aabb := mi.mesh.get_aabb()
			var s := SphereShape3D.new()
			s.radius = minf(aabb.size.x, minf(aabb.size.y, aabb.size.z)) * 0.5
			cs.shape = s
		"haelfte":
			mass = 0.02
			var k := Bau.mesh_instanz(Nussmodelle.kernhaelfte(nuss, 0), Look.kern(nuss, gold))
			_meshknoten.add_child(k)
			var b := BoxShape3D.new()
			var ab := k.mesh.get_aabb()
			b.size = ab.size * Vector3(0.9, 1.0, 0.9)
			cs.shape = b
			cs.position = ab.get_center()
		"bruch":
			mass = 0.01
			var st := Bau.mesh_instanz(Nussmodelle.bruchstueck(nuss, variante), Look.kern(nuss))
			_meshknoten.add_child(st)
			var b2 := BoxShape3D.new()
			b2.size = st.mesh.get_aabb().size * 0.9
			cs.shape = b2
		"schale":
			mass = 0.01
			var sch := MeshInstance3D.new()
			sch.mesh = Nussmodelle.schalenhaelfte(nuss, variante)
			sch.set_surface_override_material(0, Look.nuss(nuss, false, faul))
			sch.set_surface_override_material(1, Look.schale_innen(nuss))
			sch.rotation_degrees.x = 180 if randf() < 0.5 else 0
			_meshknoten.add_child(sch)
			var b3 := BoxShape3D.new()
			var ab3 := sch.mesh.get_aabb()
			b3.size = Vector3(ab3.size.x, r * 0.5, ab3.size.z) * 0.9
			cs.shape = b3
		"wurm":
			mass = 0.005
			var wk := Node3D.new()
			_meshknoten.add_child(wk)
			var wm := Look.plastik(Color(0.98, 0.62, 0.66), 0.4)
			for i in 5:
				var kugel := Bau.mesh_instanz(Bau.kugel_mesh(0.0085 - i * 0.0007, false, 8), wm, Vector3(0.012 * i - 0.024, 0, 0))
				wk.add_child(kugel)
			for a in [-1, 1]:
				wk.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.002, false, 6), Look.plastik(Color(0.05, 0.05, 0.05)), Vector3(-0.03, 0.004, 0.004 * a)))
			var b4 := BoxShape3D.new()
			b4.size = Vector3(0.06, 0.018, 0.018)
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
	if art == "wurm":
		_meshknoten.scale = Vector3(1.0 + sin(_alter * 9.0) * 0.12, 1.0, 1.0)
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
