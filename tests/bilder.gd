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
		if arg.begins_with("--modell-export="):
			load("res://tools/blender/ersatz_export.gd").new().schreibe(welt, arg.substr(16))
			get_tree().quit(0)
			return
		if arg.begins_with("--aera="):
			for a in range(2, int(arg.substr(7)) + 1):
				welt.aeren._bauen(a, false)
		if arg.begins_with("--graben="):
			# --graben=x,z,radius,anzahl;... räumt Nüsse weg, damit Funde im Berg sichtbar werden
			for teil in arg.substr(9).split(";"):
				var gw := teil.split(",")
				var n := berg.abbauen(Vector3(float(gw[0]), 0, float(gw[1])), float(gw[2]), int(gw[3]))
				Game.nuesse_vom_berg(n)
			await _warte(6.0)
		if arg == "--menue":
			await _menue_bilder(s)
			get_tree().quit(0)
			return
		if arg == "--probe":
			await _trefferprobe_bilder(s)
			get_tree().quit(0)
			return
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
			["01g_waldrand", Vector2(-24.0, -64.0), Vector3(-50.0, 4.0, -80.0)],
			["01h_veranda", Vector2(2.0, 12.0), Vector3(2.0, 1.5, 4.0)],
			["01i_garten", Vector2(-4.0, 10.0), Vector3(-11.0, 0.8, 12.0)],
			["01j_feuerstelle", Vector2(-9.5, -13.5), Vector3(-12.6, 0.3, -12.0)],
			["01k_brunnen", Vector2(-6.5, 4.5), Vector3(-10.0, 1.0, 2.0)],
			["01l_stall_holzlager", Vector2(9.0, 13.0), Vector3(15.5, 0.8, 7.0)],
			["01m_traktor", Vector2(25.0, -42.5), Vector3(19.5, 1.0, -39.5)],
			["01n_werkstatt", Vector2(4.0, 0.5), Vector3(8.6, 0.9, 2.2)],
			["01o_siedlung", Vector2(-42.0, 16.0), Vector3(-53.0, 1.5, 22.0)],
			["01p_heuschober", Vector2(-48.0, 5.0), Vector3(-56.0, 1.5, 4.0)],
			["01q_picknick", Vector2(-36.0, 33.0), Vector3(-40.0, 0.7, 36.0)],
			["01r_angelplatz", Vector2(-27.0, -11.0), Vector3(-33.0, 0.2, -13.0)],
			["01s_vom_hochsitz", Vector2(43.6, -62.7), Vector3(1.0, 3.0, -32.0), 3.8]]:
		var p: Vector2 = blick[1]
		s.global_position = Vector3(p.x, g.hoehe_bei(p.x, p.y) + 0.1 + (float(blick[3]) if blick.size() > 3 else 0.0), p.y)
		await _warte(0.4)
		_zielen(s, blick[2])
		await _warte(1.0)
		await _foto(blick[0])
	# Tageszeiten und Geheimnisse
	for zeitblick in [
			["01t_abend_hochsitz", 18.6, Vector2(43.6, -62.7), Vector3(1.0, 3.0, -32.0), 3.8],
			["01u_nacht_huette", 23.0, Vector2(1.0, -9.5), Vector3(0.5, 1.6, -3.0), 0.0],
			["01v_nacht_bach", 23.0, Vector2(-12.0, 37.5), Vector3(-30.0, 0.0, 10.0), 0.0],
			["01w_morgen_bruecke", 6.8, Vector2(-20.0, 4.0), Vector3(-29.0, 0.6, 11.6), 0.0],
			["01x_mondlichtung", 13.0, Vector2(-7.0, -83.5), Vector3(-8.0, 0.6, -95.0), 0.0],
			["01y_koenigseiche", 13.0, Vector2(26.0, -66.0), Vector3(30.0, 4.0, -78.0), 0.0],
			["01z_huehner", 11.0, Vector2(13.0, 14.5), Vector3(15.5, 0.3, 11.5), 0.0]]:
		welt.himmel.setze_zeit(float(zeitblick[1]))
		var zp: Vector2 = zeitblick[2]
		s.global_position = Vector3(zp.x, g.hoehe_bei(zp.x, zp.y) + 0.1 + float(zeitblick[4]), zp.y)
		await _warte(0.4)
		_zielen(s, zeitblick[3])
		await _warte(1.2)
		await _foto(zeitblick[0])
	welt.himmel.setze_zeit(10.5)
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
	for a in [2, 3, 4]:
		welt.aeren._bauen(a, false)
	await _warte(6.0)
	var gipfel := Vector3(1.0, 0, -22.0)
	_blick(s, Vector3(gipfel.x, berg.hoehe_bei(gipfel.x, gipfel.z) + 0.5, gipfel.z), deg_to_rad(180), -0.32)
	await _warte(1.0)
	await _foto("06_helfer_posten")
	# Betrieb am Bergfuß und ein freigelegter Fund
	_blick(s, Vector3(-4.0, 0.05, -8.0), 0.0, 0.0)
	await _warte(0.3)
	_zielen(s, Vector3(-9.6, 3.5, -3.0))
	await _warte(0.8)
	await _foto("06b_hochsilo_zelte")
	Game.nuesse_vom_berg(berg.abbauen(Vector3(-6.0, 0, -23.5), 8.0, 150000))
	Game.nuesse_vom_berg(berg.abbauen(Vector3(-3.0, 0, -17.0), 7.0, 60000))
	await _warte(5.0)
	_blick(s, Vector3(-3.0, berg.hoehe_bei(-3.0, -13.5) + 0.3, -13.5), 0.0, 0.0)
	await _warte(0.4)
	_zielen(s, Vector3(-6.0, 1.2, -23.5))
	await _warte(1.0)
	await _foto("06c_opas_erste_huette")
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
	welt.station.pruefung_start(0.0)
	await _warte(0.5)
	welt.station.set_process(false)
	welt.station.druck = welt.station.zonen.s0 - 0.07
	welt.station._visual_aktualisieren(0.0)
	await _warte(0.3)
	await _foto("07_knackbank")
	welt.station.druck = (welt.station.zonen.s0 + welt.station.zonen.s1) * 0.5
	welt.station.set_process(true)
	welt.station.treffen()
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
	welt.menues.zeige_fundbuch()
	await _warte(0.5)
	await _foto("13b_fundbuch")
	welt.menues.zeige_intro()
	await _warte(0.4)
	await _foto("14_intro")
	get_tree().quit(0)


