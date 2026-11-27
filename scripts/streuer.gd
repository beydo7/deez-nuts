class_name Streuer
extends RefCounted
## Stellt viele Kopien eines fertigen Modells (glTF aus assets/) als MultiMesh auf.
## Pro Modellteil und pro 80-m-Feld entsteht eine MultiMeshInstance, so kann Godot
## weit entfernte Felder wegschneiden und braucht trotzdem nur wenige Draw Calls.

const FELD := 80.0

static var _teile := {}


## Alle MeshInstances eines Modells mit ihrer Lage relativ zum Modellursprung.
static func teile(pfad: String) -> Array:
	if _teile.has(pfad):
		return _teile[pfad]
	var liste: Array = []
	var szene: PackedScene = load("res://assets/" + pfad)
	var wurzel := szene.instantiate()
	_sammeln(wurzel, Transform3D.IDENTITY, liste, true)
	wurzel.free()
	_teile[pfad] = liste
	return liste


static func _sammeln(n: Node, t: Transform3D, liste: Array, wurzel: bool) -> void:
	var tt := t
	if n is Node3D and not wurzel:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		liste.append([(n as MeshInstance3D).mesh, tt])
	for c in n.get_children():
		_sammeln(c, tt, liste, false)


## Setzt das Modell an alle übergebenen Stellen.
## optionen: herbst (bool, nur KayKit), schatten (bool), sicht (Meter, 0 = immer), ton (Color)
static func setzen(eltern: Node3D, pfad: String, lagen: Array, optionen := {}) -> void:
	if lagen.is_empty():
		return
	var felder := {}
	for t in lagen:
		var tr: Transform3D = t
		var schluessel := Vector2i(int(floor(tr.origin.x / FELD)), int(floor(tr.origin.z / FELD)))
		if not felder.has(schluessel):
			felder[schluessel] = []
		felder[schluessel].append(tr)
	var herbst: bool = optionen.get("herbst", false)
	var schatten: bool = optionen.get("schatten", true)
	var sicht: float = optionen.get("sicht", 0.0)
	for teil in teile(pfad):
		var mesh: Mesh = teil[0]
		var lokal: Transform3D = teil[1]
		var mat: Material = null
		if herbst:
			mat = Modelle.herbst_material(mesh.surface_get_material(0))
		if optionen.has("ton"):
			mat = Modelle.getoent_material(mat if mat else mesh.surface_get_material(0), optionen.ton)
		for schluessel in felder:
			var liste: Array = felder[schluessel]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = liste.size()
			for i in liste.size():
				mm.set_instance_transform(i, liste[i] * lokal)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if mat:
				mmi.material_override = mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if schatten else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if sicht > 0.0:
				mmi.visibility_range_end = sicht
				mmi.visibility_range_end_margin = sicht * 0.15
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			eltern.add_child(mmi)


## Lage auf dem Boden mit Drehung um Y, gleichmäßiger Größe und leichter Schräglage.
static func lage(pos: Vector3, drehung: float, skala: float, neigung := 0.0, rng: RandomNumberGenerator = null) -> Transform3D:
	var b := Basis(Vector3.UP, drehung)
	if neigung > 0.0 and rng:
		b = Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, neigung)) * b
	return Transform3D(b.scaled(Vector3.ONE * skala), pos)
