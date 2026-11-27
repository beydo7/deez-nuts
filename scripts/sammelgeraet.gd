class_name Sammelgeraet
extends Node3D
## Das Sammelwerkzeug in der rechten Hand (Ego-Sicht) und der Beutel in der linken.
## Handwerkzeuge schwingen beim Sammeln, Sauger rütteln und brummen.

var id := ""
var arbeitet := false
var _modell: Node3D
var _hand: Hand
var _beutel: Node3D
var _beutel_koerper: MeshInstance3D
var _phase := 0.0
var _ruhe := Transform3D.IDENTITY
var _fuell := 0.0


func _ready() -> void:
	_beutel = Node3D.new()
	_beutel.position = Vector3(-0.3, -0.3, -0.5)
	add_child(_beutel)
	var hand_l := Hand.erzeuge(true)
	hand_l.rotation_degrees = Vector3(20, -15, 0)
	hand_l.greifen = 0.85
	_beutel.add_child(hand_l)
	_beutel_koerper = Bau.mesh_instanz(Bau.kugel_mesh(1.0, false, 18), Look.putz(Color(0.72, 0.6, 0.42), Color(0.6, 0.48, 0.32), 260.0, 0.0, 1.0))
	_beutel.add_child(_beutel_koerper)
	_beutel_koerper.scale = Vector3(0.05, 0.055, 0.045)
	Bau.teil(_beutel, Bau.zylinder_mesh(0.025, 0.04, 0.05, 12), Look.stoff(Color(0.5, 0.35, 0.2)), Vector3(0, 0.0, -0.02))
	setze("haende")


func setze(neu: String) -> void:
	if neu == id:
		return
	id = neu
	if _modell:
		_modell.queue_free()
	_modell = Node3D.new()
	add_child(_modell)
	_hand = Hand.erzeuge(false)
	var holz := Look.holz(Look.EICHE, 9.0, 0.3)
	var stahl := Look.metall(Color(0.72, 0.74, 0.77), 0.3)
	match id:
		"haende":
			_modell.add_child(_hand)
			_hand.rotation_degrees = Vector3(-25, 10, 0)
			_hand.greifen = 0.3
			_ruhe = Transform3D(Basis(), Vector3(0.24, -0.26, -0.48))
		"loeffel":
			# Kochlöffel aus dem Kenney Food Kit (CC0), Laffe nach vorn
			var l := Modelle.setze(_modell, "kueche/cooking-spoon.glb", Vector3(0, 0.01, -0.21), -90.0, 0.8)
			_ohne_schatten(l)
			_hand_an(Vector3(0, 0.02, 0.04))
			_ruhe = Transform3D(Basis.from_euler(Vector3(-0.35, 0.15, 0)), Vector3(0.26, -0.27, -0.42))
		"harke":
			Bau.teil(_modell, Bau.zylinder_mesh(0.014, 0.014, 1.2, 10), holz, Vector3(0, 0, -0.5), Vector3(-90, 0, 0))
			Bau.teil(_modell, Bau.box_mesh(Vector3(0.36, 0.025, 0.03)), stahl, Vector3(0, 0, -1.1))
			for i in 9:
				Bau.teil(_modell, Bau.box_mesh(Vector3(0.008, 0.07, 0.008)), stahl, Vector3(-0.16 + i * 0.04, -0.04, -1.1))
			_hand_an(Vector3(0, 0.02, 0.0))
			_ruhe = Transform3D(Basis.from_euler(Vector3(-0.55, 0.12, 0)), Vector3(0.3, -0.3, -0.25))
		"schaufel":
			Bau.teil(_modell, Bau.zylinder_mesh(0.016, 0.016, 0.9, 10), holz, Vector3(0, 0, -0.35), Vector3(-90, 0, 0))
			Bau.teil(_modell, Bau.box_mesh(Vector3(0.1, 0.016, 0.02)), holz, Vector3(0, 0, 0.12))
			var blatt := Bau.teil(_modell, Bau.box_mesh(Vector3(0.24, 0.012, 0.28)), Look.metall(Color(0.45, 0.47, 0.5), 0.4), Vector3(0, -0.02, -0.92))
			blatt.rotation_degrees.x = 12
			_hand_an(Vector3(0, 0.02, -0.05))
			_ruhe = Transform3D(Basis.from_euler(Vector3(-0.5, 0.15, 0)), Vector3(0.3, -0.32, -0.25))
		"laubsauger", "turbine", "xxl":
			var farbe: Color = {"laubsauger": Color(0.95, 0.5, 0.12), "turbine": Color(0.95, 0.8, 0.15), "xxl": Color(0.8, 0.15, 0.12)}[id]
			var gross: float = {"laubsauger": 1.0, "turbine": 1.25, "xxl": 1.55}[id]
			var lack := Look.plastik(farbe, 0.35)
			var schwarz := Look.plastik(Color(0.1, 0.1, 0.11), 0.6)
			Bau.teil(_modell, Bau.box_mesh(Vector3(0.16, 0.2, 0.3) * gross), lack, Vector3(0, 0.02, 0.05))
			Bau.teil(_modell, Bau.zylinder_mesh(0.09 * gross, 0.09 * gross, 0.05, 20), schwarz, Vector3(0.09 * gross, 0.02, 0.05), Vector3(0, 0, 90))
			Bau.teil(_modell, Bau.zylinder_mesh(0.05 * gross, 0.07 * gross, 0.75 * gross, 16), schwarz, Vector3(0, -0.02, -0.4 * gross), Vector3(-90, 0, 0))
			Bau.teil(_modell, Bau.zylinder_mesh(0.075 * gross, 0.075 * gross, 0.06, 16), lack, Vector3(0, -0.02, -0.8 * gross), Vector3(-90, 0, 0))
			if id != "laubsauger":
				var ring := TorusMesh.new()
				ring.inner_radius = 0.07 * gross
				ring.outer_radius = 0.09 * gross
				Bau.teil(_modell, ring, Look.metall(Color(0.8, 0.8, 0.82), 0.25), Vector3(0, -0.02, -0.83 * gross), Vector3(90, 0, 0))
			_hand_an(Vector3(0, 0.13 * gross, 0.05))
			_ruhe = Transform3D(Basis.from_euler(Vector3(-0.3, 0.1, 0)), Vector3(0.28, -0.32, -0.32))
	_modell.transform = _ruhe


