class_name Stil
extends RefCounted
## Gemeinsamer Look für Menüs und Anzeigen: Opas Kladde. Liniertes Papier, Tinte, Rotstift,
## Klebestreifen. Über der Spielwelt steht Schrift ohne Kasten, nur mit dunklem Rand.
## Drei Schriften: Lilita One (Überschriften, Zahlen), Fredoka (Lesetext), Caveat Brush (Opas Hand).

# Über der Welt (helle Schrift mit dunklem Rand)
const TEXT := Color(0.99, 0.95, 0.86)
const LEISE := Color(0.86, 0.79, 0.67)
const GOLD := Color(1.0, 0.8, 0.3)
const GRUEN := Color(0.62, 0.9, 0.45)
const ROT := Color(1.0, 0.5, 0.4)
# Auf Papier
const PAPIER := Color(0.955, 0.925, 0.835)
const PAPIER_ALT := Color(0.875, 0.83, 0.72)
const TINTE := Color(0.17, 0.115, 0.075)
const TINTE_LEISE := Color(0.42, 0.34, 0.26)
const ROTSTIFT := Color(0.74, 0.17, 0.12)
const GRUENSTIFT := Color(0.2, 0.43, 0.2)
const NUSS := Color(0.71, 0.46, 0.2)
const LINIE := Color(0.36, 0.5, 0.66, 0.2)
# Alt (einige Stellen fragen noch danach)
const HINTERGRUND := Color(0.13, 0.085, 0.05, 0.86)
const RAND := Color(0.85, 0.62, 0.3)

const _TITEL := preload("res://fonts/LilitaOne.ttf")
const _HAND := preload("res://fonts/CaveatBrush.ttf")

static var _thema: Theme


static func schrift_titel() -> Font:
	return _TITEL


static func schrift_hand() -> Font:
	return _HAND


