extends Node
## Automatischer Durchlauf durch die wichtigsten Abläufe.
## Start:  godot --headless --path . -- --selbsttest
## Benutzt einen eigenen Spielstand, damit der echte nicht überschrieben wird.

var welt: Node
var fehler: Array = []


func pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("  ok   ", text)
	else:
		print("  FEHL ", text)
		fehler.append(text)


func warte(sekunden: float) -> void:
	await get_tree().create_timer(sekunden).timeout


func _ready() -> void:
	welt = get_parent()
	await warte(0.5)
	print("== Selbsttest Deez Nuts! ==")
	if welt.menues.ist_offen():
		welt.menues.schliessen()
	Game.erster_start = false
	welt.spieler.gesperrt = false
	await _knacken()
	await _verkaufen()
	await _laden_und_maschinen()
	await _werkstatt()
	await _eichhoernchen()
	_talente()
	_bestellungen()
	await _wischen_und_ofen()
	await _menues()
	await _spieler()
	_speichern()
	print("== %d Fehler ==" % fehler.size())
	for f in fehler:
		print("   - ", f)
	get_tree().quit(1 if fehler.size() > 0 else 0)


func _knacken() -> void:
	print("-- Knacken")
	welt._hebel_ziehen(null)
	await warte(1.2)
	var n: int = welt._nuesse_in_schale()
	pruefe(n > 0, "Hebel holt Nüsse in die Schale (%d)" % n)
	pruefe(Game.genommen > 0, "Berg wird kleiner")
	var st: Knackstation = welt.station
	# Haselnuss mit bloßen Händen: direkt perfekt
	st.lade({"art": "nuss", "nuss": "hasel"})
	pruefe(st.geladen, "Nuss liegt im Knacker")
	var vorher: int = Game.statistik.perfekt
	st.druecken_start()
	st.druck = (st.zonen.s0 + st.zonen.s1) * 0.5
	st.druecken_ende()
	pruefe(Game.statistik.perfekt == vorher + 1, "Perfekter Knack wird gezählt")
	pruefe(Game.combo == 1, "Combo steigt")
	# Walnuss mit Händen: zu schwach, erst Riss
	st.lade({"art": "nuss", "nuss": "wal"})
	pruefe(st.zonen.kappe < Knackstation.DRUCK_MAX, "Hände sind zu schwach für Walnuss")
	st.druecken_start()
	st.druck = (st.zonen.a + st.zonen.s0) * 0.5
	st.druecken_ende()
	pruefe(st.nuss_daten.get("angeknackst", false), "Riss macht die Nuss angeknackst")
	pruefe(st.zonen.kappe >= Knackstation.DRUCK_MAX, "Angeknackste Walnuss schaffen die Hände")
	st.druecken_start()
	st.druck = (st.zonen.s0 + st.zonen.s1) * 0.5
	st.druecken_ende()
	pruefe(Game.statistik.perfekt == vorher + 2, "Angeknackste Walnuss perfekt geknackt")
	# Bruch und Matsch
	st.lade({"art": "nuss", "nuss": "hasel"})
	st.druecken_start()
	st.druck = (st.zonen.s1 + st.zonen.m) * 0.5
	st.druecken_ende()
	pruefe(Game.combo == 0, "Bruch setzt die Combo zurück")
	st.lade({"art": "nuss", "nuss": "hasel", "faul": true})
	st.druecken_start()
	st.druck = 1.0
	st.druecken_ende()
	pruefe(not st.geladen, "Faule Nuss wird geöffnet")
	st.lade({"art": "nuss", "nuss": "hasel"})
	st.druecken_start()
	await warte(2.0)
	pruefe(not st.geladen and not st.drueckt, "Zu langes Drücken endet von selbst in Matsch")
	await warte(1.0)


func _verkaufen() -> void:
	print("-- Sortieren und Verkaufen")
	var glas: Behaelter = welt.glas
	var anzahl := 0
	for t in get_tree().get_nodes_in_group("items"):
		if is_instance_valid(t) and t.art == "haelfte":
			if glas.nimmt_auf(t.daten()):
				anzahl += 1
			t.queue_free()
	pruefe(anzahl >= 4, "Kernhälften ins Glas (%d)" % anzahl)
	pruefe(glas.verkaufswert() > 0.0, "Glas hat einen Wert")
	var vorher := Game.muenzen
	welt._verkaufe(glas, true)
	pruefe(Game.muenzen > vorher, "Verkauf bringt Münzen (%.1f)" % (Game.muenzen - vorher))
	pruefe(glas.belegt() == 0, "Glas ist danach leer")
	await warte(0.2)


