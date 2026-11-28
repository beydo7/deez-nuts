class_name Tierwelt
extends Node3D
## Vögel, Schmetterlinge, Glühwürmchen, Hühner, Enten, Rauch und fallende Blätter (Etappe 5).
## Alles ist bewusst billig: Schwärme als MultiMesh mit Flügelschlag im Shader, der Rest
## Partikel oder ein paar einfache Figuren ohne Schatten.

const SH_FLUEGEL := preload("res://shaders/fluegel.gdshader")
const SCHWAERME := 3
const VOEGEL_JE_SCHWARM := 6
const FALTER := 9
const HUEHNER := 4

var welt: Node
var voegel: MultiMeshInstance3D
var falter: MultiMeshInstance3D
var gluehwuermchen: Node3D
var huehner: Array = []          # Dictionaries, siehe _huhn_neu
var enten: Array = []
var rauch: GPUParticles3D
var blaetter: GPUParticles3D

var _rng := RandomNumberGenerator.new()
var _zeit := 0.0
var _schwarm: Array = []         # je Schwarm {mitte, radius, hoehe, tempo, phase}
var _falter_daten: Array = []    # je Falter {pos, ziel, tempo}
var _gack: AudioStreamPlayer3D
var _gack_timer := 9.0
var _im_stall := false
var _rauch_mat: StandardMaterial3D


func _init(w: Node) -> void:
	welt = w
	name = "Tierwelt"


func _ready() -> void:
	_rng.seed = 2611
	_voegel_bauen()
	_falter_bauen()
	_gluehwuermchen_bauen()
	_huehner_bauen()
	_enten_bauen()
	_rauch_bauen()
	_blaetter_bauen()
	_tageszeit_schalten()


func _gelaende() -> Gelaende:
	return welt.get("gelaende")


func _nacht() -> float:
	var h: Himmel = welt.get("himmel")
	return h.nacht if h else (1.0 if Game.ist_nacht() else 0.0)


func _process(delta: float) -> void:
	_zeit += delta
	_tageszeit_schalten()
	if voegel.visible:
		_voegel_bewegen()
	if falter.visible:
		_falter_bewegen(delta)
	_huehner_bewegen(delta)
	_enten_bewegen(delta)
	var sp: Node3D = welt.get("spieler")
	if sp:
		blaetter.global_position = sp.global_position + Vector3(0, 6.5, 0)
		blaetter.emitting = WeltPlan.tal_r(sp.global_position.x, sp.global_position.z) > 0.8


## Wer wann zu sehen ist: Vögel und Falter am Tag, Glühwürmchen in der Nacht.
func _tageszeit_schalten() -> void:
	var n := _nacht()
	var regen: bool = Game.wetter == "regen"
	voegel.visible = n < 0.5 and not regen
	falter.visible = n < 0.3 and not regen
	gluehwuermchen.visible = n > 0.6 and not regen
	for g in gluehwuermchen.get_children():
		(g as GPUParticles3D).emitting = gluehwuermchen.visible
	# Der Rauch ist nachts kein weißer Leuchtstreifen
	if _rauch_mat:
		_rauch_mat.albedo_color = Color(1, 1, 1).lerp(Color(0.2, 0.23, 0.32), n)


