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
	await _tal()
	await _anwesen()
	await _siedlung()
	await _leben()
	await _geheimnisse()
	await _aeren()
	await _berg_und_sammeln()
	await _abliefern()
	await _knacken()
	await _verkaufen()
	await _laden_und_maschinen()
	await _helfer_und_posten()
	await _werkstatt()
	await _eichhoernchen()
	_skills()
	_bestellungen()
	await _wischen()
	await _menues()
	await _spieler()
	_speichern()
	print("== %d Fehler ==" % fehler.size())
	for f in fehler:
		print("   - ", f)
	get_tree().quit(1 if fehler.size() > 0 else 0)


func _aeren() -> void:
	print("-- Ären")
	await warte(0.05)


func _tal() -> void:
	print("-- Tal, Bach, Wald")
	var g: Gelaende = welt.gelaende
	var raum: PhysicsDirectSpaceState3D = welt.get_world_3d().direct_space_state
	# Talsohle eben an Hütte, Berg, Silo und Posten
	for p in [Vector2(3, 0), Vector2(1, -32), Vector2(-1.15, -5.6), Vector2(6.5, -9), Vector2(-23, -22), Vector2(24.5, -24), Vector2(1, -57)]:
		pruefe(absf(g.hoehe_bei(p.x, p.y) - WeltPlan.SOHLE) < 0.05, "Boden eben bei %s" % p)
	pruefe(g.hoehe_bei(0, -125) > 8.0 and g.hoehe_bei(100, 0) > 8.0, "Hügel am Talrand")
	pruefe(g.hoehe_bei(44, -63) > 5.0, "Hügel mit dem Hochsitz")
	# Bachbett liegt unter dem Wasser, Wasserfall oben auf der Felsstufe
	var mitte: Vector3 = WeltPlan.BACH[6]
	pruefe(g.hoehe_bei(mitte.x, mitte.z) < mitte.y, "Bachbett unter der Wasserfläche")
	var kante: Vector3 = WeltPlan.BACH[WeltPlan.BACH_KANTE - 1]
	pruefe(g.hoehe_bei(kante.x, kante.z) > 2.5, "Bach oberhalb des Wasserfalls liegt hoch")
	pruefe(g.bach_abstand(mitte.x, mitte.z) < 1.0 and g.bach_abstand(3, 0) > 20.0, "Bachabstand stimmt")
	pruefe(g.weg_bei(2.0, 22.0) > 0.8, "Weg am Hoftor")
	# Kollision des Geländes
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 40, -120), Vector3(0, -10, -120), Data.L_WELT)
	var t: Dictionary = raum.intersect_ray(q)
	pruefe(not t.is_empty() and absf(t.position.y - g.hoehe_bei(0, -120)) < 0.3, "Gelände hat Kollision")
	# Brücken sind begehbar
	for br in ["bruecke_oma", "bruecke_hof"]:
		var o: Vector3 = WeltPlan.ORTE[br]
		var q2 := PhysicsRayQueryParameters3D.create(Vector3(o.x, 10, o.z), Vector3(o.x, -5, o.z), Data.L_WELT)
		var t2: Dictionary = raum.intersect_ray(q2)
		pruefe(not t2.is_empty() and t2.position.y > g.hoehe_bei(o.x, o.z) + 0.2, "%s hat eine begehbare Fläche" % br)
		pruefe(Modelle.plaetze.has(br), "Modellplatz %s angelegt" % br)
	# Wasser und Wald sind da
	pruefe(welt.find_child("Bach", true, false) != null and welt.find_child("Bach", true, false).get_child_count() > 4, "Bach mit Wasser, Becken, Wasserfall, Klang")
	var wald := welt.find_child("Wald", true, false)
	pruefe(wald != null and wald.get_child_count() > 20, "Wald angelegt (%d Teile)" % (wald.get_child_count() if wald else 0))
	# Talgrenze hält den Spieler im Tal
	var s: Spieler = welt.spieler
	var aussen := WeltPlan.TAL_MITTE + Vector2(0, -WeltPlan.TAL_RADIEN.y * (WeltPlan.GRENZE - 0.1))
	s.global_position = g.position(aussen.x, aussen.y) + Vector3(0, 0.5, 0)
	s.rotation.y = 0.0
	Input.action_press("vor")
	await warte(2.0)
	Input.action_release("vor")
	pruefe(WeltPlan.tal_r(s.global_position.x, s.global_position.z) < WeltPlan.GRENZE + 0.05, "Talgrenze hält den Spieler auf")
	print("   Modellplätze: ", Modelle.plaetze)
	s.global_position = Vector3(0.15, 0.05, -1.0)
	await warte(0.3)


