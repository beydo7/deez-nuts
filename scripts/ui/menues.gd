class_name Menues
extends CanvasLayer
## Bestellkatalog (Laden), Talentbaum, Pausemenü, Intro und Abspann.

signal geschlossen

var offen := ""            # "" | laden | talente | pause | intro | ende
var _wurzel: Control
var _inhalt: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wurzel = Control.new()
	_wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wurzel.theme = Stil.thema()
	_wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wurzel)
	Game.stand_geaendert.connect(_neu_zeichnen)
	Game.geld_geaendert.connect(_neu_zeichnen)


func _unhandled_input(event: InputEvent) -> void:
	if offen == "":
		return
	if event.is_action_pressed("pause") or (event.is_action_pressed("talente") and offen == "talente") or (event.is_action_pressed("benutzen") and offen == "laden"):
		if offen == "ende":
			return
		schliessen()
		get_viewport().set_input_as_handled()


func ist_offen() -> bool:
	return offen != ""


func _leeren() -> void:
	for c in _wurzel.get_children():
		c.queue_free()
	_inhalt = null


func schliessen() -> void:
	_leeren()
	offen = ""
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	geschlossen.emit()


func _oeffnen(art: String, pausieren := false) -> void:
	_leeren()
	offen = art
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = pausieren


func _neu_zeichnen() -> void:
	match offen:
		"laden":
			call_deferred("zeige_laden", _aktueller_reiter())
		"talente":
			call_deferred("zeige_talente")


var _reiter := 0


func _aktueller_reiter() -> int:
	return _reiter


# --- Laden ---------------------------------------------------------------------
func zeige_laden(reiter := 0) -> void:
	_oeffnen("laden")
	_reiter = reiter
	var v := Stil.fenster(_wurzel, "Bestellkatalog  ·  %s Münzen" % Data.zahl(Game.muenzen), 900, 660, schliessen)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_reiter_werkzeuge())
	tabs.add_child(_reiter_maschinen())
	tabs.add_child(_reiter_extras())
	tabs.current_tab = reiter
	tabs.tab_changed.connect(func(i): _reiter = i)


func _zeile(titel: String, text: String, knoepfe: Array) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Stil.box(Color(0.24, 0.15, 0.08, 0.9), Color(0.45, 0.32, 0.18), 8, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Stil.label(titel, 21, Stil.GOLD))
	v.add_child(Stil.label(text, 16, Stil.TEXT, true))
	for k in knoepfe:
		k.custom_minimum_size = Vector2(180, 0)
		h.add_child(k)
	return p


func _scrollbar(name: String) -> Array:
	var sc := ScrollContainer.new()
	sc.name = name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return [sc, v]


func _reiter_werkzeuge() -> Control:
	var paar := _scrollbar("Werkzeuge")
	var v: VBoxContainer = paar[1]
	for w in Data.WERKZEUGE:
		var id: String = w.id
		var knoepfe: Array = []
		var text: String = w.text + "\nKraft %d · Zudrücken %.2f s" % [int(w.kraft), w.zeit]
		if w.aera > Game.aera:
			text += "\nGibt es ab Ära %d" % w.aera
			var gesperrt := Stil.knopf("Gesperrt", func(): pass)
			gesperrt.disabled = true
			knoepfe.append(gesperrt)
		elif not Game.werkzeuge.has(id):
			var k := Stil.knopf("Kaufen: %s" % Data.zahl(w.preis), func(): Game.kaufe_werkzeug(id))
			k.disabled = Game.muenzen < w.preis
			knoepfe.append(k)
		else:
			var werte := Game.werkzeug_werte(id)
			text = w.text + "\nStufe %d/%d · Kraft %.1f · Zudrücken %.2f s · Sweet Spot %+d %%" % [werte.stufe, Data.WERKZEUG_MAX_STUFE, werte.kraft, werte.zeit, int(round(werte.sweet * 100))]
			if Game.werkzeug_aktiv == id:
				var aktiv := Stil.knopf("In Benutzung", func(): pass)
				aktiv.disabled = true
				knoepfe.append(aktiv)
			else:
				knoepfe.append(Stil.knopf("Benutzen", func(): Game.waehle_werkzeug(id)))
			if int(werte.stufe) < Data.WERKZEUG_MAX_STUFE:
				var preis := Game.werkzeug_upgrade_preis(id)
				var up := Stil.knopf("Verbessern: %s" % Data.zahl(preis), func(): Game.werte_werkzeug_auf(id))
				up.disabled = Game.muenzen < preis
				knoepfe.append(up)
		v.add_child(_zeile(w.name, text, knoepfe))
	return paar[0]


