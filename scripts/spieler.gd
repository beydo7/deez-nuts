class_name Spieler
extends CharacterBody3D
## Ego-Steuerung: laufen, schauen, greifen, tragen, werfen.
## An der Knackbank setzt man sich hin: Die Kamera fährt nah an den Nussknacker (Knack-Ansicht).

const LAUF := 3.2
const RENNEN := 5.5
const SPRUNG := 4.2
const SCHWERKRAFT := 12.0
const REICHWEITE := 2.6
const FOV_LAUFEN := 72.0
const FOV_SITZEN := 54.0

var kamera: Camera3D
var gehalten = null              # Item oder Behaelter
var stapel: Array = []           # weitere Items gleicher Art in der Hand
var ziel = null                  # worauf gerade gezielt wird
var ziel_punkt := Vector3.ZERO
var hinweis := ""                # Haupt-Hinweis am Fadenkreuz, z. B. "[E] Glas tragen"
var hinweis2 := ""               # Zweite Zeile (Infos)
var aktive_station: Knackstation = null
var gesperrt := false            # true, wenn ein Menü offen ist
var sitzt := false
var sitz_station: Knackstation = null
var _blick_x := 0.0
var welt: Node

var _blend := 0.0
var _blend_ziel := 0.0
var _sitz_gier := 0.0
var _sitz_neigung := 0.0
var _trauma := 0.0
var _fov_stoss := 0.0
var _zeit := 0.0
var _schritt_zeit := 0.0
var _wippen := 0.0
var _markiert: Node = null
var _nachlege_pause := 0.0
var _fp_hand: Hand
var _rausch := FastNoiseLite.new()


func _ready() -> void:
	collision_layer = Data.L_SPIELER
	collision_mask = Data.L_WELT
	var cs := CollisionShape3D.new()
	var kapsel := CapsuleShape3D.new()
	kapsel.radius = 0.3
	kapsel.height = 1.75
	cs.shape = kapsel
	cs.position.y = 0.875
	add_child(cs)
	kamera = Camera3D.new()
	kamera.fov = FOV_LAUFEN
	kamera.near = 0.02
	kamera.top_level = true
	add_child(kamera)
	kamera.current = true
	_fp_hand = Hand.erzeuge(false)
	_fp_hand.position = Vector3(0.16, -0.26, -0.42)
	_fp_hand.rotation_degrees = Vector3(10, 8, 180)
	_fp_hand.greifen = 0.55
	_fp_hand.visible = false
	kamera.add_child(_fp_hand)
	_rausch.frequency = 2.5
	welt = get_tree().current_scene
	kamera.global_transform = _kopf_transform()


# =============================================================================
# Eingabe
# =============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if gesperrt:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var e: float = float(Game.einstellungen.empfindlichkeit) * 0.01
		if sitzt:
			_sitz_gier = clampf(_sitz_gier - event.relative.x * e * 0.6, -0.55, 0.55)
			_sitz_neigung = clampf(_sitz_neigung - event.relative.y * e * 0.6, -0.3, 0.55)
		else:
			rotate_y(-event.relative.x * e)
			_blick_x = clampf(_blick_x - event.relative.y * e, -1.45, 1.45)
	if sitzt:
		_eingabe_sitzend(event)
		return
	if event.is_action_pressed("benutzen"):
		get_viewport().set_input_as_handled()
		_benutzen()
	elif event.is_action_pressed("fallenlassen"):
		_loslassen(Vector3.ZERO)
	elif event.is_action_pressed("wischen"):
		if welt.has_method("wischen"):
			welt.wischen(ziel_punkt)
	elif event.is_action_pressed("druecken"):
		_druecken_an()
	elif event.is_action_released("druecken"):
		_druecken_aus()
	elif event.is_action_pressed("rechts_klick"):
		if gehalten:
			_werfen()


