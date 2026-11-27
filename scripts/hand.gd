class_name Hand
extends Node3D
## Eine Comic-Hand mit Ärmel. Finger zeigen nach -Z, Handfläche nach unten (-Y).
## greifen = 0 offen … 1 Faust. Linke Hand: links = true (gespiegelt).

var greifen := 0.0:
	set(w):
		greifen = clampf(w, 0.0, 1.0)
		_finger_setzen()
var _glieder: Array = []      # [gelenk1, gelenk2, faktor]
var _daumen: Node3D
var _arm: MeshInstance3D
var _bund: MeshInstance3D
## Wenn gesetzt (global), läuft der Ärmel vom Handgelenk zu diesem Punkt (z. B. unter die Kamera).
var schulter := Vector3.INF

static var _haut: StandardMaterial3D
static var _aermel: Material


static func erzeuge(links := false) -> Hand:
	var h := Hand.new()
	h._aufbauen()
	if links:
		h.scale = Vector3(-1, 1, 1)
	return h


static func _materialien() -> void:
	if _haut == null:
		_haut = StandardMaterial3D.new()
		_haut.albedo_color = Color(0.96, 0.74, 0.6)
		_haut.roughness = 0.55
		_haut.rim_enabled = true
		_haut.rim = 0.35
		_haut.rim_tint = 0.6
		_haut.backlight_enabled = true
		_haut.backlight = Color(0.5, 0.18, 0.12)
		_aermel = Look.stoff(Color(0.55, 0.16, 0.12))


func _aufbauen() -> void:
	_materialien()
	# Ärmel und Bündchen
	_arm = MeshInstance3D.new()
	_arm.mesh = Bau.zylinder_mesh(0.031, 0.04, 1.0, 14)
	_arm.material_override = _aermel
	_arm.rotation_degrees.x = 90
	_arm.scale = Vector3(1, 0.2, 1)
	_arm.position = Vector3(0, 0.002, 0.13)
	add_child(_arm)
	_bund = MeshInstance3D.new()
	_bund.mesh = Bau.zylinder_mesh(0.033, 0.033, 0.026, 14)
	_bund.material_override = Look.stoff(Color(0.45, 0.12, 0.09))
	_bund.rotation_degrees.x = 90
	_bund.position = Vector3(0, 0.002, 0.035)
	add_child(_bund)
	# Handgelenk und Handfläche
	add_child(_kugel(Vector3(0.028, 0.02, 0.03), Vector3(0, 0.0, 0.012)))
	add_child(_kugel(Vector3(0.042, 0.019, 0.048), Vector3(0, 0.0, -0.035)))
	# Finger: Zeige-, Mittel-, Ring-, kleiner Finger (Zeigefinger auf der Daumenseite -X)
	var finger := [[-0.026, 0.031, 0.026, 0.0095], [-0.009, 0.034, 0.028, 0.0098], [0.008, 0.032, 0.026, 0.0094], [0.024, 0.026, 0.021, 0.0086]]
	for i in finger.size():
		var f: Array = finger[i]
		var g1 := Node3D.new()
		g1.position = Vector3(f[0], 0.002, -0.074 + absf(f[0]) * 0.25)
		g1.rotation_degrees.y = -f[0] * 120.0
		add_child(g1)
		g1.add_child(_glied(f[1], f[3]))
		var g2 := Node3D.new()
		g2.position = Vector3(0, 0, -f[1])
		g1.add_child(g2)
		g2.add_child(_glied(f[2], f[3] * 0.93))
		_glieder.append([g1, g2, 1.0 - i * 0.04])
	# Daumen
	_daumen = Node3D.new()
	_daumen.position = Vector3(-0.036, -0.006, -0.018)
	_daumen.rotation_degrees = Vector3(-10, 50, 20)
	add_child(_daumen)
	_daumen.add_child(_glied(0.03, 0.011))
	var d2 := Node3D.new()
	d2.position = Vector3(0, 0, -0.03)
	d2.rotation_degrees.y = 15
	_daumen.add_child(d2)
	d2.add_child(_glied(0.024, 0.01))
	_finger_setzen()


func _kugel(skala: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Bau.kugel_mesh(1.0, false, 16)
	mi.material_override = _haut
	mi.scale = skala
	mi.position = pos
	return mi


func _glied(laenge: float, radius: float) -> MeshInstance3D:
	var k := CapsuleMesh.new()
	k.radius = radius
	k.height = laenge + radius * 2.0
	k.radial_segments = 10
	k.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = k
	mi.material_override = _haut
	mi.rotation_degrees.x = 90
	mi.position = Vector3(0, 0, -laenge * 0.5)
	return mi


func _process(_delta: float) -> void:
	if not visible or schulter == Vector3.INF:
		return
	# Ärmel vom Handgelenk bis zur Schulter strecken (läuft aus dem Bild heraus)
	var gelenk := to_global(Vector3(0, 0.002, 0.03))
	var richtung := schulter - gelenk
	var laenge := richtung.length()
	if laenge < 0.01:
		return
	var y := richtung / laenge
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	_arm.global_transform = Transform3D(Basis(x, y * laenge, z), gelenk + richtung * 0.5)
	_bund.global_transform = Transform3D(Basis(x, y, z), gelenk + y * 0.01)


func _finger_setzen() -> void:
	for g in _glieder:
		var f: float = g[2]
		g[0].rotation_degrees.x = -lerpf(8.0, 78.0, greifen) * f
		g[1].rotation_degrees.x = -lerpf(10.0, 85.0, greifen) * f
	if _daumen:
		_daumen.rotation_degrees.z = lerpf(20.0, 55.0, greifen)
		_daumen.rotation_degrees.y = lerpf(50.0, 30.0, greifen)