static func box(farbe := HINTERGRUND, rand := RAND, radius := 10, innen := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = farbe
	s.border_color = rand
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = innen
	s.content_margin_right = innen
	s.content_margin_top = innen * 0.7
	s.content_margin_bottom = innen * 0.7
	s.anti_aliasing = true
	return s


static func leer(innen := 0) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.set_content_margin_all(innen)
	return s


## Ein Stück Papier: fast eckig, kein Rahmen, weicher Schatten nach unten rechts.
static func papier(farbe := PAPIER, innen := 18, schatten := 9) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = farbe
	s.set_corner_radius_all(2)
	s.content_margin_left = innen
	s.content_margin_right = innen
	s.content_margin_top = innen * 0.75
	s.content_margin_bottom = innen * 0.85
	s.shadow_color = Color(0.05, 0.03, 0.0, 0.38)
	s.shadow_size = schatten
	s.shadow_offset = Vector2(2, 4)
	s.anti_aliasing = true
	return s


static func _stempel(fuellung: Color, rand: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fuellung
	s.border_color = rand
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 5
	s.anti_aliasing = true
	return s


static func thema() -> Theme:
	if _thema:
		return _thema
	var t := Theme.new()
	t.default_font = Look.schrift(500)
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", leer())
	t.set_stylebox("panel", "Panel", leer())
	# Knöpfe: wie mit Tinte umrandet, beim Überfahren ausgefüllt
	t.set_stylebox("normal", "Button", _stempel(Color(0, 0, 0, 0), TINTE))
	t.set_stylebox("hover", "Button", _stempel(TINTE, TINTE))
	t.set_stylebox("pressed", "Button", _stempel(ROTSTIFT, ROTSTIFT))
	t.set_stylebox("disabled", "Button", _stempel(Color(0, 0, 0, 0), Color(TINTE_LEISE, 0.35)))
	t.set_stylebox("focus", "Button", _stempel(Color(0, 0, 0, 0), ROTSTIFT))
	t.set_color("font_color", "Button", TINTE)
	t.set_color("font_disabled_color", "Button", Color(TINTE_LEISE, 0.6))
	t.set_color("font_hover_color", "Button", PAPIER)
	t.set_color("font_pressed_color", "Button", PAPIER)
	t.set_color("font_focus_color", "Button", TINTE)
	t.set_font("font", "Button", Look.schrift(600))
	# Reiter: Trennblätter im Karteikasten
	var blatt := papier(PAPIER, 12, 0)
	blatt.corner_radius_bottom_left = 0
	blatt.corner_radius_bottom_right = 0
	blatt.set_corner_radius(CORNER_TOP_LEFT, 6)
	blatt.set_corner_radius(CORNER_TOP_RIGHT, 6)
	var hinten: StyleBoxFlat = blatt.duplicate()
	hinten.bg_color = PAPIER_ALT
	var mitte: StyleBoxFlat = blatt.duplicate()
	mitte.bg_color = PAPIER.lerp(PAPIER_ALT, 0.45)
	t.set_stylebox("panel", "TabContainer", leer(4))
	t.set_stylebox("tab_selected", "TabContainer", blatt)
	t.set_stylebox("tab_unselected", "TabContainer", hinten)
	t.set_stylebox("tab_hovered", "TabContainer", mitte)
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", TINTE)
	t.set_color("font_unselected_color", "TabContainer", TINTE_LEISE)
	t.set_color("font_hovered_color", "TabContainer", TINTE)
	t.set_font("font", "TabContainer", Look.schrift(600))
	t.set_color("font_color", "CheckBox", TINTE)
	# Balken: schmal, eckig
	var grund := StyleBoxFlat.new()
	grund.bg_color = Color(0.1, 0.06, 0.03, 0.3)
	grund.set_corner_radius_all(2)
	var fuell := StyleBoxFlat.new()
	fuell.bg_color = NUSS
	fuell.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", grund)
	t.set_stylebox("fill", "ProgressBar", fuell)
	# Rollbalken: dünner Bleistiftstrich
	var griff := StyleBoxFlat.new()
	griff.bg_color = Color(TINTE, 0.45)
	griff.set_corner_radius_all(3)
	griff.content_margin_left = 3
	griff.content_margin_right = 3
	for art in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", art, leer(3))
		t.set_stylebox("grabber", art, griff)
		t.set_stylebox("grabber_highlight", art, griff)
		t.set_stylebox("grabber_pressed", art, griff)
	_thema = t
	return t


## Schrift über der Spielwelt: hell mit dunklem Rand.
static func label(text: String, groesse := 20, farbe := TEXT, umbruch := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.add_theme_color_override("font_outline_color", Color(0.09, 0.055, 0.03, 0.9))
	l.add_theme_constant_override("outline_size", 6 if groesse >= 24 else 5)
	if umbruch:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Überschrift oder Zahl in Lilita One (über der Welt).
static func titel(text: String, groesse := 34, farbe := TEXT) -> Label:
	var l := label(text, groesse, farbe)
	l.add_theme_font_override("font", _TITEL)
	l.add_theme_constant_override("outline_size", int(max(6.0, groesse * 0.2)))
	return l


## Schrift auf Papier: Tinte, kein Rand.
static func tinte(text: String, groesse := 20, farbe := TINTE, umbruch := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	if umbruch:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Opas Handschrift (auf Papier).
static func hand(text: String, groesse := 26, farbe := TINTE_LEISE, umbruch := false) -> Label:
	var l := tinte(text, groesse, farbe, umbruch)
	l.add_theme_font_override("font", _HAND)
	return l


## Färbt eine helle Welt-Schrift für Papier um: dunkel, ohne Rand. Farbige Schrift bleibt farbig.
static func auf_papier(l: Label) -> void:
	if l.has_meta("tinte") or not l.has_theme_color_override("font_outline_color"):
		return
	l.set_meta("tinte", true)
	var c := l.get_theme_color("font_color")
	if c.s < 0.3:
		c = TINTE if c.v > 0.92 else TINTE_LEISE
	elif c.get_luminance() > 0.4:
		c = Color.from_hsv(c.h, clampf(c.s * 1.25 + 0.15, 0.0, 1.0), 0.5 if c.h > 0.2 and c.h < 0.45 else 0.62)
		if c.h > 0.09 and c.h < 0.17:
			c = Color(0.6, 0.36, 0.06)    # Gold wird zu Ocker
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 0)


static func knopf(text: String, rueckruf: Callable, groesse := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", groesse)
	b.pressed.connect(rueckruf)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## Ein Blatt aus der Kladde, mittig. Gibt den Inhalt-Container zurück.
static func fenster(eltern: Control, titel_text: String, breite: float, hoehe: float, schliessen: Callable) -> VBoxContainer:
	var dunkel := ColorRect.new()
	dunkel.color = Color(0.06, 0.035, 0.02, 0.55)
	dunkel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dunkel.mouse_filter = Control.MOUSE_FILTER_STOP
	eltern.add_child(dunkel)
	var blatt := Blatt.new()
	blatt.custom_minimum_size = Vector2(breite, hoehe)
	blatt.anchor_left = 0.5
	blatt.anchor_right = 0.5
	blatt.anchor_top = 0.5
	blatt.anchor_bottom = 0.5
	blatt.offset_left = -breite * 0.5
	blatt.offset_right = breite * 0.5
	blatt.offset_top = -hoehe * 0.5
	blatt.offset_bottom = hoehe * 0.5
	blatt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	blatt.grow_vertical = Control.GROW_DIRECTION_BOTH
	eltern.add_child(blatt)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	blatt.add_child(v)
	var kopf := HBoxContainer.new()
	v.add_child(kopf)
	var t := tinte(titel_text, 38)
	t.add_theme_font_override("font", _TITEL)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(t)
	if schliessen.is_valid():
		var zu := knopf("zu  [Esc]", schliessen, 17)
		zu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kopf.add_child(zu)
	return v


## Eine Taste als kleines Kästchen, z. B. [E] oder [Linksklick]. Umbelegte Tasten zeigen ihre neue Taste.
static func taste(text: String, groesse := 18) -> PanelContainer:
	var p := PanelContainer.new()
	var b := StyleBoxFlat.new()
	b.bg_color = PAPIER
	b.border_color = TINTE
	b.border_width_bottom = 3
	b.set_corner_radius_all(3)
	b.content_margin_left = 8
	b.content_margin_right = 8
	b.content_margin_top = 0
	b.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", b)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = Game.tastenname_fuer(text)
	l.add_theme_font_override("font", Look.schrift(600))
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", TINTE)
	p.add_child(l)
	return p


## Zeile im Einstellungsblatt: Name links, Bedienteil rechts, darunter klein eine Erklärung.
static func zeile(name_text: String, bedienteil: Control, hinweis := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var l := tinte(name_text, 20)
	l.add_theme_font_override("font", Look.schrift(600))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	bedienteil.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bedienteil)
	if hinweis != "":
		v.add_child(hand(hinweis, 21))
	return v


# =============================================================================
# Bauteile
# =============================================================================
## Liniertes Blatt mit roter Randlinie, auf Wunsch mit Klebestreifen oben.
class Blatt extends PanelContainer:
	var liniert := true
	var klebestreifen := false
	var farbe := Stil.PAPIER
	var innen := 30

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		var s := Stil.papier(farbe, innen, 14)
		if liniert:
			s.content_margin_left = innen + 34
		add_theme_stylebox_override("panel", s)
		set_meta("papier", true)

	func _draw() -> void:
		if liniert:
			var y := 74.0
			while y < size.y - 14.0:
				draw_line(Vector2(6, y), Vector2(size.x - 6, y), Stil.LINIE, 1.0)
				y += 31.0
			draw_line(Vector2(46, 4), Vector2(46, size.y - 4), Color(Stil.ROTSTIFT, 0.28), 1.5)
			for i in 3:
				var hy := size.y * (0.18 + 0.32 * i)
				draw_circle(Vector2(22, hy), 7.0, Color(0.1, 0.06, 0.03, 0.55))
				draw_arc(Vector2(22, hy), 7.0, 0.3, 2.6, 10, Color(0, 0, 0, 0.35), 2.0, true)
		if klebestreifen:
			draw_set_transform(Vector2(size.x * 0.5, 2), -0.04)
			draw_rect(Rect2(-46, -13, 92, 26), Color(0.96, 0.9, 0.62, 0.62))
			draw_set_transform(Vector2.ZERO, 0.0)


## Menüeintrag über der Spielwelt: große Schrift, beim Anwählen rückt er ein und bekommt eine Nuss davor.
class Eintrag extends Control:
	signal gewaehlt
	var text := ""
	var unter := ""
	var groesse := 44
	var aktiv := false
	var gesperrt := false
	var _x := 0.0

	func _init(t := "", u := "", g := 44) -> void:
		text = t
		unter = u
		groesse = g
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): grab_focus())
		focus_entered.connect(func():
			aktiv = true
			Sfx.spiele("greifen", -16.0, 1.3))
		focus_exited.connect(func(): aktiv = false)

	func _ready() -> void:
		custom_minimum_size = Vector2(560, groesse * 1.22 + (22.0 if unter != "" else 0.0))

	func _process(delta: float) -> void:
		var ziel := 34.0 if aktiv and not gesperrt else 0.0
		if not is_equal_approx(_x, ziel):
			_x = lerpf(_x, ziel, 1.0 - exp(-delta * 18.0))
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if gesperrt:
			return
		var klick: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if klick or event.is_action_pressed("ui_accept"):
			accept_event()
			Sfx.spiele("ablegen", -8.0, 1.2)
			gewaehlt.emit()

	func _draw() -> void:
		var f := Stil.schrift_titel()
		var farbe := Stil.TEXT
		if gesperrt:
			farbe = Color(Stil.LEISE, 0.45)
		elif aktiv:
			farbe = Color(1.0, 0.84, 0.42)
		var p := Vector2(_x, groesse * 0.95)
		draw_string_outline(f, p + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, int(groesse * 0.26), Color(0.09, 0.05, 0.02, 0.5))
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, int(groesse * 0.2), Color(0.12, 0.07, 0.03))
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse, farbe)
		if _x > 2.0:
			Stil.nuss_zeichnen(self, Vector2(_x - 24.0, groesse * 0.62), groesse * 0.2 * (_x / 34.0))
		if unter != "":
			var h := Stil.schrift_hand()
			draw_string_outline(h, p + Vector2(4, 24), unter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0.1, 0.06, 0.03, 0.85))
			draw_string(h, p + Vector2(4, 24), unter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Stil.LEISE)