func _geheimnisse() -> void:
	print("-- Geheimnisse")
	await warte(0.05)


func _anwesen() -> void:
	print("-- Anwesen und Werkstatt")
	var g: Gelaende = welt.gelaende
	var raum: PhysicsDirectSpaceState3D = welt.get_world_3d().direct_space_state
	for m in ["veranda", "brunnen", "huehnerstall", "holzlager", "feuerstelle", "opas_stuhl", "hoftor", "briefkasten", "traktor_kaputt", "gewaechshaus", "vogelscheuche", "leiter_apfelbaum"]:
		var k: Node = welt.find_child(m, true, false)
		pruefe(Modelle.plaetze.has(m) and k != null and k.get_child_count() > 0, "Modellplatz %s steht" % m)
	# Opas Stuhl schaut auf die Kuppe
	var stuhl: Node3D = welt.find_child("opas_stuhl", true, false)
	var blick := stuhl.global_transform.basis.z
	var soll := (Vector3(Nussberg.MITTE.x, 0, Nussberg.MITTE.z) - Vector3(stuhl.global_position.x, 0, stuhl.global_position.z)).normalized()
	pruefe(blick.dot(soll) > 0.99, "Opas Stuhl zeigt auf die Kuppe")
	# Der Hauptweg vom Hoftor bis zum Berg ist nicht verbaut
	var weg: Array = WeltPlan.WEGE[0][0]
	var frei := true
	for i in range(3, weg.size() - 1):
		for t in [0.0, 0.25, 0.5, 0.75]:
			var p: Vector2 = (weg[i] as Vector2).lerp(weg[i + 1], t)
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 2.2, p.y), Vector3(p.x, -2.0, p.y), Data.L_WELT)
			var treffer: Dictionary = raum.intersect_ray(q)
			if treffer.is_empty() or treffer.position.y > g.hoehe_bei(p.x, p.y) + 0.3:
				frei = false
				print("     verbaut bei ", p)
	pruefe(frei, "Hauptweg vom Hoftor zum Berg ist frei")
	# Abgabekreis und Bestellbrett sind nicht zugestellt
	var q2 := PhysicsRayQueryParameters3D.create(welt.ABGABE_POS + Vector3(0, 2.0, 0), welt.ABGABE_POS + Vector3(0, -1.0, 0), Data.L_WELT)
	var t2: Dictionary = raum.intersect_ray(q2)
	pruefe(not t2.is_empty() and t2.position.y < 0.2, "Abgabekreis ist frei")
	# Veranda ist über die Treppe begehbar
	var s: Spieler = welt.spieler
	s.global_position = Vector3(3.25, 0.1, 7.4)
	s.rotation.y = 0.0
	Input.action_press("vor")
	await warte(1.4)
	Input.action_release("vor")
	pruefe(s.global_position.z < 5.4 and s.global_position.y > 0.15, "Veranda über die Treppe erreichbar (y %.2f)" % s.global_position.y)
	# Briefkasten und Bauplan lassen sich lesen
	for name in ["briefkasten", "Bauplan"]:
		var knoten: Node = welt.find_child(name, true, false)
		var ia: Interaktiv = null
		for c in knoten.get_children():
			if c is Interaktiv:
				ia = c
		pruefe(ia != null, "%s ist benutzbar" % name)
		if ia:
			ia.aktion.call(s)
			await warte(0.2)
			pruefe(welt.menues.offen == "zettel", "%s öffnet einen Zettel" % name)
			welt.menues.schliessen()
			await warte(0.1)
	pruefe(welt.find_child("PlaneMaschine", true, false) != null, "Opas Maschine unter der Plane steht in der Werkstatt")
	s.gesperrt = false
	s.global_position = Vector3(0.15, 0.05, -1.0)
	await warte(0.3)


