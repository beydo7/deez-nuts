class_name Hud
extends CanvasLayer
## Alles, was über dem Bild liegt: Werte, Berg-Fortschritt, Bestellungen, Hinweise, Fadenkreuz.

var spieler: Spieler
var _werte: Label
var _berg: Label
var _berg_balken: ProgressBar
var _meilenstein: Label
var _bestellungen: VBoxContainer
var _hinweis: Label
var _hand: Label
var _ergebnis: Label
var _ergebnis_zeit := 0.0
var _toasts: VBoxContainer
var _kreuz: Fadenkreuz
var _warnung: Label


func _ready() -> void:
	layer = 5
	var wurzel := Control.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.theme = Stil.thema()
	add_child(wurzel)

	# Werte links oben
	var links := PanelContainer.new()
	links.position = Vector2(16, 16)
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.add_child(links)
	_werte = Stil.label("", 20)
	links.add_child(_werte)

	# Berg oben Mitte
	var mitte := VBoxContainer.new()
	mitte.anchor_left = 0.5
	mitte.anchor_right = 0.5
	mitte.offset_left = -260
	mitte.offset_right = 260
	mitte.offset_top = 14
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.add_child(mitte)
	_berg = Stil.label("", 22, Stil.TEXT)
	_berg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_berg)
	_berg_balken = ProgressBar.new()
	_berg_balken.custom_minimum_size = Vector2(520, 14)
	_berg_balken.show_percentage = false
	_berg_balken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mitte.add_child(_berg_balken)
	_meilenstein = Stil.label("", 16, Stil.LEISE)
	_meilenstein.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_meilenstein)
	_warnung = Stil.label("", 26, Stil.ROT)
	_warnung.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_warnung)

	# Bestellungen rechts oben
	var rechts := PanelContainer.new()
	rechts.anchor_left = 1.0
	rechts.anchor_right = 1.0
	rechts.offset_left = -380
	rechts.offset_right = -16
	rechts.offset_top = 16
	rechts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.add_child(rechts)
	_bestellungen = VBoxContainer.new()
	rechts.add_child(_bestellungen)

	# Toasts links Mitte
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(16, 260)
	_toasts.custom_minimum_size = Vector2(520, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.add_child(_toasts)

	# Fadenkreuz
	_kreuz = Fadenkreuz.new()
	_kreuz.set_anchors_preset(Control.PRESET_CENTER)
	_kreuz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wurzel.add_child(_kreuz)

	_ergebnis = Stil.label("", 34, Stil.GOLD)
	_ergebnis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ergebnis.anchor_left = 0.5
	_ergebnis.anchor_right = 0.5
	_ergebnis.anchor_top = 0.5
	_ergebnis.anchor_bottom = 0.5
	_ergebnis.offset_left = -400
	_ergebnis.offset_right = 400
	_ergebnis.offset_top = -150
	_ergebnis.offset_bottom = -100
	wurzel.add_child(_ergebnis)

	_hand = Stil.label("", 18, Stil.LEISE)
	_hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand.anchor_left = 0.5
	_hand.anchor_right = 0.5
	_hand.anchor_top = 1.0
	_hand.anchor_bottom = 1.0
	_hand.offset_left = -500
	_hand.offset_right = 500
	_hand.offset_top = -110
	_hand.offset_bottom = -80
	wurzel.add_child(_hand)

	_hinweis = Stil.label("", 22, Stil.TEXT)
	_hinweis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hinweis.anchor_left = 0.5
	_hinweis.anchor_right = 0.5
	_hinweis.anchor_top = 1.0
	_hinweis.anchor_bottom = 1.0
	_hinweis.offset_left = -600
	_hinweis.offset_right = 600
	_hinweis.offset_top = -76
	_hinweis.offset_bottom = -40
	wurzel.add_child(_hinweis)

	var tasten := Stil.label("[Tab] Talentbaum   [F] Schalen wischen   [H] Hilfsring   [Esc] Menü", 15, Stil.LEISE)
	tasten.anchor_top = 1.0
	tasten.anchor_bottom = 1.0
	tasten.offset_left = 16
	tasten.offset_top = -30
	wurzel.add_child(tasten)

	Game.toast.connect(zeige_toast)
	Game.knack_ergebnis.connect(_knack_ergebnis)
	Game.bestellungen_geaendert.connect(_bestellungen_zeichnen)
	_bestellungen_zeichnen()


func _process(delta: float) -> void:
	var z := "Münzen: %s" % Data.zahl(Game.muenzen)
	if Game.gold > 0:
		z += "\nGoldene Nüsse: %d" % Game.gold
	z += "\nMeisterpunkte: %d" % Game.mp
	if Game.mp > 0:
		z += "  [Tab]"
	if Game.hat_maschine("ofen") or Game.energie > 0.0:
		z += "\nEnergie: %d" % int(Game.energie)
	z += "\nWerkzeug: %s" % Data.werkzeug(Game.werkzeug_aktiv).name
	if Game.combo > 0:
		z += "\nCombo: ×%d  (+%d %%)" % [Game.combo, int(Game.combo_bonus() * 100)]
	_werte.text = z
	var s := Game.schicht()
	_berg.text = "Nussberg: %s übrig  ·  Schicht: %s" % [Data.zahl(Game.berg_rest()), s.name]
	var naechste := Data.naechste_schicht(Game.genommen)
	if naechste.is_empty():
		_berg_balken.value = 100.0 * float(Game.genommen) / Data.BERG_GROESSE
	else:
		var von: float = s.ab
		var bis: float = naechste.ab
		_berg_balken.value = 100.0 * (Game.genommen - von) / max(1.0, bis - von)
	var ms := Data.meilenstein_bei(Game.naechster_meilenstein)
	var text_m := "Geknackt: %s  ·  nächster Meisterpunkt bei %s" % [Data.zahl(Game.geknackt), Data.zahl(ms)]
	if not naechste.is_empty():
		text_m += "  ·  %s ab %s" % [naechste.name, Data.zahl(naechste.ab)]
	_meilenstein.text = text_m
	if spieler:
		_hinweis.text = spieler.hinweis
		if spieler.gehalten:
			_hand.text = "In der Hand: " + spieler._gehalten_name()
		else:
			_hand.text = ""
		var st := spieler.blickt_auf_station()
		if st == null and spieler.aktive_station:
			st = spieler.aktive_station
		_kreuz.station = st if (st and st.geladen and Game.einstellungen.hilfsring) else null
		_kreuz.queue_redraw()
	if _ergebnis_zeit > 0.0:
		_ergebnis_zeit -= delta
		_ergebnis.modulate.a = clampf(_ergebnis_zeit / 0.5, 0.0, 1.0)
	for i in range(_toasts.get_child_count() - 1, -1, -1):
		var t: Label = _toasts.get_child(i)
		var rest: float = t.get_meta("zeit") - delta
		t.set_meta("zeit", rest)
		t.modulate.a = clampf(rest / 0.6, 0.0, 1.0)
		if rest <= 0.0:
			t.queue_free()


func zeige_warnung(text: String) -> void:
	_warnung.text = text


func zeige_toast(text: String, farbe: Color) -> void:
	var l := Stil.label(text, 19, farbe, true)
	l.custom_minimum_size = Vector2(520, 0)
	l.set_meta("zeit", 4.5)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 6:
		var alt := _toasts.get_child(0)
		_toasts.remove_child(alt)
		alt.queue_free()


func _knack_ergebnis(art: String, text: String) -> void:
	var farben := {"perfekt": Stil.GRUEN, "bruch": Color(1, 0.7, 0.3), "matsch": Stil.ROT, "riss": Stil.TEXT,
		"frueh": Stil.LEISE, "schwach": Stil.ROT, "faul": Color(0.6, 0.8, 0.3)}
	_ergebnis.text = text
	_ergebnis.add_theme_color_override("font_color", farben.get(art, Stil.TEXT))
	_ergebnis_zeit = 1.4
	_ergebnis.modulate.a = 1.0


func _bestellungen_zeichnen() -> void:
	for c in _bestellungen.get_children():
		c.queue_free()
	_bestellungen.add_child(Stil.label("Bestellungen", 20, Stil.GOLD))
	for b in Game.bestellungen:
		var n: String = Data.NUESSE[b.nuss].name
		var minuten := int(b.zeit) / 60
		var sekunden := int(b.zeit) % 60
		var zeile := "%s  ·  %d:%02d\n%d/%d %s-Hälften  ·  %s Münzen%s" % [b.kunde, minuten, sekunden, b.stand, b.menge, n, Data.zahl(b.lohn), " + Goldnuss" if b.gold > 0 else ""]
		var l := Stil.label(zeile, 15, Stil.TEXT, true)
		l.custom_minimum_size = Vector2(330, 0)
		_bestellungen.add_child(l)


var _bestell_timer := 0.0


func _physics_process(delta: float) -> void:
	_bestell_timer += delta
	if _bestell_timer > 1.0:
		_bestell_timer = 0.0
		_bestellungen_zeichnen()


class Fadenkreuz extends Control:
	var station: Knackstation

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.85))
		if station == null or station.zonen.is_empty():
			return
		var r := 46.0
		var z := station.zonen
		var gesamt := Knackstation.DRUCK_MAX
		var start := -PI * 0.5
		var abschnitte := [[0.0, z.a, Color(1, 1, 1, 0.18)], [z.a, z.s0, Color(1, 0.9, 0.5, 0.45)],
			[z.s0, z.s1, Color(0.4, 1.0, 0.4, 0.9)], [z.s1, z.m, Color(1.0, 0.6, 0.2, 0.6)], [z.m, gesamt, Color(1.0, 0.3, 0.25, 0.6)]]
		for a in abschnitte:
			var w0: float = start + TAU * float(a[0]) / gesamt
			var w1: float = start + TAU * float(a[1]) / gesamt
			if w1 > w0:
				draw_arc(Vector2.ZERO, r, w0, w1, 32, a[2], 7.0, true)
		if z.kappe < gesamt:
			var wk: float = start + TAU * float(z.kappe) / gesamt
			draw_line(Vector2(cos(wk), sin(wk)) * (r - 10), Vector2(cos(wk), sin(wk)) * (r + 10), Color(1, 0.2, 0.2), 3.0)
		var wd: float = start + TAU * station.druck / gesamt
		draw_line(Vector2(cos(wd), sin(wd)) * (r - 14), Vector2(cos(wd), sin(wd)) * (r + 12), Color(1, 1, 1), 3.0)
