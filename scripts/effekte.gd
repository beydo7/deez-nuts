class_name Effekte
extends RefCounted
## Einmalige Partikel-Effekte: Schalenkrümel, Staub, Funken, Münzen.

static var _punkt: GradientTexture2D


static func _weicher_punkt() -> GradientTexture2D:
	if _punkt == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_punkt = GradientTexture2D.new()
		_punkt.gradient = g
		_punkt.fill = GradientTexture2D.FILL_RADIAL
		_punkt.fill_from = Vector2(0.5, 0.5)
		_punkt.fill_to = Vector2(0.5, 0.0)
		_punkt.width = 64
		_punkt.height = 64
	return _punkt


static func _ausblenden(alpha := 1.0) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, alpha))
	g.set_color(1, Color(1, 1, 1, 0))
	return g


static func _einmal(eltern: Node, p: CPUParticles3D, pos: Vector3, lebensdauer: float) -> CPUParticles3D:
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.lifetime = lebensdauer
	eltern.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(lebensdauer + 0.5, false).timeout.connect(p.queue_free)
	return p


## Schalensplitter, die herumspritzen.
static func kruemel(eltern: Node, pos: Vector3, nuss: String, anzahl := 18, kraft := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.amount = anzahl
	p.mesh = Nussmodelle.splitter()
	p.material_override = Look.nuss(nuss)
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 0.5 * kraft
	p.initial_velocity_max = 1.6 * kraft
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.damping_min = 0.5
	p.damping_max = 1.5
	_einmal(eltern, p, pos, 0.9)


## Weiche Staubwolke (Schalenstaub).
static func staub(eltern: Node, pos: Vector3, farbe := Color(0.85, 0.72, 0.55, 0.5), anzahl := 10, groesse := 0.05) -> void:
	var p := CPUParticles3D.new()
	p.amount = anzahl
	var q := QuadMesh.new()
	q.size = Vector2(groesse, groesse)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = _weicher_punkt()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = farbe
	p.material_override = m
	p.direction = Vector3.UP
	p.spread = 90.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.35
	p.gravity = Vector3(0, 0.05, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 2.2
	var kurve := Curve.new()
	kurve.add_point(Vector2(0, 0.5))
	kurve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = kurve
	p.color_ramp = _ausblenden(farbe.a)
	_einmal(eltern, p, pos, 1.1)


## Leuchtende Funken (perfekter Knack, Goldnuss, Verkauf).
static func funken(eltern: Node, pos: Vector3, farbe := Color(1.0, 0.85, 0.4), anzahl := 16, tempo := 0.8) -> void:
	var p := CPUParticles3D.new()
	p.amount = anzahl
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = _weicher_punkt()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = farbe * 2.5
	p.material_override = m
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = tempo * 0.4
	p.initial_velocity_max = tempo
	p.gravity = Vector3(0, -0.6, 0)
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.color_ramp = _ausblenden()
	_einmal(eltern, p, pos, 0.8)


## Münzen, die aus der Verkaufsklappe spritzen.
static func muenzen(eltern: Node, pos: Vector3, anzahl := 14) -> void:
	var p := CPUParticles3D.new()
	p.amount = anzahl
	var c := CylinderMesh.new()
	c.top_radius = 0.018
	c.bottom_radius = 0.018
	c.height = 0.004
	c.radial_segments = 14
	p.mesh = c
	p.material_override = Look.metall(Color(1.0, 0.78, 0.3), 0.25)
	p.direction = Vector3(0, 1, 0)
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = -900
	p.angular_velocity_max = 900
	p.particle_flag_rotate_y = true
	_einmal(eltern, p, pos, 1.0)