func _laden_und_maschinen() -> void:
	print("-- Laden")
	Game.verdiene(500000, false)
	pruefe(Game.kaufe_werkzeug("holz"), "Holz-Nussknacker kaufen")
	pruefe(Game.werkzeug_aktiv == "holz", "Neues Werkzeug ist aktiv")
	pruefe(Game.kaufe_werkzeug("metall"), "Metall-Hebelknacker kaufen")
	pruefe(Game.werte_werkzeug_auf("metall"), "Werkzeug verbessern")
	pruefe(not Game.kaufe_werkzeug("hammer"), "Hammer erst ab Ära 2")
	pruefe(Game.kaufe_maschine("rutsche"), "Nussrutsche kaufen")
	pruefe(Game.kaufe_maschine("deckel"), "Glasdeckel kaufen")
	pruefe(Game.kaufe_maschine("mimi"), "Katze kaufen")
	pruefe(not Game.kaufe_maschine("walze"), "Walzenknacker erst ab Ära 2")
	await warte(3.0)
	pruefe(welt.station.geladen, "Rutsche legt eine Nuss in den Knacker")


func _werkstatt() -> void:
	print("-- Werkstatt")
	Game.nuesse_vom_berg(1000)
	await warte(0.2)
	pruefe(Game.aera == 2, "Ära 2 nach 1.000 Nüssen")
	pruefe(welt._werkstatt_tuer == null, "Werkstatttür ist offen")
	for id in ["ofen", "sieb", "walze", "band"]:
		pruefe(Game.kaufe_maschine(id), "%s kaufen" % id)
	pruefe(Game.kaufe_werkzeug("hammer"), "Hammer kaufen")
	pruefe(Game.kaufe_werkzeug("schraubstock"), "Schraubstock kaufen")
	Game.energie = 200.0
	var vorher := Game.geknackt
	var muenzen_vorher := Game.muenzen
	await warte(8.0)
	pruefe(Game.geknackt > vorher, "Walzenknacker knackt allein (%d)" % (Game.geknackt - vorher))
	pruefe(Game.energie < 200.0, "Walzenknacker verbraucht Energie")
	pruefe(Game.muenzen > muenzen_vorher or welt.kiste.belegt() > 0, "Förderband oder Kiste bekommt Kerne")
	# Sieb sortiert nach einem Handknack
	var st: Knackstation = welt.station
	if st.geladen:
		st.entnehme()
	st.lade({"art": "nuss", "nuss": "wal"})
	var glas_vorher: int = welt.glas.haelften
	st.druecken_start()
	st.druck = (st.zonen.s0 + st.zonen.s1) * 0.5
	st.druecken_ende()
	await warte(1.5)
	pruefe(welt.glas.haelften > glas_vorher, "Tisch-Sieb bringt Hälften ins Glas")


func _eichhoernchen() -> void:
	print("-- Eichhörnchen")
	welt.glas.fuelle("haelfte", 10, 4.0)
	welt._eichhoernchen_schicken(1)
	var e = get_tree().get_nodes_in_group("eichhoernchen")
	pruefe(e.size() > 0, "Eichhörnchen kommt")
	await warte(6.0)
	pruefe(Game.statistik.verscheucht > 0 or Game.statistik.gestohlen > 0, "Eichhörnchen klaut oder wird verscheucht")
	welt._eichhoernchen_schicken(1)
	await warte(0.3)
	for x in get_tree().get_nodes_in_group("eichhoernchen"):
		x.verscheuchen()
	pruefe(true, "Verscheuchen ohne Absturz")
	welt._raubzug(3)
	await warte(2.5)
	pruefe(get_tree().get_nodes_in_group("eichhoernchen").size() > 0, "Raubzug schickt mehrere")


func _talente() -> void:
	print("-- Talente")
	Game.mp = 300
	pruefe(Game.lerne_talent("ruhige_hand"), "Ruhige Hand lernen")
	pruefe(not Game.lerne_talent("goldhand"), "Goldhändchen gesperrt ohne Vorstufe")
	pruefe(Game.lerne_talent("waldkenner"), "Waldkenner lernen")
	pruefe(Game.lerne_talent("katzenfreund"), "Katzenfreund lernen")
	pruefe(Game.talent_status("nussfluesterer") == "ausgeschlossen", "Zähmen ist nach Abwehr ausgeschlossen")
	pruefe(Game.lerne_talent("feilschen"), "Feilschen lernen")
	pruefe(Game.preis_faktor() > 1.0, "Feilschen erhöht Preise")