func _leben() -> void:
	print("-- Leben: Tag-Nacht, Wetter, Tiere")
	await warte(0.05)


func _siedlung() -> void:
	print("-- Siedlung und Aussicht")
	var g: Gelaende = welt.gelaende
	var s: Spieler = welt.spieler
	for m in ["koehlerhuette_ruine", "schuppen_ruine", "lagerhaus_alt", "holzwagen_kaputt", "wegweiser", "heuschober", "picknick", "sperre", "angelplatz", "hochsitz"]:
		var k: Node = welt.find_child(m, true, false)
		pruefe(Modelle.plaetze.has(m) and k != null and k.get_child_count() > 0, "Modellplatz %s steht" % m)
	# Bauplätze sind eben
	for ort in ["siedlung", "heuschober", "picknick", "koenigseiche", "hochsitz"]:
		var o: Vector3 = WeltPlan.ORTE[ort]
		pruefe(g.steigung(o.x, o.z) < 0.08, "Bauplatz %s ist eben" % ort)
	var mond: Vector3 = WeltPlan.ORTE.mondlichtung
	pruefe(g.hoehe_bei(mond.x, mond.z) < g.hoehe_bei(mond.x + 7.0, mond.z) - 0.5, "Mondlichtung hat einen Krater")
	# Hochsitz: Leiter hoch und wieder runter
	var hoch: Node = welt.find_child("hochsitz", true, false)
	var leitern: Array = []
	for c in hoch.get_children():
		if c is Interaktiv:
			leitern.append(c)
	pruefe(leitern.size() == 2, "Hochsitz hat Leiter hoch und runter")
	var boden: float = g.hoehe_bei(WeltPlan.ORTE.hochsitz.x, WeltPlan.ORTE.hochsitz.z)
	leitern[0].aktion.call(s)
	await warte(0.6)
	pruefe(s.global_position.y > boden + 3.4 and s.is_on_floor(), "Oben auf dem Hochsitz stehen (%.1f m über dem Boden)" % (s.global_position.y - boden))
	leitern[1].aktion.call(s)
	await warte(0.6)
	pruefe(s.global_position.y < boden + 1.0, "Wieder unten")
	# Der Steg am Angelplatz trägt
	var steg: Node3D = welt.find_child("angelplatz", true, false)
	s.global_position = steg.to_global(Vector3(0, 1.0, 1.9))
	await warte(0.7)
	pruefe(s.is_on_floor() and s.global_position.y > -0.3, "Steg am Angelplatz trägt (y %.2f)" % s.global_position.y)
	# Loses Brett am Lagerhaus
	var lager: Node = welt.find_child("lagerhaus_alt", true, false)
	var brett_ia: Interaktiv = null
	for c in lager.get_children():
		if c is Interaktiv:
			brett_ia = c
	pruefe(brett_ia != null, "Loses Brett ist benutzbar")
	if brett_ia:
		brett_ia.aktion.call(s)
		await warte(0.8)
		pruefe((lager.find_child("Loses_Brett", true, false) as Node3D).rotation_degrees.x > 50.0, "Brett schwingt zur Seite")
	s.global_position = Vector3(0.15, 0.05, -1.0)
	await warte(0.3)


