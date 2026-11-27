class_name Stil
extends RefCounted
## Gemeinsamer Look für alle Menüs: warmes Holzbraun, Creme, Nussgold.

const HINTERGRUND := Color(0.16, 0.1, 0.06, 0.92)
const RAND := Color(0.85, 0.62, 0.3)
const TEXT := Color(0.98, 0.93, 0.82)
const LEISE := Color(0.8, 0.72, 0.6)
const GOLD := Color(1.0, 0.8, 0.3)
const GRUEN := Color(0.55, 0.9, 0.45)
const ROT := Color(1.0, 0.5, 0.4)

static var _thema: Theme


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
	return s


static func thema() -> Theme:
	if _thema:
		return _thema
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("panel", "Panel", box())
	t.set_stylebox("normal", "Button", box(Color(0.38, 0.24, 0.12), Color(0.7, 0.5, 0.25), 8, 10))
	t.set_stylebox("hover", "Button", box(Color(0.5, 0.32, 0.15), GOLD, 8, 10))
	t.set_stylebox("pressed", "Button", box(Color(0.3, 0.18, 0.08), GOLD, 8, 10))
	t.set_stylebox("disabled", "Button", box(Color(0.22, 0.17, 0.13), Color(0.35, 0.3, 0.25), 8, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.45))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_stylebox("panel", "TabContainer", box(Color(0.2, 0.13, 0.08, 0.95)))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(0.45, 0.28, 0.13), GOLD, 6, 10))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.25, 0.16, 0.09), Color(0.45, 0.33, 0.2), 6, 10))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.35, 0.22, 0.11), GOLD, 6, 10))
	t.set_color("font_selected_color", "TabContainer", TEXT)
	t.set_color("font_unselected_color", "TabContainer", LEISE)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0.1, 0.07, 0.04, 0.9), Color(0.5, 0.36, 0.2), 6, 0))
	t.set_stylebox("fill", "ProgressBar", box(Color(0.78, 0.55, 0.25), Color(0.78, 0.55, 0.25), 6, 0))
	_thema = t
	return t


static func label(text: String, groesse := 20, farbe := TEXT, umbruch := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	if umbruch:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func knopf(text: String, rueckruf: Callable, groesse := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", groesse)
	b.pressed.connect(rueckruf)
	b.focus_mode = Control.FOCUS_NONE
	return b


## Ein zentriertes Fenster mit Titel und Schließen-Knopf. Gibt den Inhalt-Container zurück.
static func fenster(eltern: Control, titel: String, breite: float, hoehe: float, schliessen: Callable) -> VBoxContainer:
	var dunkel := ColorRect.new()
	dunkel.color = Color(0, 0, 0, 0.45)
	dunkel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dunkel.mouse_filter = Control.MOUSE_FILTER_STOP
	eltern.add_child(dunkel)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(breite, hoehe)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -breite * 0.5
	panel.offset_right = breite * 0.5
	panel.offset_top = -hoehe * 0.5
	panel.offset_bottom = hoehe * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	eltern.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var kopf := HBoxContainer.new()
	v.add_child(kopf)
	var t := label(titel, 30, GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(t)
	if schliessen.is_valid():
		kopf.add_child(knopf("Schließen  [Esc]", schliessen, 18))
	return v