func _reiter_maschinen() -> Control:
	var paar := _scrollbar("Maschinen")
	var v: VBoxContainer = paar[1]
	for id in Data.MASCHINEN:
		var m: Dictionary = Data.MASCHINEN[id]
		if id == "laufrad" and not Game.hat_talent("laufrad"):
			continue
		var knoepfe: Array = []
		var text: String = m.text
		if m.aera > Game.aera:
			text += "\nGibt es ab Ära %d (Schicht „Hang“, 1.000 Nüsse)" % m.aera
			var g := Stil.knopf("Gesperrt", func(): pass)
			g.disabled = true
			knoepfe.append(g)
		elif not Game.hat_maschine(id):
			var preis := Game.maschinen_preis(id)
			var k := Stil.knopf("Kaufen: %s" % ("gratis" if preis == 0 else Data.zahl(preis)), func(): Game.kaufe_maschine(id))
			k.disabled = Game.muenzen < preis
			knoepfe.append(k)
		else:
			var stufe := Game.maschinen_stufe(id)
			if int(m.stufen) > 0:
				text += "\nStufe %d/%d" % [stufe, m.stufen]
				if id == "walze":
					text += " · Präzision %d %%" % int(Game.walzen_praezision() * 100)
				if stufe < int(m.stufen):
					var preis2 := Game.maschinen_upgrade_preis(id)
					var up := Stil.knopf("Verbessern: %s" % Data.zahl(preis2), func(): Game.werte_maschine_auf(id))
					up.disabled = Game.muenzen < preis2
					knoepfe.append(up)
			var da := Stil.knopf("Vorhanden", func(): pass)
			da.disabled = true
			knoepfe.append(da)
		v.add_child(_zeile(m.name, text, knoepfe))
	return paar[0]


func _reiter_extras() -> Control:
	var paar := _scrollbar("Extras")
	var v: VBoxContainer = paar[1]
	var ruhe := Stil.knopf("1 Goldene Nuss", func():
		if Game.gold > 0:
			Game.gold -= 1
			get_tree().current_scene.ruhe_vor_eichhoernchen(600.0)
			Game.stand_geaendert.emit())
	ruhe.disabled = Game.gold <= 0
	v.add_child(_zeile("Bestechung", "Eine Goldene Nuss für den Eichhörnchen-König: 10 Minuten keine Diebe.\nDu hast %d Goldene Nüsse." % Game.gold, [ruhe]))
	var st := Game.statistik
	var text := "Perfekt: %s · Bruch: %s · Matsch: %s\nVerdient: %s Münzen · Geklaut: %s · Verscheucht: %s\nSpielzeit: %d min" % [
		Data.zahl(st.perfekt), Data.zahl(st.bruch), Data.zahl(st.matsch), Data.zahl(st.verkauft), Data.zahl(st.gestohlen), Data.zahl(st.verscheucht), int(Game.spielzeit / 60.0)]
	v.add_child(_zeile("Statistik", text, []))
	return paar[0]


# --- Talentbaum ----------------------------------------------------------------
func zeige_talente() -> void:
	_oeffnen("talente")
	var v := Stil.fenster(_wurzel, "Opas Talentbaum  ·  %d Meisterpunkte" % Game.mp, 1240, 720, schliessen)
	v.add_child(Stil.label("Meisterpunkte gibt es für Meilensteine am Berg und für erfüllte Bestellungen. Im Wald entscheidest du dich: Abwehr oder Zähmen.", 16, Stil.LEISE, true))
	var spalten := HBoxContainer.new()
	spalten.add_theme_constant_override("separation", 10)
	spalten.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spalten)
	for zweig in ["handwerk", "maschinen", "handel"]:
		var sp := VBoxContainer.new()
		sp.custom_minimum_size = Vector2(225, 0)
		sp.add_theme_constant_override("separation", 8)
		spalten.add_child(sp)
		sp.add_child(_zweig_kopf(Data.ZWEIG_NAMEN[zweig]))
		for id in _talente_im_zweig(zweig):
			sp.add_child(_talent_karte(id))
	var wald := VBoxContainer.new()
	wald.custom_minimum_size = Vector2(470, 0)
	wald.add_theme_constant_override("separation", 8)
	spalten.add_child(wald)
	wald.add_child(_zweig_kopf("Wald: abwehren oder zähmen"))
	wald.add_child(_talent_karte("waldkenner"))
	var zwei := HBoxContainer.new()
	zwei.add_theme_constant_override("separation", 10)
	wald.add_child(zwei)
	for zweig in ["abwehr", "zaehmen"]:
		var sp2 := VBoxContainer.new()
		sp2.custom_minimum_size = Vector2(230, 0)
		sp2.add_theme_constant_override("separation", 8)
		zwei.add_child(sp2)
		for id in _talente_im_zweig(zweig):
			sp2.add_child(_talent_karte(id))