func _eingabe_sitzend(event: InputEvent) -> void:
	var st := sitz_station
	if event.is_action_pressed("benutzen") or event.is_action_pressed("pause") or event.is_action_pressed("zurueck"):
		get_viewport().set_input_as_handled()
		aufstehen()
	elif event.is_action_pressed("druecken"):
		if st.geladen:
			if Game.einstellungen.tippen and st.drueckt:
				st.druecken_ende()
				aktive_station = null
			else:
				st.druecken_start()
				aktive_station = st
		else:
			_nachlegen()
	elif event.is_action_released("druecken"):
		if not Game.einstellungen.tippen and aktive_station:
			aktive_station.druecken_ende()
			aktive_station = null
	elif event.is_action_pressed("rechts_klick") or event.is_action_pressed("wischen"):
		if welt.has_method("eichhoernchen_am_tisch") and welt.eichhoernchen_am_tisch():
			welt.eichhoernchen_verjagen()
		elif welt.has_method("wischen"):
			welt.wischen(st.global_position)
			_wisch_geste()
	elif event.is_action_pressed("hebel"):
		if welt.has_method("hebel_ziehen"):
			welt.hebel_ziehen()


# =============================================================================
# Sitzen an der Knackbank
# =============================================================================
func hinsetzen(st: Knackstation) -> void:
	if sitzt or st == null:
		return
	if gehalten:
		_loslassen(Vector3.ZERO)
	sitzt = true
	sitz_station = st
	_blend_ziel = 1.0
	_sitz_gier = 0.0
	_sitz_neigung = 0.0
	velocity = Vector3.ZERO
	st.zeige_haende(true)
	_markieren(null)
	Sfx.spiele("hinsetzen", -6.0)
	Game.ziel_melden("hinsetzen")
	_nachlege_pause = 0.35


func aufstehen() -> void:
	if not sitzt:
		return
	if aktive_station:
		aktive_station.druecken_ende()
		aktive_station = null
	sitzt = false
	_blend_ziel = 0.0
	# Blick wieder nach vorn auf den Tisch
	_blick_x = -0.45
	if sitz_station:
		sitz_station.zeige_haende(false)
	sitz_station = null


func _sitz_transform() -> Transform3D:
	var st := sitz_station
	if st == null:
		return _kopf_transform()
	var basis_pos := st.global_position + Vector3(0.02, 0.66, 0.62)
	var ziel_pos := st.global_position + Vector3(0.02, 0.0, -0.1)
	var t := Transform3D.IDENTITY.translated(basis_pos).looking_at(ziel_pos, Vector3.UP)
	t.basis = Basis(Vector3.UP, _sitz_gier) * t.basis
	t.basis = t.basis * Basis(Vector3.RIGHT, _sitz_neigung)
	return t


func _kopf_transform() -> Transform3D:
	var t := global_transform
	t = t.translated_local(Vector3(0, 1.62 + _wippen, 0))
	t.basis = t.basis * Basis(Vector3.RIGHT, _blick_x)
	return t


## Hand schiebt die Schalen weg (nur Optik).
func _wisch_geste() -> void:
	if sitz_station == null:
		return
	var h := sitz_station.hand_l
	var start := h.transform
	var tw := create_tween()
	tw.tween_property(h, "position", sitz_station.to_local(sitz_station.global_position + Vector3(-0.22, 0.04, 0.05)), 0.08)
	tw.tween_property(h, "position", sitz_station.to_local(sitz_station.global_position + Vector3(0.3, 0.04, 0.05)), 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "transform", start, 0.18)


func _nachlegen() -> void:
	if sitz_station == null or sitz_station.geladen or _nachlege_pause > 0.0:
		return
	if welt.has_method("nuss_nachlegen"):
		if welt.nuss_nachlegen(sitz_station):
			_nachlege_pause = 0.4


