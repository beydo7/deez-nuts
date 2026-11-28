extends RefCounted
## Schreibt alle Modellplätze (Ersatzmodelle aus Code) als JSON, damit Blender sie maßgenau
## als Blockout nachbauen kann. Aufruf:
##   godot --headless --path . -- --selbsttest --bilder=/tmp/x --modell-export=/pfad/ersatz.json


func schreibe(welt: Node, pfad: String) -> void:
	var aus := []
	var namen: Array = Modelle.plaetze.keys()
	namen.sort()
	for n in namen:
		var k: Node = welt.find_child(n, true, false)
		if k == null:
			continue
		aus.append({"name": n, "k": _kinder(k)})
	var f := FileAccess.open(pfad, FileAccess.WRITE)
	f.store_string(JSON.stringify(aus))
	f.close()
	print("Modell-Export: %d Modellplätze nach %s" % [aus.size(), pfad])


func _kinder(n: Node) -> Array:
	var liste := []
	for c in n.get_children():
		var d := _knoten(c)
		if not d.is_empty():
			liste.append(d)
	return liste


func _x(t: Transform3D) -> Array:
	var b := t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


func _knoten(c: Node) -> Dictionary:
	if c is Interaktiv or c is Light3D or c is AudioStreamPlayer3D or c is GPUParticles3D or c is Area3D:
		return {}
	if not (c is Node3D):
		return {}
	if not c.has_meta("ersatz"):
		return {}  # kam nicht aus dem Ersatzmodell
	if str(c.name).begins_with("Figur_"):
		return {}  # Sammelfiguren setzt das Spiel selbst
	var n3 := c as Node3D
	var d := {"n": str(c.name), "x": _x(n3.transform), "t": "node"}
	if c.scene_file_path != "":
		d.t = "extern"
		d["pfad"] = c.scene_file_path
		return d
	if c is Label3D:
		var l := c as Label3D
		d.t = "text"
		d["text"] = l.text
		d["hoehe"] = l.font_size * l.pixel_size
		d["farbe"] = [l.modulate.r, l.modulate.g, l.modulate.b]
		return d
	if c is CollisionShape3D:
		var s: Shape3D = (c as CollisionShape3D).shape
		if s is BoxShape3D:
			d.t = "koll_box"
			d["g"] = [s.size.x, s.size.y, s.size.z]
		elif s is CylinderShape3D:
			d.t = "koll_zyl"
			d["r"] = s.radius
			d["h"] = s.height
		else:
			return {}
		return d
	if c is MultiMeshInstance3D:
		return {}
	if c is MeshInstance3D:
		var mi := c as MeshInstance3D
		var m: Mesh = mi.mesh
		if m is BoxMesh:
			d.t = "box"
			d["g"] = [m.size.x, m.size.y, m.size.z]
		elif m is CylinderMesh:
			d.t = "zyl"
			d["r1"] = m.top_radius
			d["r2"] = m.bottom_radius
			d["h"] = m.height
			d["seg"] = m.radial_segments
		elif m is SphereMesh:
			d.t = "kugel"
			d["r"] = m.radius
			d["hh"] = m.height
			d["halb"] = m.is_hemisphere
		elif m is TorusMesh:
			d.t = "torus"
			d["r1"] = m.inner_radius
			d["r2"] = m.outer_radius
		else:
			return {}
		var mat: Material = mi.material_override
		if mat == null and m != null:
			mat = m.surface_get_material(0)
		d["mat"] = _material(mat)
	d["k"] = _kinder(c)
	return d


func _material(mat: Material) -> Dictionary:
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		var art := sm.shader.resource_path.get_file().get_basename()
		var d := {"art": art, "shader": sm.shader.resource_path, "u": {}}
		for e in sm.shader.get_shader_uniform_list():
			var wert = sm.get_shader_parameter(e.name)
			if wert is Color:
				d.u[e.name] = ["c", wert.r, wert.g, wert.b, wert.a]
			elif wert is Vector3:
				d.u[e.name] = ["v", wert.x, wert.y, wert.z]
			elif wert is float or wert is int or wert is bool:
				d.u[e.name] = wert
		for p in ["farbe", "farbe2", "farbe_hell", "farbe_dunkel", "unten", "oben"]:
			var v = sm.get_shader_parameter(p)
			if v is Color:
				d[p] = [v.r, v.g, v.b]
			elif v is Vector3:
				d[p] = [v.x, v.y, v.z]
		for p in ["kacheln", "rauheit", "dielen", "lack"]:
			var w = sm.get_shader_parameter(p)
			if w != null:
				d[p] = float(w)
		return d
	if mat is StandardMaterial3D:
		var st := mat as StandardMaterial3D
		return {"art": "std", "farbe": [st.albedo_color.r, st.albedo_color.g, st.albedo_color.b], "alpha": st.albedo_color.a,
			"rauheit": st.roughness, "metall": st.metallic, "leuchtet": st.emission_enabled}
	return {"art": "std", "farbe": [0.6, 0.6, 0.6], "alpha": 1.0, "rauheit": 0.8, "metall": 0.0, "leuchtet": false}
