class_name Katze
extends Node3D
## Mimi. Verscheucht Eichhörnchen und lässt sich streicheln.

var bereich_min := Vector3(-2.5, 0, -2.5)
var bereich_max := Vector3(2.5, 0, 2.5)
var _ziel := Vector3.ZERO
var _warte := 0.0
var _t := 0.0
var _koerper: Node3D
var streichel_koerper: Interaktiv


func _ready() -> void:
	_koerper = Node3D.new()
	add_child(_koerper)
	var fell := Bau.mat(Color(0.85, 0.55, 0.25), 0.9)
	var weiss := Bau.mat(Color(0.97, 0.95, 0.9), 0.9)
	var leib := Bau.mesh_instanz(Bau.kugel_mesh(0.12), fell, Vector3(0, 0.17, 0))
	leib.scale = Vector3(0.8, 0.8, 1.6)
	_koerper.add_child(leib)
	_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.085), fell, Vector3(0, 0.29, -0.2)))
	_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.045), weiss, Vector3(0, 0.26, -0.27)))
	for s in [-1, 1]:
		var ohr := Bau.mesh_instanz(Bau.zylinder_mesh(0.0, 0.03, 0.06, 4), fell, Vector3(0.045 * s, 0.38, -0.2))
		_koerper.add_child(ohr)
		_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.012), Bau.mat(Color(0.1, 0.25, 0.1), 0.2), Vector3(0.03 * s, 0.31, -0.275)))
		for v in [-1, 1]:
			_koerper.add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.022, 0.022, 0.12), weiss, Vector3(0.06 * s, 0.06, 0.1 * v)))
	var schwanz := Bau.mesh_instanz(Bau.zylinder_mesh(0.018, 0.025, 0.32), fell, Vector3(0, 0.3, 0.26))
	schwanz.rotation_degrees.x = 35
	_koerper.add_child(schwanz)
	streichel_koerper = Interaktiv.erzeuge(self, Vector3(0.3, 0.4, 0.55), Vector3(0, 0.2, 0), "Mimi streicheln", _streicheln)
	_neues_ziel()


func _streicheln(_spieler) -> void:
	Sfx.spiele("miau", -4.0)
	Game.toast.emit("Mimi schnurrt.", Game.FARBE_INFO)


func _neues_ziel() -> void:
	_ziel = Vector3(randf_range(bereich_min.x, bereich_max.x), 0, randf_range(bereich_min.z, bereich_max.z))
	_warte = randf_range(1.0, 4.0)


func _process(delta: float) -> void:
	_t += delta
	var tempo := 1.4 * (2.0 if Game.hat_talent("katzenfreund") else 1.0)
	var beute: Eichhoernchen = null
	var best := 999.0
	for e in get_tree().get_nodes_in_group("eichhoernchen"):
		if e.zustand != "flucht":
			var a: float = (e.global_position - global_position).length()
			if a < best:
				best = a
				beute = e
	var ziel := _ziel
	if beute:
		ziel = Vector3(beute.global_position.x, 0, beute.global_position.z)
		tempo *= 2.0
		var flach := Vector2(beute.global_position.x - global_position.x, beute.global_position.z - global_position.z)
		if flach.length() < 0.45:
			beute.verscheuchen()
			Sfx.spiele("miau", 0.0, 1.2)
			return
	else:
		if _warte > 0.0 and (Vector3(_ziel.x, 0, _ziel.z) - Vector3(global_position.x, 0, global_position.z)).length() < 0.1:
			_warte -= delta
			if _warte <= 0.0:
				_neues_ziel()
			_koerper.position.y = 0.0
			return
	var d := Vector3(ziel.x - global_position.x, 0, ziel.z - global_position.z)
	if d.length() > 0.05:
		global_position += d.normalized() * min(d.length(), tempo * delta)
		look_at(global_position + d, Vector3.UP)
		rotate_y(PI)
		_koerper.position.y = abs(sin(_t * 10.0)) * 0.02