# =============================================================================
# Bewegung und Kamera
# =============================================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= SCHWERKRAFT * delta
	var richtung := Vector3.ZERO
	if not gesperrt and not sitzt:
		var eingabe := Input.get_vector("links", "rechts", "vor", "zurueck")
		richtung = (transform.basis * Vector3(eingabe.x, 0, eingabe.y)).normalized()
		if Input.is_action_just_pressed("springen") and is_on_floor():
			velocity.y = SPRUNG
	var tempo := RENNEN if Input.is_action_pressed("rennen") else LAUF
	velocity.x = move_toward(velocity.x, richtung.x * tempo, 40.0 * delta)
	velocity.z = move_toward(velocity.z, richtung.z * tempo, 40.0 * delta)
	move_and_slide()
	if global_position.y < -10.0:
		global_position = Vector3(0, 0.2, 0.5)
	# Schritte und leichtes Wippen
	var flach := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and flach > 0.5:
		_schritt_zeit -= delta * flach / LAUF
		_wippen = sin(_zeit * 11.0 * flach / LAUF) * 0.018
		if _schritt_zeit <= 0.0:
			_schritt_zeit = 0.42
			Sfx.spiele("schritt", -16.0, 1.0, 0.12)
	else:
		_wippen = lerpf(_wippen, 0.0, delta * 8.0)
	if sitzt:
		ziel = sitz_station.koerper if sitz_station else null
		hinweis = ""
		hinweis2 = ""
	else:
		_zielen()
	_halten(delta)
	# Station loslassen, wenn man im Stehen wegschaut
	if not sitzt and aktive_station and aktive_station.drueckt:
		if not _schaut_auf_station(aktive_station):
			aktive_station.druecken_ende()
			aktive_station = null


func _process(delta: float) -> void:
	_zeit += delta
	_nachlege_pause = max(0.0, _nachlege_pause - delta)
	_blend = move_toward(_blend, _blend_ziel, delta / 0.42)
	var t := smoothstep(0.0, 1.0, _blend)
	var kt := _kopf_transform()
	var ziel_t := kt if t <= 0.0 else kt.interpolate_with(_sitz_transform(), t)
	# Wackeln (Trauma²) und Druck-Zittern
	_trauma = max(0.0, _trauma - delta * 1.8)
	var druck_zittern := 0.0
	if sitzt and sitz_station and sitz_station.drueckt:
		druck_zittern = clampf(sitz_station.druck, 0.0, 1.0) * 0.12
	var w := _trauma * _trauma + druck_zittern * druck_zittern
	if w > 0.0001:
		var n := _zeit * 40.0
		var drehung := Vector3(_rausch.get_noise_2d(n, 1.0), _rausch.get_noise_2d(n, 50.0), _rausch.get_noise_2d(n, 99.0)) * 0.06 * w
		ziel_t.basis = ziel_t.basis * Basis.from_euler(drehung)
		ziel_t.origin += ziel_t.basis * Vector3(_rausch.get_noise_2d(n, 7.0), _rausch.get_noise_2d(n, 17.0), 0) * 0.01 * w
	kamera.global_transform = ziel_t
	_fov_stoss = lerpf(_fov_stoss, 0.0, 1.0 - exp(-delta * 10.0))
	kamera.fov = lerpf(FOV_LAUFEN, FOV_SITZEN, t) + _fov_stoss
	# Automatisch nachlegen, wenn man sitzt
	if sitzt and sitz_station and not sitz_station.geladen and _nachlege_pause <= 0.0:
		_nachlegen()
	_fp_hand.visible = gehalten != null and not sitzt and _blend < 0.05


func wackeln(staerke: float) -> void:
	_trauma = clampf(_trauma + staerke, 0.0, 1.0)


func fov_stoss(grad: float) -> void:
	_fov_stoss += grad


func halte_punkt() -> Vector3:
	var abstand := 0.55
	var tiefer := 0.2
	var seite := 0.1
	if gehalten is Behaelter:
		abstand = 0.7
		tiefer = 0.38
		seite = 0.05
	var k := _kopf_transform()
	return k.origin - k.basis.z * abstand - k.basis.y * tiefer + k.basis.x * seite


func _halten(delta: float) -> void:
	if gehalten == null:
		return
	if not is_instance_valid(gehalten):
		gehalten = null
		stapel.clear()
		return
	var ziel_pos := halte_punkt()
	var diff: Vector3 = ziel_pos - gehalten.global_position
	if diff.length() > 1.6:
		_loslassen(Vector3.ZERO)
		return
	gehalten.linear_velocity = (diff / max(delta, 0.001) * 0.45).limit_length(10.0)
	gehalten.angular_velocity *= 0.6
	if gehalten is Behaelter:
		var rot: Vector3 = gehalten.global_basis.get_euler()
		gehalten.angular_velocity += Vector3(-rot.x, 0, -rot.z) * 8.0


