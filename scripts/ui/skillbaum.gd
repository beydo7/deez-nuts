class_name Skillbaum
extends Control
## Opas Notizbuch: der Skillbaum. Sieben Pfade vom Mittelpunkt aus, Knoten kosten Münzen.
## Ziehen = verschieben, Mausrad = zoomen, Klick auf einen leuchtenden Knoten = kaufen.

signal gekauft(id: String)

var _versatz := Vector2.ZERO
var _zoom := 0.85
var _ziehen := false
var _gezogen := 0.0
var _ueber := ""
var _zeit := 0.0
var _pop: Dictionary = {}          # id -> Zeit seit Kauf
var _farben := {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for p in Data.SKILL_PFADE:
		_farben[p.id] = p.farbe


func _process(delta: float) -> void:
	_zeit += delta
	for id in _pop.keys():
		_pop[id] += delta
		if _pop[id] > 0.6:
			_pop.erase(id)
	queue_redraw()


func _bild(p: Vector2) -> Vector2:
	return size * 0.5 + _versatz + p * _zoom


func _knoten_bei(maus: Vector2) -> String:
	var alle := Data.skills()
	var best := ""
	var best_d := 9999.0
	for id in alle:
		var k: Dictionary = alle[id]
		var r := (22.0 if k.gross else 13.0) * _zoom + 4.0
		var d := _bild(k.pos).distance_to(maus)
		if d < r and d < best_d:
			best = id
			best_d = d
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoomen(1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoomen(1.0 / 1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_ziehen = true
				_gezogen = 0.0
			else:
				_ziehen = false
				if event.button_index == MOUSE_BUTTON_LEFT and _gezogen < 6.0:
					var id := _knoten_bei(event.position)
					if id != "" and Game.kaufe_skill(id):
						_pop[id] = 0.0
						gekauft.emit(id)
					elif id != "" and Game.skill_status(id) == "zu_teuer":
						Sfx.spiele("fehler")
		accept_event()
	elif event is InputEventMouseMotion:
		if _ziehen:
			_versatz += event.relative
			_gezogen += event.relative.length()
		_ueber = _knoten_bei(event.position)
		accept_event()


func _zoomen(f: float, um: Vector2) -> void:
	var alt := _zoom
	_zoom = clampf(_zoom * f, 0.35, 1.8)
	var mitte := size * 0.5 + _versatz
	_versatz += (um - mitte) * (1.0 - _zoom / alt)


func _draw() -> void:
	var alle := Data.skills()
	var schrift := Look.schrift(600)
	# Verbindungen
	for id in alle:
		var k: Dictionary = alle[id]
		if k.braucht == "":
			continue
		var p: Dictionary = alle[k.braucht]
		var besessen: bool = Game.skills.has(id)
		var farbe: Color = _farben.get(k.pfad, Color.WHITE)
		var c := farbe if besessen else Color(0.45, 0.38, 0.3, 0.6)
		draw_line(_bild(p.pos), _bild(k.pos), c, (5.0 if besessen else 3.0) * _zoom, true)
	# Pfadnamen
	for i in Data.SKILL_PFADE.size():
		var pf: Dictionary = Data.SKILL_PFADE[i]
		var winkel := TAU * float(i) / Data.SKILL_PFADE.size() - PI * 0.5
		var pos := _bild(Vector2(cos(winkel), sin(winkel)) * 78.0)
		var text: String = pf.name
		var b := schrift.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * max(_zoom, 0.7)))
		draw_string_outline(schrift, pos - Vector2(b.x * 0.5, -6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * max(_zoom, 0.7)), 6, Color(0.1, 0.06, 0.03))
		draw_string(schrift, pos - Vector2(b.x * 0.5, -6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * max(_zoom, 0.7)), pf.farbe)
	# Knoten
	for id in alle:
		var k: Dictionary = alle[id]
		var status := Game.skill_status(id)
		var farbe: Color = _farben.get(k.pfad, Color(1, 0.9, 0.6))
		var r := (22.0 if k.gross else 13.0) * _zoom
		var p := _bild(k.pos)
		if _pop.has(id):
			var t: float = _pop[id]
			draw_arc(p, r + t * 60.0 * _zoom, 0, TAU, 32, Color(farbe, 1.0 - t / 0.6), 4.0, true)
		match status:
			"besessen":
				draw_circle(p, r + 2.0, Color(0.1, 0.06, 0.03))
				draw_circle(p, r, farbe)
				draw_circle(p, r * 0.45, farbe.lightened(0.5))
			"frei":
				var puls := 0.5 + 0.5 * sin(_zeit * 5.0)
				draw_circle(p, r + 2.0, Color(0.1, 0.06, 0.03))
				draw_circle(p, r, Color(0.22, 0.16, 0.1))
				draw_arc(p, r + 3.0 + puls * 3.0, 0, TAU, 32, Color(farbe, 0.6 + puls * 0.4), 3.0, true)
			"zu_teuer":
				draw_circle(p, r, Color(0.2, 0.15, 0.1))
				draw_arc(p, r, 0, TAU, 32, Color(farbe, 0.45), 2.0, true)
			_:
				draw_circle(p, r, Color(0.14, 0.11, 0.08, 0.85))
				draw_arc(p, r, 0, TAU, 32, Color(0.4, 0.35, 0.3, 0.5), 1.5, true)
		if k.gross and status != "gesperrt":
			draw_string(schrift, p + Vector2(-110.0, r + 16 * _zoom), k.name, HORIZONTAL_ALIGNMENT_CENTER, 220.0, int(max(11.0, 13.0 * _zoom)), Color(1, 0.95, 0.85))
	# Tooltip
	if _ueber != "":
		_tooltip(alle[_ueber], _ueber)


func _tooltip(k: Dictionary, id: String) -> void:
	var schrift := Look.schrift(500)
	var status := Game.skill_status(id)
	var zeilen: Array = [k.name]
	if k.text != k.name:
		zeilen.append(k.text)
	match status:
		"besessen":
			zeilen.append("Gelernt")
		"frei":
			zeilen.append("Klick: %s Münzen" % Data.zahl(k.preis))
		"zu_teuer":
			zeilen.append("Kostet %s Münzen (fehlen %s)" % [Data.zahl(k.preis), Data.zahl(float(k.preis) - Game.muenzen)])
		_:
			zeilen.append("Erst den Knoten davor lernen · %s Münzen" % Data.zahl(k.preis))
	var breite := 0.0
	for z in zeilen:
		breite = max(breite, schrift.get_string_size(z, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)
	var pos := _bild(k.pos) + Vector2(24, -20)
	var box := Rect2(pos, Vector2(breite + 24, zeilen.size() * 24 + 14))
	if box.end.x > size.x:
		box.position.x -= box.size.x + 48
	if box.end.y > size.y:
		box.position.y = size.y - box.size.y
	draw_rect(box, Color(0.1, 0.07, 0.04, 0.95))
	draw_rect(box, _farben.get(k.pfad, Stil.GOLD), false, 2.0)
	for i in zeilen.size():
		var farbe := Stil.GOLD if i == 0 else (Stil.TEXT if i < zeilen.size() - 1 else Stil.LEISE)
		draw_string(schrift, box.position + Vector2(12, 26 + i * 24), zeilen[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, farbe)
