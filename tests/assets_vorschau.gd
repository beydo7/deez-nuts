extends Node3D
## Zeigt alle Fremd-Modelle aus assets/ im Raster (nur zur Kontrolle beim Entwickeln).

func _ready() -> void:
	var ziel := "/tmp/assets.png"
	var ordner: String = "wald"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vorschau="):
			ziel = a.substr(11)
		if a.begins_with("--ordner="):
			ordner = a.substr(9)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.75)
	env.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-50, 30, 0)
	add_child(l)
	var dateien: Array = []
	for d in DirAccess.get_files_at("res://assets/" + ordner):
		if d.ends_with(".glb") or d.ends_with(".gltf"):
			dateien.append(d)
	var spalten := 8
	var abstand := 3.0 if ordner != "kueche" else 0.6
	for i in dateien.size():
		var szene: PackedScene = load("res://assets/%s/%s" % [ordner, dateien[i]])
		var n := szene.instantiate()
		add_child(n)
		n.position = Vector3((i % spalten) * abstand, 0, -(i / spalten) * abstand)
		var lb := Label3D.new()
		lb.text = dateien[i].get_basename()
		lb.font_size = 32 if ordner != "kueche" else 12
		lb.pixel_size = 0.01 if ordner != "kueche" else 0.004
		lb.position = n.position + Vector3(0, -0.15, 0.6 if ordner != "kueche" else 0.15)
		lb.rotation_degrees.x = -40
		add_child(lb)
		var aabb := Rect2()
	var cam := Camera3D.new()
	var breite := spalten * abstand
	cam.position = Vector3(breite * 0.45, breite * 0.55, breite * 0.55)
	add_child(cam)
	cam.look_at(Vector3(breite * 0.45, 0, -breite * 0.2))
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ziel)
	get_tree().quit()