func _berg_und_sammeln() -> void:
	print("-- Nussberg und Sammeln")
	var berg: Nussberg = welt.berg
	pruefe(berg.volumen > 1000.0, "Berg hat Volumen (%d m³)" % int(berg.volumen))
	pruefe(berg.hoehe_bei(Nussberg.MITTE.x, Nussberg.MITTE.z) > 7.0, "Berg ist in der Mitte hoch")
	pruefe(berg.hoehe_bei(2.0, -3.0) == 0.0, "An der Hütte liegt kein Berg")
	# Bodenkollision: ein Strahl von oben trifft den Berg
	var q := PhysicsRayQueryParameters3D.create(Vector3(1, 30, -32), Vector3(1, -5, -32), Data.L_WELT)
	var t: Dictionary = welt.get_world_3d().direct_space_state.intersect_ray(q)
	pruefe(not t.is_empty() and berg.ist_berg(t.collider), "Berg hat Kollision")
	# Abbauen hält Zähler und Volumen zusammen
	var rest_vorher := Game.berg_rest()
	var vol_vorher := berg.volumen
	var stelle := Vector3(1.0, 0, -14.0)
	var h_vorher := berg.hoehe_bei(stelle.x, stelle.z)
	var n := berg.abbauen(stelle, 1.0, 200)
	Game.nuesse_vom_berg(n)
	pruefe(n > 150 and n <= 201, "Abbauen liefert die gewünschte Menge (%d)" % n)
	pruefe(berg.hoehe_bei(stelle.x, stelle.z) < h_vorher, "Berg sinkt an der Stelle")
	var verh_vorher := float(rest_vorher) / vol_vorher
	var verh_nachher := float(Game.berg_rest()) / berg.volumen
	pruefe(absf(verh_vorher - verh_nachher) / verh_vorher < 0.01, "Nüsse pro m³ bleiben gleich")
	# Spieler sammelt mit gedrückter Taste
	var s: Spieler = welt.spieler
	s.global_position = Vector3(1.0, berg.hoehe_bei(1.0, -11.0) + 0.8, -11.0)
	await warte(0.8)
	_zielen_auf(s, Vector3(1.0, berg.hoehe_bei(1.0, -12.8), -12.8))
	await warte(0.3)
	pruefe(s.sammel_punkt != Vector3.INF, "Fadenkreuz trifft den Berg")
	pruefe(s.hinweis.contains("sammeln"), "Hinweis zeigt Sammeln")
	Game.sammler["schaufel"] = 0
	Game.waehle_sammler("schaufel")
	var genommen_vorher := Game.genommen
	s.set_meta("test_sammeln", true)
	await warte(2.0)
	s.remove_meta("test_sammeln")
	pruefe(Game.beutel_menge() > 0, "Sammeln füllt den Beutel (%d)" % Game.beutel_menge())
	pruefe(Game.genommen > genommen_vorher, "Gesammelte Nüsse fehlen dem Berg")
	pruefe(Game.beutel_frei() == 0, "Beutel ist irgendwann voll")
	pruefe(welt.flug.anzahl() >= 0, "Fliegende Nüsse ohne Absturz")
	Game.sammler.erase("schaufel")
	Game.waehle_sammler("haende")


func _abliefern() -> void:
	print("-- Abliefern")
	var s: Spieler = welt.spieler
	var menge := Game.beutel_menge()
	var muenzen := Game.muenzen
	s.global_position = welt.ABGABE_POS + Vector3(0, 0.1, 0)
	await warte(1.2)
	pruefe(Game.beutel_menge() == 0, "Im gelben Kreis wird der Beutel geleert")
	pruefe(Game.lager_menge() >= menge, "Nüsse liegen im Lager (%d)" % Game.lager_menge())
	pruefe(Game.muenzen >= muenzen + menge * 0.99, "Abliefern bringt sofort Münzen")
	Game.einlagern({"wal": 30, "hasel": 30})
	s.global_position = Vector3(0.15, 0.05, -1.0)
	await warte(0.3)


