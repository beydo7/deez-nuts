class_name Hud
extends CanvasLayer
## Alles, was über dem Bild liegt: Kasse, Ziel, Berg, Bestellungen, Hinweise, Fadenkreuz,
## Trefferprobe (Ring mit Zeiger) in der Knack-Ansicht, Ergebnis-Stempel und fliegende Münzbeträge.

var spieler: Spieler
var welt: Node

var _wurzel: Control
var _muenz_label: Label
var _muenz_anzeige := 0.0
var _muenz_box: Control
var _nebenwerte: Label
var _combo: Label
var _berg_label: Label
var _uhr_label: Label
var _berg_balken: ProgressBar
var _berg_info: Label
var _warnung: Label
var _bestellungen: VBoxContainer
var _ziel_box: PanelContainer
var _ziel_titel: Label
var _ziel_text: Label
var _ziel_hilfe: Label
var _ziel_balken: ProgressBar
var _prompt: HBoxContainer
var _prompt2: HBoxContainer
var _prompt2_alt := ""
var _tasten_leiste: HBoxContainer
var _glas_box: PanelContainer
var _glas_text: Label
var _glas_balken: ProgressBar
var _glas_alt := -1
var _stempel: Label
var _stempel_zeit := 0.0
var _toasts: VBoxContainer
var _banner: VBoxContainer
var _kreuz: Fadenkreuz
var _beutel_box: PanelContainer
var _beutel_text: Label
var _beutel_balken: ProgressBar
var _beutel_alt := -1
var _pfeil: Pfeil
var _prompt_alt := ""
var _bestell_timer := 0.0


func _ready() -> void:
	layer = 5
	_wurzel = Control.new()
	_wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.theme = Stil.thema()
	add_child(_wurzel)
	_kasse_bauen()
	_berg_bauen()
	_bestellungen_bauen()
	_ziel_bauen()
	_mitte_bauen()
	_unten_bauen()
	Game.toast.connect(zeige_toast)
	Game.knack_ergebnis.connect(_knack_ergebnis)
	Game.bestellungen_geaendert.connect(_bestellungen_zeichnen)
	Game.ziel_geaendert.connect(_ziel_zeichnen)
	Game.geld_geaendert.connect(_ziel_zeichnen)
	Game.verkauft.connect(_verkauft)
	Game.abgeliefert.connect(_abgeliefert)
	_muenz_anzeige = Game.muenzen
	_bestellungen_zeichnen()
	_ziel_zeichnen()


# =============================================================================
# Aufbau
# =============================================================================
func _kasse_bauen() -> void:
	var p := PanelContainer.new()
	p.position = Vector2(18, 16)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(p)
	_muenz_box = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var muenze := Muenze.new()
	muenze.custom_minimum_size = Vector2(40, 40)
	muenze.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(muenze)
	_muenz_label = Stil.titel("0", 42, Stil.GOLD)
	h.add_child(_muenz_label)
	_nebenwerte = Stil.label("", 17, Stil.LEISE)
	v.add_child(_nebenwerte)
	_combo = Stil.titel("", 26, Color(1.0, 0.6, 0.25))
	_combo.position = Vector2(22, 104)
	_wurzel.add_child(_combo)


func _berg_bauen() -> void:
	var mitte := VBoxContainer.new()
	mitte.anchor_left = 0.5
	mitte.anchor_right = 0.5
	mitte.offset_left = -230
	mitte.offset_right = 230
	mitte.offset_top = 12
	mitte.add_theme_constant_override("separation", 3)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(mitte)
	_berg_label = Stil.label("", 21, Stil.TEXT)
	_berg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_berg_label)
	_berg_balken = ProgressBar.new()
	_berg_balken.custom_minimum_size = Vector2(460, 10)
	_berg_balken.show_percentage = false
	_berg_balken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mitte.add_child(_berg_balken)
	_berg_info = Stil.label("", 15, Stil.LEISE)
	_berg_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_berg_info)
	_warnung = Stil.label("", 28, Stil.ROT)
	_warnung.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(_warnung)
	# Uhrzeit, dezent rechts neben dem Bergbalken
	_uhr_label = Stil.label("", 16, Stil.LEISE)
	_uhr_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_uhr_label.offset_left = 246
	_uhr_label.offset_top = 36
	_uhr_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(_uhr_label)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	mitte.add_child(_toasts)


