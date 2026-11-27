class_name Modelle
extends RefCounted
## Lädt fertige Modelle aus assets/ (Kenney und KayKit, beide CC0) und stellt sie in die Welt.

static func neu(pfad: String) -> Node3D:
	var s: PackedScene = load("res://assets/" + pfad)
	return s.instantiate() as Node3D


## Setzt ein Modell an eine Stelle. drehung in Grad um Y, skala gleichmäßig.
static func setze(eltern: Node, pfad: String, pos: Vector3, drehung := 0.0, skala := 1.0) -> Node3D:
	var n := neu(pfad)
	eltern.add_child(n)
	n.position = pos
	n.rotation_degrees.y = drehung
	n.scale = Vector3.ONE * skala
	return n


static var _herbst_mats := {}

## Tauscht bei KayKit-Modellen die Farbtextur gegen die herbstliche Variante (Laub orange/gold).
static func herbstlich(n: Node) -> void:
	var tex: Texture2D = load("res://assets/wald/forest_texture_herbst.png")
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var alt := m.mesh.surface_get_material(i)
			if not (alt is StandardMaterial3D):
				continue
			if not _herbst_mats.has(alt):
				var neu := (alt as StandardMaterial3D).duplicate() as StandardMaterial3D
				neu.albedo_texture = tex
				_herbst_mats[alt] = neu
			m.set_surface_override_material(i, _herbst_mats[alt])
