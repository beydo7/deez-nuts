class_name Modelle
extends RefCounted
## Lädt fertige Modelle aus assets/ (Kenney und KayKit, beide CC0) und stellt sie in die Welt.
## Dazu die Modellplätze für die Blender-Modelle: Liegt assets/blender/<name>.glb im Projekt,
## wird es geladen, sonst baut ein Ersatz aus Code das Objekt in den richtigen Maßen.

const BLENDER_ORDNER := "res://assets/blender/"

static var _herbst_mats := {}
## Alle Modellplätze dieser Sitzung: Name -> true, wenn ein Blender-Modell geladen wurde
static var plaetze := {}


static func neu(pfad: String) -> Node3D:
	var s: PackedScene = load("res://assets/" + pfad)
	var n := s.instantiate() as Node3D
	if pfad.begins_with("natur/"):
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).mesh = mit_blattgruen((mi as MeshInstance3D).mesh)
	return n


## Setzt ein Modell an eine Stelle. drehung in Grad um Y, skala gleichmäßig.
static func setze(eltern: Node, pfad: String, pos: Vector3, drehung := 0.0, skala := 1.0) -> Node3D:
	var n := neu(pfad)
	eltern.add_child(n)
	n.position = pos
	n.rotation_degrees.y = drehung
	n.scale = Vector3.ONE * skala
	return n


## Modellplatz für ein Blender-Modell. Die Front des Modells zeigt nach +Z (in Blender nach -Y).
## ersatz(knoten) baut das Ersatzmodell in den Knoten, solange es keine .glb gibt.
static func platz(eltern: Node, modell: String, pos: Vector3, drehung := 0.0, ersatz := Callable()) -> Node3D:
	var k := Node3D.new()
	k.name = modell
	eltern.add_child(k)
	k.position = pos
	k.rotation_degrees.y = drehung
	var pfad := BLENDER_ORDNER + modell + ".glb"
	if ResourceLoader.exists(pfad):
		var s: PackedScene = load(pfad)
		k.add_child(s.instantiate())
		plaetze[modell] = true
	else:
		plaetze[modell] = false
		if ersatz.is_valid():
			ersatz.call(k)
	return k


## Herbstliche Variante eines KayKit-Materials (Laub orange und gold).
static func herbst_material(alt: Material) -> Material:
	if not (alt is StandardMaterial3D):
		return alt
	if not _herbst_mats.has(alt):
		var neu_m := (alt as StandardMaterial3D).duplicate() as StandardMaterial3D
		neu_m.albedo_texture = load("res://assets/wald/forest_texture_herbst.png")
		_herbst_mats[alt] = neu_m
	return _herbst_mats[alt]


static var _toene := {}
static var _gruen := {}


## Kenney-Pflanzen haben türkises Laub. Liefert ein Mesh, bei dem diese Flächen
## ein warmes Blattgrün bekommen; alle anderen Farben bleiben.
static func mit_blattgruen(mesh: Mesh) -> Mesh:
	if _gruen.has(mesh):
		return _gruen[mesh]
	var neu_mesh: Mesh = mesh.duplicate()
	for i in neu_mesh.get_surface_count():
		var m := neu_mesh.surface_get_material(i)
		if m is StandardMaterial3D:
			var c: Color = (m as StandardMaterial3D).albedo_color
			if c.g > c.r * 1.15 and c.b > c.r * 1.15:
				var m2 := m.duplicate() as StandardMaterial3D
				var hell := c.get_luminance()
				m2.albedo_color = Color(0.42, 0.6, 0.2) * (0.55 + hell)
				m2.albedo_color.a = 1.0
				neu_mesh.surface_set_material(i, m2)
	_gruen[mesh] = neu_mesh
	return neu_mesh

## Abgetönte Variante eines Materials (z. B. wärmere Felsen).
static func getoent_material(alt: Material, ton: Color) -> Material:
	if not (alt is StandardMaterial3D):
		return alt
	var k := "%d|%s" % [alt.get_instance_id(), ton.to_html()]
	if not _toene.has(k):
		var neu_m := (alt as StandardMaterial3D).duplicate() as StandardMaterial3D
		neu_m.albedo_color = neu_m.albedo_color * ton
		_toene[k] = neu_m
	return _toene[k]


## Tauscht bei einem KayKit-Modell die Farbtextur gegen die herbstliche Variante.
static func herbstlich(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			m.set_surface_override_material(i, herbst_material(m.mesh.surface_get_material(i)))
