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
	if ResourceLoader.exists(pfad) and not _ist_export():
		var s: PackedScene = load(pfad)
		var inst := s.instantiate()
		k.add_child(inst)
		_blender_materialien(inst)
		plaetze[modell] = true
	else:
		plaetze[modell] = false
		if ersatz.is_valid():
			ersatz.call(k)
			if _ist_export():
				for n in k.find_children("*", "", true, false):
					n.set_meta("ersatz", true)
	return k


## Beim Auslesen der Ersatzmodelle für Blender (--modell-export=...) zählt nur der Ersatz aus Code;
## seine Knoten werden markiert, damit später Hinzugefügtes (Figuren, König) nicht im Modell landet.
static var _export_modus := -1


static func _ist_export() -> bool:
	if _export_modus < 0:
		_export_modus = 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--modell-export="):
				_export_modus = 1
	return _export_modus == 1


## Blender-Modelle bringen nur Farbe und Namen mit. Hier bekommen sie die Shader des Spiels:
## assets/blender/materialien.json ordnet jedem Materialnamen Shader und Werte zu.
static var _blender_tabelle: Dictionary = {}
static var _blender_geladen := false
static var _blender_cache: Dictionary = {}


static func _blender_materialien(n: Node) -> void:
	if not _blender_geladen:
		_blender_geladen = true
		var pfad := BLENDER_ORDNER + "materialien.json"
		if ResourceLoader.exists(pfad):
			var j: JSON = load(pfad)
			if j != null and j.data is Dictionary:
				_blender_tabelle = j.data
	if _blender_tabelle.is_empty():
		return
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var alt: Material = mi.mesh.surface_get_material(i)
			if alt == null:
				continue
			var mat := _blender_material(alt.resource_name)
			if mat != null:
				mi.set_surface_override_material(i, mat)


static func _blender_material(name: String) -> Material:
	if _blender_cache.has(name):
		return _blender_cache[name]
	var mat: ShaderMaterial = null
	if _blender_tabelle.has(name):
		var d: Dictionary = _blender_tabelle[name]
		var sh := str(d.get("shader", ""))
		if sh != "" and ResourceLoader.exists(sh):
			mat = ShaderMaterial.new()
			mat.shader = load(sh)
			var werte: Dictionary = d.get("u", {})
			for schluessel in werte:
				var w = werte[schluessel]
				if w is Array and w.size() >= 4 and str(w[0]) == "c":
					mat.set_shader_parameter(schluessel, Color(w[1], w[2], w[3], w[4] if w.size() > 4 else 1.0))
				elif w is Array and w.size() >= 4:
					mat.set_shader_parameter(schluessel, Vector3(w[1], w[2], w[3]))
				else:
					mat.set_shader_parameter(schluessel, w)
	_blender_cache[name] = mat
	return mat


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