func _hand_an(pos: Vector3) -> void:
	_modell.add_child(_hand)
	_hand.position = pos
	_hand.rotation_degrees = Vector3(0, 0, 0)
	_hand.greifen = 0.85


func ist_sauger() -> bool:
	return id in ["laubsauger", "turbine", "xxl"]


func setze_fuellung(anteil: float) -> void:
	_fuell = clampf(anteil, 0.0, 1.0)


func _process(delta: float) -> void:
	if _modell == null:
		return
	var t := _ruhe
	if arbeitet:
		_phase += delta * (9.0 if not ist_sauger() else 30.0)
		if ist_sauger():
			t.origin += Vector3(sin(_phase * 1.7), cos(_phase * 2.3), 0) * 0.004
		else:
			# Schaufelbewegung: Werkzeug kommt ins Bild, sticht nach vorn ein und hebt die Ladung an
			var s := (sin(_phase) * 0.5 + 0.5)
			t.origin += Vector3(-0.07 * s, 0.05 - 0.07 * s, -0.04 - 0.1 * s)
			t.basis = t.basis * Basis(Vector3.RIGHT, 0.55 - 0.45 * s)
			if id == "haende" and _hand:
				_hand.greifen = 0.2 + 0.7 * s
	else:
		_phase = 0.0
		t.origin.y += sin(Time.get_ticks_msec() * 0.002) * 0.004
	_modell.transform = _modell.transform.interpolate_with(t, 1.0 - exp(-delta * 18.0))
	# Beutel wächst mit dem Inhalt
	var groesse := lerpf(0.05, 0.13, _fuell)
	var ziel := Vector3(groesse, groesse * 1.1, groesse * 0.9)
	_beutel_koerper.scale = _beutel_koerper.scale.lerp(ziel, 1.0 - exp(-delta * 10.0))
	_beutel_koerper.position = Vector3(0, -groesse * 0.9, 0)


## Wohin die gesammelten Nüsse fliegen (Öffnung des Beutels).
func beutel_mund() -> Vector3:
	return _beutel.global_position + Vector3(0, 0.02, 0)


func _ohne_schatten(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_ohne_schatten(c)
