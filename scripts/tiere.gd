class_name Eichhoernchen
extends Node3D
## Klaut Kernhälften aus Glas und Kiste. Mit [E], einem Wurf oder der Katze verscheuchen.

signal fertig

var weg: Array = []              # Wegpunkte bis zum Ziel
var ziel_behaelter: Behaelter
var zustand := "hin"             # hin | klauen | flucht
var beute := 0
var _index := 0
var _klau_zeit := 0.0
var _t := 0.0
var _koerper: Node3D
var bereich: Area3D
const TEMPO := 1.5


func _ready() -> void:
	_koerper = Node3D.new()
	add_child(_koerper)
	var fell := Bau.mat(Color(0.72, 0.36, 0.14), 0.9)
	var hell := Bau.mat(Color(0.95, 0.85, 0.7), 0.9)
	var leib := Bau.mesh_instanz(Bau.kugel_mesh(0.07), fell, Vector3(0, 0.07, 0))
	leib.scale = Vector3(0.8, 0.9, 1.3)
	_koerper.add_child(leib)
	_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.045), fell, Vector3(0, 0.13, -0.08)))
	_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.03), hell, Vector3(0, 0.06, -0.04)))
	for s in [-1, 1]:
		_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.014), fell, Vector3(0.025 * s, 0.18, -0.07)))
		_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.007), Bau.mat(Color(0.05, 0.03, 0.02), 0.3), Vector3(0.022 * s, 0.145, -0.118)))
	for i in 4:
		var schwanz := Bau.mesh_instanz(Bau.kugel_mesh(0.05 + i * 0.006), fell, Vector3(0, 0.08 + i * 0.05, 0.11 + sin(i * 0.9) * 0.04))
		_koerper.add_child(schwanz)
	bereich = Area3D.new()
	bereich.collision_layer = Data.L_TIER
	bereich.collision_mask = Data.L_ITEM | Data.L_BEHAELTER
	var cs := CollisionShape3D.new()
	var k := SphereShape3D.new()
	k.radius = 0.16
	cs.shape = k
	cs.position.y = 0.1
	bereich.add_child(cs)
	add_child(bereich)
	bereich.body_entered.connect(_getroffen)
	if weg.size() > 0:
		global_position = weg[0]
	Sfx.spiele("eichhorn", -6.0)


func _getroffen(body: Node) -> void:
	if body is RigidBody3D and body.linear_velocity.length() > 2.2 and not body.get("gehalten"):
		verscheuchen()


func verscheuchen() -> void:
	if zustand == "flucht":
		return
	Game.statistik.verscheucht += 1
	Sfx.spiele("eichhorn", 0.0, 1.3)
	if beute > 0 and Game.hat_talent("waechter"):
		var welt := get_tree().current_scene
		for i in beute:
			if welt.has_method("item_spawnen"):
				welt.item_spawnen({"art": "haelfte", "nuss": "wal", "wert": Data.NUESSE.wal.wert}, global_position + Vector3(0, 0.15, 0), Vector3(randf_range(-1, 1), 2, randf_range(-1, 1)))
		Game.verdiene(5)
		Game.toast.emit("Der Dieb lässt die Beute fallen (+5 Münzen)", Game.FARBE_GUT)
		beute = 0
	_flucht()


func _flucht() -> void:
	zustand = "flucht"
	weg.reverse()
	_index = max(0, weg.size() - 1 - _index)


func _process(delta: float) -> void:
	_t += delta
	match zustand:
		"hin", "flucht":
			var tempo := TEMPO * (2.0 if zustand == "flucht" else 1.0)
			if zustand == "hin" and (ziel_behaelter == null or not is_instance_valid(ziel_behaelter) or ziel_behaelter.gehalten):
				_flucht()
				return
			if _index >= weg.size():
				if zustand == "hin":
					zustand = "klauen"
					_klau_zeit = 1.2
					if ziel_behaelter.typ == "glas" and Game.hat_maschine("deckel"):
						_klau_zeit *= 3.0
					if Game.hat_talent("festung"):
						_klau_zeit *= 2.0
				else:
					fertig.emit()
					queue_free()
				return
			var ziel: Vector3 = weg[_index]
			if zustand == "hin" and _index == weg.size() - 1:
				ziel = ziel_behaelter.global_position + Vector3(0.12, 0.0, 0.0)
			var d := ziel - global_position
			if d.length() < 0.05:
				_index += 1
			else:
				global_position += d.normalized() * min(d.length(), tempo * delta)
				var flach := Vector3(d.x, 0, d.z)
				if flach.length() > 0.01:
					look_at(global_position + flach, Vector3.UP)
					rotate_y(PI)
			_koerper.position.y = abs(sin(_t * 14.0)) * 0.05
		"klauen":
			if ziel_behaelter == null or not is_instance_valid(ziel_behaelter) or ziel_behaelter.gehalten:
				_flucht()
				return
			_klau_zeit -= delta
			_koerper.position.y = abs(sin(_t * 30.0)) * 0.015
			if _klau_zeit <= 0.0:
				var menge := 3
				if Game.hat_talent("nussfluesterer"):
					menge = 1
				beute = ziel_behaelter.nimm_haelften(menge)
				if beute > 0:
					Game.statistik.gestohlen += beute
					Game.toast.emit("Ein Eichhörnchen hat %d Kernhälfte(n) geklaut!" % beute, Game.FARBE_WARN)
					Sfx.spiele("eichhorn", -2.0, 0.9)
				_flucht()