func _zweig_kopf(text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Stil.box(Color(0.35, 0.3, 0.25, 0.9), Color(0.6, 0.55, 0.45), 8, 8))
	var l := Stil.label(text, 20, Stil.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _talente_im_zweig(zweig: String) -> Array:
	var aus: Array = []
	for id in Data.TALENTE:
		if Data.TALENTE[id].zweig == zweig:
			aus.append(id)
	aus.sort_custom(func(a, b): return Data.TALENTE[a].reihe < Data.TALENTE[b].reihe)
	return aus


func _talent_karte(id: String) -> Control:
	var t: Dictionary = Data.TALENTE[id]
	var status := Game.talent_status(id)
	var stufe := Game.talent(id)
	var schluss := int(t.reihe) == 4
	var rand := Stil.GOLD if schluss else Color(0.6, 0.45, 0.28)
	var grund := Color(0.3, 0.2, 0.1, 0.95)
	if stufe > 0:
		grund = Color(0.22, 0.38, 0.18, 0.95)
	if status == "gesperrt" or status == "ausgeschlossen":
		grund = Color(0.18, 0.15, 0.13, 0.95)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Stil.box(grund, rand, 8, 10))
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(Stil.label(t.name, 19, Stil.GOLD if schluss else Stil.TEXT))
	v.add_child(Stil.label(t.text, 15, Stil.TEXT, true))
	var info := "Stufe %d/%d · %d MP" % [stufe, t.max, t.kosten]
	match status:
		"gesperrt":
			info += " · braucht %s" % Data.TALENTE[t.braucht].name
		"ausgeschlossen":
			info = "Anderer Weg gewählt"
		"max":
			info = "Gelernt" if int(t.max) == 1 else "Stufe %d/%d · voll" % [stufe, t.max]
	v.add_child(Stil.label(info, 14, Stil.LEISE, true))
	if status == "frei" or status == "zu_teuer":
		var k := Stil.knopf("Lernen", func(): Game.lerne_talent(id), 16)
		k.disabled = status != "frei"
		v.add_child(k)
	return p


# --- Pause -----------------------------------------------------------------------
func zeige_pause() -> void:
	_oeffnen("pause", true)
	var v := Stil.fenster(_wurzel, "Pause", 620, 640, schliessen)
	v.add_child(Stil.knopf("Weiterspielen", schliessen, 22))
	v.add_child(Stil.label("Einstellungen", 22, Stil.GOLD))
	v.add_child(_regler("Maus-Empfindlichkeit", 0.05, 0.8, float(Game.einstellungen.empfindlichkeit), func(x): Game.einstellungen.empfindlichkeit = x))
	v.add_child(_regler("Lautstärke", 0.0, 1.0, float(Game.einstellungen.lautstaerke), func(x):
		Game.einstellungen.lautstaerke = x
		AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001, x)))))
	v.add_child(_schalter("Hilfsring am Fadenkreuz zeigen  [H]", "hilfsring"))
	v.add_child(_schalter("Tippen statt Halten (Klick = zudrücken, Klick = loslassen)", "tippen"))
	v.add_child(Stil.knopf("Steuerung anzeigen", zeige_intro, 20))
	v.add_child(Stil.knopf("Speichern", func():
		Game.speichern()
		Game.toast.emit("Gespeichert", Game.FARBE_GUT), 20))
	var neu := Stil.knopf("Neues Spiel (Spielstand löschen)", func(): _bestaetigen_neu(), 20)
	v.add_child(neu)
	v.add_child(Stil.knopf("Speichern und beenden", func():
		Game.speichern()
		get_tree().quit(), 20))


