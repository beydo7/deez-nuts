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
	# 1: Blick auf den Tisch, Nuss im Knacker, mitten im Zudrücken
	welt._hebel_ziehen(null)
	welt.glas.fuelle("haelfte", 14, 4.0)
	welt.glas.fuelle("bruch", 2, 0.8)
	welt.eimer.fuelle("schale", 12, 0)
	_blick(s, Vector3(0.15, 0.05, -1.45), 0.0, -0.62)
	await _warte(1.5)
	welt.station.lade({"art": "nuss", "nuss": "wal", "angeknackst": true})
	welt.station.druecken_start()
	s.aktive_station = welt.station
	await _warte(0.42)
	welt.station.set_process(false)
	await _warte(0.2)
	await _foto("01_knacken")
	welt.station.set_process(true)
	welt.station.druecken_ende()
	s.aktive_station = null
	await _warte(1.0)
	await _foto("02_nach_dem_knack")
	# 2: Blick aus dem Fenster auf den Berg
	_blick(s, Vector3(0.15, 0.05, -1.6), 0.0, 0.05)
	await _warte(0.6)
	await _foto("03_berg")
	# 3: Raum-Übersicht
	_blick(s, Vector3(2.3, 0.05, 2.3), deg_to_rad(40), -0.25)
	await _warte(0.6)
	await _foto("04_kueche")
	# 4: Werkstatt mit Maschinen
	Game.verdiene(500000, false)
	Game.nuesse_vom_berg(1000)
	for id in ["rutsche", "mimi", "ofen", "sieb", "walze", "band"]:
		Game.kaufe_maschine(id)
	Game.energie = 120
	welt.kiste.fuelle("haelfte", 30, 4.0)
	_blick(s, Vector3(4.0, 0.05, 1.8), deg_to_rad(-55), -0.2)
	await _warte(2.0)
	await _foto("05_werkstatt")
	# 5: Eichhörnchen am Glas
	welt.glas.fuelle("haelfte", 8, 4.0)
	welt._eichhoernchen_schicken(1)
	_blick(s, Vector3(0.6, 0.05, -1.5), deg_to_rad(10), -0.5)
	await _warte(2.6)
	await _foto("06_eichhoernchen")
	# 6: Menüs
	welt.menues.zeige_laden(0)
	await _warte(0.4)
	await _foto("07_katalog")
	Game.mp = 40
	welt.menues.zeige_talente()
	await _warte(0.4)
	await _foto("08_talente")
	welt.menues.zeige_intro()
	await _warte(0.4)
	await _foto("09_intro")
	get_tree().quit(0)


func _blick(s: Spieler, pos: Vector3, dreh_y: float, neigung: float) -> void:
	s.global_position = pos
	s.rotation.y = dreh_y
	s._blick_x = neigung
	s.kamera.rotation.x = neigung


func _warte(sek: float) -> void:
	await get_tree().create_timer(sek, true).timeout


func _foto(name: String) -> void:
	await RenderingServer.frame_post_draw
	var bild := get_viewport().get_texture().get_image()
	bild.save_png("%s/%s.png" % [ziel, name])
	print("Bild: ", name)