func _bestellungen_bauen() -> void:
	var rechts := VBoxContainer.new()
	rechts.anchor_left = 1.0
	rechts.anchor_right = 1.0
	rechts.offset_left = -330
	rechts.offset_right = -16
	rechts.offset_top = 16
	rechts.add_theme_constant_override("separation", 6)
	rechts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(rechts)
	_bestellungen = rechts


func _ziel_bauen() -> void:
	var zettel := Stil.Blatt.new()
	zettel.liniert = false
	zettel.klebestreifen = true
	zettel.innen = 16
	zettel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ziel_box = zettel
	_ziel_box.position = Vector2(26, 182)
	_ziel_box.custom_minimum_size = Vector2(318, 0)
	_ziel_box.rotation_degrees = -1.3
	_wurzel.add_child(_ziel_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_ziel_box.add_child(v)
	_ziel_titel = Stil.hand("Ziel", 24, Stil.ROTSTIFT)
	v.add_child(_ziel_titel)
	_ziel_text = Stil.tinte("", 21, Stil.TINTE, true)
	_ziel_text.add_theme_font_override("font", Look.schrift(600))
	_ziel_text.custom_minimum_size = Vector2(286, 0)
	v.add_child(_ziel_text)
	_ziel_hilfe = Stil.hand("", 22, Stil.TINTE_LEISE, true)
	_ziel_hilfe.custom_minimum_size = Vector2(286, 0)
	v.add_child(_ziel_hilfe)
	_ziel_balken = ProgressBar.new()
	_ziel_balken.custom_minimum_size = Vector2(286, 7)
	_ziel_balken.show_percentage = false
	var fuell := StyleBoxFlat.new()
	fuell.bg_color = Stil.GRUENSTIFT
	fuell.set_corner_radius_all(2)
	_ziel_balken.add_theme_stylebox_override("fill", fuell)
	v.add_child(_ziel_balken)


func _mitte_bauen() -> void:
	_kreuz = Fadenkreuz.new()
	_kreuz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kreuz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(_kreuz)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -500
	box.offset_right = 500
	box.offset_top = 34
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(box)
	_prompt = HBoxContainer.new()
	_prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("separation", 8)
	box.add_child(_prompt)
	_prompt2 = HBoxContainer.new()
	_prompt2.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt2.add_theme_constant_override("separation", 6)
	box.add_child(_prompt2)
	_stempel = Stil.titel("", 54, Stil.GOLD)
	_stempel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stempel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stempel.add_theme_constant_override("outline_size", 10)
	_stempel.size = Vector2(800, 90)
	_stempel.pivot_offset = Vector2(400, 45)
	_stempel.modulate.a = 0.0
	_wurzel.add_child(_stempel)
	_banner = VBoxContainer.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.3
	_banner.anchor_bottom = 0.3
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_wurzel.add_child(_banner)


func _unten_bauen() -> void:
	_tasten_leiste = HBoxContainer.new()
	_tasten_leiste.anchor_left = 0.5
	_tasten_leiste.anchor_right = 0.5
	_tasten_leiste.anchor_top = 1.0
	_tasten_leiste.anchor_bottom = 1.0
	_tasten_leiste.offset_left = -600
	_tasten_leiste.offset_right = 600
	_tasten_leiste.offset_top = -52
	_tasten_leiste.alignment = BoxContainer.ALIGNMENT_CENTER
	_tasten_leiste.add_theme_constant_override("separation", 22)
	_tasten_leiste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(_tasten_leiste)
	_beutel_box = PanelContainer.new()
	_beutel_box.anchor_left = 0.5
	_beutel_box.anchor_right = 0.5
	_beutel_box.anchor_top = 1.0
	_beutel_box.anchor_bottom = 1.0
	_beutel_box.offset_left = -170
	_beutel_box.offset_right = 170
	_beutel_box.offset_top = -132
	_beutel_box.offset_bottom = -66
	_beutel_box.pivot_offset = Vector2(170, 33)
	_beutel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(_beutel_box)
	var bv := VBoxContainer.new()
	_beutel_box.add_child(bv)
	_beutel_text = Stil.label("", 19, Stil.TEXT)
	_beutel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_beutel_text)
	_beutel_balken = ProgressBar.new()
	_beutel_balken.custom_minimum_size = Vector2(320, 12)
	_beutel_balken.show_percentage = false
	bv.add_child(_beutel_balken)
	_pfeil = Pfeil.new()
	_pfeil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pfeil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(_pfeil)
	_glas_box = PanelContainer.new()
	_glas_box.anchor_left = 1.0
	_glas_box.anchor_right = 1.0
	_glas_box.anchor_top = 1.0
	_glas_box.anchor_bottom = 1.0
	_glas_box.offset_left = -330
	_glas_box.offset_right = -16
	_glas_box.offset_top = -108
	_glas_box.offset_bottom = -16
	_glas_box.pivot_offset = Vector2(157, 46)
	_glas_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(_glas_box)
	var v := VBoxContainer.new()
	_glas_box.add_child(v)
	_glas_text = Stil.label("", 19, Stil.TEXT)
	v.add_child(_glas_text)
	_glas_balken = ProgressBar.new()
	_glas_balken.custom_minimum_size = Vector2(290, 12)
	_glas_balken.show_percentage = false
	v.add_child(_glas_balken)


