class_name Bau
extends RefCounted
## Kleine Helfer, um Platzhalter-Geometrie aus Code zu bauen, bis Blender-Modelle da sind.

static var _materialien := {}


static func mat(farbe: Color, rauheit := 0.8, metall := 0.0, transparent := false) -> StandardMaterial3D:
	var schluessel := "%s|%.2f|%.2f|%s" % [farbe.to_html(), rauheit, metall, transparent]
	if _materialien.has(schluessel):
		return _materialien[schluessel]
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe
	m.roughness = rauheit
	m.metallic = metall
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materialien[schluessel] = m
	return m


static func mesh_instanz(mesh: Mesh, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	return mi


static func box_mesh(groesse: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = groesse
	return b


static func zylinder_mesh(r_oben: float, r_unten: float, hoehe: float, segmente := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_oben
	c.bottom_radius = r_unten
	c.height = hoehe
	c.radial_segments = segmente
	return c


static func kugel_mesh(radius: float, halb := false, segmente := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * (1.0 if halb else 2.0)
	s.is_hemisphere = halb
	s.radial_segments = segmente
	s.rings = max(4, segmente / 2)
	return s


## Statischer Klotz mit Kollision (Wände, Tische, Böden).
static func klotz(eltern: Node3D, groesse: Vector3, pos: Vector3, farbe: Color, kollision := true, rauheit := 0.85) -> Node3D:
	var knoten: Node3D
	if kollision:
		var sb := StaticBody3D.new()
		sb.collision_layer = Data.L_WELT
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var form := BoxShape3D.new()
		form.size = groesse
		cs.shape = form
		sb.add_child(cs)
		knoten = sb
	else:
		knoten = Node3D.new()
	knoten.position = pos
	knoten.add_child(mesh_instanz(box_mesh(groesse), mat(farbe, rauheit)))
	eltern.add_child(knoten)
	return knoten


static func zylinder(eltern: Node3D, r: float, hoehe: float, pos: Vector3, farbe: Color, kollision := false) -> Node3D:
	var knoten: Node3D
	if kollision:
		var sb := StaticBody3D.new()
		sb.collision_layer = Data.L_WELT
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var form := CylinderShape3D.new()
		form.radius = r
		form.height = hoehe
		cs.shape = form
		sb.add_child(cs)
		knoten = sb
	else:
		knoten = Node3D.new()
	knoten.position = pos
	knoten.add_child(mesh_instanz(zylinder_mesh(r, r, hoehe), mat(farbe)))
	eltern.add_child(knoten)
	return knoten


static func schild(eltern: Node3D, text: String, pos: Vector3, groesse := 48, farbe := Color.WHITE, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = groesse
	l.pixel_size = 0.0025
	l.modulate = farbe
	l.outline_size = 5
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	l.double_sided = true
	eltern.add_child(l)
	return l
