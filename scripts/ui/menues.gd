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
func zeige_laden(reiter := -1) -> void:
	_oeffnen("laden")
	if reiter >= 0:
		_reiter = reiter
	var v := Stil.fenster(_wurzel, "Bestellbrett  ·  %s Münzen" % Data.zahl(Game.muenzen), 980, 700, schliessen)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_reiter_sammeln())
	tabs.add_child(_reiter_tragen())
	tabs.add_child(_reiter_helfer())
	tabs.add_child(_reiter_werkzeuge())
	tabs.add_child(_reiter_maschinen())
	tabs.add_child(_reiter_extras())
	tabs.current_tab = clampi(_reiter, 0, tabs.get_tab_count() - 1)
	tabs.tab_changed.connect(func(i): _reiter = i)


func _gesperrt_knopf(aera: int) -> Button:
	var g := Stil.knopf("Ab Ära %d" % aera, func(): pass)
	g.disabled = true
	return g


func _reiter_sammeln() -> Control:
	var paar := _scrollbar("Sammeln")
	var v: VBoxContainer = paar[1]
	v.add_child(Stil.label("Womit du am Berg sammelst. [X] wechselt zwischen deinen Werkzeugen.", 16, Stil.LEISE, true))
	for w in Data.SAMMLER:
		var id: String = w.id
		if w.get("geheim", false) and not Game.sammler.has(id):
			continue
		var knoepfe: Array = []
		var text: String = w.text + "\n%s Nüsse/s · Reichweite %.1f m" % [str(w.rate).replace(".", ","), w.reichweite]
		if int(w.aera) > Game.aera:
			knoepfe.append(_gesperrt_knopf(w.aera))
		elif not Game.sammler.has(id):
			var k := Stil.knopf("Kaufen: %s" % Data.zahl(w.preis), func(): Game.kaufe_sammler(id))
			k.disabled = Game.muenzen < float(w.preis)
			knoepfe.append(k)
		elif Game.sammler_aktiv == id:
			var a := Stil.knopf("In der Hand", func(): pass)
			a.disabled = true
			knoepfe.append(a)
		else:
			knoepfe.append(Stil.knopf("Nehmen", func(): Game.waehle_sammler(id)))
		v.add_child(_zeile(w.name, text, knoepfe))
	return paar[0]


func _reiter_tragen() -> Control:
	var paar := _scrollbar("Tragen")
	var v: VBoxContainer = paar[1]
	v.add_child(Stil.label("Mehr tragen heißt seltener laufen. Du trägst gerade %d Nüsse." % Game.kapazitaet(), 16, Stil.LEISE, true))
	var jetzt := Data.BEUTEL.find(Data.beutel(Game.beutel_id))
	for i in Data.BEUTEL.size():
		var b: Dictionary = Data.BEUTEL[i]
		var id: String = b.id
		var knoepfe: Array = []
		var text: String = b.text + "\nFasst %s Nüsse%s" % [Data.zahl(b.kap), "" if float(b.tempo) >= 1.0 else " · %d %% langsamer" % int(round((1.0 - float(b.tempo)) * 100))]
		if i <= jetzt:
			var d := Stil.knopf("Vorhanden" if i == jetzt else "Abgelöst", func(): pass)
			d.disabled = true
			knoepfe.append(d)
		elif int(b.get("aera", 1)) > Game.aera:
			knoepfe.append(_gesperrt_knopf(b.aera))
		else:
			var k := Stil.knopf("Kaufen: %s" % Data.zahl(b.preis), func(): Game.kaufe_beutel(id))
			k.disabled = Game.muenzen < float(b.preis)
			knoepfe.append(k)
		v.add_child(_zeile(b.name, text, knoepfe))
	return paar[0]