# =============================================================================
# Zielen und Hinweise
# =============================================================================
func _zielen() -> void:
	ziel = null
	hinweis = ""
	hinweis2 = ""
	var raum := get_world_3d().direct_space_state
	var k := _kopf_transform()
	var von := k.origin
	var nach := von - k.basis.z * REICHWEITE
	var anfrage := PhysicsRayQueryParameters3D.create(von, nach, Data.L_WELT | Data.L_ITEM | Data.L_BEHAELTER | Data.L_INTERAKT | Data.L_TIER)
	var ausnahmen: Array[RID] = [get_rid()]
	if gehalten and is_instance_valid(gehalten):
		ausnahmen.append(gehalten.get_rid())
	anfrage.exclude = ausnahmen
	anfrage.collide_with_areas = true
	var treffer := raum.intersect_ray(anfrage)
	if treffer.is_empty():
		ziel_punkt = nach
		_markieren(null)
		return
	ziel_punkt = treffer.position
	ziel = treffer.collider
	# Kleine Teile verzeihend auswählen: in der Nähe des Trefferpunkts nach Items suchen
	if not (ziel is Item) and not (ziel is Behaelter):
		var kugel := SphereShape3D.new()
		kugel.radius = 0.08
		var form := PhysicsShapeQueryParameters3D.new()
		form.shape = kugel
		form.transform = Transform3D(Basis(), ziel_punkt)
		form.collision_mask = Data.L_ITEM
		form.exclude = ausnahmen
		var nahe := raum.intersect_shape(form, 8)
		var bester = null
		var best_abstand := 999.0
		for n in nahe:
			if n.collider is Item and not n.collider.fliegt:
				var a: float = (n.collider.global_position - ziel_punkt).length()
				if a < best_abstand:
					best_abstand = a
					bester = n.collider
		var st := _station_von(ziel)
		if bester and (st == null or gehalten or best_abstand < 0.06):
			ziel = bester
	if ziel is Item and ziel.fliegt:
		ziel = null
	hinweis = _hinweis_fuer(ziel)
	_markieren(_markier_knoten(ziel) if hinweis != "" else null)


func _markier_knoten(o) -> Node:
	if o == null:
		return null
	if o is Item or o is Behaelter:
		return o
	if o is Interaktiv:
		if o.has_meta("station"):
			return o.get_meta("station")
		return o.get_parent()
	if o is Area3D and o.get_parent() and o.get_parent().has_method("verscheuchen"):
		return o.get_parent()
	return null


func _markieren(n: Node) -> void:
	if n == _markiert:
		return
	if _markiert and is_instance_valid(_markiert):
		Look.markiere(_markiert, false)
	_markiert = n
	if n:
		Look.markiere(n, true)


func _station_von(o) -> Knackstation:
	if o is Interaktiv and o.has_meta("station"):
		return o.get_meta("station")
	return null


func _schaut_auf_station(s: Knackstation) -> bool:
	return _station_von(ziel) == s


func _hinweis_fuer(o) -> String:
	var st := _station_von(o)
	if gehalten:
		var was := _gehalten_name()
		if o is Interaktiv and o.mit_gegenstand and o.aktion.is_valid():
			return "[E] %s" % o.text_mit_gegenstand
		if st and gehalten is Item and gehalten.art == "nuss" and st.kann_laden():
			return "[E] %s in den Knacker legen" % was
		if o is Behaelter and gehalten is Item and o.akzeptiert(gehalten.art):
			hinweis2 = o.info_text()
			return "[E] %s hinein" % was
		if o is Item and gehalten is Item and o.art == gehalten.art and stapel.size() + 1 < Item.MAX_STAPEL.get(o.art, 1):
			return "[E] dazunehmen (%s)" % was
		hinweis2 = "[Rechtsklick] werfen  ·  [Q] fallen lassen"
		return "[E] %s ablegen" % was
	if st:
		hinweis2 = "%s  ·  Linksklick geht auch" % st.koerper.text
		return "[E] An die Knackbank setzen"
	if o is Item:
		return "[E] %s nehmen" % o.anzeige_name()
	if o is Behaelter:
		hinweis2 = o.info_text()
		return "[E] %s tragen" % o.anzeige_name()
	if o is Interaktiv:
		if o.info.is_valid():
			hinweis2 = o.info.call()
		return "[E] %s" % o.text
	if o is Area3D and o.get_parent() and o.get_parent().has_method("verscheuchen"):
		return "[E] Eichhörnchen verscheuchen!"
	return ""


