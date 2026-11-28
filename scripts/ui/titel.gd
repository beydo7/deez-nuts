class_name Titel
extends CanvasLayer
## Das Titelbild. Dahinter liegt kein Bild, sondern das echte Tal des aktuellen Spielstands:
## Die Kamera steht vor dem Hoftor und schaut auf Hütte und Nussberg. Je weiter man ist, desto
## kleiner ist dort der Berg. Seiten: Hauptmenü, Gläser (Spielstände), Einstellungen.

var welt: Node
var _wurzel: Control
var _seite: Control
var _kamera: Camera3D
var _stand := Vector3.ZERO
var _zeit := 0.0
var _art := "haupt"
var _blende: ColorRect


func _init(w: Node = null) -> void:
	welt = w
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	welt.hud.visible = false
	welt.spieler.gesperrt = true
	_kamera = Camera3D.new()
	_kamera.process_mode = Node.PROCESS_MODE_ALWAYS
	_kamera.fov = 52.0
	welt.add_child(_kamera)
	_stand = Vector3(8.5, welt.gelaende.hoehe_bei(8.5, 34.0) + 2.3, 34.0)
	_kamera.make_current()
	_kamera_setzen()
	_wurzel = Control.new()
	_wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wurzel.theme = Stil.thema()
	add_child(_wurzel)
	# Links wird das Bild dunkler, damit die Schrift ruhig steht
	var verlauf := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.07, 0.04, 0.02, 0.78))
	g.set_color(1, Color(0.07, 0.04, 0.02, 0.0))
	verlauf.gradient = g
	var schatten := TextureRect.new()
	schatten.texture = verlauf
	schatten.stretch_mode = TextureRect.STRETCH_SCALE
	schatten.anchor_bottom = 1.0
	schatten.anchor_right = 0.62
	schatten.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(schatten)
	_seite = Control.new()
	_seite.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wurzel.add_child(_seite)
	_blende = ColorRect.new()
	_blende.color = Color(0.05, 0.03, 0.01, 1.0)
	_blende.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(_blende)
	_tween().tween_property(_blende, "color:a", 0.0, 0.7)
	_haupt()


func _tween() -> Tween:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t


func _process(delta: float) -> void:
	_zeit += delta
	_kamera_setzen()


