class_name Hud
extends CanvasLayer
## Alles, was über dem Bild liegt: Kasse, Ziel, Berg, Bestellungen, Hinweise, Fadenkreuz,
## Hilfsring in der Knack-Ansicht, Ergebnis-Stempel und fliegende Münzbeträge.

var spieler: Spieler
var welt: Node

var _wurzel: Control
var _muenz_label: Label
var _muenz_anzeige := 0.0
var _muenz_box: Control
var _nebenwerte: Label
var _combo: Label
var _berg_label: Label
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
	muenze.custom_minimum_size = Vector2(34, 34)
	h.add_child(muenze)
	_muenz_label = Stil.label("0", 34, Stil.GOLD)
	h.add_child(_muenz_label)
	_nebenwerte = Stil.label("", 17, Stil.LEISE)
	v.add_child(_nebenwerte)
	_combo = Stil.label("", 22, Color(1.0, 0.6, 0.25))
	_combo.position = Vector2(22, 112)
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
	_ziel_box = PanelContainer.new()
	_ziel_box.position = Vector2(18, 170)
	_ziel_box.custom_minimum_size = Vector2(330, 0)
	_ziel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ziel_box.add_theme_stylebox_override("panel", Stil.box(Color(0.14, 0.2, 0.12, 0.85), Color(0.55, 0.78, 0.4), 12, 14))
	_wurzel.add_child(_ziel_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_ziel_box.add_child(v)
	_ziel_titel = Stil.label("ZIEL", 15, Color(0.7, 0.95, 0.55))
	v.add_child(_ziel_titel)
	_ziel_text = Stil.label("", 21, Stil.TEXT, true)
	_ziel_text.custom_minimum_size = Vector2(300, 0)
	v.add_child(_ziel_text)
	_ziel_hilfe = Stil.label("", 15, Stil.LEISE, true)
	_ziel_hilfe.custom_minimum_size = Vector2(300, 0)
	v.add_child(_ziel_hilfe)
	_ziel_balken = ProgressBar.new()
	_ziel_balken.custom_minimum_size = Vector2(300, 8)
	_ziel_balken.show_percentage = false
	_ziel_balken.add_theme_stylebox_override("fill", Stil.box(Color(0.55, 0.85, 0.4), Color(0.55, 0.85, 0.4), 4, 0))
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
	_stempel = Stil.label("", 54, Stil.GOLD)
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
	var neben := "%d Meisterpunkte" % Game.mp
	if Game.mp > 0:
		neben += "  [Tab]"
	if Game.gold > 0:
		neben += "\n%d Goldene Nüsse" % Game.gold
	if Game.hat_maschine("ofen") or Game.energie > 0.0:
		neben += "\nEnergie %d" % int(Game.energie)
	neben += "\n" + Data.werkzeug(Game.werkzeug_aktiv).name
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
		_kreuz.station = st if (sitzt and st and st.geladen and Game.einstellungen.hilfsring) else null
		if _kreuz.station:
			_kreuz.nuss_bild = spieler.kamera.unproject_position(st.sitz_global())
		_kreuz.queue_redraw()
	_tasten_leiste_zeichnen(sitzt)
	_glas_zeichnen(sitzt)
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
			paare = [["Linksklick", "halten & loslassen: knacken"], ["Rechtsklick", "Schalen wischen"], ["R", "Hebel"], ["E", "aufstehen"]]
		"leer":
			paare = [["R", "Nüsse holen (Hebel)"], ["Rechtsklick", "Schalen wischen"], ["E", "aufstehen"]]
		"dieb":
			paare = [["Rechtsklick", "EICHHÖRNCHEN VERJAGEN!"], ["E", "aufstehen"]]
		"tragen":
			paare = [["E", "ablegen / hinein"], ["Rechtsklick", "werfen"], ["Q", "fallen lassen"]]
		"laufen":
			paare = [["WASD", "laufen"], ["E", "benutzen"], ["R", "Hebel"], ["Tab", "Talente"], ["Esc", "Menü"]]
	for p in paare:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(Stil.taste(p[0], 15))
		h.add_child(Stil.label(p[1], 16, Stil.ROT if modus == "dieb" else Stil.TEXT))
		_tasten_leiste.add_child(h)


func _glas_zeichnen(sitzt: bool) -> void:
	var glas: Behaelter = welt.glas if welt else null
	_glas_box.visible = glas != null and (sitzt or glas.belegt() > 0)
	if not _glas_box.visible:
		return
	_glas_text.text = "%s  %d/%d  ·  %s Münzen" % [glas.anzeige_name(), glas.belegt(), glas.kapazitaet, Data.zahl(glas.verkaufswert())]
	_glas_balken.value = 100.0 * float(glas.belegt()) / float(glas.kapazitaet)
	if glas.voll():
		_glas_text.text = "%s VOLL  ·  %s Münzen  ·  ab zur Klappe!" % [glas.anzeige_name(), Data.zahl(glas.verkaufswert())]
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
		_ziel_titel.text = "ZIEL %d/%d" % [Game.ziel_index + 1, Data.ZIELE.size()]
		_ziel_text.text = z.text
		_ziel_hilfe.text = z.hilfe
		var n := int(z.get("anzahl", 1))
		_ziel_balken.visible = n > 1
		_ziel_balken.value = 100.0 * float(Game.ziel_zaehler) / float(n)
		return
	var k := Game.naechstes_kaufziel()
	if k.is_empty():
		var naechste := Data.naechste_schicht(Game.genommen)
		_ziel_titel.text = "ZIEL"
		_ziel_text.text = "Trag den Berg ab!" if naechste.is_empty() else "Grab dich bis zur Schicht „%s“" % naechste.name
		_ziel_hilfe.text = "Talente lernen mit [Tab]" if Game.mp > 0 else ""
		_ziel_balken.visible = false
		return
	_ziel_titel.text = "NÄCHSTES ZIEL"
	_ziel_text.text = "%s bestellen" % k.name
	var fehlt: float = max(0.0, float(k.preis) - Game.muenzen)
	_ziel_hilfe.text = ("Noch %s Münzen" % Data.zahl(fehlt)) if fehlt > 0.0 else "Genug Geld! Ab zum roten Telefon."
	_ziel_balken.visible = true
	_ziel_balken.value = 100.0 * clampf(Game.muenzen / max(1.0, float(k.preis)), 0.0, 1.0)


func _bestellungen_zeichnen() -> void:
	for c in _bestellungen.get_children():
		c.queue_free()
	var kopf := Stil.label("Bestellungen", 17, Stil.GOLD)
	kopf.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bestellungen.add_child(kopf)
	for b in Game.bestellungen:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Stil.box(Color(0.12, 0.08, 0.05, 0.78), Color(0.5, 0.38, 0.22, 0.8), 10, 10))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var z1 := HBoxContainer.new()
		v.add_child(z1)
		var name_l := Stil.label(b.kunde, 16, Stil.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		z1.add_child(name_l)
		var zeit := int(b.zeit)
		z1.add_child(Stil.label("%d:%02d" % [zeit / 60, zeit % 60], 15, Stil.ROT if zeit < 60 else Stil.LEISE))
		var n: String = Data.NUESSE[b.nuss].name
		v.add_child(Stil.label("%d/%d %s-Hälften  ·  %s%s" % [b.stand, b.menge, n, Data.zahl(b.lohn), " + Goldnuss" if b.gold > 0 else ""], 14, Stil.LEISE))
		var bal := ProgressBar.new()
		bal.custom_minimum_size = Vector2(0, 6)
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
	p.add_theme_stylebox_override("panel", Stil.box(Color(0.1, 0.07, 0.04, 0.78), farbe * Color(1, 1, 1, 0.6), 14, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Stil.label(text, 16, farbe, true)
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
		if station == null or station.zonen.is_empty():
			return
		# Hilfsring um die Nuss: Zonen und Druck-Zeiger
		var mitte := nuss_bild + Vector2(0, 0)
		var r := 92.0
		var z := station.zonen
		var gesamt := Knackstation.DRUCK_MAX
		var start := -PI * 0.5
		draw_arc(mitte, r, 0, TAU, 64, Color(0, 0, 0, 0.35), 12.0, true)
		var abschnitte := [[0.0, z.a, Color(1, 1, 1, 0.22)], [z.a, z.s0, Color(1, 0.88, 0.45, 0.55)],
			[z.s0, z.s1, Color(0.45, 1.0, 0.4, 0.95)], [z.s1, z.m, Color(1.0, 0.6, 0.2, 0.7)], [z.m, gesamt, Color(1.0, 0.3, 0.25, 0.7)]]
		for a in abschnitte:
			var w0: float = start + TAU * float(a[0]) / gesamt
			var w1: float = start + TAU * float(a[1]) / gesamt
			if w1 > w0:
				draw_arc(mitte, r, w0, w1, 32, a[2], 8.0, true)
		if z.kappe < gesamt:
			var wk: float = start + TAU * float(z.kappe) / gesamt
			draw_line(mitte + Vector2(cos(wk), sin(wk)) * (r - 12), mitte + Vector2(cos(wk), sin(wk)) * (r + 12), Color(1, 0.2, 0.2), 4.0, true)
		var wd: float = start + TAU * station.druck / gesamt
		var im_sweet: bool = station.druck >= z.s0 and station.druck <= z.s1
		var zeiger_farbe := Color(0.6, 1.0, 0.5) if im_sweet else Color(1, 1, 1)
		draw_line(mitte + Vector2(cos(wd), sin(wd)) * (r - 16), mitte + Vector2(cos(wd), sin(wd)) * (r + 14), zeiger_farbe, 4.0, true)
		draw_circle(mitte + Vector2(cos(wd), sin(wd)) * (r + 14), 4.0, zeiger_farbe)
