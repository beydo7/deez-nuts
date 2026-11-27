extends Node
## Macht Bildschirmfotos von typischen Spielsituationen (für Kontrolle und Steam-Seite).
## Start:  godot --path . -- --selbsttest --bilder=/pfad/zum/ordner

var welt: Node
var ziel := "user://bilder"


func _ready() -> void:
	welt = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bilder="):
			ziel = a.substr(9)
	DirAccess.make_dir_recursive_absolute(ziel)
	await _warte(1.0)
	if welt.menues.ist_offen():
		welt.menues.schliessen()
	Game.erster_start = false
	var s: Spieler = welt.spieler
	# 1: An der Knackbank, Walnuss mitten im Zudrücken
	welt.hebel_ziehen()
	welt.glas.fuelle("haelfte", 9, 4.0, "wal")
	welt.glas.fuelle("haelfte", 4, 1.0, "hasel")
	welt.bruchschale.fuelle("bruch", 4, 0.8, "wal")
	welt.eimer.fuelle("schale", 12, 0, "wal")
	_blick(s, Vector3(0.15, 0.05, -1.45), 0.0, -0.5)
	await _warte(0.8)
	s.hinsetzen(welt.station)
	await _warte(1.2)
	for i in 3:
		welt.item_spawnen({"art": "schale", "nuss": "wal"}, welt.station.global_position + Vector3(randf_range(-0.18, 0.18), 0.06, randf_range(0.0, 0.1)), Vector3.ZERO)
	if welt.station.geladen:
		welt.station.entnehme()
	welt.station.lade({"art": "nuss", "nuss": "wal", "angeknackst": true})
	welt.station.druecken_start()
	s.aktive_station = welt.station
	await _warte(0.5)
	welt.station.set_process(false)
	welt.station.druck = (welt.station.zonen.s0 + welt.station.zonen.s1) * 0.5
	welt.station._visual_aktualisieren(0.0)
	await _warte(0.3)
	await _foto("01_knackbank")
	welt.station.set_process(true)
	welt.station.druecken_ende()
	s.aktive_station = null
	await _warte(0.18)
	await _foto("02_knack")
	await _warte(1.0)
	await _foto("03_danach")
	# Werkzeug Holz an der Bank
	Game.verdiene(500000, false)
	Game.kaufe_werkzeug("holz")
	await _warte(0.6)
	if not welt.station.geladen:
		welt.station.lade({"art": "nuss", "nuss": "wal"})
	welt.station.druecken_start()
	await _warte(0.35)
	welt.station.set_process(false)
	await _warte(0.2)
	await _foto("04_hebelknacker")
	welt.station.set_process(true)
	welt.station.druecken_ende()
	s.aufstehen()
	await _warte(0.8)
	# Schale neben dem Knacker anvisieren: [E] nehmen, Linksklick hinsetzen
	var sch: Item = welt.item_spawnen({"art": "schale", "nuss": "wal"}, welt.station.global_position + Vector3(0.09, 0.04, 0.05), Vector3.ZERO)
	await _warte(0.6)
	_blick(s, Vector3(0.15, 0.05, -1.45), 0.0, -0.5)
	var kopf := s._kopf_transform().origin
	var r := sch.global_position - kopf
	s.rotation.y = atan2(-r.x, -r.z)
	s._blick_x = atan2(r.y, Vector2(r.x, r.z).length())
	await _warte(0.4)
	await _foto("04b_schale_nehmen")
	# Blick aus dem Fenster auf den Berg
	_blick(s, Vector3(0.55, 0.05, -1.7), 0.0, 0.08)
	await _warte(0.8)
	await _foto("05_berg")
	# Raum-Übersicht
	_blick(s, Vector3(2.3, 0.05, 2.3), deg_to_rad(40), -0.22)
	await _warte(0.8)
	await _foto("06_kueche")
	_blick(s, Vector3(-0.8, 0.05, 1.6), deg_to_rad(-120), -0.12)
	await _warte(0.8)
	await _foto("07_kueche_west")
	# Glas tragen
	_blick(s, Vector3(-1.9, 0.05, -1.2), deg_to_rad(90), -0.3)
	await _warte(0.2)
	welt.glas.global_position = s.halte_punkt()
	s._greifen(welt.glas)
	await _warte(0.9)
	await _foto("08_glas_tragen")
	s._loslassen(Vector3.ZERO)
	welt.glas.heimkehren()
	# Werkstatt mit Maschinen
	Game.nuesse_vom_berg(1000)
	for id in ["rutsche", "mimi", "ofen", "sieb", "walze", "band", "grosses_glas", "rohrpost", "deckel"]:
		Game.kaufe_maschine(id)
	Game.energie = 120
	welt.kiste.fuelle("haelfte", 30, 4.0)
	await _warte(1.5)
	_blick(s, Vector3(4.0, 0.05, 1.8), deg_to_rad(-55), -0.2)
	await _warte(1.5)
	await _foto("09_werkstatt")
	# Hammer und Schraubstock an der Bank
	Game.kaufe_werkzeug("hammer")
	Game.kaufe_werkzeug("schraubstock")
	_blick(s, Vector3(0.15, 0.05, -1.45), 0.0, -0.5)
	await _warte(0.3)
	for wz in ["hammer", "schraubstock"]:
		Game.waehle_werkzeug(wz)
		s.hinsetzen(welt.station)
		await _warte(0.8)
		if welt.station.geladen:
			welt.station.entnehme()
		welt.station.lade({"art": "nuss", "nuss": "mandel"})
		welt.station.druecken_start()
		await _warte(0.4 if wz == "hammer" else 0.9)
		welt.station.set_process(false)
		await _warte(0.2)
		await _foto("09b_" + wz)
		welt.station.set_process(true)
		welt.station.druecken_ende()
		await _warte(0.3)
		s.aufstehen()
		await _warte(0.5)
	# Eichhörnchen am Glas
	welt.glas.fuelle("haelfte", 8, 4.0)
	welt._eichhoernchen_schicken(1)
	_blick(s, Vector3(0.6, 0.05, -1.5), deg_to_rad(10), -0.5)
	await _warte(2.6)
	await _foto("10_eichhoernchen")
	# Menüs
	welt.menues.zeige_laden(1)
	await _warte(0.4)
	await _foto("11_katalog")
	Game.mp = 40
	welt.menues.zeige_talente()
	await _warte(0.4)
	await _foto("12_talente")
	welt.menues.zeige_intro()
	await _warte(0.4)
	await _foto("13_intro")
	get_tree().quit(0)


func _blick(s: Spieler, pos: Vector3, dreh_y: float, neigung: float) -> void:
	s.global_position = pos
	s.rotation.y = dreh_y
	s._blick_x = neigung


func _warte(sek: float) -> void:
	await get_tree().create_timer(sek, true, false, true).timeout


func _foto(name: String) -> void:
	await RenderingServer.frame_post_draw
	var bild := get_viewport().get_texture().get_image()
	bild.save_png("%s/%s.png" % [ziel, name])
	print("Bild: ", name)