func _kamera_setzen() -> void:
	if not is_instance_valid(_kamera):
		return
	# langsames Treiben, als stünde jemand am Tor und schaut
	_kamera.global_position = _stand + Vector3(sin(_zeit * 0.06) * 1.8, sin(_zeit * 0.045) * 0.25, cos(_zeit * 0.05) * 0.8)
	_kamera.look_at(Vector3(-3.5 + sin(_zeit * 0.04) * 0.8, 5.0, -10.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _art != "haupt":
		get_viewport().set_input_as_handled()
		Game.einstellungen_speichern()
		_haupt()


func _leeren() -> void:
	for c in _seite.get_children():
		c.queue_free()


# =============================================================================
# Hauptmenü
# =============================================================================
func _haupt() -> void:
	_leeren()
	_art = "haupt"
	var logo := Logo.new()
	logo.position = Vector2(84, 70)
	_seite.add_child(logo)
	var liste := VBoxContainer.new()
	liste.position = Vector2(96, 372)
	liste.add_theme_constant_override("separation", 6)
	_seite.add_child(liste)
	var info := Game.slot_info(Game.slot)
	var erster: Stil.Eintrag
	if info.is_empty():
		erster = Stil.Eintrag.new("Spielen", "Glas %d · ein neuer Berg wartet" % Game.slot, 56)
	else:
		erster = Stil.Eintrag.new("Weiterspielen", "Glas %d · %s" % [Game.slot, _kurz(info)], 56)
	erster.gewaehlt.connect(_los)
	liste.add_child(erster)
	var glaeser := Stil.Eintrag.new("Gläser", "", 40)
	glaeser.gewaehlt.connect(_glaeser)
	liste.add_child(glaeser)
	var opt := Stil.Eintrag.new("Einstellungen", "", 40)
	opt.gewaehlt.connect(_einstellungen)
	liste.add_child(opt)
	var ende := Stil.Eintrag.new("Beenden", "", 40)
	ende.gewaehlt.connect(func():
		Game.einstellungen_speichern()
		get_tree().quit())
	liste.add_child(ende)
	erster.grab_focus.call_deferred()


static func _kurz(info: Dictionary) -> String:
	var minuten := int(float(info.spielzeit) / 60.0)
	var zeit := ("%d min" % minuten) if minuten < 60 else ("%d h %02d min" % [minuten / 60, minuten % 60])
	return "%s von 1.000.000 Nüssen abgetragen · %s" % [Data.zahl(float(info.genommen)), zeit]


# =============================================================================
# Gläser: drei Spielstände
# =============================================================================
func _glaeser() -> void:
	_leeren()
	_art = "glaeser"
	var kopf := Stil.titel("Gläser", 64)
	kopf.position = Vector2(96, 60)
	_seite.add_child(kopf)
	var unter := Stil.label("Jedes Glas ist ein eigener Spielstand. Je voller, desto mehr vom Berg ist abgetragen.", 26, Stil.LEISE)
	unter.add_theme_font_override("font", Stil.schrift_hand())
	unter.position = Vector2(100, 136)
	_seite.add_child(unter)
	var reihe := HBoxContainer.new()
	reihe.set_anchors_preset(Control.PRESET_CENTER)
	reihe.grow_horizontal = Control.GROW_DIRECTION_BOTH
	reihe.grow_vertical = Control.GROW_DIRECTION_BOTH
	reihe.offset_top = 30
	reihe.add_theme_constant_override("separation", 46)
	_seite.add_child(reihe)
	for n in range(1, Game.SLOTS + 1):
		reihe.add_child(_glas_karte(n))
	var zurueck := Stil.Eintrag.new("Zurück", "", 36)
	zurueck.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	zurueck.offset_left = 96
	zurueck.offset_top = -112
	zurueck.offset_bottom = -52
	zurueck.gewaehlt.connect(_haupt)
	_seite.add_child(zurueck)


func _glas_karte(n: int) -> Control:
	var info := Game.slot_info(n)
	var blatt := Stil.Blatt.new()
	blatt.liniert = false
	blatt.klebestreifen = true
	blatt.innen = 22
	blatt.custom_minimum_size = Vector2(330, 0)
	blatt.rotation_degrees = [-1.4, 0.7, -0.6][(n - 1) % 3]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	blatt.add_child(v)
	var bild := Glas.new()
	bild.fuellung = 0.0 if info.is_empty() else clampf(float(info.genommen) / 1000000.0, 0.0, 1.0)
	bild.leer = info.is_empty()
	bild.nummer = n
	v.add_child(bild)
	if info.is_empty():
		v.add_child(Stil.hand("noch leer", 30, Stil.TINTE_LEISE))
		v.add_child(Stil.hand("Ein neuer Berg: eine Million Nüsse.", 23))
	else:
		v.add_child(Stil.hand("%s Nüsse abgetragen" % Data.zahl(float(info.genommen)), 30, Stil.TINTE))
		var minuten := int(float(info.spielzeit) / 60.0)
		var zeit := ("%d min" % minuten) if minuten < 60 else ("%d h %02d" % [minuten / 60, minuten % 60])
		v.add_child(Stil.hand("%s Münzen · Ära %d · %s" % [Data.zahl(float(info.muenzen)), int(info.aera), zeit], 23))
	if n == Game.slot:
		v.add_child(Stil.hand("steht gerade offen auf dem Tisch", 22, Stil.ROTSTIFT))
	else:
		v.add_child(Stil.hand(" ", 22))
	var knoepfe := HBoxContainer.new()
	knoepfe.add_theme_constant_override("separation", 8)
	v.add_child(knoepfe)
	var spielen := Stil.knopf("Neu anfangen" if info.is_empty() else "Aufschrauben", func(): _glas_waehlen(n), 20)
	spielen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	knoepfe.add_child(spielen)
	if not info.is_empty():
		var weg := Stil.knopf("Wegschütten", Callable(), 16)
		weg.pressed.connect(func():
			if weg.has_meta("sicher"):
				_blende_dann(func():
					if n == Game.slot:
						Game.slot_loeschen(n)
					else:
						_loeschen(n))
			else:
				weg.set_meta("sicher", true)
				weg.text = "Wirklich? Nochmal")
		knoepfe.add_child(weg)
	return blatt


func _loeschen(n: int) -> void:
	Game.slot_loeschen(n)
	_blende.color.a = 0.0
	_glaeser()


func _glas_waehlen(n: int) -> void:
	if n == Game.slot:
		_los()
	else:
		_blende_dann(func(): Game.slot_wechseln(n), "Glas %d wird aufgeschraubt …" % n)


## Blendet ab, zeigt auf Wunsch einen Satz und führt dann aus (Welt neu laden dauert einen Moment).
func _blende_dann(tun: Callable, text := "") -> void:
	_blende.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := _tween()
	t.tween_property(_blende, "color:a", 1.0, 0.25)
	t.tween_callback(func():
		if text != "":
			var l := Stil.label(text, 40, Stil.TEXT)
			l.add_theme_font_override("font", Stil.schrift_hand())
			l.set_anchors_preset(Control.PRESET_CENTER)
			l.grow_horizontal = Control.GROW_DIRECTION_BOTH
			_wurzel.add_child(l))
	t.tween_interval(0.08)
	t.tween_callback(tun)


# =============================================================================
# Einstellungen
# =============================================================================
func _einstellungen() -> void:
	_leeren()
	_art = "einstellungen"
	var halter := Control.new()
	halter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_seite.add_child(halter)
	Optionen.baue(halter, _haupt)


# =============================================================================
# Ins Spiel
# =============================================================================
func _los() -> void:
	if _art == "los":
		return
	_art = "los"
	_blende.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := _tween()
	t.tween_property(_blende, "color:a", 1.0, 0.25)
	t.tween_callback(func():
		_seite.visible = false
		for c in _wurzel.get_children():
			if c != _blende:
				c.visible = false
		welt.spieler.kamera.make_current()
		_kamera.queue_free()
		welt.hud.visible = true
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		welt.spieler.gesperrt = false)
	t.tween_property(_blende, "color:a", 0.0, 0.45)
	t.tween_callback(func():
		if Game.erster_start:
			welt._menue(welt.menues.zeige_intro)
		queue_free())


# =============================================================================
# Zeichnungen
# =============================================================================
## Der Schriftzug: schräg, dick, mit Rotstift unterstrichen.
class Logo extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(720, 280)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := Stil.schrift_titel()
		draw_set_transform(Vector2(6, 26), -0.055)
		var p := Vector2(0, 132)
		draw_string_outline(f, p + Vector2(0, 9), "Deez Nuts!", HORIZONTAL_ALIGNMENT_LEFT, -1, 138, 34, Color(0.07, 0.04, 0.02, 0.55))
		draw_string_outline(f, p, "Deez Nuts!", HORIZONTAL_ALIGNMENT_LEFT, -1, 138, 26, Color(0.16, 0.09, 0.04))
		draw_string(f, p, "Deez Nuts!", HORIZONTAL_ALIGNMENT_LEFT, -1, 138, Color(1.0, 0.95, 0.82))
		# das Ausrufezeichen und der Strich in Rotstift
		var breit := f.get_string_size("Deez Nuts", HORIZONTAL_ALIGNMENT_LEFT, -1, 138).x
		draw_string(f, p + Vector2(breit, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 138, Color(0.93, 0.36, 0.24))
		var strich := PackedVector2Array()
		for i in 40:
			strich.append(Vector2(8.0 + i * 15.0, 162.0 + sin(i * 0.9) * 3.2 - i * 0.12))
		draw_polyline(strich, Color(0.16, 0.09, 0.04), 11.0, true)
		draw_polyline(strich, Color(0.93, 0.36, 0.24), 6.0, true)
		var h := Stil.schrift_hand()
		draw_string_outline(h, Vector2(14, 214), "Opa Walters Nussberg im Haselgrund", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, 8, Color(0.1, 0.06, 0.03, 0.9))
		draw_string(h, Vector2(14, 214), "Opa Walters Nussberg im Haselgrund", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Stil.LEISE)
		draw_set_transform(Vector2.ZERO, 0.0)


## Ein Einmachglas, das sich mit dem Fortschritt füllt.
class Glas extends Control:
	var fuellung := 0.0
	var leer := true
	var nummer := 1

	func _init() -> void:
		custom_minimum_size = Vector2(286, 230)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var m := size.x * 0.5
		var oben := 46.0
		var unten := 218.0
		var halb := 74.0
		# Nüsse im Glas: mindestens eine Handbreit, sobald gespielt wurde
		if not leer:
			var hoehe: float = lerpf(18.0, unten - oben - 22.0, sqrt(fuellung))
			var y0 := unten - 6.0 - hoehe
			draw_rect(Rect2(m - halb + 6.0, y0, halb * 2.0 - 12.0, hoehe), Color(0.62, 0.4, 0.18))
			var rng := RandomNumberGenerator.new()
			rng.seed = nummer * 977
			var reihen := int(hoehe / 13.0) + 1
			for r in reihen:
				for i in 9:
					var p := Vector2(m - halb + 14.0 + i * 15.0 + rng.randf_range(-4, 4) + (7.0 if r % 2 == 1 else 0.0), unten - 13.0 - r * 13.0 + rng.randf_range(-2, 2))
					if p.y < y0 - 4.0 or p.x > m + halb - 12.0:
						continue
					draw_circle(p, 8.0, Color(0.5, 0.31, 0.13))
					draw_circle(p + Vector2(-1.5, -1.5), 6.0, Color(0.74, 0.5, 0.24).lerp(Color(0.66, 0.42, 0.2), rng.randf()))
		# Glas: Körper, Schulter, Deckel
		var glas := Color(0.2, 0.3, 0.32, 0.9)
		var koerper := PackedVector2Array([Vector2(m - halb + 14, oben), Vector2(m - halb, oben + 22), Vector2(m - halb, unten - 8),
			Vector2(m - halb + 8, unten), Vector2(m + halb - 8, unten), Vector2(m + halb, unten - 8), Vector2(m + halb, oben + 22), Vector2(m + halb - 14, oben)])
		draw_colored_polygon(koerper, Color(0.78, 0.9, 0.9, 0.16))
		koerper.append(koerper[0])
		draw_polyline(koerper, glas, 3.5, true)
		draw_line(Vector2(m - halb + 14, oben + 30), Vector2(m - halb + 14, unten - 40), Color(1, 1, 1, 0.45), 5.0, true)
		draw_rect(Rect2(m - halb + 8, oben - 22, halb * 2.0 - 16, 22), Color(0.72, 0.2, 0.15))
		draw_rect(Rect2(m - halb + 8, oben - 22, halb * 2.0 - 16, 6), Color(0.86, 0.32, 0.24))
		draw_rect(Rect2(m - halb + 8, oben - 22, halb * 2.0 - 16, 22), Color(0.3, 0.08, 0.05), false, 2.5)
		# Etikett
		draw_set_transform(Vector2(m, oben + 78), 0.03)
		draw_rect(Rect2(-52, -24, 104, 48), Stil.PAPIER)
		draw_rect(Rect2(-52, -24, 104, 48), Color(Stil.TINTE, 0.5), false, 1.5)
		draw_string(Stil.schrift_hand(), Vector2(-52, 12), "Glas %d" % nummer, HORIZONTAL_ALIGNMENT_CENTER, 104, 34, Stil.TINTE)
		draw_set_transform(Vector2.ZERO, 0.0)