# --- Vögel -----------------------------------------------------------------------
func _fluegel_mesh(spann: float, laenge: float, breit := false) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var n := PackedVector3Array()
	# Körper
	for p in [Vector3(0, 0, -laenge * 0.55), Vector3(-laenge * 0.12, 0, laenge * 0.45), Vector3(laenge * 0.12, 0, laenge * 0.45)]:
		v.append(p)
		uv.append(Vector2.ZERO)
		n.append(Vector3.UP)
	# Flügel links und rechts
	for s in [-1.0, 1.0]:
		var ecken := [[Vector3(s * laenge * 0.08, 0, -laenge * 0.2), 0.0], [Vector3(s * laenge * 0.08, 0, laenge * 0.22), 0.0], [Vector3(s * spann, 0, laenge * 0.08), 1.0]]
		if breit:
			# Schmetterling: breite Flügelfläche aus zwei Dreiecken
			var a := Vector3(s * laenge * 0.06, 0, -laenge * 0.55)
			var b := Vector3(s * laenge * 0.06, 0, laenge * 0.5)
			var c := Vector3(s * spann * 0.9, 0, laenge * 0.75)
			var d := Vector3(s * spann, 0, -laenge * 0.85)
			ecken = [[a, 0.0], [b, 0.0], [c, 0.9], [a, 0.0], [c, 0.9], [d, 1.0]]
		for p in ecken:
			v.append(p[0])
			uv.append(Vector2(float(p[1]), 0))
			n.append(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_NORMAL] = n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _schwarm_mmi(mesh: Mesh, anzahl: int, knotenname: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = anzahl
	var mmi := MultiMeshInstance3D.new()
	mmi.name = knotenname
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = SH_FLUEGEL
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-140, -5, -150), Vector3(280, 60, 260))
	add_child(mmi)
	return mmi


func _voegel_bauen() -> void:
	voegel = _schwarm_mmi(_fluegel_mesh(0.55, 0.42), SCHWAERME * VOEGEL_JE_SCHWARM, "Voegel")
	var mitten := [Vector2(-16, -12), Vector2(22, 6), Vector2(4, -52)]
	for i in SCHWAERME:
		_schwarm.append({"mitte": mitten[i], "radius": _rng.randf_range(22.0, 34.0), "hoehe": _rng.randf_range(12.0, 17.0),
			"tempo": _rng.randf_range(0.14, 0.2) * (1.0 if i % 2 == 0 else -1.0), "phase": _rng.randf() * TAU})
	for i in voegel.multimesh.instance_count:
		voegel.multimesh.set_instance_color(i, Color(0.1, 0.09, 0.09) * _rng.randf_range(0.7, 1.3))
		voegel.multimesh.set_instance_custom_data(i, Color(_rng.randf(), 0.26, _rng.randf_range(9.0, 12.0), 0))
	_voegel_bewegen()


func _schwarm_ort(s: Dictionary, t: float) -> Vector3:
	var w: float = float(s.tempo) * t + float(s.phase)
	var m: Vector2 = s.mitte
	var r: float = s.radius
	return Vector3(m.x + cos(w) * r, float(s.hoehe) + sin(w * 2.3) * 2.5, m.y + sin(w) * r * 0.65)


func _voegel_bewegen() -> void:
	for si in SCHWAERME:
		var s: Dictionary = _schwarm[si]
		var ort := _schwarm_ort(s, _zeit)
		var vor := (_schwarm_ort(s, _zeit + 0.2) - ort).normalized()
		var quer := vor.cross(Vector3.UP).normalized()
		for bi in VOEGEL_JE_SCHWARM:
			# Keilformation mit etwas Eigenleben
			var reihe := (bi + 1) / 2
			var seite := 1.0 if bi % 2 == 0 else -1.0
			var eigen := Vector3(sin(_zeit * 0.7 + bi * 1.9), sin(_zeit * 0.9 + bi * 2.7) * 0.6, cos(_zeit * 0.6 + bi)) * 0.5
			var p := ort - vor * reihe * 1.7 + quer * seite * reihe * 1.5 + eigen
			var basis := Basis.looking_at(vor, Vector3.UP).rotated(vor, sin(_zeit * 0.8 + bi) * 0.25)
			voegel.multimesh.set_instance_transform(si * VOEGEL_JE_SCHWARM + bi, Transform3D(basis, p))