func _bestellungen() -> void:
	print("-- Bestellungen")
	pruefe(Game.bestellungen.size() >= 3, "Drei Bestellungen offen")
	var b: Dictionary = Game.bestellungen[0]
	b.nuss = "wal"
	b.menge = 2
	b.stand = 0
	var mp_vorher := Game.mp
	Game.melde_knack("wal", "perfekt", true, 2)
	pruefe(Game.mp == mp_vorher + 1, "Erfüllte Bestellung gibt einen Meisterpunkt")


func _wischen_und_ofen() -> void:
	print("-- Wischen und Ofen")
	var eimer: Behaelter = welt.eimer
	eimer.leeren()
	var p: Vector3 = welt.station.global_position + Vector3(0, 0.05, 0.1)
	for i in 5:
		welt.item_spawnen({"art": "schale", "nuss": "wal"}, p + Vector3(randf_range(-0.1, 0.1), 0.02, 0), Vector3.ZERO)
	await warte(0.5)
	welt.wischen(p)
	await warte(1.2)
	pruefe(eimer.schalen >= 5, "Wischen bringt Schalen in den Eimer (%d)" % eimer.schalen)
	var e_vorher := Game.energie
	welt._ofen_betreten(eimer)
	pruefe(Game.energie > e_vorher, "Ofen macht aus Schalen Energie")


func _menues() -> void:
	print("-- Menüs")
	var m: Menues = welt.menues
	m.zeige_laden(0)
	await warte(0.2)
	m.zeige_laden(1)
	await warte(0.2)
	m.zeige_laden(2)
	await warte(0.2)
	m.zeige_talente()
	await warte(0.2)
	m.zeige_pause()
	await warte(0.2)
	m.zeige_intro()
	await warte(0.2)
	m.zeige_ende()
	await warte(0.2)
	m.schliessen()
	pruefe(not m.ist_offen(), "Alle Menüs öffnen und schließen")


func _spieler() -> void:
	print("-- Spieler")
	var s: Spieler = welt.spieler
	var it: Item = welt.item_spawnen({"art": "nuss", "nuss": "mandel"}, s.halte_punkt(), Vector3.ZERO)
	await warte(0.1)
	s._greifen(it)
	await warte(0.5)
	pruefe(s.gehalten == it, "Spieler hält eine Nuss")
	pruefe(it.global_position.distance_to(s.halte_punkt()) < 0.3, "Nuss folgt der Hand")
	s._werfen()
	pruefe(s.gehalten == null, "Werfen leert die Hand")
	s._greifen(welt.glas)
	await warte(0.5)
	pruefe(s.gehalten == welt.glas, "Glas tragen")
	s._loslassen(Vector3.ZERO)
	await warte(0.3)
	welt.glas.heimkehren()
	await warte(0.3)
	# Zielen: vom Platz vor dem Tisch auf den Knacker schauen
	s.global_position = Vector3(0.15, 0.05, -1.45)
	s.rotation.y = 0.0
	s._blick_x = -0.62
	s.kamera.rotation.x = -0.62
	if not welt.station.geladen:
		welt.station.lade({"art": "nuss", "nuss": "hasel"})
	await warte(0.3)
	pruefe(s.blickt_auf_station() == welt.station, "Fadenkreuz trifft den Knacker vom Platz am Tisch")
	pruefe(s.hinweis.contains("zudrücken"), "Hinweis zeigt Zudrücken")
	s._druecken_an()
	await warte(0.2)
	pruefe(welt.station.drueckt, "Linksklick drückt zu")
	s._druecken_aus()
	pruefe(not welt.station.drueckt, "Loslassen knackt")
	# Eine Hälfte neben dem Knacker greifen
	await warte(0.8)
	var haelfte: Item = welt.item_spawnen({"art": "haelfte", "nuss": "wal", "wert": 4.0}, welt.station.global_position + Vector3(0.12, 0.05, 0.0), Vector3.ZERO)
	await warte(0.6)
	s.look_at(haelfte.global_position, Vector3.UP)
	s.rotation.x = 0
	s.rotation.z = 0
	var richtung := haelfte.global_position - s.kamera.global_position
	s._blick_x = atan2(richtung.y, Vector2(richtung.x, richtung.z).length())
	s.kamera.rotation.x = s._blick_x
	await warte(0.2)
	pruefe(s.ziel == haelfte, "Hälfte neben dem Knacker lässt sich anvisieren")


func _speichern() -> void:
	print("-- Speichern")
	Game.speichern()
	pruefe(FileAccess.file_exists(Game.SPEICHER_PFAD), "Spielstand geschrieben")
	var d = JSON.parse_string(FileAccess.get_file_as_string(Game.SPEICHER_PFAD))
	pruefe(typeof(d) == TYPE_DICTIONARY and d.has("behaelter"), "Spielstand lesbar")