func _reiter_helfer() -> Control:
	var paar := _scrollbar("Helfer & Posten")
	var v: VBoxContainer = paar[1]
	var hw := Game.helfer_werte()
	var hk := Stil.knopf("Einstellen: %s" % Data.zahl(Game.helfer_preis()), func(): Game.kaufe_helfer())
	hk.disabled = Game.muenzen < Game.helfer_preis()
	v.add_child(_zeile("Sammel-Eichhörnchen  ·  %d im Dienst" % Game.helfer,
		"Zahme Eichhörnchen mit rotem Halstuch. Sammeln am Berg und bringen alles zur nächsten Abgabestelle.\nJedes trägt %d Nüsse und sammelt %s pro Sekunde." % [int(hw.last), str(snappedf(float(hw.rate), 0.1)).replace(".", ",")], [hk]))
	for d in Data.POSTEN:
		var id: String = d.id
		var knoepfe: Array = []
		if Game.posten.has(id):
			var x := Stil.knopf("Gebaut", func(): pass)
			x.disabled = true
			knoepfe.append(x)
		elif int(d.aera) > Game.aera:
			knoepfe.append(_gesperrt_knopf(d.aera))
		else:
			var preis := Game.posten_preis(id)
			var k := Stil.knopf("Bauen: %s" % Data.zahl(preis), func(): Game.kaufe_posten(id))
			k.disabled = Game.muenzen < preis
			knoepfe.append(k)
		v.add_child(_zeile(d.name, d.text, knoepfe))
	return paar[0]


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
	var paar := _scrollbar("Knacken")
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
		var knoepfe: Array = []
		var text: String = m.text
		if m.aera > Game.aera:
			text += "\nGibt es ab Ära %d (Schicht „Hang“, %s Nüsse)" % [m.aera, Data.zahl(Data.SCHICHTEN[1].ab)]
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
	var v := Stil.fenster(_wurzel, "Opas Notizbuch", 1400, 820, schliessen)
	var titel := Stil.label("", 18, Stil.LEISE, true)
	v.add_child(titel)
	var aktualisieren := func():
		titel.text = "%s Münzen  ·  %d von %d Skills gelernt  ·  Ziehen = verschieben, Mausrad = zoomen, Klick auf leuchtende Knoten = lernen" % [Data.zahl(Game.muenzen), Game.skills.size(), Data.skills().size() - 1]
	aktualisieren.call()
	v.add_child(Stil.knopf("Fundbuch aufschlagen  (%d von %d Entdeckungen)" % [Game.funde_anzahl(), Data.FUNDE.size()], zeige_fundbuch, 18))
	var baum := Skillbaum.new()
	baum.size_flags_vertical = Control.SIZE_EXPAND_FILL
	baum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	baum.custom_minimum_size = Vector2(1300, 700)
	baum.gekauft.connect(func(_id): aktualisieren.call())
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Stil.box(Color(0.16, 0.11, 0.07, 0.95), Color(0.45, 0.32, 0.18), 8, 4))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(baum)
	v.add_child(p)





func zeige_pause() -> void:
	_oeffnen("pause", true)
	var v := Stil.fenster(_wurzel, "Pause", 620, 700, schliessen)
	v.add_child(Stil.knopf("Weiterspielen", schliessen, 22))
	v.add_child(Stil.label("Einstellungen", 22, Stil.GOLD))
	v.add_child(_regler("Maus-Empfindlichkeit", 0.05, 0.8, float(Game.einstellungen.empfindlichkeit), func(x): Game.einstellungen.empfindlichkeit = x))
	v.add_child(_regler("Lautstärke", 0.0, 1.0, float(Game.einstellungen.lautstaerke), func(x):
		Game.einstellungen.lautstaerke = x
		AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001, x)))))
	v.add_child(_regler("Musik", 0.0, 1.0, float(Game.einstellungen.musik), func(x):
		Game.einstellungen.musik = x
		Sfx.musik_lautstaerke(x)))
	v.add_child(_schalter("Hilfsring um die Nuss zeigen  [H]", "hilfsring"))
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
## Die zweite Seite in Opas Notizbuch: alle Geheimnisse des Tals. Ungefundene zeigen nur eine Andeutung.
func zeige_fundbuch() -> void:
	_oeffnen("fundbuch")
	var v := Stil.fenster(_wurzel, "Fundbuch", 920, 780, schliessen)
	v.add_child(Stil.label("%d von %d Entdeckungen im Haselgrund. Opa hat zu jeder etwas aufgeschrieben." % [Game.funde_anzahl(), Data.FUNDE.size()], 18, Stil.LEISE, true))
	var paar := _scrollbar("Fundbuch")
	var sc: ScrollContainer = paar[0]
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(860, 560)
	var liste: VBoxContainer = paar[1]
	for f in Data.FUNDE:
		var da := Game.hat_fund(f.id)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Stil.box(Color(0.2, 0.14, 0.09, 0.95) if da else Color(0.13, 0.1, 0.08, 0.9), Color(0.75, 0.58, 0.25) if da else Color(0.35, 0.28, 0.2), 8, 10))
		var z := VBoxContainer.new()
		z.add_child(Stil.label(str(f.name) if da else "? ? ?", 22, Stil.GOLD if da else Stil.LEISE))
		z.add_child(Stil.label(("„%s“ – Opa" % f.text) if da else str(f.hinweis), 17, Stil.TEXT if da else Stil.LEISE, true))
		p.add_child(z)
		liste.add_child(p)
	v.add_child(sc)
	v.add_child(Stil.knopf("Zurück zum Notizbuch", zeige_talente, 18))