# =============================================================================
# Jedes Bild
# =============================================================================
func _process(delta: float) -> void:
	# Kasse zählt sichtbar hoch
	var ziel := Game.muenzen
	if absf(_muenz_anzeige - ziel) < 0.5:
		_muenz_anzeige = ziel
	else:
		_muenz_anzeige = lerpf(_muenz_anzeige, ziel, 1.0 - exp(-delta * 6.0))
	_muenz_label.text = Data.zahl(_muenz_anzeige)
	var neben := "Lager %s / %s" % [Data.zahl(Game.lager_menge()), Data.zahl(Game.lager_kapazitaet())]
	if Game.helfer > 0:
		neben += "\n%d Sammel-Eichhörnchen" % Game.helfer
	if Game.gold > 0:
		neben += "\n%d Goldene Nüsse" % Game.gold
	_nebenwerte.text = neben
	_combo.position.y = _muenz_box.position.y + _muenz_box.size.y + 6
	if Game.combo >= 2:
		_combo.text = "Combo ×%d  ·  +%d %%" % [Game.combo, int(Game.combo_bonus() * 100)]
		var hitze := clampf(float(Game.combo) / 20.0, 0.0, 1.0)
		_combo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4).lerp(Color(1.0, 0.35, 0.15), hitze))
	else:
		_combo.text = ""
	_ziel_box.position.y = _combo.position.y + (34 if _combo.text != "" else 4)
	# Berg
	var s := Game.schicht()
	_berg_label.text = "Nussberg  %s" % Data.zahl(Game.berg_rest())
	var uhr_h := int(Game.tageszeit)
	var uhr_m := int((Game.tageszeit - uhr_h) * 60.0)
	_uhr_label.text = "%02d:%02d%s" % [uhr_h, uhr_m - uhr_m % 5, "  ·  Regen" if Game.wetter == "regen" else ""]
	var naechste := Data.naechste_schicht(Game.genommen)
	if naechste.is_empty():
		_berg_balken.value = 100.0 * float(Game.genommen) / Data.BERG_GROESSE
		_berg_info.text = "Schicht: %s" % s.name
	else:
		var von: float = s.ab
		var bis: float = naechste.ab
		_berg_balken.value = 100.0 * (Game.genommen - von) / max(1.0, bis - von)
		_berg_info.text = "Schicht %s  ·  %s in %s Nüssen" % [s.name, naechste.name, Data.zahl(float(naechste.ab) - Game.genommen)]
	# Hinweise und Knack-Ansicht
	var sitzt := spieler != null and spieler.sitzt
	if spieler:
		var p := spieler.hinweis
		if p != _prompt_alt:
			_prompt_alt = p
			_prompt_setzen(p, _prompt, 18, 22, Stil.TEXT)
		if spieler.hinweis2 != _prompt2_alt:
			_prompt2_alt = spieler.hinweis2
			_prompt_setzen(spieler.hinweis2, _prompt2, 15, 17, Stil.LEISE)
		_kreuz.aktiv = p != ""
		_kreuz.sitzend = sitzt
		var st := spieler.blickt_auf_station()
		_kreuz.station = st if (sitzt and st and st.zeigt_ring()) else null
		if _kreuz.station:
			_kreuz.nuss_bild = spieler.kamera.unproject_position(st.sitz_global())
		_kreuz.queue_redraw()
	_tasten_leiste.visible = bool(Game.einstellungen.tastenhilfe)
	_tasten_leiste_zeichnen(sitzt)
	_glas_zeichnen(sitzt)
	_beutel_zeichnen(sitzt)
	# Stempel
	if _stempel_zeit > 0.0:
		_stempel_zeit -= delta
		_stempel.modulate.a = clampf(_stempel_zeit / 0.35, 0.0, 1.0)
	# Toasts
	for i in range(_toasts.get_child_count() - 1, -1, -1):
		var t: Control = _toasts.get_child(i)
		var rest: float = t.get_meta("zeit") - delta
		t.set_meta("zeit", rest)
		t.modulate.a = clampf(rest / 0.6, 0.0, 1.0)
		if rest <= 0.0:
			t.queue_free()
	_bestell_timer += delta
	if _bestell_timer > 1.0:
		_bestell_timer = 0.0
		_bestellungen_zeichnen()
		_ziel_zeichnen()