func _knacken() -> void:
	print("-- Knacken")
	welt._hebel_ziehen(null)
	await warte(1.2)
	var n: int = welt._nuesse_in_schale()
	pruefe(n > 0, "Hebel holt Nüsse aus dem Lager in die Schale (%d)" % n)
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
	var anzahl := glas.haelften
	pruefe(anzahl >= 4, "Perfekte Kerne fliegen von selbst ins Glas (%d)" % anzahl)
	pruefe(glas.inhalt.size() == glas.belegt(), "Inhalt des Glases ist sichtbar gespeichert")
	pruefe(welt.bruchschale.bruch >= 3, "Bruch fliegt in die Bruchschale (%d)" % welt.bruchschale.bruch)
	pruefe(glas.verkaufswert() > 0.0, "Glas hat einen Wert")
	var vorher := Game.muenzen
	var s: Spieler = welt.spieler
	s._greifen(glas)
	await warte(0.3)
	welt._klappe_benutzen(s)
	await warte(0.6)
	pruefe(Game.muenzen > vorher, "Glas an der Klappe verkauft (%.1f Münzen)" % (Game.muenzen - vorher))
	pruefe(glas.belegt() == 0, "Glas ist danach leer")
	await warte(0.5)
	pruefe(glas.global_position.distance_to(glas.heim.origin) < 0.1, "Glas steht wieder auf dem Tisch")
	var m_vorher := Game.muenzen
	glas.fuelle("haelfte", glas.kapazitaet, 4.0, "wal")
	await warte(2.5)
	pruefe(glas.belegt() == 0 and Game.muenzen > m_vorher, "Rohrpost verkauft volle Gläser von selbst")


func _laden_und_maschinen() -> void:
	print("-- Laden")
	Game.verdiene(500000, false)
	pruefe(Game.kaufe_sammler("loeffel"), "Holzlöffel kaufen")
	pruefe(Game.sammler_aktiv == "loeffel", "Löffel ist in der Hand")
	pruefe(not Game.kaufe_sammler("laubsauger"), "Laubsauger erst ab Ära 2")
	var kap := Game.kapazitaet()
	pruefe(Game.kaufe_beutel("stoffbeutel"), "Stoffbeutel kaufen")
	pruefe(Game.kapazitaet() > kap, "Mehr Platz im Beutel (%d)" % Game.kapazitaet())
	pruefe(not Game.kaufe_beutel("taschen"), "Kein Rückschritt beim Beutel")
	pruefe(Game.kaufe_werkzeug("holz"), "Holz-Nussknacker kaufen")
	pruefe(Game.werkzeug_aktiv == "holz", "Neues Werkzeug ist aktiv")
	pruefe(Game.kaufe_werkzeug("metall"), "Metall-Hebelknacker kaufen")
	pruefe(Game.werte_werkzeug_auf("metall"), "Werkzeug verbessern")
	pruefe(not Game.kaufe_werkzeug("hammer"), "Hammer erst ab Ära 2")
	for id in ["rutsche", "deckel", "mimi", "sieb"]:
		pruefe(Game.kaufe_maschine(id), "%s kaufen" % Data.MASCHINEN[id].name)
	pruefe(not Game.kaufe_maschine("walze"), "Walzenknacker erst ab Ära 2")
	Game.einlagern({"wal": 20})
	await warte(3.0)
	pruefe(welt.station.geladen, "Rutsche legt eine Nuss aus dem Lager in den Knacker")