func _zielen(s: Spieler, punkt: Vector3) -> void:
	var kopf := s._kopf_transform().origin
	var r := punkt - kopf
	s.rotation.y = atan2(-r.x, -r.z)
	s._blick_x = atan2(r.y, Vector2(r.x, r.z).length())


## Titelbild, Gläser, Einstellungen, Pause, Laden und Anzeigen im Spiel: --menue
func _menue_bilder(s: Spieler) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.genommen = 183450
	Game.muenzen = 48210.0
	Game.spielzeit = 9360.0
	Game.erster_start = false
	var t := Titel.new(welt)
	welt.add_child(t)
	t._blende.visible = false      # die Blende läuft im langsamen Testbild zu lange
	await _frames(3)
	await _foto("m1_titel")
	# Ein Beispielglas, damit ein gefülltes zu sehen ist (wird gleich wieder entfernt)
	var probe := FileAccess.open("user://glas_2.json", FileAccess.WRITE)
	probe.store_string(JSON.stringify({"genommen": 412300, "muenzen": 1284000.0, "spielzeit": 20520.0, "aera": 3, "geknackt": 9200}))
	probe.close()
	t._glaeser()
	await _frames(3)
	await _foto("m2_glaeser")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://glas_2.json"))
	for i in 4:
		t._einstellungen()
		await _frames(3)
		Optionen.baue(t._seite.get_child(t._seite.get_child_count() - 1), t._haupt, i)
		await _frames(3)
		await _foto("m3_einstellungen_%d" % i)
	t._haupt()
	t._los()
	await _frames(9)
	_blick(s, Vector3(1.0, 0.05, -6.2), 0.0, 0.05)
	Game.toast.emit("Holzlöffel gekauft", Game.FARBE_GUT)
	await _frames(3)
	await _foto("m4_hud")
	welt._menue(welt.menues.zeige_pause)
	await _frames(3)
	await _foto("m5_pause")
	welt.menues.zeige_laden(0)
	await _frames(3)
	await _foto("m6_laden")
	welt.menues.zeige_talente()
	await _frames(3)
	await _foto("m7_skills")
	welt.menues.zeige_fundbuch()
	await _frames(3)
	await _foto("m8_fundbuch")
	welt.menues.schliessen()
	get_tree().paused = false
	print("Menübilder fertig")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Nur die Trefferprobe an der Knackbank: --probe