# --- Schmetterlinge ---------------------------------------------------------------
func _falter_bauen() -> void:
	falter = _schwarm_mmi(_fluegel_mesh(0.1, 0.09, true), FALTER, "Falter")
	var farben := [Color(1.0, 0.85, 0.3), Color(0.95, 0.95, 0.9), Color(0.95, 0.5, 0.2), Color(0.55, 0.7, 1.0)]
	for i in FALTER:
		var p := _falter_ziel(i)
		_falter_daten.append({"pos": p, "ziel": _falter_ziel(i), "tempo": _rng.randf_range(0.6, 1.1)})
		falter.multimesh.set_instance_color(i, farben[i % farben.size()])
		falter.multimesh.set_instance_custom_data(i, Color(_rng.randf(), 0.085, _rng.randf_range(18.0, 24.0), 0.09))
	_falter_bewegen(0.0)


## Flugziele: über dem Garten, ein paar am Apfelbaum und an der Veranda.
func _falter_ziel(i: int) -> Vector3:
	var g := _gelaende()
	var x := _rng.randf_range(-14.0, -8.0)
	var z := _rng.randf_range(9.0, 15.6)
	if i % 4 == 3:
		x = _rng.randf_range(-8.0, -4.0)
		z = _rng.randf_range(16.5, 20.0)
	elif i % 4 == 2:
		x = _rng.randf_range(-4.0, 8.0)
		z = _rng.randf_range(6.0, 9.0)
	var h := g.hoehe_bei(x, z) if g else 0.0
	return Vector3(x, h + _rng.randf_range(0.5, 1.5), z)


func _falter_bewegen(delta: float) -> void:
	for i in FALTER:
		var d: Dictionary = _falter_daten[i]
		var pos: Vector3 = d.pos
		var ziel: Vector3 = d.ziel
		var weg := ziel - pos
		if weg.length() < 0.25:
			d.ziel = _falter_ziel(i)
			weg = (d.ziel as Vector3) - pos
		var richtung := weg.normalized()
		pos += richtung * float(d.tempo) * delta
		d.pos = pos
		var flatter := Vector3(sin(_zeit * 5.0 + i * 2.1) * 0.12, sin(_zeit * 7.3 + i * 1.3) * 0.1, cos(_zeit * 4.1 + i) * 0.12)
		var vor := Vector3(richtung.x, 0, richtung.z)
		if vor.length() < 0.05:
			vor = Vector3.FORWARD
		falter.multimesh.set_instance_transform(i, Transform3D(Basis.looking_at(vor.normalized(), Vector3.UP), pos + flatter))


