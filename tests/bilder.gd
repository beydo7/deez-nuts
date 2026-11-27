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
	var berg: Nussberg = welt.berg
	# Nur bestimmte Blicke: --blicke=name:x,z,zielx,ziely,zielz;name2:...
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--blicke="):
			print("BLICKE ", arg)
			for teil in arg.substr(9).split(";"):
				var nz := teil.split(":")
				var w := nz[1].split(",")
				var px := float(w[0])
				var pz := float(w[1])
				var hoch := float(w[5]) if w.size() > 5 else 0.0
				s.global_position = Vector3(px, welt.gelaende.hoehe_bei(px, pz) + 0.1 + hoch, pz)
				await _warte(0.4)
				_zielen(s, Vector3(float(w[2]), float(w[3]), float(w[4])))
				await _warte(1.0)
				await _foto(nz[0])
			get_tree().quit(0)
			return
	# 1: Vor der Hütte, Blick auf den Nussberg
	_blick(s, Vector3(1.0, 0.05, -6.2), 0.0, 0.05)
	await _warte(1.2)
	await _foto("01_hof_berg")
	# Das Tal: Orte aus dem Weltplan
	var g: Gelaende = welt.gelaende
	for blick in [
			["01b_hoftor", Vector2(2.6, 26.0), Vector3(1.0, 6.0, -32.0)],
			["01c_hochsitz", Vector2(43.0, -60.0), Vector3(-10.0, 2.0, -10.0)],
			["01d_wasserfall", Vector2(-43.0, -55.0), Vector3(-52.0, 2.6, -69.0)],
			["01e_omas_bruecke", Vector2(-20.0, 4.0), Vector3(-29.0, 0.6, 11.6)],
			["01f_bach_sued", Vector2(-12.0, 37.5), Vector3(-30.0, 0.0, 10.0)],
			["01g_waldrand", Vector2(-24.0, -64.0), Vector3(-50.0, 4.0, -80.0)]]:
		var p: Vector2 = blick[1]
		s.global_position = Vector3(p.x, g.hoehe_bei(p.x, p.y) + 0.1, p.y)
		await _warte(0.4)
		_zielen(s, blick[2])
		await _warte(1.0)
		await _foto(blick[0])
	# 2: Am Berg mit dem Kochlöffel sammeln
	Game.sammler["loeffel"] = 0
	Game.waehle_sammler("loeffel")
	s.global_position = Vector3(1.0, berg.hoehe_bei(1.0, -11.0) + 0.8, -11.0)
	await _warte(0.6)
	_zielen(s, Vector3(1.0, berg.hoehe_bei(1.0, -12.6), -12.6))
	s.set_meta("test_sammeln", true)
	await _warte(1.0)
	await _foto("02_sammeln_loeffel")
	# 3: Mit der Schaufel, Beutel voll -> Pfeil zur Abgabe
	Game.sammler["schaufel"] = 0
	Game.waehle_sammler("schaufel")
	await _warte(1.0)
	Game.beutel_hinzu("wal", 7)
	Game.beutel_hinzu("hasel", 5)
	await _warte(1.0)
	await _foto("03_beutel_voll")
	s.remove_meta("test_sammeln")
	# 4: Am Silo abliefern
	_blick(s, welt.ABGABE_POS + Vector3(0.6, 0.1, -3.2), deg_to_rad(170), 0.08)
	await _warte(0.8)
	await _foto("04_silo")
	_blick(s, welt.ABGABE_POS + Vector3(0, 0.1, 0), deg_to_rad(180), -0.05)
	await _warte(1.0)
	for i in 6:
		await get_tree().process_frame
	await _warte(0.6)
	for i in 3:
		await get_tree().process_frame
	await _foto("04b_abgeliefert")
	# 5: Laubsauger hoch oben am Berg
	Game.sammler["turbine"] = 0
	Game.waehle_sammler("turbine")
	Game.aera = 4
	Game.beutel_id = "schubkarre"
	Game.beutel_geaendert.emit()
	var oben := Vector3(-2.0, 0, -26.0)
	s.global_position = Vector3(oben.x, berg.hoehe_bei(oben.x, oben.z) + 0.8, oben.z)
	await _warte(0.6)
	_zielen(s, Vector3(-2.0, berg.hoehe_bei(-2.0, -30.0), -30.0))
	s.set_meta("test_sammeln", true)
	Game.beutel_hinzu("wal", 260)
	Game.beutel_hinzu("hasel", 140)
	await _warte(1.4)
	await _foto("05_turbine")
	s.remove_meta("test_sammeln")
	# 6: Helfer und Außenposten, Blick vom Berg zurück zur Hütte
	Game.verdiene(3000000, false)
	for i in 12:
		Game.kaufe_helfer()
	for id in ["posten_vorn", "posten_west", "posten_ost"]:
		Game.kaufe_posten(id)
	await _warte(6.0)
	var gipfel := Vector3(1.0, 0, -22.0)
	_blick(s, Vector3(gipfel.x, berg.hoehe_bei(gipfel.x, gipfel.z) + 0.5, gipfel.z), deg_to_rad(180), -0.32)
	await _warte(1.0)
	await _foto("06_helfer_posten")
	# 7: An der Knackbank, Walnuss mitten im Zudrücken
	Game.einlagern({"wal": 40, "hasel": 20})
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
	await _foto("07_knackbank")
	welt.station.set_process(true)
	welt.station.druecken_ende()
	s.aktive_station = null
	await _warte(0.18)
	await _foto("08_knack")
	s.aufstehen()
	await _warte(0.8)
	# 9: Küche und Werkstatt
	_blick(s, Vector3(2.3, 0.05, 2.3), deg_to_rad(40), -0.22)
	await _warte(0.8)
	await _foto("09_kueche")
	for id in ["rutsche", "mimi", "sieb", "walze", "deckel", "lagerhalle"]:
		Game.kaufe_maschine(id)
	await _warte(1.5)
	_blick(s, Vector3(4.0, 0.05, 1.8), deg_to_rad(-55), -0.2)
	await _warte(1.5)
	await _foto("10_werkstatt")
	# Menüs
	welt.menues.zeige_laden(0)
	await _warte(0.4)
	await _foto("11_laden_sammeln")
	welt.menues.zeige_laden(2)
	await _warte(0.4)
	await _foto("12_laden_helfer")
	welt.menues.zeige_talente()
	await _warte(0.5)
	await _foto("13_skillbaum")
	welt.menues.zeige_intro()
	await _warte(0.4)
	await _foto("14_intro")
	get_tree().quit(0)


func _zielen(s: Spieler, punkt: Vector3) -> void:
	var kopf := s._kopf_transform().origin
	var r := punkt - kopf
	s.rotation.y = atan2(-r.x, -r.z)
	s._blick_x = atan2(r.y, Vector2(r.x, r.z).length())


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