func _gehalten_name() -> String:
	if gehalten is Item:
		var n: String = gehalten.anzeige_name()
		if stapel.size() > 0:
			return "%d× %s" % [stapel.size() + 1, n]
		return n
	if gehalten is Behaelter:
		return gehalten.anzeige_name()
	return ""


# =============================================================================
# Benutzen, Greifen, Werfen
# =============================================================================
func _benutzen() -> void:
	var st := _station_von(ziel)
	if gehalten:
		if ziel is Interaktiv and ziel.mit_gegenstand:
			ziel.benutzen(self)
			return
		if gehalten is Item:
			if st and gehalten.art == "nuss" and st.kann_laden():
				if st.lade(gehalten.daten()):
					_verbrauche_eins()
				return
			if ziel is Behaelter and ziel.akzeptiert(gehalten.art):
				var rein := 0
				while gehalten and ziel.nimmt_auf(gehalten.daten()):
					rein += 1
					_verbrauche_eins()
				if rein > 0:
					Sfx.spiele("einwurf")
					ziel.stoss()
				else:
					Sfx.spiele("fehler")
					Game.toast.emit("%s ist voll" % ziel.anzeige_name(), Game.FARBE_WARN)
				return
			if ziel is Item and ziel.art == gehalten.art and stapel.size() + 1 < Item.MAX_STAPEL.get(ziel.art, 1):
				stapel.append(ziel.daten())
				ziel.queue_free()
				Sfx.spiele("greifen", -4.0, 1.2)
				return
		_loslassen(Vector3.ZERO)
		return
	if st:
		hinsetzen(st)
		return
	if ziel is Item or ziel is Behaelter:
		_greifen(ziel)
	elif ziel is Interaktiv:
		ziel.benutzen(self)
	elif ziel is Area3D and ziel.get_parent() and ziel.get_parent().has_method("verscheuchen"):
		ziel.get_parent().verscheuchen()


func _greifen(o) -> void:
	if o == null or not is_instance_valid(o):
		return
	if o is Behaelter and o.freeze:
		return
	gehalten = o
	stapel.clear()
	o.set("gehalten", true)
	o.gravity_scale = 0.0
	o.sleeping = false
	Sfx.spiele("greifen", -4.0)


## Nimmt ein Teil aus der Hand weg (z. B. weil es ins Glas ging).
func _verbrauche_eins() -> void:
	if stapel.size() > 0:
		stapel.pop_back()
		return
	if gehalten:
		gehalten.queue_free()
	gehalten = null


func _loslassen(impuls: Vector3) -> void:
	if gehalten == null or not is_instance_valid(gehalten):
		gehalten = null
		stapel.clear()
		return
	var o = gehalten
	gehalten = null
	o.set("gehalten", false)
	o.gravity_scale = 1.0
	o.linear_velocity = impuls
	for d in stapel:
		if welt.has_method("item_spawnen"):
			var streu := Vector3(randf_range(-0.05, 0.05), randf_range(0, 0.05), randf_range(-0.05, 0.05))
			welt.item_spawnen(d, o.global_position + streu, impuls * randf_range(0.85, 1.05) + streu * 4.0)
	stapel.clear()
	if impuls == Vector3.ZERO:
		Sfx.spiele("ablegen", -6.0)


func _werfen() -> void:
	var kraft := 3.0 if gehalten is Behaelter else 5.5
	var k := _kopf_transform()
	_loslassen(-k.basis.z * kraft + Vector3(0, 0.8, 0))
	Sfx.spiele("werfen", -4.0)


func _druecken_an() -> void:
	if gehalten:
		_werfen()
		return
	var st := _station_von(ziel)
	if st:
		hinsetzen(st)
		return
	if ziel is Area3D and ziel.get_parent() and ziel.get_parent().has_method("verscheuchen"):
		ziel.get_parent().verscheuchen()


func _druecken_aus() -> void:
	if Game.einstellungen.tippen:
		return
	if aktive_station:
		aktive_station.druecken_ende()
		aktive_station = null


func blickt_auf_station() -> Knackstation:
	if sitzt:
		return sitz_station
	return _station_von(ziel)
