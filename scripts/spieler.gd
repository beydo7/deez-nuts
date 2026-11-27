class_name Spieler
extends CharacterBody3D
## Ego-Steuerung: laufen, schauen, greifen, tragen, werfen, knacken.

const LAUF := 3.2
const RENNEN := 5.5
const SPRUNG := 4.2
const SCHWERKRAFT := 12.0
const REICHWEITE := 2.6

var kamera: Camera3D
var gehalten = null              # Item oder Behaelter
var stapel: Array = []           # weitere Items gleicher Art in der Hand
var ziel = null                  # worauf gerade gezielt wird
var ziel_punkt := Vector3.ZERO
var hinweis := ""
var aktive_station: Knackstation = null
var gesperrt := false            # true, wenn ein Menü offen ist
var _blick_x := 0.0
var welt: Node


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
	kamera.position = Vector3(0, 1.62, 0)
	kamera.fov = 72.0
	kamera.near = 0.03
	add_child(kamera)
	kamera.current = true
	welt = get_tree().current_scene


func _unhandled_input(event: InputEvent) -> void:
	if gesperrt:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var e: float = float(Game.einstellungen.empfindlichkeit) * 0.01
		rotate_y(-event.relative.x * e)
		_blick_x = clampf(_blick_x - event.relative.y * e, -1.45, 1.45)
		kamera.rotation.x = _blick_x
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
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
	elif event.is_action_pressed("werfen_alt"):
		if gehalten:
			_werfen()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= SCHWERKRAFT * delta
	var richtung := Vector3.ZERO
	if not gesperrt:
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
	_zielen()
	_halten(delta)
	# Station loslassen, wenn man wegschaut oder sich entfernt
	if aktive_station and aktive_station.drueckt:
		if not _schaut_auf_station(aktive_station):
			aktive_station.druecken_ende()
			aktive_station = null


func halte_punkt() -> Vector3:
	var abstand := 0.55
	var tiefer := 0.18
	if gehalten is Behaelter:
		abstand = 0.75
		tiefer = 0.35
	return kamera.global_position - kamera.global_basis.z * abstand - kamera.global_basis.y * tiefer


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
		# Behälter aufrecht halten
		var rot: Vector3 = gehalten.global_basis.get_euler()
		gehalten.angular_velocity += Vector3(-rot.x, 0, -rot.z) * 8.0


func _zielen() -> void:
	ziel = null
	hinweis = ""
	var raum := get_world_3d().direct_space_state
	var von := kamera.global_position
	var nach := von - kamera.global_basis.z * REICHWEITE
	var anfrage := PhysicsRayQueryParameters3D.create(von, nach, Data.L_WELT | Data.L_ITEM | Data.L_BEHAELTER | Data.L_INTERAKT | Data.L_TIER)
	var ausnahmen: Array[RID] = [get_rid()]
	if gehalten and is_instance_valid(gehalten):
		ausnahmen.append(gehalten.get_rid())
	anfrage.exclude = ausnahmen
	anfrage.collide_with_areas = true
	var treffer := raum.intersect_ray(anfrage)
	if treffer.is_empty():
		ziel_punkt = nach
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
			if n.collider is Item:
				var a: float = (n.collider.global_position - ziel_punkt).length()
				if a < best_abstand:
					best_abstand = a
					bester = n.collider
		var st := _station_von(ziel)
		# Eine geladene Station hat Vorrang (zum Drücken), sonst gewinnt das Teil daneben.
		if bester and not (st and st.geladen and not gehalten):
			ziel = bester
	hinweis = _hinweis_fuer(ziel)


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
		if st and gehalten is Item and gehalten.art == "nuss" and st.kann_laden():
			return "[E] %s in den Knacker legen" % was
		if o is Behaelter and gehalten is Item and o.akzeptiert(gehalten.art):
			return "[E] %s ins %s  ·  [Linksklick] werfen" % [was, o.anzeige_name()]
		if o is Item and gehalten is Item and o.art == gehalten.art and stapel.size() + 1 < Item.MAX_STAPEL.get(o.art, 1):
			return "[E] dazunehmen (%s)  ·  [Linksklick] werfen" % was
		return "[E] ablegen  ·  [Linksklick] werfen  ·  [Q] fallen lassen"
	if st:
		if st.geladen:
			var n: String = Data.NUESSE[st.nuss_daten.nuss].name
			if Game.einstellungen.tippen:
				return "[Linksklick] zudrücken / loslassen  ·  %s  ·  [E] herausnehmen" % n
			return "[Linksklick halten] zudrücken, loslassen zum Knacken  ·  %s" % n
		return "%s – lege eine Nuss ein" % st.koerper.text
	if o is Item:
		return "[E] %s greifen" % o.anzeige_name()
	if o is Behaelter:
		return "[E] %s tragen" % o.anzeige_name()
	if o is Interaktiv:
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


func _benutzen() -> void:
	var st := _station_von(ziel)
	if gehalten:
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
		if st.geladen and not st.drueckt:
			var d := st.entnehme()
			if not d.is_empty() and welt.has_method("item_spawnen"):
				_greifen(welt.item_spawnen(d, halte_punkt(), Vector3.ZERO))
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
	_loslassen(-kamera.global_basis.z * kraft + Vector3(0, 0.8, 0))
	Sfx.spiele("werfen", -4.0)


func _druecken_an() -> void:
	if gehalten:
		_werfen()
		return
	var st := _station_von(ziel)
	if st and st.geladen:
		if Game.einstellungen.tippen and st.drueckt:
			st.druecken_ende()
			aktive_station = null
		else:
			st.druecken_start()
			aktive_station = st
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
	return _station_von(ziel)
