class_name Optionen
extends RefCounted
## Das Einstellungsblatt. Wird vom Titelbild und vom Pausenmenü benutzt.
## Jede Änderung gilt sofort (man sieht und hört sie hinter dem Blatt) und wird beim Schließen gesichert.

const REITER := ["Bild", "Ton", "Steuerung", "Spiel"]
const BILDRATEN := [0, 30, 60, 120, 144, 240]
## Welche Einstellungen "Standard wiederherstellen" je Reiter zurücksetzt.
const SCHLUESSEL := [
	["anzeige", "vsync", "bildrate", "qualitaet", "renderskala", "helligkeit", "sichtfeld", "ui_groesse"],
	["lautstaerke", "musik", "stumm_ohne_fokus"],
	["empfindlichkeit", "y_umkehren", "tasten"],
	["wackeln", "tastenhilfe", "zeiger_gemuetlich", "zeit_fest"]]


static func baue(eltern: Control, zurueck: Callable, reiter := 0) -> void:
	for c in eltern.get_children():
		c.queue_free()
	eltern.process_mode = Node.PROCESS_MODE_ALWAYS
	var fertig := func():
		Game.einstellungen_speichern()
		zurueck.call()
	var v := Stil.fenster(eltern, "Einstellungen", 900, 740, Callable())
	var e := Game.einstellungen
	var neu := func(r: int): baue(eltern, zurueck, r)
	# Reiter
	var kopf := HBoxContainer.new()
	kopf.add_theme_constant_override("separation", 26)
	v.add_child(kopf)
	for i in REITER.size():
		var r := ReiterKnopf.new(REITER[i], i == reiter)
		r.pressed.connect(neu.bind(i))
		kopf.add_child(r)
	# Zeilen
	var rollen := ScrollContainer.new()
	rollen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rollen.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rollen)
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", 9)
	rollen.add_child(liste)
	var setze := func(wert, schluessel: String):
		e[schluessel] = wert
		Game.einstellungen_anwenden()
	var prozent := func(w: float) -> String: return "%d %%" % int(round(w * 100.0))
	match reiter:
		0:
			liste.add_child(Stil.zeile("Anzeige", _wahl(["Fenster", "Vollbild ohne Rand", "Vollbild"], int(e.anzeige), setze.bind("anzeige"))))
			liste.add_child(Stil.zeile("Qualität", _wahl(["Niedrig", "Mittel", "Hoch"], int(e.qualitaet), setze.bind("qualitaet")),
				"Schatten, Kantenglättung und weiches Licht. Niedrig bringt am meisten Tempo."))
			liste.add_child(Stil.zeile("Renderauflösung", _regler(0.5, 1.0, 0.05, float(e.renderskala), prozent, setze.bind("renderskala")),
				"Unter 100 % wird die Welt kleiner gerechnet und hochgezogen. Schrift bleibt scharf."))
			liste.add_child(Stil.zeile("Bildabgleich (VSync)", _haken(bool(e.vsync), setze.bind("vsync")), "Verhindert zerrissene Bilder."))
			var raten: Array = []
			for b in BILDRATEN:
				raten.append("Unbegrenzt" if b == 0 else "%d Bilder/s" % b)
			liste.add_child(Stil.zeile("Bildrate begrenzen", _wahl(raten, max(0, BILDRATEN.find(int(e.bildrate))), func(i: int): setze.call(BILDRATEN[i], "bildrate"))))
			liste.add_child(Stil.zeile("Sichtfeld", _regler(60.0, 100.0, 1.0, float(e.sichtfeld), func(w: float) -> String: return "%d°" % int(w), setze.bind("sichtfeld"))))
			liste.add_child(Stil.zeile("Helligkeit", _regler(0.7, 1.3, 0.05, float(e.helligkeit), prozent, setze.bind("helligkeit"))))
			liste.add_child(Stil.zeile("Größe von Schrift und Anzeigen", _regler(0.8, 1.3, 0.05, float(e.ui_groesse), prozent, setze.bind("ui_groesse"))))
		1:
			liste.add_child(Stil.zeile("Gesamtlautstärke", _regler(0.0, 1.0, 0.05, float(e.lautstaerke), prozent, setze.bind("lautstaerke"))))
			liste.add_child(Stil.zeile("Musik", _regler(0.0, 1.0, 0.05, float(e.musik), prozent, setze.bind("musik"))))
			liste.add_child(Stil.zeile("Still, wenn das Fenster nicht vorn ist", _haken(bool(e.stumm_ohne_fokus), setze.bind("stumm_ohne_fokus"))))
		2:
			liste.add_child(Stil.zeile("Mausempfindlichkeit", _regler(0.05, 0.8, 0.01, float(e.empfindlichkeit), func(w: float) -> String: return "%d" % int(round(w * 100.0)), setze.bind("empfindlichkeit"))))
			liste.add_child(Stil.zeile("Maus hoch/runter umkehren", _haken(bool(e.y_umkehren), setze.bind("y_umkehren"))))
			liste.add_child(Stil.hand("Tasten: anklicken, dann die neue Taste drücken. War sie schon vergeben, tauschen die beiden.", 22))
			var gitter := GridContainer.new()
			gitter.columns = 2
			gitter.add_theme_constant_override("h_separation", 44)
			gitter.add_theme_constant_override("v_separation", 7)
			liste.add_child(gitter)
			for paar in Game.TASTEN_AKTIONEN:
				var z := HBoxContainer.new()
				z.custom_minimum_size = Vector2(365, 0)
				var l := Stil.tinte(paar[1], 18)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				z.add_child(l)
				z.add_child(Tastenfang.new(paar[0], neu.bind(reiter)))
				gitter.add_child(z)
			liste.add_child(Stil.hand("Maus: Linksklick sammelt und legt nach, Rechtsklick wischt und wirft.", 22))
		3:
			liste.add_child(Stil.zeile("Gemütlicher Zeiger", _haken(bool(e.zeiger_gemuetlich), setze.bind("zeiger_gemuetlich")),
				"Der Zeiger der Trefferprobe läuft ein gutes Stück langsamer. Kostet nichts."))
			liste.add_child(Stil.zeile("Bildwackeln", _regler(0.0, 1.0, 0.1, float(e.wackeln), prozent, setze.bind("wackeln")),
				"Wie stark das Bild beim Knacken und bei Treffern ruckt. 0 % schaltet es ab."))
			liste.add_child(Stil.zeile("Tastenhilfe am unteren Rand", _haken(bool(e.tastenhilfe), setze.bind("tastenhilfe"))))
			liste.add_child(Stil.zeile("Zeit anhalten", _haken(bool(e.zeit_fest), setze.bind("zeit_fest")), "Es bleibt immer dieselbe Tageszeit."))
	# Fuß
	var fuss := HBoxContainer.new()
	v.add_child(fuss)
	fuss.add_child(Stil.knopf("%s auf Standard" % REITER[reiter], func():
		Game.einstellungen_standard(SCHLUESSEL[reiter])
		neu.call(reiter), 17))
	var luft := Control.new()
	luft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fuss.add_child(luft)
	fuss.add_child(Stil.knopf("Fertig", fertig, 22))


