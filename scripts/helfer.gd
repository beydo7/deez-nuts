class_name SammelHelfer
extends Node3D
## Ein zahmes Sammel-Eichhörnchen mit rotem Halstuch und Säckchen.
## Läuft zum Berg, sammelt, trägt zur nächsten Abgabestelle und liefert ab. Immer wieder.
## Bei sehr vielen Helfern steht ein sichtbares Eichhörnchen für mehrere (vielfach).

var welt: Node
var vielfach := 1
var zustand := "hin"              # hin | sammeln | zurueck
var _ziel := Vector3.INF
var _last := 0
var _sorten := {}
var _acc := 0.0
var _t := 0.0
var _koerper: Node3D
var _sack: MeshInstance3D
var _leerlauf := 0.0


func _ready() -> void:
	_koerper = Node3D.new()
	_koerper.scale = Vector3.ONE * 2.4
	add_child(_koerper)
	var fell := Look.stoff(Color(0.74, 0.4, 0.16))
	var hell := Look.stoff(Color(0.96, 0.88, 0.74))
	var leib := Bau.mesh_instanz(Bau.kugel_mesh(0.07), fell, Vector3(0, 0.07, 0))
	leib.scale = Vector3(0.8, 0.9, 1.3)
	_koerper.add_child(leib)
	_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.045), fell, Vector3(0, 0.13, -0.08)))
	_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.03), hell, Vector3(0, 0.06, -0.04)))
	for s in [-1, 1]:
		_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.014), fell, Vector3(0.025 * s, 0.18, -0.07)))
		_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.007), Look.plastik(Color(0.05, 0.03, 0.02), 0.2), Vector3(0.022 * s, 0.145, -0.118)))
	for i in 4:
		_koerper.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.05 + i * 0.006), fell, Vector3(0, 0.08 + i * 0.05, 0.11 + sin(i * 0.9) * 0.04)))
	# Halstuch und Säckchen
	var tuch := TorusMesh.new()
	tuch.inner_radius = 0.028
	tuch.outer_radius = 0.04
	_koerper.add_child(Bau.mesh_instanz(tuch, Look.stoff(Color(0.85, 0.15, 0.12)), Vector3(0, 0.105, -0.07)))
	_sack = Bau.mesh_instanz(Bau.kugel_mesh(0.04), Look.putz(Color(0.72, 0.6, 0.42), Color(0.6, 0.48, 0.32), 260.0, 0.0, 1.0), Vector3(0, 0.12, 0.04))
	_koerper.add_child(_sack)


func _process(delta: float) -> void:
	if welt == null:
		return
	_t += delta
	var berg: Nussberg = welt.berg
	var w := Game.helfer_werte()
	match zustand:
		"hin":
			if _ziel == Vector3.INF:
				_ziel = berg.naechste_stelle(global_position, 0.5, 8.0)
				if _ziel == Vector3.INF:
					return
			if _gehen(_ziel, w.tempo, delta, berg):
				zustand = "sammeln"
				_leerlauf = 0.0
		"sammeln":
			_acc += float(w.rate) * vielfach * delta
			var n := int(_acc)
			if n > 0:
				_acc -= n
				var weg := berg.abbauen(global_position, 0.7, n)
				if weg > 0:
					Game.nuesse_vom_berg(weg)
					_last += weg
					for i in weg:
						var nuss := Data.zufalls_nuss(Game.genommen, Game.rng)
						_sorten[nuss] = int(_sorten.get(nuss, 0)) + 1
				else:
					_leerlauf += delta
			global_position.y = berg.hoehe_bei(global_position.x, global_position.z)
			_koerper.rotation.x = sin(_t * 14.0) * 0.25
			if _last >= int(w.last) * vielfach or (_leerlauf > 1.5):
				if _last > 0:
					zustand = "zurueck"
					_ziel = welt.naechste_abgabe(global_position)
				else:
					zustand = "hin"
					_ziel = Vector3.INF
				_koerper.rotation.x = 0.0
		"zurueck":
			if _gehen(_ziel, w.tempo * 0.9, delta, berg):
				welt.helfer_abliefern(_sorten, global_position)
				_sorten = {}
				_last = 0
				zustand = "hin"
				_ziel = Vector3.INF
	var voll := clampf(float(_last) / float(max(1, int(w.last) * vielfach)), 0.0, 1.0)
	_sack.scale = Vector3.ONE * (0.6 + voll * 0.9)


## Läuft (hüpfend) auf ein Ziel zu. true = angekommen.
func _gehen(ziel: Vector3, tempo: float, delta: float, berg: Nussberg) -> bool:
	var d := Vector3(ziel.x - global_position.x, 0, ziel.z - global_position.z)
	if d.length() < 0.35:
		return true
	var schritt: Vector3 = d.normalized() * minf(d.length(), tempo * delta)
	global_position += schritt
	var boden := berg.hoehe_bei(global_position.x, global_position.z)
	global_position.y = boden + absf(sin(_t * 10.0)) * 0.12
	rotation.y = atan2(-d.x, -d.z)
	return false