# --- Glühwürmchen -------------------------------------------------------------------
func _gluehwuermchen_bauen() -> void:
	gluehwuermchen = Node3D.new()
	gluehwuermchen.name = "Gluehwuermchen"
	add_child(gluehwuermchen)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.75, 1.0, 0.35)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _weicher_punkt()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = mat
	var verlauf := Gradient.new()
	verlauf.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 0.85, 1.0])
	verlauf.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var rampe := GradientTexture1D.new()
	rampe.gradient = verlauf
	var weg := Bach.glaetten(WeltPlan.BACH, 2.0)
	var abstand := 99.0
	for i in range(1, weg.size()):
		var p: Vector3 = weg[i]
		abstand += Vector2(p.x - weg[i - 1].x, p.z - weg[i - 1].z).length()
		if p.y > 1.0 or WeltPlan.tal_r(p.x, p.z) > 1.05 or abstand < 11.0:
			continue
		abstand = 0.0
		var t := GPUParticles3D.new()
		t.amount = 9
		t.lifetime = 7.0
		t.preprocess = 4.0
		t.randomness = 1.0
		t.position = p + Vector3(0, 1.3, 0)
		t.visibility_aabb = AABB(Vector3(-7, -3, -7), Vector3(14, 6, 14))
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(4.5, 0.9, 4.5)
		pm.direction = Vector3(1, 0.2, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.35
		pm.gravity = Vector3.ZERO
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.4
		pm.turbulence_noise_scale = 2.0
		pm.color_ramp = rampe
		t.process_material = pm
		t.draw_pass_1 = quad
		gluehwuermchen.add_child(t)


func _weicher_punkt() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex


# --- Hühner -------------------------------------------------------------------------
func _vogel_figur(rumpf: Color, kopf: Color, schnabel: Color, kamm := Color(0, 0, 0, 0), groesse := 1.0) -> Node3D:
	var k := Node3D.new()
	var leib := Node3D.new()
	leib.name = "Leib"
	k.add_child(leib)
	var m_rumpf := Look.stoff(rumpf)
	var m_kopf := Look.stoff(kopf)
	var teile := [
		[Bau.kugel_mesh(0.13, false, 10), m_rumpf, Vector3(0, 0.2, 0), Vector3(0.85, 0.85, 1.25)],
		[Bau.kugel_mesh(0.07, false, 8), m_rumpf, Vector3(0, 0.3, 0.14), Vector3(0.7, 1.0, 0.8)],
		[Bau.kugel_mesh(0.065, false, 8), m_kopf, Vector3(0, 0.37, -0.13), Vector3.ONE],
		[Bau.zylinder_mesh(0.0, 0.022, 0.06, 6), Bau.mat(schnabel), Vector3(0, 0.36, -0.2), Vector3.ONE],
	]
	for t in teile:
		var mi := Bau.teil(leib, t[0], t[1], t[2], Vector3.ZERO, t[3])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(leib.get_child(3) as MeshInstance3D).rotation_degrees.x = -90
	if kamm.a > 0.0:
		var km := Bau.teil(leib, Bau.box_mesh(Vector3(0.015, 0.05, 0.07)), Bau.mat(kamm), Vector3(0, 0.445, -0.13))
		km.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in [-1.0, 1.0]:
			var bein := Bau.teil(k, Bau.zylinder_mesh(0.008, 0.008, 0.1, 5), Bau.mat(schnabel), Vector3(s * 0.045, 0.05, 0.0))
			bein.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s in [-1.0, 1.0]:
		var auge := Bau.teil(leib, Bau.kugel_mesh(0.011, false, 6), Bau.mat(Color(0.03, 0.03, 0.03), 0.2), Vector3(s * 0.045, 0.385, -0.17))
		auge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.scale = Vector3.ONE * groesse
	return k


func _huehner_bauen() -> void:
	var farben := [Color(0.93, 0.9, 0.84), Color(0.62, 0.36, 0.2), Color(0.9, 0.86, 0.8), Color(0.2, 0.18, 0.17)]
	var gruppe := Node3D.new()
	gruppe.name = "Huehner"
	add_child(gruppe)
	for i in HUEHNER:
		var f: Color = farben[i % farben.size()]
		var fig := _vogel_figur(f, f.lightened(0.05), Color(0.95, 0.65, 0.15), Color(0.8, 0.12, 0.1), _rng.randf_range(1.0, 1.2))
		fig.name = "Huhn%d" % i
		gruppe.add_child(fig)
		var ort := _huhn_ziel()
		fig.position = ort
		huehner.append({"knoten": fig, "ziel": ort, "zustand": "stehen", "timer": _rng.randf_range(0.5, 3.0), "phase": _rng.randf() * TAU})
	var pfad := "res://sounds/gack.wav"
	if ResourceLoader.exists(pfad):
		_gack = AudioStreamPlayer3D.new()
		_gack.stream = load(pfad)
		_gack.volume_db = -10.0
		_gack.max_distance = 22.0
		_gack.unit_size = 3.0
		_gack.bus = Sfx.BUS_DRAUSSEN
		_gack.position = Vector3(15.5, 0.5, 11.5)
		add_child(_gack)


## Die Hühner laufen frei auf der Wiese südlich vom Stall.
func _huhn_ziel() -> Vector3:
	var g := _gelaende()
	var x := _rng.randf_range(12.0, 19.5)
	var z := _rng.randf_range(10.0, 14.2)
	return Vector3(x, g.hoehe_bei(x, z) if g else 0.0, z)


func _stall_tuer() -> Vector3:
	var g := _gelaende()
	var o: Vector3 = WeltPlan.ORTE.huehnerstall
	return Vector3(o.x + 0.6, g.hoehe_bei(o.x + 0.6, o.z + 1.5) if g else 0.0, o.z + 1.5)


func _huehner_bewegen(delta: float) -> void:
	var schlafenszeit := Game.tageszeit >= 19.0 or Game.tageszeit < 6.5 or Game.wetter == "regen"
	if schlafenszeit != _im_stall:
		_im_stall = schlafenszeit
		for h in huehner:
			h.zustand = "heim" if schlafenszeit else "raus"
			h.ziel = _stall_tuer() if schlafenszeit else _huhn_ziel()
			if not schlafenszeit:
				(h.knoten as Node3D).visible = true
				(h.knoten as Node3D).position = _stall_tuer()
	var wach := 0
	for h in huehner:
		var k: Node3D = h.knoten
		if not k.visible:
			continue
		wach += 1
		var leib: Node3D = k.get_node("Leib")
		h.timer = float(h.timer) - delta
		match str(h.zustand):
			"stehen":
				leib.rotation.x = lerpf(leib.rotation.x, 0.0, delta * 8.0)
				if float(h.timer) <= 0.0:
					if _rng.randf() < 0.55:
						h.zustand = "picken"
						h.timer = _rng.randf_range(1.2, 3.0)
					else:
						h.zustand = "gehen"
						h.ziel = _huhn_ziel() if _rng.randf() < 0.3 else k.position + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
			"picken":
				leib.rotation.x = -0.55 * absf(sin(_zeit * 9.0 + float(h.phase)))
				if float(h.timer) <= 0.0:
					h.zustand = "stehen"
					h.timer = _rng.randf_range(0.4, 2.0)
			"gehen", "heim", "raus":
				leib.rotation.x = lerpf(leib.rotation.x, 0.0, delta * 8.0)
				var ziel: Vector3 = h.ziel
				ziel.x = clampf(ziel.x, 11.5, 20.0)
				ziel.z = clampf(ziel.z, 9.7, 14.6)
				var weg := Vector3(ziel.x - k.position.x, 0, ziel.z - k.position.z)
				if weg.length() < 0.15:
					if str(h.zustand) == "heim":
						k.visible = false
					h.zustand = "stehen"
					h.timer = _rng.randf_range(0.5, 2.5)
				else:
					var tempo := 1.6 if str(h.zustand) == "heim" else 0.7
					var schritt := weg.normalized() * tempo * delta
					k.position.x += schritt.x
					k.position.z += schritt.z
					k.rotation.y = lerp_angle(k.rotation.y, atan2(-weg.x, -weg.z), delta * 6.0)
					var g := _gelaende()
					k.position.y = (g.hoehe_bei(k.position.x, k.position.z) if g else 0.0) + absf(sin(_zeit * 10.0 + float(h.phase))) * 0.02
	# Gackern am Tag
	if _gack and wach > 0 and not Game.selbsttest:
		_gack_timer -= delta
		if _gack_timer <= 0.0:
			_gack_timer = _rng.randf_range(9.0, 26.0)
			_gack.pitch_scale = _rng.randf_range(0.9, 1.15)
			_gack.play()


func huehner_wach() -> int:
	var n := 0
	for h in huehner:
		if (h.knoten as Node3D).visible:
			n += 1
	return n


# --- Enten -----------------------------------------------------------------------------
func _enten_bauen() -> void:
	var a: Vector3 = WeltPlan.BACH[5]
	var b: Vector3 = WeltPlan.BACH[6]
	var gruppe := Node3D.new()
	gruppe.name = "Enten"
	add_child(gruppe)
	for i in 2:
		var fig := _vogel_figur(Color(0.5, 0.38, 0.26) if i == 0 else Color(0.82, 0.8, 0.76), Color(0.12, 0.36, 0.22) if i == 1 else Color(0.45, 0.33, 0.22), Color(0.95, 0.75, 0.15), Color(0, 0, 0, 0), 1.15)
		fig.name = "Ente%d" % i
		gruppe.add_child(fig)
		enten.append({"knoten": fig, "von": a.lerp(b, 0.22), "bis": a.lerp(b, 0.44), "s": 0.2 + 0.5 * i, "richtung": 1.0, "seite": -0.45 + 0.9 * i})
	_enten_bewegen(0.0)


func _enten_bewegen(delta: float) -> void:
	for e in enten:
		var k: Node3D = e.knoten
		var von: Vector3 = e.von
		var bis: Vector3 = e.bis
		var laenge := von.distance_to(bis)
		e.s = float(e.s) + float(e.richtung) * delta * 0.22 / laenge
		if float(e.s) > 1.0 or float(e.s) < 0.0:
			e.s = clampf(float(e.s), 0.0, 1.0)
			e.richtung = -float(e.richtung)
		var lauf := (bis - von).normalized()
		var quer := Vector3(-lauf.z, 0, lauf.x)
		var p := von.lerp(bis, float(e.s)) + quer * (float(e.seite) + sin(_zeit * 0.3 + float(e.seite) * 4.0) * 0.2)
		p.y = von.y - 0.13 + sin(_zeit * 1.7 + float(e.seite) * 3.0) * 0.012
		k.position = p
		var blick := lauf * float(e.richtung)
		k.rotation.y = lerp_angle(k.rotation.y, atan2(-blick.x, -blick.z), delta * 2.0)


# --- Rauch und Blätter ---------------------------------------------------------------------
func _rauch_bauen() -> void:
	rauch = GPUParticles3D.new()
	rauch.name = "Rauch"
	rauch.amount = 22
	rauch.lifetime = 6.0
	rauch.preprocess = 6.0
	rauch.position = Vector3(-1.8, 5.35, 1.4)
	rauch.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 12, 12))
	rauch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.12, 0.05, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var groesse := Curve.new()
	groesse.add_point(Vector2(0, 0.35))
	groesse.add_point(Vector2(1, 2.4))
	var gt := CurveTexture.new()
	gt.curve = groesse
	pm.scale_curve = gt
	var verlauf := Gradient.new()
	verlauf.offsets = PackedFloat32Array([0.0, 0.12, 1.0])
	verlauf.colors = PackedColorArray([Color(0.8, 0.8, 0.8, 0.0), Color(0.82, 0.82, 0.84, 0.34), Color(0.9, 0.9, 0.92, 0.0)])
	var rampe := GradientTexture1D.new()
	rampe.gradient = verlauf
	pm.color_ramp = rampe
	rauch.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _weicher_punkt()
	_rauch_mat = m
	quad.material = m
	rauch.draw_pass_1 = quad
	add_child(rauch)


func _blaetter_bauen() -> void:
	blaetter = GPUParticles3D.new()
	blaetter.name = "Blaetter"
	blaetter.amount = 14
	blaetter.lifetime = 9.0
	blaetter.local_coords = false
	blaetter.emitting = false
	blaetter.visibility_aabb = AABB(Vector3(-16, -12, -16), Vector3(32, 16, 32))
	blaetter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12, 0.6, 12)
	pm.direction = Vector3(1, -0.3, 0.3)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, -0.55, 0)
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	var farben := Gradient.new()
	farben.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	farben.colors = PackedColorArray([Color(0.9, 0.5, 0.12), Color(0.95, 0.75, 0.2), Color(0.6, 0.25, 0.1)])
	var ft := GradientTexture1D.new()
	ft.gradient = farben
	pm.color_initial_ramp = ft
	blaetter.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.065)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	quad.material = m
	blaetter.draw_pass_1 = quad
	add_child(blaetter)