func _prompt_setzen(text: String, ziel: HBoxContainer, tasten_groesse: int, text_groesse: int, farbe: Color) -> void:
	for c in ziel.get_children():
		c.queue_free()
	if text == "":
		return
	for t in _tasten_teilen(text):
		if t[0]:
			ziel.add_child(Stil.taste(t[1], tasten_groesse))
		else:
			ziel.add_child(Stil.label(t[1], text_groesse, farbe))


## Zerlegt "[E] Glas tragen" in [[true,"E"],[false,"Glas tragen"]].
func _tasten_teilen(text: String) -> Array:
	var aus: Array = []
	var rest := text
	while rest != "":
		var a := rest.find("[")
		var b := rest.find("]")
		if a == -1 or b == -1 or b < a:
			aus.append([false, rest.strip_edges()])
			break
		if a > 0:
			aus.append([false, rest.substr(0, a).strip_edges()])
		aus.append([true, rest.substr(a + 1, b - a - 1)])
		rest = rest.substr(b + 1)
	return aus.filter(func(x): return x[1] != "")


var _leiste_modus := ""


func _tasten_leiste_zeichnen(sitzt: bool) -> void:
	var modus := "sitzen" if sitzt else ("tragen" if spieler and spieler.gehalten else "laufen")
	var st: Knackstation = spieler.sitz_station if spieler else null
	if sitzt and st and not st.geladen:
		modus = "leer"
	if sitzt and welt and welt.has_method("eichhoernchen_am_tisch") and welt.eichhoernchen_am_tisch():
		modus = "dieb"
	if modus == _leiste_modus:
		return
	_leiste_modus = modus
	for c in _tasten_leiste.get_children():
		c.queue_free()
	var paare: Array = []
	match modus:
		"sitzen":
			paare = [["Leertaste", "im hellen Bereich drücken: knacken"], ["Rechtsklick", "Schalen wischen"], ["R", "Nüsse aus dem Lager"], ["E", "aufstehen"]]
		"leer":
			paare = [["R", "Nüsse aus dem Lager holen"], ["Rechtsklick", "Schalen wischen"], ["E", "aufstehen"]]
		"dieb":
			paare = [["Rechtsklick", "EICHHÖRNCHEN VERJAGEN!"], ["E", "aufstehen"]]
		"tragen":
			paare = [["E", "ablegen / hinein"], ["Rechtsklick", "werfen"], ["Q", "fallen lassen"]]
		"laufen":
			paare = [["Linksklick", "sammeln"], ["E", "benutzen"], ["X", "Werkzeug"], ["B", "Laden"], ["Tab", "Skills"], ["Esc", "Menü"]]
	for p in paare:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(Stil.taste(p[0], 15))
		h.add_child(Stil.label(p[1], 16, Stil.ROT if modus == "dieb" else Stil.TEXT))
		_tasten_leiste.add_child(h)