func _helfer_und_posten() -> void:
	print("-- Helfer und Außenposten")
	var preis := Game.helfer_preis()
	pruefe(Game.kaufe_helfer(), "Sammel-Eichhörnchen einstellen")
	pruefe(Game.helfer_preis() > preis, "Jedes weitere kostet mehr")
	for i in 3:
		Game.kaufe_helfer()
	await warte(0.2)
	pruefe(welt._helfer_knoten.size() == 4, "Helfer stehen in der Welt (%d)" % welt._helfer_knoten.size())
	pruefe(Game.kaufe_posten("posten_vorn"), "Außenposten Vorn bauen")
	pruefe(welt._abgaben.size() == 2, "Zweite Abgabestelle")
	pruefe(not Game.kaufe_posten("posten_west"), "Posten West erst ab Ära 2")
	var lager := int(Game.statistik.get("abgeliefert", 0))
	var genommen := Game.genommen
	await warte(14.0)
	pruefe(Game.genommen > genommen, "Helfer sammeln am Berg (%d)" % (Game.genommen - genommen))
	pruefe(int(Game.statistik.get("abgeliefert", 0)) > lager, "Helfer liefern ab")


func _werkstatt() -> void:
	print("-- Werkstatt")
	Game.nuesse_vom_berg(Data.SCHICHTEN[1].ab)
	await warte(0.2)
	pruefe(Game.aera == 2, "Ära 2 nach %s Nüssen" % Data.zahl(Data.SCHICHTEN[1].ab))
	pruefe(welt._werkstatt_tuer == null, "Werkstatttür ist offen")
	pruefe(Game.kaufe_maschine("walze"), "Walzenknacker kaufen")
	pruefe(Game.kaufe_maschine("lagerhalle"), "Lagerhalle kaufen")
	pruefe(Game.lager_kapazitaet() >= Data.LAGER_GROESSE * 10, "Lagerhalle vergrößert das Lager")
	pruefe(Game.kaufe_sammler("laubsauger"), "Laubsauger kaufen")
	pruefe(Game.kaufe_werkzeug("hammer"), "Hammer kaufen")
	pruefe(not Game.kaufe_werkzeug("schraubstock"), "Schraubstock erst ab Ära 3")
	for h in welt._helfer_knoten:
		h.set_process(false)
	Game.einlagern({"wal": 300, "hasel": 300})
	var vorher := Game.geknackt
	var lager := Game.lager_menge()
	await warte(4.0)
	pruefe(Game.geknackt > vorher, "Walzenknacker knackt allein (%d)" % (Game.geknackt - vorher))
	pruefe(Game.lager_menge() < lager, "Walzenknacker nimmt aus dem Lager")
	for h in welt._helfer_knoten:
		h.set_process(true)


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


func _skills() -> void:
	print("-- Skillbaum")
	var alle := Data.skills()
	pruefe(alle.size() > 150, "Skillbaum hat viele Knoten (%d)" % alle.size())
	for id in ["ruhige_hand", "rhythmus", "goldhand", "meisterknack", "gut_geoelt", "baumeister", "selbstlaeufer", "feilschen",
			"stammkunden", "nussbaron", "katzenfreund", "festung", "waechter", "nussfluesterer", "koenigsbund", "wuehlmaus",
			"grabkoenig", "nusswelle", "packesel", "siebenmeilen", "bodenlos"]:
		if not alle.has(id):
			pruefe(false, "Schlüsselknoten %s fehlt" % id)
	for id in alle:
		var k: Dictionary = alle[id]
		if k.braucht != "" and not alle.has(k.braucht):
			pruefe(false, "Knoten %s hängt an fehlendem %s" % [id, k.braucht])
	Game.verdiene(100000, false)
	var rate := float(Game.sammel_werte().rate)
	pruefe(Game.skill_status("sammeln_1") == "gesperrt", "Zweiter Knoten ist erst gesperrt")
	pruefe(Game.kaufe_skill("sammeln_0"), "Ersten Sammel-Skill lernen")
	pruefe(float(Game.sammel_werte().rate) > rate, "Skill erhöht das Sammeltempo")
	pruefe(Game.skill_status("sammeln_1") != "gesperrt", "Nächster Knoten wird frei")
	pruefe(not Game.kaufe_skill("sammeln_0"), "Doppelt lernen geht nicht")
	var kap := Game.kapazitaet()
	Game.kaufe_skill("tragen_0")
	pruefe(Game.kapazitaet() > kap, "Tragen-Skill erhöht die Kapazität")