func _trefferprobe_bilder(s: Spieler) -> void:
	var st: Knackstation = welt.station
	Game.maschinen.erase("rutsche")
	_blick(s, Vector3(0.15, 0.05, -1.45), 0.0, -0.5)
	await _warte(0.8)
	s.hinsetzen(st)
	await _warte(1.0)
	# Im Sitzen legt der Spieler selbst nach und startet die Probe; für feste Bilder wird hier
	# die Station angehalten und der Zeiger von Hand gestellt.
	st.set_process(false)
	var stelle := func(nuss: Dictionary, phase: String, wo: float, vorlauf := 0.0):
		if st.geladen:
			st.abbrechen()
			st.entnehme()
		st.lade(nuss)
		st.pruefung_start(0.0)
		st.phase = phase
		st.drueckt = phase == "lauf"
		st._phase_zeit = vorlauf
		st.druck = wo
		st._visual_aktualisieren(0.0)
	stelle.call({"art": "nuss", "nuss": "hasel"}, "vorlauf", 0.0, Knackstation.VORLAUF * 0.55)
	await _warte(0.25)
	await _foto("p1_ring_ploppt_auf")
	stelle.call({"art": "nuss", "nuss": "hasel"}, "lauf", 0.0)
	st.druck = st.zonen.a * 0.6
	await _warte(0.25)
	await _foto("p2_zeiger_laeuft")
	Game.werkzeug_aktiv = "metall"
	Game.werkzeuge["metall"] = 0
	st._werkzeug_bauen()
	stelle.call({"art": "nuss", "nuss": "pekan"}, "lauf", 0.0)
	st.druck = st.zonen.s0 + 0.03
	st._visual_aktualisieren(0.0)
	await _warte(0.25)
	await _foto("p3_schmale_zone_pekan")
	Game.werkzeug_aktiv = "haende"
	st._werkzeug_bauen()
	stelle.call({"art": "nuss", "nuss": "wal"}, "lauf", 0.0)
	st.druck = st.zonen.a - 0.1
	await _warte(0.25)
	await _foto("p4_zu_schwach_gelb")
	stelle.call({"art": "nuss", "nuss": "hasel"}, "lauf", 0.0)
	st.druck = (st.zonen.s0 + st.zonen.s1) * 0.5
	st.set_process(true)
	st.treffen()
	await _warte(0.12)
	await _foto("p5_treffer")
	await _warte(1.2)
	st.set_process(false)
	stelle.call({"art": "nuss", "nuss": "hasel"}, "warten", 0.0)
	st.drueckt = false
	await _warte(0.25)
	await _foto("p6_wartet")


func _blick(s: Spieler, pos: Vector3, dreh_y: float, neigung: float) -> void:
	s.global_position = pos
	s.rotation.y = dreh_y
	s._blick_x = neigung


func _warte(sek: float) -> void:
	await get_tree().create_timer(sek, true, false, true).timeout


func _foto(name: String) -> void:
	await RenderingServer.frame_post_draw
	print("Messung %s: %d Draw Calls, %d Dreiecke, %d Objekte" % [name,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	var bild := get_viewport().get_texture().get_image()
	bild.save_png("%s/%s.png" % [ziel, name])
	print("Bild: ", name)