func _beutel_zeichnen(sitzt: bool) -> void:
	var menge := Game.beutel_menge()
	var kap := Game.kapazitaet()
	_beutel_box.visible = not sitzt
	var voll := menge >= kap
	_beutel_text.text = ("%s VOLL – ab zum gelben Kreis!" if voll else "%s  %s / %s") % ([Data.beutel(Game.beutel_id).name] if voll else [Data.beutel(Game.beutel_id).name, Data.zahl(menge), Data.zahl(kap)])
	_beutel_text.add_theme_color_override("font_color", Stil.GOLD if voll else Stil.TEXT)
	_beutel_balken.value = 100.0 * float(menge) / float(max(1, kap))
	if menge != _beutel_alt:
		if _beutel_alt >= 0 and menge > _beutel_alt and _beutel_box.scale.x < 1.02:
			_beutel_box.scale = Vector2(1.04, 1.04)
			create_tween().tween_property(_beutel_box, "scale", Vector2.ONE, 0.12)
		_beutel_alt = menge
	# Pfeil zur nächsten Abgabe, wenn der Beutel voll ist
	_pfeil.ziel_bild = Vector2.INF
	if voll and not sitzt and welt and spieler:
		var ziel: Vector3 = welt.naechste_abgabe(spieler.global_position)
		var cam := spieler.kamera
		var abstand := spieler.global_position.distance_to(ziel)
		_pfeil.text = "%d m" % int(abstand)
		if abstand > 2.0:
			if cam.is_position_behind(ziel):
				var lokal := cam.global_transform.affine_inverse() * ziel
				_pfeil.ziel_bild = _wurzel.size * 0.5 + Vector2(lokal.x, -lokal.y).normalized() * -2000.0
			else:
				_pfeil.ziel_bild = cam.unproject_position(ziel + Vector3(0, 1.0, 0))
	_pfeil.queue_redraw()