func _bestellungen() -> void:
	print("-- Bestellungen")
	pruefe(Game.bestellungen.size() >= 3, "Drei Bestellungen offen")
	var b: Dictionary = Game.bestellungen[0]
	b.nuss = "wal"
	b.menge = 2
	b.stand = 0
	var vorher := Game.muenzen
	Game.melde_knack("wal", "perfekt", true, 2)
	pruefe(Game.muenzen > vorher, "Erfüllte Bestellung bringt Münzen")


func _wischen() -> void:
	print("-- Wischen")
	var eimer: Behaelter = welt.eimer
	eimer.leeren()
	var p: Vector3 = welt.station.global_position + Vector3(0, 0.05, 0.1)
	Game.maschinen.erase("sieb")
	for i in 5:
		welt.item_spawnen({"art": "schale", "nuss": "wal"}, p + Vector3(randf_range(-0.1, 0.1), 0.02, 0), Vector3.ZERO)
	await warte(0.5)
	welt.wischen(p)
	await warte(1.2)
	pruefe(eimer.schalen >= 5, "Wischen bringt Schalen in den Eimer (%d)" % eimer.schalen)


func _menues() -> void:
	print("-- Menüs")
	var m: Menues = welt.menues
	for r in 6:
		m.zeige_laden(r)
		await warte(0.15)
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
	await warte(0.3)
	pruefe(s.blickt_auf_station() == welt.station, "Fadenkreuz trifft den Knacker vom Platz am Tisch")
	pruefe(s.hinweis.contains("Knackbank"), "Hinweis zeigt Hinsetzen")
	# Hinsetzen, nachlegen, knacken, wischen, aufstehen
	if welt.station.geladen:
		welt.station.entnehme()
	Game.maschinen.erase("rutsche")
	Game.einlagern({"wal": 20})
	welt._hebel_sperre = 0.0
	welt.hebel_ziehen()
	await warte(1.0)
	_taste(KEY_E)
	await warte(0.1)
	pruefe(s.sitzt, "[E] am Knacker: hinsetzen")
	await warte(1.0)
	pruefe(welt.station.geladen, "Im Sitzen wird automatisch nachgelegt")
	_maus(MOUSE_BUTTON_LEFT, true)
	await warte(0.2)
	pruefe(welt.station.drueckt, "Linksklick drückt zu")
	_maus(MOUSE_BUTTON_LEFT, false)
	pruefe(not welt.station.drueckt, "Loslassen knackt")
	await warte(0.3)
	welt.item_spawnen({"art": "schale", "nuss": "wal"}, welt.station.global_position + Vector3(0.1, 0.05, 0.05), Vector3.ZERO)
	await warte(0.4)
	var schalen_vorher: int = welt.eimer.schalen
	_maus(MOUSE_BUTTON_RIGHT, true)
	_maus(MOUSE_BUTTON_RIGHT, false)
	await warte(0.9)
	pruefe(welt.eimer.schalen > schalen_vorher, "Rechtsklick wischt Schalen in den Eimer")
	_taste(KEY_E)
	await warte(0.6)
	pruefe(not s.sitzt, "[E] steht wieder auf")
	# Schale direkt neben dem Knacker: [E] nimmt sie, Linksklick setzt sich hin
	for versatz in [Vector3(0.07, 0.04, 0.02), Vector3(-0.08, 0.04, 0.05), Vector3(0.03, 0.04, 0.09)]:
		s.global_position = Vector3(0.15, 0.05, -1.45)
		var schale: Item = welt.item_spawnen({"art": "schale", "nuss": "wal"}, welt.station.global_position + versatz, Vector3.ZERO)
		await warte(0.6)
		_zielen_auf(s, schale.global_position)
		await warte(0.15)
		pruefe(s.ziel == schale, "Schale neben dem Knacker anvisiert (%s)" % str(versatz))
		pruefe(s.hinweis.contains("nehmen"), "Hinweis sagt „nehmen“, nicht „hinsetzen“")
		s._benutzen()
		await warte(0.1)
		pruefe(s.gehalten == schale and not s.sitzt, "[E] nimmt die Schale statt hinzusetzen")
		s._loslassen(Vector3.ZERO)
		if is_instance_valid(schale):
			schale.queue_free()
	var sch2: Item = welt.item_spawnen({"art": "schale", "nuss": "wal"}, welt.station.global_position + Vector3(0.07, 0.04, 0.02), Vector3.ZERO)
	await warte(0.6)
	_zielen_auf(s, sch2.global_position)
	await warte(0.15)
	pruefe(s.ziel_station == welt.station, "Knackbank bleibt für Linksklick erreichbar")
	s._druecken_an()
	pruefe(s.sitzt and s.gehalten == null, "Linksklick auf die Schale am Knacker setzt sich hin")
	s.aufstehen()
	await warte(0.5)
	sch2.queue_free()
	# Hocker
	s.global_position = Vector3(0.15, 0.05, -0.7)
	_zielen_auf(s, Vector3(0.15, 0.4, -1.55))
	await warte(0.15)
	s._benutzen()
	pruefe(s.sitzt, "[E] auf den Hocker setzt sich an die Knackbank")
	s.aufstehen()
	await warte(0.5)
	s.global_position = Vector3(0.15, 0.05, -1.45)
	# Eine Hälfte neben dem Knacker greifen
	var haelfte: Item = welt.item_spawnen({"art": "haelfte", "nuss": "wal", "wert": 4.0}, welt.station.global_position + Vector3(0.16, 0.05, 0.06), Vector3.ZERO)
	await warte(0.6)
	s.look_at(haelfte.global_position, Vector3.UP)
	s.rotation.x = 0
	s.rotation.z = 0
	var richtung := haelfte.global_position - s._kopf_transform().origin
	s._blick_x = atan2(richtung.y, Vector2(richtung.x, richtung.z).length())
	await warte(0.2)
	pruefe(s.ziel == haelfte, "Hälfte neben dem Knacker lässt sich anvisieren")