## Eine kleine Haselnuss, als Marke und als Reglerknopf.
static func nuss_zeichnen(c: CanvasItem, p: Vector2, r: float) -> void:
	c.draw_circle(p + Vector2(1, 2), r, Color(0, 0, 0, 0.3))
	c.draw_circle(p, r, Color(0.62, 0.38, 0.16))
	c.draw_circle(p + Vector2(-r * 0.2, -r * 0.15), r * 0.72, Color(0.75, 0.5, 0.24))
	c.draw_arc(p, r, PI * 1.1, PI * 1.9, 10, Color(0.36, 0.22, 0.1), max(2.0, r * 0.45), true)
	c.draw_circle(p + Vector2(-r * 0.35, -r * 0.1), r * 0.18, Color(1, 0.9, 0.7, 0.55))


## Schieberegler: Bleistiftstrich, eine Nuss als Knopf, der Wert daneben in Handschrift.
class Regler extends Control:
	signal geaendert(wert: float)
	var von := 0.0
	var bis := 1.0
	var schritt := 0.05
	var wert := 0.5
	var anzeige := Callable()
	var _zieht := false

	func _init(v := 0.0, b := 1.0, s := 0.05, w := 0.5, text := Callable()) -> void:
		von = v
		bis = b
		schritt = s
		wert = w
		anzeige = text
		custom_minimum_size = Vector2(330, 34)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _setze(w: float) -> void:
		w = clampf(snappedf(w, schritt), von, bis)
		if not is_equal_approx(w, wert):
			wert = w
			queue_redraw()
			geaendert.emit(wert)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_zieht = event.pressed
			if _zieht:
				grab_focus()
				_setze(lerpf(von, bis, clampf((event.position.x - 10.0) / 220.0, 0.0, 1.0)))
		elif event is InputEventMouseMotion and _zieht:
			_setze(lerpf(von, bis, clampf((event.position.x - 10.0) / 220.0, 0.0, 1.0)))
		elif event.is_action_pressed("ui_left", true):
			accept_event()
			_setze(wert - schritt)
		elif event.is_action_pressed("ui_right", true):
			accept_event()
			_setze(wert + schritt)

	func _draw() -> void:
		var y := size.y * 0.5
		var t := inverse_lerp(von, bis, wert)
		var punkte := PackedVector2Array()
		for i in 23:
			punkte.append(Vector2(10.0 + i * 10.0, y + sin(i * 1.7) * 0.9))
		draw_polyline(punkte, Color(Stil.TINTE, 0.75), 2.0, true)
		draw_line(Vector2(10, y - 6), Vector2(10, y + 6), Stil.TINTE, 2.0)
		draw_line(Vector2(230, y - 6), Vector2(230, y + 6), Stil.TINTE, 2.0)
		draw_line(Vector2(10, y), Vector2(10.0 + 220.0 * t, y), Stil.ROTSTIFT if has_focus() else Stil.TINTE, 3.5, true)
		Stil.nuss_zeichnen(self, Vector2(10.0 + 220.0 * t, y), 11.0)
		var text := "%d %%" % int(round(t * 100.0))
		if anzeige.is_valid():
			text = str(anzeige.call(wert))
		draw_string(Stil.schrift_hand(), Vector2(246, y + 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Stil.TINTE)


## Ankreuzkästchen, von Hand gezogen, mit rotem Haken.
class Haken extends Control:
	signal geaendert(an: bool)
	var an := false

	func _init(start := false) -> void:
		an = start
		custom_minimum_size = Vector2(330, 34)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		var klick: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if klick or event.is_action_pressed("ui_accept"):
			accept_event()
			an = not an
			Sfx.spiele("ablegen", -12.0, 1.5 if an else 1.1)
			queue_redraw()
			geaendert.emit(an)

	func _draw() -> void:
		var o := Vector2(10, size.y * 0.5 - 12)
		var kasten := PackedVector2Array([o + Vector2(1, 0), o + Vector2(24, 1), o + Vector2(23, 24), o + Vector2(0, 23), o + Vector2(1, 0)])
		draw_polyline(kasten, Stil.ROTSTIFT if has_focus() else Stil.TINTE, 2.5, true)
		if an:
			draw_polyline(PackedVector2Array([o + Vector2(4, 12), o + Vector2(10, 20), o + Vector2(30, -6)]), Stil.ROTSTIFT, 4.5, true)
		draw_string(Stil.schrift_hand(), o + Vector2(42, 21), "ja" if an else "nein", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Stil.TINTE if an else Stil.TINTE_LEISE)


## Auswahl aus wenigen Möglichkeiten: ‹ Wert ›
class Wahl extends Control:
	signal geaendert(index: int)
	var werte: Array = []
	var index := 0

	func _init(liste: Array = [], start := 0) -> void:
		werte = liste
		index = clampi(start, 0, max(0, liste.size() - 1))
		custom_minimum_size = Vector2(330, 34)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _weiter(d: int) -> void:
		index = posmod(index + d, werte.size())
		Sfx.spiele("ablegen", -12.0, 1.3)
		queue_redraw()
		geaendert.emit(index)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			grab_focus()
			_weiter(-1 if event.position.x < 60.0 else 1)
		elif event.is_action_pressed("ui_left"):
			accept_event()
			_weiter(-1)
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
			accept_event()
			_weiter(1)

	func _draw() -> void:
		var y := size.y * 0.5
		var farbe := Stil.ROTSTIFT if has_focus() else Stil.TINTE
		draw_polyline(PackedVector2Array([Vector2(24, y - 9), Vector2(13, y), Vector2(24, y + 9)]), farbe, 3.0, true)
		draw_polyline(PackedVector2Array([Vector2(306, y - 9), Vector2(317, y), Vector2(306, y + 9)]), farbe, 3.0, true)
		draw_string(Look.schrift(600), Vector2(30, y + 7), str(werte[index]), HORIZONTAL_ALIGNMENT_CENTER, 270, 20, Stil.TINTE)