func _bestaetigen_neu() -> void:
	_oeffnen("pause", true)
	var v := Stil.fenster(_wurzel, "Wirklich neu anfangen?", 560, 220, zeige_pause)
	v.add_child(Stil.label("Der ganze Spielstand wird gelöscht.", 20, Stil.TEXT, true))
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(Stil.knopf("Ja, löschen", func():
		get_tree().paused = false
		Game.zuruecksetzen(), 20))
	h.add_child(Stil.knopf("Abbrechen", zeige_pause, 20))


func _regler(titel: String, von: float, bis: float, wert: float, setzen: Callable) -> Control:
	var h := HBoxContainer.new()
	var l := Stil.label(titel, 18)
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = von
	s.max_value = bis
	s.step = 0.01
	s.value = wert
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(setzen)
	h.add_child(s)
	return h


func _schalter(titel: String, schluessel: String) -> Control:
	var c := CheckBox.new()
	c.text = titel
	c.button_pressed = bool(Game.einstellungen[schluessel])
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(func(an): Game.einstellungen[schluessel] = an)
	c.focus_mode = Control.FOCUS_NONE
	return c


# --- Intro und Steuerung ------------------------------------------------------------
func zeige_intro() -> void:
	_oeffnen("intro", true)
	var v := Stil.fenster(_wurzel, "Deez Nuts!", 860, 700, Callable())
	v.add_child(Stil.label("Opa Walter hat dir seine alte Nussknackerei vererbt – und kurz vor seinem Tod einen Vertrag mit der Lebkuchenfabrik unterschrieben. Heute früh hat ein Laster eine Million Nüsse in den Hof gekippt. Trag den Berg ab, Nuss für Nuss. Die Eichhörnchen aus dem Wald haben ihn auch schon entdeckt …", 19, Stil.TEXT, true))
	v.add_child(Stil.label("So geht's", 24, Stil.GOLD))
	var steuerung := """[WASD] laufen · [Shift] rennen · [Leertaste] springen · Maus schauen
[E] greifen, ablegen, einlegen, benutzen · [Q] fallen lassen
[Linksklick halten] Nussknacker zudrücken – loslassen zum Knacken
[Linksklick] mit etwas in der Hand: werfen
[F] Schalen vom Tisch in den Eimer wischen · [Tab] Talentbaum · [Esc] Menü

1. Am Hebel links neben dem Fenster Nüsse aus dem Berg holen.
2. Nuss greifen und mit [E] in den Knacker legen.
3. Zudrücken und im richtigen Moment loslassen: Hör aufs Knarzen, achte auf die Risse.
   Erster Riss = noch zu früh. Zweiter Riss und Zittern = jetzt loslassen!
4. Ganze Kernhälften ins Glas, Schalen in den Eimer, Bruch in die Bruchschale.
5. Volles Glas zur Verkaufsklappe an der linken Wand tragen und hineinwerfen.
6. Am Telefon Werkzeuge und Maschinen bestellen."""
	v.add_child(Stil.label(steuerung, 17, Stil.TEXT, true))
	v.add_child(Stil.label("Testhilfen: [F9] +5.000 Münzen · [F10] +1.000 Nüsse geknackt · [F11] +5 Meisterpunkte", 15, Stil.LEISE, true))
	v.add_child(Stil.knopf("Los geht's!", func():
		Game.erster_start = false
		schliessen(), 24))


func zeige_ende() -> void:
	_oeffnen("ende", true)
	var v := Stil.fenster(_wurzel, "Der Berg ist leer!", 760, 460, Callable())
	v.add_child(Stil.label("Ganz unten lag Opas goldene Nuss. Darin steckte ein kleiner Zettel:", 20, Stil.TEXT, true))
	v.add_child(Stil.label("„Deez Nuts!“", 48, Stil.GOLD))
	var st := Game.statistik
	v.add_child(Stil.label("Eine Million Nüsse in %d Minuten. Perfekte Knacke: %s. Geklaut: %s." % [int(Game.spielzeit / 60.0), Data.zahl(st.perfekt), Data.zahl(st.gestohlen)], 18, Stil.LEISE, true))
	v.add_child(Stil.knopf("Weiterknacken", func():
		offen = ""
		schliessen(), 22))