func _zielen_auf(s: Spieler, punkt: Vector3) -> void:
	var kopf := s._kopf_transform().origin
	var richtung := punkt - kopf
	s.rotation.y = atan2(-richtung.x, -richtung.z)
	s._blick_x = atan2(richtung.y, Vector2(richtung.x, richtung.z).length())


func _taste(k: Key) -> void:
	for gedrueckt in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.pressed = gedrueckt
		Input.parse_input_event(ev)


func _maus(knopf: MouseButton, gedrueckt: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = knopf
	ev.pressed = gedrueckt
	# direkt an die Sitz-Steuerung (im Headless-Modus ist die Maus nie eingefangen)
	if welt.spieler.sitzt:
		welt.spieler._eingabe_sitzend(ev)
	else:
		welt.spieler._unhandled_input(ev)


func _speichern() -> void:
	print("-- Speichern")
	Game.speichern()
	pruefe(FileAccess.file_exists(Game.SPEICHER_PFAD), "Spielstand geschrieben")
	var d = JSON.parse_string(FileAccess.get_file_as_string(Game.SPEICHER_PFAD))
	pruefe(typeof(d) == TYPE_DICTIONARY and d.has("behaelter") and d.has("lager"), "Spielstand lesbar")
	pruefe(FileAccess.file_exists(Game.BERG_PFAD), "Berg gespeichert")
	var kopie := Nussberg.new()
	pruefe(kopie.laden(Game.BERG_PFAD) and absf(kopie.volumen - welt.berg.volumen) < 0.01, "Berg wird genau so wieder geladen")
	kopie.free()
