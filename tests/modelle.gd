extends Node3D
## Zeigt alle Nussmodelle nebeneinander (nur zur Kontrolle beim Entwickeln).
## Start: godot --path . -- --modelle=/pfad/bild.png

func _ready() -> void:
	var ziel := "/tmp/modelle.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--modelle="):
			ziel = a.substr(10)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.22, 0.2)
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-50, 30, 0)
	l.shadow_enabled = true
	add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(0.3, 0.32, 0.55)
	cam.fov = 40
	add_child(cam)
	cam.look_at(Vector3(0.3, 0.0, 0.0))
	cam.current = true
	var ids := ["hasel", "wal", "mandel", "pekan", "para", "macadamia"]
	for i in ids.size():
		var id: String = ids[i]
		var x := i * 0.12
		var g := MeshInstance3D.new()
		g.mesh = Nussmodelle.ganz(id, 0, 2)
		g.material_override = Look.nuss(id)
		g.position = Vector3(x, 0.1, 0)
		add_child(g)
		var k := MeshInstance3D.new()
		k.mesh = Nussmodelle.kernhaelfte(id)
		k.material_override = Look.kern(id)
		k.position = Vector3(x, 0.0, 0.08)
		add_child(k)
		var s := MeshInstance3D.new()
		s.mesh = Nussmodelle.schalenhaelfte(id)
		s.set_surface_override_material(0, Look.nuss(id))
		s.set_surface_override_material(1, Look.schale_innen(id))
		s.position = Vector3(x, 0.0, -0.05)
		s.rotation_degrees.x = 120
		add_child(s)
		var b := MeshInstance3D.new()
		b.mesh = Nussmodelle.bruchstueck(id, i)
		b.material_override = Look.kern(id)
		b.position = Vector3(x + 0.04, 0.0, 0.12)
		add_child(b)
	var r := MeshInstance3D.new()
	r.mesh = Nussmodelle.ganz("wal", 1, 2)
	var rm := Look.nuss("wal", false, false, true)
	rm.set_shader_parameter("riss", 0.7)
	r.material_override = rm
	r.position = Vector3(0.12, 0.1, 0.12)
	add_child(r)
	var gd := MeshInstance3D.new()
	gd.mesh = Nussmodelle.ganz("wal", 2, 2)
	gd.material_override = Look.nuss("wal", true)
	gd.position = Vector3(0.24, 0.1, 0.12)
	add_child(gd)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ziel)
	get_tree().quit()