## Ein Zettel, Brief oder Bauplan zum Lesen.
func zeige_zettel(titel: String, text: String) -> void:
	_oeffnen("zettel")
	var v := Stil.fenster(_wurzel, titel, 720, 520, schliessen)
	v.add_child(Stil.label(text, 19, Stil.TEXT, true))


func zeige_intro() -> void:
	_oeffnen("intro", true)
	var v := Stil.fenster(_wurzel, "Deez Nuts!", 860, 700, Callable())
	v.add_child(Stil.label("Opa Walter hat 52 Jahre lang Nüsse gesammelt und nie eine einzige verkauft. Jetzt gehört dir der Haselgrund: seine Hütte, sein Tal und ein Berg aus einer Million Nüssen. Du hast zwei Hände und Hosentaschen. Trag den Berg ab!", 19, Stil.TEXT, true))
	v.add_child(Stil.label("So geht's", 24, Stil.GOLD))
	var steuerung := """Draußen am Nussberg:
   [Linksklick halten] Nüsse sammeln · ist der Beutel voll, lauf in den gelben Kreis am Silo
   [X] Sammelwerkzeug wechseln · [WASD] laufen · [Shift] rennen · [Leertaste] springen

In der Hütte an der Knackbank ([E] auf den Nussknacker oder den Hocker):
   [R] holt Nüsse aus dem Lager · [Linksklick halten] zudrücken, loslassen wenn die Nuss zittert
   [Rechtsklick] Schalen wegwischen · [E] aufstehen
   Knacken bringt viel mehr als Abliefern. Volle Gläser verkauft die Rohrpost von selbst.

Am Bestellbrett vor der Hütte (oder [B]) kaufst du Werkzeug, Beutel, Helfer und Posten.
[Tab] öffnet Opas Notizbuch, den Skillbaum. [Esc] Menü."""
	v.add_child(Stil.label(steuerung, 17, Stil.TEXT, true))
	v.add_child(Stil.label("Testhilfen: [F9] +5.000 Münzen · [F10] +1.000 Nüsse ins Lager · [F11] +50.000 Münzen", 15, Stil.LEISE, true))
	v.add_child(Stil.knopf("Los geht's!", func():
		Game.erster_start = false
		schliessen(), 24))


## Der Abspann. Mit Brief (aus der Luke unter dem Berg) oder ohne.
func zeige_ende(brief := "") -> void:
	_oeffnen("ende", true)
	var v := Stil.fenster(_wurzel, "Der Berg ist leer!", 780, 700 if brief != "" else 460, Callable())
	if brief != "":
		v.add_child(Stil.label(brief, 18, Stil.TEXT, true))
		v.add_child(Stil.label("Du nimmst den Setzling und pflanzt ihn dorthin, wo der Berg war.", 19, Stil.GOLD, true))
	else:
		v.add_child(Stil.label("Wo die Kuppe war, liegt eine Luke im Boden. Opa hat dort etwas für dich hinterlassen.", 20, Stil.TEXT, true))
	v.add_child(Stil.label("„Deez Nuts!“", 48, Stil.GOLD))
	var st := Game.statistik
	v.add_child(Stil.label("Eine Million Nüsse in %d Minuten. Perfekte Knacke: %s. Geklaut: %s." % [int(Game.spielzeit / 60.0), Data.zahl(st.perfekt), Data.zahl(st.gestohlen)], 18, Stil.LEISE, true))
	v.add_child(Stil.knopf("Weiterknacken", func():
		offen = ""
		schliessen(), 22))
