class_name Bach
extends Node3D
## Das Wasser des Bachs: Wasserfläche als Band entlang des Bachlaufs, der Wasserfall als
## gebogener Vorhang, Gischt im Becken und Wasserrauschen, das man in der Nähe hört.

const SH_WASSER := preload("res://shaders/wasser.gdshader")

var gelaende: Gelaende
var _mat: ShaderMaterial
var _mat_fall: ShaderMaterial


func _init(g: Gelaende) -> void:
	gelaende = g
	name = "Bach"


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SH_WASSER
	_mat_fall = ShaderMaterial.new()
	_mat_fall.shader = SH_WASSER
	_mat_fall.set_shader_parameter("tempo", 2.6)
	_mat_fall.set_shader_parameter("schaum_staerke", 0.75)
	_mat_fall.set_shader_parameter("wellen", 2.0)
	var punkte: Array = WeltPlan.BACH
	var k := WeltPlan.BACH_KANTE
	_band(punkte.slice(0, k + 1), 0.0)
	_band(punkte.slice(k + 1), 0.0)
	_becken(punkte[k + 1])
	_wasserfall(punkte[k], punkte[k + 1], punkte[k - 1])
	_gischt(punkte[k + 1])
	_klaenge(punkte)


## Glatte Kurve durch die Punkte (Catmull-Rom), etwa alle 0,8 m ein Punkt.
static func glaetten(punkte: Array, schritt := 0.8) -> Array:
	var aus: Array = []
	for i in punkte.size() - 1:
		var p0: Vector3 = punkte[maxi(i - 1, 0)]
		var p1: Vector3 = punkte[i]
		var p2: Vector3 = punkte[i + 1]
		var p3: Vector3 = punkte[mini(i + 2, punkte.size() - 1)]
		var n := maxi(1, int(Vector2(p1.x - p2.x, p1.z - p2.z).length() / schritt))
		for j in n:
			var t := float(j) / n
			var t2 := t * t
			var t3 := t2 * t
			var p := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			p.y = lerpf(p1.y, p2.y, t)
			aus.append(p)
	aus.append(punkte[-1])
	return aus


func _band(punkte: Array, _x: float) -> void:
	var weg := glaetten(punkte)
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	var laenge := 0.0
	var halb := WeltPlan.BACH_BREITE * 0.5 + 0.9
	for i in weg.size():
		var p: Vector3 = weg[i]
		var vor: Vector3 = weg[mini(i + 1, weg.size() - 1)] - weg[maxi(i - 1, 0)]
		vor.y = 0.0
		vor = vor.normalized()
		var quer := Vector3(-vor.z, 0.0, vor.x)
		if i > 0:
			laenge += Vector2(p.x - weg[i - 1].x, p.z - weg[i - 1].z).length()
		v.append(p - quer * halb)
		v.append(p + quer * halb)
		uv.append(Vector2(0.0, laenge * 0.5))
		uv.append(Vector2(1.0, laenge * 0.5))
		nrm.append(Vector3.UP)
		nrm.append(Vector3.UP)
		if i > 0:
			var a := (i - 1) * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	_mesh_hinzu(v, nrm, uv, idx, _mat)


func _becken(mitte: Vector3) -> void:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	v.append(mitte)
	uv.append(Vector2(0.5, 0.0))
	nrm.append(Vector3.UP)
	var n := 24
	for i in n + 1:
		var w := TAU * float(i) / n
		v.append(mitte + Vector3(cos(w), 0.0, sin(w)) * 3.9)
		uv.append(Vector2(0.5 + 0.5 * cos(w), 0.8))
		nrm.append(Vector3.UP)
		if i > 0:
			idx.append_array([0, i + 1, i])
	_mesh_hinzu(v, nrm, uv, idx, _mat)


## Ein Vorhang aus Wasser von der Kante bis ins Becken, oben leicht nach vorn gewölbt.
func _wasserfall(kante: Vector3, becken: Vector3, oben: Vector3) -> void:
	var richtung := Vector3(becken.x - oben.x, 0.0, becken.z - oben.z).normalized()
	var quer := Vector3(-richtung.z, 0.0, richtung.x)
	var fall := kante.y - becken.y
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	var stufen := 14
	var halb := 1.25
	for i in stufen + 1:
		var t := float(i) / stufen
		var p := Vector3(kante.x, kante.y + 0.05, kante.z) + richtung * (0.9 * sqrt(t) + 0.2 * t) + Vector3.DOWN * fall * t * t
		var breiter := halb * (1.0 + 0.35 * t)
		v.append(p - quer * breiter)
		v.append(p + quer * breiter)
		uv.append(Vector2(0.0, t * 3.0))
		uv.append(Vector2(1.0, t * 3.0))
		nrm.append(-richtung)
		nrm.append(-richtung)
		if i > 0:
			var a := (i - 1) * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	_mesh_hinzu(v, nrm, uv, idx, _mat_fall)


func _mesh_hinzu(v: PackedVector3Array, nrm: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array, mat: Material) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Gischt und feiner Nebel unten am Wasserfall.
func _gischt(becken: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.4
	p.position = becken + Vector3(0, 0.1, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.2
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -1.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var kurve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.3))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.0))
	kurve.curve = c
	pm.scale_curve = kurve
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.2)
	m.vertex_color_use_as_albedo = true
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(0.5, 0.0)
	m.albedo_texture = grad
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


## Plätschern entlang des Bachs, Rauschen am Wasserfall.
func _klaenge(punkte: Array) -> void:
	var weg := glaetten(punkte, 4.0)
	var abstand := 0.0
	for i in range(1, weg.size()):
		abstand += Vector2(weg[i].x - weg[i - 1].x, weg[i].z - weg[i - 1].z).length()
		if abstand > 18.0:
			abstand = 0.0
			_klangquelle("res://sounds/bach.wav", weg[i] + Vector3(0, 0.3, 0), -12.0, 16.0)
	var k := WeltPlan.BACH_KANTE
	_klangquelle("res://sounds/wasserfall.wav", (punkte[k] + punkte[k + 1]) * 0.5, -4.0, 45.0)


func _klangquelle(pfad: String, pos: Vector3, db: float, weite: float) -> void:
	if not ResourceLoader.exists(pfad):
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = load(pfad)
	a.volume_db = db
	a.max_distance = weite
	a.unit_size = weite * 0.18
	a.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	a.position = pos
	a.bus = Sfx.BUS_DRAUSSEN
	a.autoplay = true
	a.finished.connect(a.play)
	add_child(a)