static func _regler(von: float, bis: float, schritt: float, wert: float, text: Callable, setzen: Callable) -> Control:
	var r := Stil.Regler.new(von, bis, schritt, wert, text)
	r.geaendert.connect(setzen)
	return r


static func _haken(an: bool, setzen: Callable) -> Control:
	var h := Stil.Haken.new(an)
	h.geaendert.connect(setzen)
	return h


static func _wahl(werte: Array, index: int, setzen: Callable) -> Control:
	var w := Stil.Wahl.new(werte, index)
	w.geaendert.connect(setzen)
	return w


## Reiter oben im Blatt: Schrift, der gewählte ist rot unterstrichen.
class ReiterKnopf extends Button:
	var gewaehlt := false

	func _init(t := "", an := false) -> void:
		text = t
		gewaehlt = an
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_font_override("font", Stil.schrift_titel())
		add_theme_font_size_override("font_size", 27)
		for art in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(art, Stil.leer(4))
		add_theme_color_override("font_color", Stil.TINTE if an else Stil.TINTE_LEISE)
		add_theme_color_override("font_hover_color", Stil.ROTSTIFT)
		add_theme_color_override("font_pressed_color", Stil.ROTSTIFT)

	func _draw() -> void:
		if gewaehlt:
			var p := PackedVector2Array()
			for i in int(size.x / 8.0) + 1:
				p.append(Vector2(2.0 + i * 8.0, size.y - 3.0 + sin(i * 1.3) * 1.6))
			if p.size() >= 2:
				draw_polyline(p, Stil.ROTSTIFT, 3.5, true)


## Knopf, der auf die nächste Taste wartet und sie der Aktion gibt.
class Tastenfang extends Button:
	var aktion := ""
	var danach := Callable()
	var wartet := false

	func _init(a := "", d := Callable()) -> void:
		aktion = a
		danach = d
		custom_minimum_size = Vector2(150, 0)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_font_size_override("font_size", 17)
		text = Game.tastentext(Game.taste_von(a))
		pressed.connect(func():
			wartet = true
			text = "Taste drücken …")

	func _input(event: InputEvent) -> void:
		if not wartet or not (event is InputEventKey) or not event.pressed:
			return
		get_viewport().set_input_as_handled()
		wartet = false
		var code: int = event.physical_keycode
		if code == KEY_ESCAPE:
			text = Game.tastentext(Game.taste_von(aktion))
			return
		Game.taste_belegen(aktion, code)
		if danach.is_valid():
			danach.call_deferred()