func _abgeliefert(anzahl: int, betrag: float, pos: Vector3) -> void:
	if spieler == null or pos.distance_to(spieler.global_position) > 8.0:
		return
	var l := Stil.label("+%s  (%s Nüsse)" % [Data.zahl(betrag), Data.zahl(anzahl)], 34, Stil.GOLD)
	l.add_theme_constant_override("outline_size", 8)
	l.position = _wurzel.size * 0.5 + Vector2(-120, -120)
	_wurzel.add_child(l)
	var ziel := _muenz_box.position + Vector2(60, 6)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -50), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", ziel, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "scale", Vector2(0.5, 0.5), 0.5)
	tw.tween_callback(func():
		l.queue_free()
		Sfx.spiele("muenzen", -6.0)
		_muenz_box.pivot_offset = _muenz_box.size * 0.5
		_muenz_box.scale = Vector2(1.12, 1.12)
		create_tween().tween_property(_muenz_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


func _glas_zeichnen(sitzt: bool) -> void:
	var glas: Behaelter = welt.glas if welt else null
	_glas_box.visible = glas != null and sitzt
	if not _glas_box.visible:
		return
	_glas_text.text = "%s  %d/%d  ·  %s Münzen" % [glas.anzeige_name(), glas.belegt(), glas.kapazitaet, Data.zahl(glas.verkaufswert())]
	_glas_balken.value = 100.0 * float(glas.belegt()) / float(glas.kapazitaet)
	if glas.voll():
		_glas_text.text = "%s VOLL  ·  %s Münzen  ·  Rohrpost!" % [glas.anzeige_name(), Data.zahl(glas.verkaufswert())]
		_glas_text.add_theme_color_override("font_color", Stil.GOLD)
	else:
		_glas_text.add_theme_color_override("font_color", Stil.TEXT)
	if glas.belegt() != _glas_alt:
		if _glas_alt >= 0 and glas.belegt() > _glas_alt:
			_glas_box.scale = Vector2(1.06, 1.06)
			create_tween().tween_property(_glas_box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		_glas_alt = glas.belegt()


# =============================================================================
# Ziele, Bestellungen
# =============================================================================
func _ziel_zeichnen() -> void:
	var z := Game.ziel_aktuell()
	if not z.is_empty():
		_ziel_titel.text = "Ziel %d von %d" % [Game.ziel_index + 1, Data.ZIELE.size()]
		_ziel_text.text = z.text
		_ziel_hilfe.text = z.hilfe
		var n := int(z.get("anzahl", 1))
		_ziel_balken.visible = n > 1
		_ziel_balken.value = 100.0 * float(Game.ziel_zaehler) / float(n)
		return
	var k := Game.naechstes_kaufziel()
	if k.is_empty():
		var naechste := Data.naechste_schicht(Game.genommen)
		_ziel_titel.text = "Ziel"
		_ziel_text.text = "Trag den Berg ab!" if naechste.is_empty() else "Grab dich bis zur Schicht „%s“" % naechste.name
		_ziel_hilfe.text = "Skills lernen mit [Tab]"
		_ziel_balken.visible = false
		return
	_ziel_titel.text = "Als Nächstes"
	_ziel_text.text = "%s bestellen" % k.name
	var fehlt: float = max(0.0, float(k.preis) - Game.muenzen)
	_ziel_hilfe.text = ("Noch %s Münzen" % Data.zahl(fehlt)) if fehlt > 0.0 else "Genug Geld! Ab zum roten Telefon."
	_ziel_balken.visible = true
	_ziel_balken.value = 100.0 * clampf(Game.muenzen / max(1.0, float(k.preis)), 0.0, 1.0)


func _bestellungen_zeichnen() -> void:
	for c in _bestellungen.get_children():
		c.queue_free()
	if Game.bestellungen.is_empty():
		return
	var kopf := Stil.label("Bestellungen", 26, Stil.TEXT)
	kopf.add_theme_font_override("font", Stil.schrift_hand())
	kopf.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bestellungen.add_child(kopf)
	var nr := 0
	for b in Game.bestellungen:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Stil.papier(Stil.PAPIER, 12, 6))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.pivot_offset = Vector2(157, 30)
		p.rotation_degrees = [0.7, -0.9, 0.4, -0.5][nr % 4]
		nr += 1
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		p.add_child(v)
		var z1 := HBoxContainer.new()
		v.add_child(z1)
		var name_l := Stil.tinte(b.kunde, 17)
		name_l.add_theme_font_override("font", Look.schrift(600))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		z1.add_child(name_l)
		var zeit := int(b.zeit)
		z1.add_child(Stil.hand("%d:%02d" % [zeit / 60, zeit % 60], 22, Stil.ROTSTIFT if zeit < 60 else Stil.TINTE_LEISE))
		var n: String = Data.NUESSE[b.nuss].name
		v.add_child(Stil.tinte("%d von %d %s-Hälften" % [b.stand, b.menge, n], 15, Stil.TINTE))
		v.add_child(Stil.hand("bringt %s%s" % [Data.zahl(b.lohn), " und eine Goldnuss" if b.gold > 0 else ""], 20, Stil.TINTE_LEISE))
		var bal := ProgressBar.new()
		bal.custom_minimum_size = Vector2(0, 5)
		bal.show_percentage = false
		bal.value = 100.0 * float(b.stand) / float(b.menge)
		v.add_child(bal)
		_bestellungen.add_child(p)


# =============================================================================
# Meldungen
# =============================================================================
func zeige_warnung(text: String) -> void:
	_warnung.text = text


func zeige_toast(text: String, farbe: Color) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Stil.label(text, 19, farbe.lerp(Stil.TEXT, 0.25), true)
	l.add_theme_font_override("font", Look.schrift(600))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.set_meta("zeit", 3.2)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		var alt := _toasts.get_child(0)
		_toasts.remove_child(alt)
		alt.queue_free()


func zeige_banner(titel: String, unter: String) -> void:
	for c in _banner.get_children():
		c.queue_free()
	var t := Stil.label(titel, 64, Stil.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 12)
	_banner.add_child(t)
	var u := Stil.label(unter, 30, Stil.TEXT)
	u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(u)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(3.0)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _knack_ergebnis(art: String, text: String) -> void:
	var farben := {"perfekt": Stil.GRUEN, "bruch": Color(1, 0.7, 0.3), "matsch": Stil.ROT, "riss": Stil.TEXT,
		"frueh": Stil.LEISE, "schwach": Stil.ROT, "faul": Color(0.6, 0.8, 0.3)}
	_stempel.text = text
	_stempel.add_theme_color_override("font_color", farben.get(art, Stil.TEXT))
	var gross := art == "perfekt"
	_stempel.add_theme_font_size_override("font_size", 58 if gross else 38)
	var vp := _wurzel.size
	_stempel.position = Vector2(vp.x * 0.5 - 400, vp.y * 0.5 - (190 if spieler and spieler.sitzt else 150))
	_stempel.modulate.a = 1.0
	_stempel_zeit = 1.1 if gross else 0.9
	_stempel.scale = Vector2(1.7, 1.7) if gross else Vector2(1.2, 1.2)
	_stempel.rotation = randf_range(-0.08, 0.08)
	var tw := create_tween()
	tw.tween_property(_stempel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ein Betrag fliegt vom Verkaufsort zur Kasse.
func _verkauft(betrag: float, pos: Vector3) -> void:
	if spieler == null:
		return
	var start := _wurzel.size * 0.5
	if not spieler.kamera.is_position_behind(pos):
		start = spieler.kamera.unproject_position(pos)
	var l := Stil.label("+%s" % Data.zahl(betrag), 40, Stil.GOLD)
	l.add_theme_constant_override("outline_size", 8)
	l.position = start - Vector2(60, 20)
	_wurzel.add_child(l)
	var ziel := _muenz_box.position + Vector2(60, 6)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -60), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position", ziel, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "scale", Vector2(0.6, 0.6), 0.55)
	tw.tween_callback(func():
		l.queue_free()
		Sfx.spiele("muenzen", -6.0)
		_muenz_box.pivot_offset = _muenz_box.size * 0.5
		_muenz_box.scale = Vector2(1.12, 1.12)
		create_tween().tween_property(_muenz_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


# =============================================================================
# Zeichnungen
# =============================================================================
class Pfeil extends Control:
	var ziel_bild := Vector2.INF
	var text := ""

	func _draw() -> void:
		if ziel_bild == Vector2.INF:
			return
		var rand := 70.0
		var m := size * 0.5
		var p := ziel_bild
		var innen := Rect2(Vector2(rand, rand), size - Vector2(rand, rand) * 2.0)
		var am_rand := not innen.has_point(p)
		if am_rand:
			var d := (p - m)
			var f: float = min((size.x * 0.5 - rand) / max(absf(d.x), 0.001), (size.y * 0.5 - rand) / max(absf(d.y), 0.001))
			p = m + d * f
		var puls := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.008)
		var richtung := (p - m).normalized() if am_rand else Vector2.DOWN
		var spitze := p + richtung * 16.0 * puls
		var quer := Vector2(-richtung.y, richtung.x)
		draw_colored_polygon(PackedVector2Array([spitze, p - richtung * 10.0 + quer * 14.0, p - richtung * 10.0 - quer * 14.0]), Color(1.0, 0.8, 0.25, 0.95))
		var schrift := Look.schrift(600)
		draw_string_outline(schrift, p - richtung * 26.0 - Vector2(24, -6), text, HORIZONTAL_ALIGNMENT_CENTER, 48, 18, 6, Color(0.1, 0.06, 0.03))
		draw_string(schrift, p - richtung * 26.0 - Vector2(24, -6), text, HORIZONTAL_ALIGNMENT_CENTER, 48, 18, Color(1.0, 0.85, 0.35))


class Muenze extends Control:
	func _draw() -> void:
		var m := size * 0.5
		var r: float = min(size.x, size.y) * 0.5
		draw_circle(m + Vector2(1.5, 2), r, Color(0, 0, 0, 0.35))
		draw_circle(m, r, Color(0.85, 0.6, 0.15))
		draw_circle(m, r * 0.8, Color(1.0, 0.8, 0.3))
		draw_arc(m, r * 0.62, -2.4, -0.7, 12, Color(1, 0.95, 0.75), 2.0, true)


class Fadenkreuz extends Control:
	var station: Knackstation
	var aktiv := false
	var sitzend := false
	var nuss_bild := Vector2.ZERO

	func _draw() -> void:
		var m := size * 0.5
		if not sitzend:
			if aktiv:
				draw_arc(m, 9.0, 0, TAU, 24, Color(1, 0.9, 0.6, 0.9), 2.0, true)
				draw_circle(m, 2.5, Color(1, 1, 1, 0.95))
			else:
				draw_circle(m, 2.5, Color(1, 1, 1, 0.7))
		if station == null or not station.zonen.has("s0"):
			return
		_trefferprobe(station)

	## Die Trefferprobe um die Nuss: Ring, helle Trefferzone, roter Zeiger, darunter die Taste.
	func _trefferprobe(st: Knackstation) -> void:
		const HELL := Color(1.0, 0.97, 0.86)
		const GELB := Color(1.0, 0.82, 0.3)
		const GRUEN := Color(0.45, 1.0, 0.4)
		var gesamt := Knackstation.DRUCK_MAX
		var mitte := nuss_bild
		var winkel := func(d: float) -> float: return -PI * 0.5 + TAU * clampf(d, 0.0, gesamt) / gesamt
		var blitz := clampf(st.treffer_zeit / Knackstation.NACHHALL, 0.0, 1.0)
		var laeuft := st.geladen and st.phase != "ruhe"
		# Nachhall eines Treffers, der die Nuss geöffnet hat: Zone und Zeiger blitzen auf und wachsen
		# nach außen weg, während innen schon der Ring für die nächste Nuss aufploppt.
		if blitz > 0.0 and st.phase != "treffer" and st.treffer_zonen.has("s0"):
			var tz: Dictionary = st.treffer_zonen
			var farbe := GRUEN if st.treffer_art == "perfekt" else Color(1.0, 0.5, 0.25)
			var rb := 112.0 * (1.0 + 0.22 * (1.0 - blitz))
			if st.treffer_art == "perfekt":
				draw_arc(mitte, rb, winkel.call(tz.s0), winkel.call(tz.s1), 32, Color(farbe, blitz), 18.0 + 10.0 * blitz, true)
			var wb: float = winkel.call(st.treffer_druck)
			var rv := Vector2(cos(wb), sin(wb))
			draw_line(mitte + rv * (rb - 34.0), mitte + rv * (rb + 18.0), Color(farbe, blitz), 5.0, true)
		if not laeuft:
			return
		var z: Dictionary = st.zonen
		var steht := st.phase == "treffer"
		# Aufploppen: Ring kommt von außen herein
		var ein := st.vorlauf_anteil()
		var r := 112.0 * lerpf(1.3, 1.0, 1.0 - pow(1.0 - ein, 3.0))
		var alpha := clampf(ein * 2.5, 0.0, 1.0)
		if st.phase == "warten":
			alpha = 0.45
		# Grundring und Startmarke oben
		draw_arc(mitte, r, 0, TAU, 96, Color(0, 0, 0, 0.5 * alpha), 11.0, true)
		draw_arc(mitte, r, 0, TAU, 96, Color(1, 1, 1, 0.6 * alpha), 2.0, true)
		draw_line(mitte + Vector2(0, -r - 10), mitte + Vector2(0, -r + 10), Color(1, 1, 1, 0.5 * alpha), 2.0, true)
		# Zonen
		var z0: float = z.s0
		var zonenfarbe := HELL
		if z.get("schwach", false):
			# Werkzeug zu schwach: Die ganze Zone knackst nur an, deshalb gelb und mit der Riss-Flanke verbunden
			z0 = z.a
			zonenfarbe = GELB
		else:
			draw_arc(mitte, r, winkel.call(z.a), winkel.call(z.s0), 24, Color(GELB, 0.8 * alpha), 7.0, true)
			draw_arc(mitte, r, winkel.call(z.s1), winkel.call(z.m), 24, Color(1.0, 0.55, 0.2, 0.8 * alpha), 7.0, true)
			draw_arc(mitte, r, winkel.call(z.m), winkel.call(gesamt), 32, Color(0.95, 0.25, 0.2, 0.45 * alpha), 4.0, true)
		var dick := 18.0 + 10.0 * (st.sprung_zeit / 0.3)
		draw_arc(mitte, r, winkel.call(z0) - 0.014, winkel.call(z.s1) + 0.014, 32, Color(0.1, 0.06, 0.03, 0.9 * alpha), dick + 5.0, true)
		draw_arc(mitte, r, winkel.call(z0), winkel.call(z.s1), 32, Color(zonenfarbe, alpha), dick, true)
		# Zeiger
		if st.phase != "warten":
			var w: float = winkel.call(st.druck)
			var richtung := Vector2(cos(w), sin(w))
			var zeiger := Color(0.95, 0.2, 0.15)
			if steht and st.treffer_art == "riss":
				zeiger = GELB
			draw_line(mitte + richtung * (r - 36.0), mitte + richtung * (r + 20.0), Color(0.08, 0.04, 0.02, 0.85 * alpha), 9.0, true)
			draw_line(mitte + richtung * (r - 35.0), mitte + richtung * (r + 19.0), Color(zeiger, alpha), 5.0, true)
			draw_circle(mitte + richtung * (r + 19.0), 5.0, Color(zeiger, alpha))
		# Taste unter dem Ring
		var schrift := Look.schrift(600)
		var text := "LEERTASTE"
		if st.phase == "warten":
			text = "LEERTASTE: NEUE RUNDE"
			alpha = 1.0
		var breite := schrift.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
		var kasten := Rect2(mitte + Vector2(-breite * 0.5, r + 32.0), Vector2(breite, 30.0))
		var gedrueckt := 3.0 if steht else 0.0
		kasten.position.y += gedrueckt
		draw_rect(Rect2(kasten.position + Vector2(0, 4.0 - gedrueckt), kasten.size), Color(0.1, 0.06, 0.03, 0.7 * alpha))
		draw_rect(kasten, Color(0.98, 0.94, 0.84, 0.95 * alpha))
		draw_string(schrift, kasten.position + Vector2(14.0, 21.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 0.12, 0.06, alpha))
