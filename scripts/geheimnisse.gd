class_name Geheimnisse
extends Node3D
## Alle Geheimnisse des Haselgrunds (Etappe 4 des Weltplans): Mondlichtung, Nadel im Heuhaufen,
## Eichhörnchen-König und neun weitere. Was gefunden ist, steht im Fundbuch (Game.fund / Game.extra).
## Keine Leuchtmarker: Hinweise kommen nur aus der Welt und aus dem Fundbuch.

const STAUB_ANZAHL := 260
const KRATER_RADIUS := 4.5
const KELLER_POS := Vector3(300.0, 0.0, 0.0)
const STUDIO_POS := Vector3(300.0, 0.0, 60.0)
const FIGUREN := ["kueche", "werkstatt", "veranda", "brunnen", "hochsitz", "picknick", "koehler", "lagerhaus",
	"angelplatz", "koenigseiche", "keller", "hexenring"]

const BRIEF_FLASCHE := """An den, der das findet:

Ich heiße Walter und wohne im Haselgrund. Ich sammle Nüsse. Wenn du auch Nüsse sammelst, schreib mir. Wenn du KEINE Nüsse sammelst, schreib mir erst recht und erklär mir, warum nicht.

Diese Flasche soll bis ans Meer schwimmen.

Walter, 1976

(Darunter, mit anderem Stift: „Sie hängt seit drei Wochen im Schilf, Walter. – F.“)"""

const TEXT_FOTO := """Ein vergilbtes Foto, auf der Rückseite steht: „Haselgrund, Herbst 1974“.

Eine winzige Hütte. Davor ein junger Mann mit einem einzigen Korb Nüsse und eine Frau, die lacht. Hinter den beiden: eine leere Wiese, wo heute der Berg liegt.

Jemand hat einen Pfeil auf die Wiese gemalt und dazugeschrieben: „Hier kommt mal was Großes hin.“"""

const TEXT_AUDIENZ := """Der König mustert dich lange. Dann hebt er eine Pfote.

Ein Eichhörnchen mit Schriftrolle tritt vor und piepst feierlich etwas, das wie ein Vertrag klingt.

Du bist jetzt „Freund der Krone“.
· Wilde Eichhörnchen klauen dir ein Viertel weniger.
· Einer deiner Helfer trägt ab heute eine kleine Krone. Er ist sehr stolz."""

var welt: Node
## Alle benutzbaren Stellen der Geheimnisse, Name -> Interaktiv (auch für den Selbsttest)
var ia := {}
var _g: Gelaende
var _rng := RandomNumberGenerator.new()
var _zeit := 0.0
var _sekunde := 0.0
# Mondlichtung
var _mond: Vector3
var _staub_mm: MultiMesh
var _staub_lage: Array = []
var _staub_da := PackedByteArray()
var _staub_rest := 0
var _staub_acc := 0.0
var _staub_neu := false
var _wolke := 0.0
var _maschine: Node3D
var _mondnuss: Node3D
# Nadel
var _nadel: Node3D
var _blitz: MeshInstance3D
var _vitrine: Node3D
var _applaus: Array = []
var _applaus_zeit := 0.0
# König
var _eiche: Node3D
var _koenig: Node3D
var _opfer_nuesse: Array = []
# Briefkasten
var _miniberg: MeshInstance3D
# Keller und Studio
var _raum: Node3D
var _rueckweg := Vector3.ZERO
var _teppich: Node3D
var _falltuer: Node3D
var _foto_kueche: Node3D
# Sir Nussbert
var _nb_timer := 180.0
var _nb_aktiv := 0.0
var _nb_blick := 0.0
var _nb_helfer: SammelHelfer
var nussbert_winkel := 180.0     # Winkel zwischen Blick und Sir Nussbert (Grad)
# Hexenring
var _ring: Node3D
var _sternbild: Node3D
var _stern_zeit := 0.0
# Figuren
var _figuren := {}
var _trophaee: Node3D
var _parade: Array = []
var _parade_zeit := 0.0


func _init(w: Node) -> void:
	welt = w
	name = "Geheimnisse"


func _ready() -> void:
	_g = welt.gelaende
	_rng.seed = 384400
	_nb_timer = _rng.randf_range(150.0, 420.0)
	_mondlichtung()
	_nadel_bauen()
	_koenig_bauen()
	_briefkasten()
	_flaschenpost()
	_herz()
	_goldwalnuss()
	_keller_zugang()
	_studio_zugang()
	_hexenring()
	_kueche()
	_figuren_bauen()
	Game.fund_gemacht.connect(func(_id): _trophaeen_zeigen())
	_trophaeen_zeigen()


func _ort(name_: String) -> Node3D:
	return welt.find_child(name_, true, false) as Node3D


func _zettel(titel: String, text: String) -> void:
	welt._menue(welt.menues.zeige_zettel.bind(titel, text))


func _versetzen(sp: Node, pos: Vector3) -> void:
	sp.velocity = Vector3.ZERO
	sp.global_position = pos


## Entfernt etwas, auf das der Spieler vielleicht gerade zielt: sofort unsichtbar und nicht mehr
## benutzbar, gelöscht erst einen Moment später (sonst hält der Spieler einen toten Verweis).
func _spaeter_weg(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n is Node3D:
		(n as Node3D).visible = false
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0
	for c in n.find_children("*", "CollisionObject3D", true, false):
		(c as CollisionObject3D).collision_layer = 0
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free())


func _interaktiv_an(i: Interaktiv, an: bool) -> void:
	i.collision_layer = Data.L_INTERAKT if an else 0


func _process(delta: float) -> void:
	_zeit += delta
	_staub_wolke(delta)
	_nadel_blitzen()
	_applaus_bewegen(delta)
	_nussbert(delta)
	_hexenring_pruefen(delta)
	_parade_bewegen(delta)
	_sekunde -= delta
	if _sekunde <= 0.0:
		_sekunde = 0.5
		_langsam()


## Zweimal pro Sekunde: Zustände, die sich nur gemächlich ändern.
func _langsam() -> void:
	if _staub_neu:
		_staub_neu = false
		_staub_speichern()
	# König: nur nachts und nur, wenn alle drei Opfergaben liegen
	if _koenig:
		var da := _opfer() == 7 and Game.ist_nacht()
		_koenig.visible = da
		_interaktiv_an(ia.koenig, da and not Game.hat_fund("koenig"))
	# Mini-Berg im Briefkasten schrumpft mit dem echten
	if _miniberg:
		var anteil := clampf(float(Game.berg_rest()) / float(Data.BERG_GROESSE), 0.0, 1.0)
		var s := pow(anteil, 1.0 / 3.0)
		_miniberg.visible = anteil > 0.0
		_miniberg.scale = Vector3(0.12, 0.07, 0.1) * maxf(s, 0.08)
	# Der Gesandte der Krone
	if Game.hat_fund("koenig") and welt._helfer_knoten.size() > 0:
		(welt._helfer_knoten[0] as SammelHelfer).setze_krone(true)
	# Figur hinter dem losen Brett erst zeigen, wenn das Brett zur Seite geschoben ist
	if _figuren.has("lagerhaus") and is_instance_valid(_figuren.lagerhaus):
		var brett := welt.find_child("Loses_Brett", true, false) as Node3D
		_figur_sichtbar("lagerhaus", brett == null or brett.rotation_degrees.x > 30.0)


# =============================================================================
# 1. Die Mondlichtung
# =============================================================================
func _mondlichtung() -> void:
	var o: Vector3 = WeltPlan.ORTE.mondlichtung
	_mond = _g.position(o.x, o.z)
	# Staubflecken, immer an denselben Stellen (fester Zufall)
	var r := RandomNumberGenerator.new()
	r.seed = 1969
	var fleck := SphereMesh.new()
	fleck.radius = 1.0
	fleck.height = 2.0
	fleck.radial_segments = 10
	fleck.rings = 5
	_staub_mm = MultiMesh.new()
	_staub_mm.transform_format = MultiMesh.TRANSFORM_3D
	_staub_mm.mesh = fleck
	_staub_mm.instance_count = STAUB_ANZAHL
	_staub_da.resize(STAUB_ANZAHL)
	var gespeichert := str(Game.extra.get("mondstaub", ""))
	for i in STAUB_ANZAHL:
		var w := r.randf() * TAU
		var d := sqrt(r.randf()) * (KRATER_RADIUS - 0.2)
		var p := Vector3(o.x + cos(w) * d, 0, o.z + sin(w) * d)
		p.y = _g.hoehe_bei(p.x, p.z) + 0.03
		var gr := r.randf_range(0.42, 0.75)
		var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(gr, r.randf_range(0.04, 0.08), gr * r.randf_range(0.7, 1.0))), p)
		_staub_lage.append(t)
		var da := not (gespeichert.length() == STAUB_ANZAHL and gespeichert[i] == "0")
		if _mond_stand() > 0:
			da = false
		_staub_da[i] = 1 if da else 0
		_staub_mm.set_instance_transform(i, t if da else Transform3D(Basis().scaled(Vector3.ZERO), p))
		if da:
			_staub_rest += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Mondstaub"
	mmi.multimesh = _staub_mm
	mmi.material_override = Look.putz(Color(0.88, 0.86, 0.8), Color(0.72, 0.7, 0.64), 70.0, 0.0, 1.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# Ein paar Brocken am Kraterrand
	for i in 7:
		var w2 := r.randf() * TAU
		var p2 := _g.position(o.x + cos(w2) * (KRATER_RADIUS + 0.9), o.z + sin(w2) * (KRATER_RADIUS + 0.9))
		var st := Bau.teil(self, Bau.kugel_mesh(1.0, false, 7), Look.putz(Color(0.74, 0.72, 0.66), Color(0.58, 0.56, 0.5), 30.0, 0.0, 1.0), p2, Vector3(0, r.randf() * 360, 0), Vector3(r.randf_range(0.2, 0.45), r.randf_range(0.15, 0.3), r.randf_range(0.2, 0.4)))
		st.set_meta("ohne_rand", true)
	# Opas Maschine am Nordrand, Auswurf zum Krater
	_maschine = Modelle.platz(self, "mondmaschine", _g.position(o.x + 1.2, o.z - 6.7), 0.0, Ersatz.mondmaschine)
	_mondnuss = Node3D.new()
	_mondnuss.position = Vector3(0, 0.8, 0.9)
	_maschine.add_child(_mondnuss)
	Bau.teil(_mondnuss, Bau.box_mesh(Vector3(0.3, 0.02, 0.26)), Look.stoff(Color(0.25, 0.1, 0.3)), Vector3(0, -0.05, 0))
	Bau.teil(_mondnuss, Bau.kugel_mesh(0.085, false, 14), Look.metall(Color(0.9, 0.92, 1.0), 0.15), Vector3(0, 0.045, 0), Vector3.ZERO, Vector3(1, 1.1, 1))
	Bau.teil(_mondnuss, Bau.kugel_mesh(0.02, false, 8), Look.leuchten(Color(0.85, 0.92, 1.0), 1.5), Vector3(0.03, 0.12, 0.04))
	ia["mondnuss"] = Interaktiv.erzeuge(_maschine, Vector3(0.5, 0.4, 0.5), Vector3(0, 0.85, 0.9), "Mondnuss nehmen", func(_s): _mondnuss_nehmen())
	ia["mondmaschine"] = Interaktiv.erzeuge(_maschine, Vector3(1.2, 0.9, 0.3), Vector3(0, 1.2, 0.72), "Mondsiebmaschine", func(_s):
		Sfx.spiele("fehler", -8.0)
		Game.toast.emit("Die Maschine rührt sich nicht. Auf einem Zettel steht: „Erst sauber machen!“" if _mond_stand() == 0 else "Die Maschine ist leer und sehr zufrieden.", Game.FARBE_INFO))
	_mond_anzeigen()


func _mond_stand() -> int:
	return int(Game.extra.get("mond", 0))


func _mond_anzeigen() -> void:
	var stand := _mond_stand()
	_mondnuss.visible = stand == 1
	_interaktiv_an(ia.mondnuss, stand == 1)
	_interaktiv_an(ia.mondmaschine, stand != 1)


## Liegt an dieser Stelle noch Mondstaub? (Der Spieler fragt das beim Zielen.)
func staub_bei(p: Vector3) -> bool:
	return _mond_stand() == 0 and _staub_rest > 0 and Vector2(p.x - _mond.x, p.z - _mond.z).length() < KRATER_RADIUS + 0.4


func staub_rest() -> int:
	return _staub_rest


func staub_text() -> String:
	return "Krater zu %d %% sauber" % int(round(100.0 * (1.0 - float(_staub_rest) / STAUB_ANZAHL)))


## Fegt Staub rund um punkt weg. werte = Game.sammel_werte() (rate, radius).
func fegen(punkt: Vector3, werte: Dictionary, delta: float) -> void:
	if _mond_stand() != 0:
		return
	_staub_acc += (5.0 + 2.0 * sqrt(float(werte.get("rate", 1.0)))) * delta
	var reich := maxf(0.9, float(werte.get("radius", 0.5)) * 1.3)
	while _staub_acc >= 1.0 and _staub_rest > 0:
		_staub_acc -= 1.0
		var best := -1
		var best_d := reich
		for i in STAUB_ANZAHL:
			if _staub_da[i] == 0:
				continue
			var o: Vector3 = (_staub_lage[i] as Transform3D).origin
			var d := Vector2(o.x - punkt.x, o.z - punkt.z).length()
			if d < best_d:
				best_d = d
				best = i
		if best < 0:
			_staub_acc = 0.0
			break
		_fleck_weg(best)
	if _wolke <= 0.0:
		_wolke = 0.3
		Effekte.staub(welt, punkt + Vector3(0, 0.1, 0), Color(0.75, 0.75, 0.8, 0.45), 6, 0.3)
	# Die letzten Krümel nimmt der Wind mit
	if _staub_rest > 0 and _staub_rest <= int(STAUB_ANZAHL * 0.04):
		for i in STAUB_ANZAHL:
			if _staub_da[i] == 1:
				_fleck_weg(i)
	if _staub_rest == 0:
		_krater_sauber()


func _fleck_weg(i: int) -> void:
	_staub_da[i] = 0
	_staub_rest -= 1
	_staub_neu = true
	_staub_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), (_staub_lage[i] as Transform3D).origin))


func _staub_wolke(delta: float) -> void:
	_wolke -= delta


func _staub_speichern() -> void:
	var s := ""
	for i in STAUB_ANZAHL:
		s += "1" if _staub_da[i] == 1 else "0"
	Game.extra["mondstaub"] = s


func _krater_sauber() -> void:
	Game.extra["mond"] = 1
	Game.extra.erase("mondstaub")
	_staub_neu = false
	Sfx.spiele("maschine", -2.0)
	Sfx.spiele("freischalten", -4.0)
	Game.toast.emit("Der Krater ist sauber. Opas Maschine springt an!", Game.FARBE_GOLD)
	var rad := _maschine.find_child("Rad", true, false) as Node3D
	var tw := create_tween()
	if rad:
		tw.tween_property(rad, "rotation:x", TAU * 3.0, 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		tw.tween_interval(2.2)
	var grund := _maschine.position
	var ruettel := create_tween().set_loops(11)
	ruettel.tween_property(_maschine, "position", grund + Vector3(0.02, 0.01, 0), 0.1)
	ruettel.tween_property(_maschine, "position", grund, 0.1)
	var klappe := _maschine.find_child("Klappe", true, false) as Node3D
	if klappe:
		tw.tween_property(klappe, "rotation_degrees:x", -70.0, 0.25)
	tw.tween_callback(func():
		Sfx.spiele("plopp", 0.0, 0.8)
		Effekte.funken(welt, _mondnuss.global_position, Color(0.8, 0.9, 1.0), 14, 0.6)
		_mond_anzeigen())


func _mondnuss_nehmen() -> void:
	if _mond_stand() != 1:
		return
	Game.extra["mond"] = 2
	_mond_anzeigen()
	Game.sammler["zahnbuerste"] = 0
	Game.fund("mondlichtung")
	Game.verdiene(Data.MONDNUSS_WERT, false)
	Game.werkzeug_geaendert.emit()
	Game.toast.emit("Eine Mondnuss (+%s Münzen) – und in der Maschine klemmte eine Goldene Zahnbürste! [X] wechselt das Werkzeug." % Data.zahl(Data.MONDNUSS_WERT), Game.FARBE_GOLD)


# =============================================================================
# 2. Die Nadel im Heuhaufen
# =============================================================================
func _nadel_bauen() -> void:
	var hs := _ort("heuschober")
	if hs == null:
		return
	# Vitrine in der Küche gibt es immer, gefüllt erst nach dem Fund (siehe _kueche)
	if Game.hat_fund("nadel"):
		return
	_nadel = Node3D.new()
	_nadel.name = "Nadel"
	_nadel.position = Vector3(0.85, 1.235, -1.05)
	_nadel.rotation_degrees = Vector3(35, 20, 50)
	hs.add_child(_nadel)
	var gold := Look.metall(Color(1.0, 0.8, 0.25), 0.15)
	Bau.teil(_nadel, Bau.zylinder_mesh(0.0012, 0.0002, 0.03, 5), gold)
	Bau.teil(_nadel, Bau.zylinder_mesh(0.002, 0.002, 0.003, 5), gold, Vector3(0, 0.0155, 0))
	_blitz = Bau.teil(hs, Bau.kugel_mesh(0.012, false, 6), Look.leuchten(Color(1.0, 0.95, 0.7), 6.0), _nadel.position + Vector3(0, 0.012, 0))
	_blitz.visible = false
	_blitz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ia["nadel"] = Interaktiv.erzeuge(hs, Vector3(0.14, 0.14, 0.14), _nadel.position + Vector3(0, 0.03, 0), "Goldene Nadel herausziehen", func(sp): _nadel_gefunden(sp))


func nadel_blitzt() -> bool:
	return _blitz != null and is_instance_valid(_blitz) and Game.ist_abend()


## Nur in der Abendsonne blitzt die Nadel alle paar Sekunden kurz auf.
func _nadel_blitzen() -> void:
	if _blitz == null or not is_instance_valid(_blitz):
		return
	_blitz.visible = Game.ist_abend() and fmod(_zeit, 3.6) < 0.22


func _nadel_gefunden(sp: Node) -> void:
	_spaeter_weg(_nadel)
	_spaeter_weg(_blitz)
	_blitz = null
	if ia.has("nadel"):
		_spaeter_weg(ia.nadel)
	Game.fund("nadel")
	Game.toast.emit("Die goldene Nadel! Irgendwo raschelt es. Sehr viel.", Game.FARBE_GOLD)
	_applaus_starten(sp)


## Ein Dutzend Eichhörnchen stellt sich im Kreis um den Spieler auf und klatscht fünf Sekunden lang.
func _applaus_starten(sp: Node) -> void:
	var vorn: Vector3 = -(sp as Node3D).global_transform.basis.z
	vorn.y = 0
	vorn = vorn.normalized() if vorn.length() > 0.01 else Vector3.FORWARD
	var mitte: Vector3 = (sp as Node3D).global_position
	# Rundherum, damit man sie sieht, egal wohin man sich dreht (vorn steht oft der Heuhaufen im Weg)
	for i in 12:
		var w := TAU * (i + 0.5) / 12.0
		var richtung := vorn.rotated(Vector3.UP, w)
		var p := mitte + richtung * (2.3 + (i % 2) * 0.6)
		p.y = maxf(_g.hoehe_bei(p.x, p.z), mitte.y - 0.3)
		var e := eichhorn_figur(2.2)
		add_child(e)
		e.global_position = p
		e.rotation.y = atan2(richtung.x, richtung.z)
		_applaus.append(e)
	_applaus_zeit = 5.0
	Sfx.spiele("freischalten")
	Sfx.spiele("meilenstein", -2.0)
	for t in [0.4, 1.3, 2.2, 3.1, 4.0]:
		get_tree().create_timer(t).timeout.connect(func(): Sfx.spiele("eichhorn", -8.0, randf_range(0.9, 1.3)))


func applaus_anzahl() -> int:
	return _applaus.size()


func _applaus_bewegen(delta: float) -> void:
	if _applaus.is_empty():
		return
	_applaus_zeit -= delta
	for i in _applaus.size():
		var e: Node3D = _applaus[i]
		var k: Node3D = e.get_child(0)
		k.position.y = absf(sin(_zeit * 9.0 + i * 0.7)) * 0.05
		k.rotation.x = sin(_zeit * 22.0 + i) * 0.12 - 0.35
	if _applaus_zeit <= 0.0:
		for e in _applaus:
			Effekte.staub(welt, (e as Node3D).global_position, Color(0.85, 0.72, 0.55, 0.5), 6, 0.1)
			e.queue_free()
		_applaus.clear()


## Ein Eichhörnchen als bloße Figur (ohne Verhalten). Blick nach -Z wie die Helfer.
static func eichhorn_figur(skala := 2.4, fell_farbe := Color(0.74, 0.4, 0.16)) -> Node3D:
	var wurzel := Node3D.new()
	var k := Node3D.new()
	k.scale = Vector3.ONE * skala
	wurzel.add_child(k)
	var fell := Look.stoff(fell_farbe)
	var hell := Look.stoff(Color(0.96, 0.88, 0.74))
	var leib := Bau.mesh_instanz(Bau.kugel_mesh(0.07), fell, Vector3(0, 0.07, 0))
	leib.scale = Vector3(0.8, 0.9, 1.3)
	k.add_child(leib)
	k.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.045), fell, Vector3(0, 0.13, -0.08)))
	k.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.03), hell, Vector3(0, 0.06, -0.04)))
	for s in [-1, 1]:
		k.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.014), fell, Vector3(0.025 * s, 0.18, -0.07)))
		k.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.007), Bau.mat(Color(0.05, 0.03, 0.02), 0.3), Vector3(0.022 * s, 0.145, -0.118)))
		k.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.016), fell, Vector3(0.04 * s, 0.09, -0.07)))
	for i in 4:
		k.add_child(Bau.mesh_instanz(Bau.kugel_mesh(0.05 + i * 0.006), fell, Vector3(0, 0.08 + i * 0.05, 0.11 + sin(i * 0.9) * 0.04)))
	return wurzel


# =============================================================================
# 3. Der Eichhörnchen-König
# =============================================================================
func _opfer() -> int:
	return int(Game.extra.get("opfer", 0))


func _koenig_bauen() -> void:
	var o: Vector3 = WeltPlan.ORTE.koenigseiche
	var pos := _g.position(o.x, o.z)
	# Die Öffnung zeigt dem Wildpfad entgegen
	var pfad: Array = WeltPlan.WEGE[6][0]
	var von: Vector2 = pfad[pfad.size() - 2]
	_eiche = Modelle.platz(self, "koenigseiche", pos, rad_to_deg(atan2(von.x - o.x, von.y - o.z)), Ersatz.koenigseiche)
	# Drei Stümpfe für Opfergaben vor der Öffnung
	for i in 3:
		var lokal := Vector3(-2.3 + i * 2.3, 0, 4.6 + (0.7 if i == 1 else 0.0))
		var welt_pos := _eiche.to_global(lokal)
		var st := Node3D.new()
		st.name = "Opferstumpf%d" % i
		add_child(st)
		st.global_position = _g.position(welt_pos.x, welt_pos.z)
		Ersatz.stumpf(st, Vector3.ZERO, 0.3, 0.5)
		# ein Kranz aus Eicheln und Schalen: hier wurde schon oft etwas abgelegt
		for j in 7:
			var w := TAU * j / 7.0
			Bau.teil(st, Bau.kugel_mesh(0.03, true, 8), Look.nuss("hasel" if j % 2 == 0 else "wal"), Vector3(cos(w) * 0.2, 0.505, sin(w) * 0.2), Vector3(180 if j % 3 == 0 else 0, j * 50.0, 0))
		var gold := Bau.teil(st, Bau.kugel_mesh(0.06, false, 12), Look.nuss("wal", true), Vector3(0, 0.56, 0), Vector3.ZERO, Vector3(1, 1.1, 1))
		gold.visible = (_opfer() >> i) & 1 == 1
		_opfer_nuesse.append(gold)
		var nr := i
		ia["opfer%d" % i] = Interaktiv.erzeuge(st, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.55, 0), "Goldene Nuss auf den Stumpf legen", func(_s): _opfern(nr))
		ia["opfer%d" % i].info = func(): return "Du hast %d Goldene Nüsse" % Game.gold
		_interaktiv_an(ia["opfer%d" % i], not gold.visible)
		var sb := StaticBody3D.new()
		sb.collision_layer = Data.L_WELT
		var cs := CollisionShape3D.new()
		var z := CylinderShape3D.new()
		z.radius = 0.3
		z.height = 0.5
		cs.shape = z
		cs.position.y = 0.25
		sb.add_child(cs)
		st.add_child(sb)
	# Der König auf dem Thron
	var thron := _eiche.find_child("Thron", true, false) as Node3D
	_koenig = eichhorn_figur(3.1, Color(0.62, 0.3, 0.12))
	_koenig.name = "Koenig"
	(thron if thron else _eiche).add_child(_koenig)
	_koenig.position = Vector3(0, 0.09, 0.02)
	_koenig.rotation.y = PI
	var k: Node3D = _koenig.get_child(0)
	k.scale = Vector3(3.6, 3.0, 3.1)
	var gold_m := Look.metall(Color(0.98, 0.8, 0.25), 0.2)
	k.add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.03, 0.026, 0.02, 10), gold_m, Vector3(0, 0.18, -0.08)))
	for j in 5:
		var w := TAU * j / 5.0
		k.add_child(Bau.mesh_instanz(Bau.zylinder_mesh(0.0, 0.008, 0.022, 4), gold_m, Vector3(cos(w) * 0.024, 0.2, -0.08 + sin(w) * 0.024)))
	var umhang := Bau.mesh_instanz(Bau.kugel_mesh(0.085, true, 12), Look.stoff(Color(0.6, 0.08, 0.1)), Vector3(0, 0.03, 0.03))
	umhang.scale = Vector3(1.0, 1.25, 1.2)
	k.add_child(umhang)
	ia["koenig"] = Interaktiv.erzeuge(_koenig, Vector3(0.6, 0.8, 0.6), Vector3(0, 0.35, 0), "Audienz beim Eichhörnchen-König", func(_s): _audienz())
	_koenig.visible = false
	_interaktiv_an(ia.koenig, false)
	_spuren()
	_kronenbaeume()


func _opfern(nr: int) -> void:
	if (_opfer() >> nr) & 1 == 1:
		return
	if Game.gold <= 0:
		Sfx.spiele("fehler", -8.0)
		Game.toast.emit("Hier hat jemand Nüsse abgelegt. Du hast keine Goldene Nuss dabei.", Game.FARBE_INFO)
		return
	Game.gold -= 1
	Game.extra["opfer"] = _opfer() | (1 << nr)
	(_opfer_nuesse[nr] as Node3D).visible = true
	_interaktiv_an(ia["opfer%d" % nr], false)
	Sfx.spiele("ablegen")
	Sfx.spiele("gold", -6.0)
	Game.stand_geaendert.emit()
	if _opfer() == 7:
		Game.toast.emit("Drei Gaben liegen. In der Eiche raschelt es. Komm wieder, wenn es dunkel ist.", Game.FARBE_GOLD)
	else:
		Game.toast.emit("Die Goldene Nuss liegt auf dem Stumpf. Irgendwer schaut zu.", Game.FARBE_INFO)


func _audienz() -> void:
	if not Game.fund("koenig"):
		return
	Sfx.spiele("glocke", -4.0)
	_zettel("Audienz beim Eichhörnchen-König", TEXT_AUDIENZ)


## Paarweise kleine Fußabdrücke vom Berg entlang des Wildpfads bis zur Eiche.
func _spuren() -> void:
	var pfad: Array = WeltPlan.WEGE[6][0]
	var punkte: Array = [Vector2(12.5, -47.0)] + pfad
	var abdruck := SphereMesh.new()
	abdruck.radius = 1.0
	abdruck.height = 2.0
	abdruck.radial_segments = 6
	abdruck.rings = 3
	var lagen: Array = []
	for i in punkte.size() - 1:
		var a: Vector2 = punkte[i]
		var b: Vector2 = punkte[i + 1]
		var n := int(a.distance_to(b) / 0.9)
		var richtung := (b - a).normalized()
		var quer := Vector2(-richtung.y, richtung.x)
		for j in n:
			var m := a.lerp(b, float(j) / n) + quer * sin(j * 0.6) * 0.25
			for s in [-1.0, 1.0]:
				var p: Vector2 = m + quer * s * 0.07
				var pos := Vector3(p.x, _g.hoehe_bei(p.x, p.y) + 0.012, p.y)
				lagen.append(Transform3D(Basis(Vector3.UP, atan2(richtung.x, richtung.y)).scaled(Vector3(0.028, 0.004, 0.045)), pos))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = abdruck
	mm.instance_count = lagen.size()
	for i in lagen.size():
		mm.set_instance_transform(i, lagen[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Fussspuren"
	mmi.multimesh = mm
	mmi.material_override = Bau.mat(Color(0.16, 0.11, 0.07), 1.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 30.0
	add_child(mmi)


## Fünf Bäume am Wildpfad tragen eine eingeritzte Krone.
func _kronenbaeume() -> void:
	var stellen := [Vector2(14.0, -53.5), Vector2(21.5, -57.0), Vector2(21.0, -66.0), Vector2(28.5, -67.5), Vector2(26.0, -73.5)]
	var gold := Bau.mat(Color(0.86, 0.7, 0.3), 0.6)
	for i in stellen.size():
		var p: Vector2 = stellen[i]
		var pos := _g.position(p.x, p.y)
		var baum := Node3D.new()
		baum.name = "Kronenbaum%d" % i
		add_child(baum)
		baum.global_position = pos
		var rinde := Look.holz([Color(0.36, 0.27, 0.2), Color(0.2, 0.14, 0.1)], 14.0, 0.0)
		Bau.teil(baum, Bau.zylinder_mesh(0.26, 0.38, 5.5, 10), rinde, Vector3(0, 2.75, 0))
		var laub := Look.laub(Color(0.86, 0.5, 0.14), Color(0.6, 0.3, 0.08)) if i % 2 == 0 else Look.laub(Color(0.5, 0.58, 0.2), Color(0.3, 0.4, 0.12))
		for j in 4:
			Bau.teil(baum, Bau.kugel_mesh(1.0, false, 12), laub, Vector3(sin(j * 1.9) * 1.1, 5.6 + (j % 2) * 0.9, cos(j * 1.9) * 1.1), Vector3.ZERO, Vector3.ONE * (1.5 + 0.25 * (j % 3)))
		Ersatz._koll(baum, Vector3(0.6, 4.0, 0.6), Vector3(0, 2.0, 0))
		# Krone zum Pfad hin eingeritzt
		var zum_pfad := Vector2(24.0, -64.0) - p
		var marke := Node3D.new()
		marke.rotation.y = atan2(zum_pfad.x, zum_pfad.y)
		baum.add_child(marke)
		Bau.teil(marke, Bau.box_mesh(Vector3(0.16, 0.035, 0.01)), gold, Vector3(0, 1.3, 0.335))
		for z in 3:
			Bau.teil(marke, Bau.box_mesh(Vector3(0.035, 0.09, 0.01)), gold, Vector3(-0.06 + z * 0.06, 1.36 + (0.02 if z == 1 else 0.0), 0.332), Vector3(0, 0, (z - 1) * -14.0))


# =============================================================================
# 4. Mini-Nussberg im Briefkasten
# =============================================================================
func _briefkasten() -> void:
	var kasten := _ort("briefkasten")
	if kasten == null:
		return
	_miniberg = Bau.teil(kasten, Bau.kugel_mesh(1.0, true, 12), Look.nusshaufen(0.02), Vector3(0.03, 1.075, 0.2), Vector3.ZERO, Vector3(0.12, 0.07, 0.1))
	_miniberg.set_meta("ohne_rand", true)
	for c in kasten.get_children():
		if c is Interaktiv:
			var alt: Callable = (c as Interaktiv).aktion
			(c as Interaktiv).aktion = func(sp):
				alt.call(sp)
				if Game.fund("miniberg"):
					Game.toast.emit("Im Briefkasten liegt ein winziger Nussberg. Maßstab 1 : 150.", Game.FARBE_INFO)
			ia["briefkasten"] = c


# =============================================================================
# 5. Flaschenpost, 6. O + F, 7. Goldene Walnuss
# =============================================================================
func _flaschenpost() -> void:
	var steg := _ort("angelplatz")
	if steg == null:
		return
	var flasche := Node3D.new()
	flasche.name = "Flaschenpost"
	flasche.position = Vector3(-0.9, -0.28, 2.15)
	flasche.rotation_degrees = Vector3(62, 30, 0)
	steg.add_child(flasche)
	Bau.teil(flasche, Bau.zylinder_mesh(0.045, 0.045, 0.2, 12), Look.glas(Color(0.6, 0.85, 0.7)))
	Bau.teil(flasche, Bau.zylinder_mesh(0.018, 0.04, 0.07, 10), Look.glas(Color(0.6, 0.85, 0.7)), Vector3(0, 0.135, 0))
	Bau.teil(flasche, Bau.zylinder_mesh(0.017, 0.015, 0.03, 8), Look.holz(Look.KIEFER, 12.0, 0.0), Vector3(0, 0.18, 0))
	Bau.teil(flasche, Bau.zylinder_mesh(0.022, 0.022, 0.13, 8), Bau.mat(Color(0.93, 0.88, 0.72)), Vector3(0, -0.01, 0))
	ia["flaschenpost"] = Interaktiv.erzeuge(steg, Vector3(0.4, 0.45, 0.4), Vector3(-0.9, -0.22, 2.15), "Flasche aus dem Schilf fischen", func(_s):
		Game.fund("flaschenpost")
		_zettel("Flaschenpost", BRIEF_FLASCHE))


func _herz() -> void:
	var bruecke := _ort("bruecke_oma")
	if bruecke == null:
		return
	var brett := Node3D.new()
	brett.name = "Herzbrett"
	brett.position = Vector3(0.0, 0.3, 0.0)
	bruecke.add_child(brett)
	Bau.teil(brett, Bau.box_mesh(Vector3(0.75, 0.36, 0.05)), Look.holz(Look.ALTHOLZ, 9.0, 0.0))
	for s in [-1.0, 1.0]:
		Bau.teil(brett, Bau.box_mesh(Vector3(0.06, 0.34, 0.06)), Look.holz(Look.NUSSBAUM, 6.0, 0.1), Vector3(s * 0.34, 0.2, 0))
	var kerbe := Bau.mat(Color(0.2, 0.12, 0.07), 1.0)
	for seite in [1.0, -1.0]:
		var fl := Node3D.new()
		fl.position = Vector3(0, 0, seite * 0.027)
		fl.rotation_degrees.y = 0.0 if seite > 0 else 180.0
		brett.add_child(fl)
		# Herz aus zwei Bögen und einer Spitze
		for s in [-1.0, 1.0]:
			Bau.teil(fl, Bau.kugel_mesh(0.045, false, 10), kerbe, Vector3(-0.24 + s * 0.036, 0.03, 0), Vector3.ZERO, Vector3(1, 1, 0.08))
		Bau.teil(fl, Bau.box_mesh(Vector3(0.085, 0.085, 0.004)), kerbe, Vector3(-0.24, -0.012, 0), Vector3(0, 0, 45))
		Bau.schrift(fl, "O + F", Vector3(0.08, 0.0, 0.002), 60, Color(0.2, 0.12, 0.07))
	ia["herz"] = Interaktiv.erzeuge(bruecke, Vector3(0.9, 0.5, 0.5), Vector3(0, 0.3, 0), "Schnitzerei ansehen", func(_s):
		if Game.fund("herz"):
			Game.toast.emit("Ein Herz, darin „O + F“. Opa und Frieda.", Game.FARBE_INFO))


func _goldwalnuss() -> void:
	var hochsitz := _ort("hochsitz")
	if hochsitz == null:
		return
	var nest := Node3D.new()
	nest.name = "Vogelnest"
	nest.position = Vector3(0.86, 5.48, 0.86)
	hochsitz.add_child(nest)
	var reisig := Look.putz(Color(0.45, 0.34, 0.2), Color(0.3, 0.22, 0.12), 140.0, 0.0, 1.0)
	Bau.teil(nest, Bau.box_mesh(Vector3(0.5, 0.04, 0.5)), Look.holz(Look.ALTHOLZ, 9.0, 0.0), Vector3(0, -0.06, 0))
	var kranz := TorusMesh.new()
	kranz.inner_radius = 0.09
	kranz.outer_radius = 0.19
	Bau.teil(nest, kranz, reisig, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.8, 1))
	for i in 2:
		Bau.teil(nest, Bau.kugel_mesh(0.03, false, 8), Bau.mat(Color(0.82, 0.88, 0.86), 0.5), Vector3(-0.05 + i * 0.07, 0.01, -0.04), Vector3.ZERO, Vector3(1, 1.25, 1))
	if not Game.hat_fund("goldwalnuss"):
		var nuss := Bau.teil(nest, Bau.kugel_mesh(0.05, false, 12), Look.nuss("wal", true), Vector3(0.02, 0.03, 0.05), Vector3.ZERO, Vector3(1, 1.1, 1))
		ia["goldwalnuss"] = Interaktiv.erzeuge(nest, Vector3(0.45, 0.35, 0.45), Vector3(0, 0.03, 0), "Ins Vogelnest greifen", func(_s):
			if Game.fund("goldwalnuss"):
				Game.gold += 10
				Game.stand_geaendert.emit()
				_spaeter_weg(nuss)
				_spaeter_weg(ia.goldwalnuss)
				Game.toast.emit("Die Goldene Walnuss! Das sind gut und gern 10 Goldene Nüsse.", Game.FARBE_GOLD))


# =============================================================================
# 8. Opas Keller (Raum wird erst beim Betreten gebaut)
# =============================================================================
func _keller_zugang() -> void:
	var werkstatt := _ort("Werkstatt")
	if werkstatt == null:
		return
	for c in werkstatt.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var gr: Vector3 = ((c as MeshInstance3D).mesh as BoxMesh).size
			if absf(gr.x - 2.6) < 0.01 and absf(gr.z - 1.7) < 0.01 and gr.y < 0.02:
				_teppich = c
	_falltuer = Node3D.new()
	_falltuer.name = "Falltuer"
	_falltuer.position = Vector3(5.85, 0.0, 0.3)
	werkstatt.add_child(_falltuer)
	var holz := Look.holz(Look.NUSSBAUM, 5.0, 0.1, 0.2, false)
	var d := Bau.teil(_falltuer, Bau.box_mesh(Vector3(0.95, 0.012, 0.95)), holz, Vector3(0, 0.007, 0))
	d.set_meta("ohne_rand", true)
	for s in [-1.0, 1.0]:
		Bau.teil(_falltuer, Bau.box_mesh(Vector3(0.95, 0.016, 0.05)), Look.metall(Color(0.25, 0.25, 0.27), 0.6), Vector3(0, 0.009, s * 0.3))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.04
	ring.outer_radius = 0.055
	Bau.teil(_falltuer, ring, Look.metall(Color(0.3, 0.3, 0.32), 0.5), Vector3(0.3, 0.022, 0))
	ia["falltuer"] = Interaktiv.erzeuge(_falltuer, Vector3(0.95, 0.08, 0.95), Vector3(0, 0.05, 0), "Falltür: in Opas Keller steigen", func(sp): _in_den_keller(sp))
	ia["teppich"] = Interaktiv.erzeuge(werkstatt, Vector3(2.6, 0.06, 1.7), Vector3(6.3, 0.045, 0.3), "Teppich anheben", func(_s): _teppich_heben(true))
	if int(Game.extra.get("teppich", 0)) == 1:
		_teppich_heben(false)
	else:
		_teppich_zeigen(false)


func _teppich_zeigen(offen: bool) -> void:
	_falltuer.visible = offen
	_interaktiv_an(ia.falltuer, offen)
	_interaktiv_an(ia.teppich, not offen)


func _teppich_heben(mit_ton: bool) -> void:
	Game.extra["teppich"] = 1
	_teppich_zeigen(true)
	if _teppich == null:
		return
	if mit_ton:
		Sfx.spiele("wischen", -4.0, 0.7)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_teppich, "scale:x", 0.3, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_teppich, "position:x", 7.2, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_teppich, "position:y", 0.04, 0.5)
		Game.toast.emit("Unter dem Teppich ist eine Falltür.", Game.FARBE_INFO)
	else:
		_teppich.scale.x = 0.3
		_teppich.position.x = 7.2
		_teppich.position.y = 0.04
	_teppich.scale.y = 9.0


func _raum_weg() -> void:
	if _raum and is_instance_valid(_raum):
		_raum.name = "Raum_alt"
		_spaeter_weg(_raum)
	_raum = null
	for k in ["keller_foto", "keller_leiter", "studio_tafel", "studio_ausgang"]:
		ia.erase(k)


## Geschlossener Raum aus Boden, Decke und vier Wänden. Innenmaße b x h x t, Mitte am Boden = Ursprung.
func _raum_huelle(b: float, h: float, t: float, boden: Material, wand: Material, decke: Material) -> Node3D:
	_raum_weg()
	_raum = Node3D.new()
	add_child(_raum)
	Bau.block(_raum, Vector3(b + 0.4, 0.2, t + 0.4), Vector3(0, -0.1, 0), boden)
	Bau.block(_raum, Vector3(b + 0.4, 0.2, t + 0.4), Vector3(0, h + 0.1, 0), decke)
	for s in [-1.0, 1.0]:
		Bau.block(_raum, Vector3(0.2, h, t + 0.4), Vector3(s * (b * 0.5 + 0.1), h * 0.5, 0), wand)
		Bau.block(_raum, Vector3(b, h, 0.2), Vector3(0, h * 0.5, s * (t * 0.5 + 0.1)), wand)
	return _raum


func _in_den_keller(sp: Node) -> void:
	var stein := Look.putz(Color(0.5, 0.47, 0.42), Color(0.38, 0.36, 0.33), 22.0, 0.3, 0.95)
	var r := _raum_huelle(5.0, 2.5, 4.0, Look.putz(Color(0.36, 0.3, 0.24), Color(0.28, 0.23, 0.18), 30.0, 0.0, 1.0), stein, Look.holz(Look.ALTHOLZ, 6.0, 0.0, 0.25, false))
	r.name = "Keller"
	r.position = KELLER_POS
	var licht := OmniLight3D.new()
	licht.position = Vector3(0, 2.0, 0)
	licht.light_color = Color(1.0, 0.78, 0.5)
	licht.light_energy = 1.6
	licht.omni_range = 7.0
	r.add_child(licht)
	Bau.teil(r, Bau.kugel_mesh(0.06, false, 10), Look.leuchten(Color(1.0, 0.85, 0.55), 4.0), Vector3(0, 2.2, 0))
	Bau.teil(r, Bau.zylinder_mesh(0.004, 0.004, 0.3, 4), Bau.mat(Color(0.1, 0.1, 0.1)), Vector3(0, 2.38, 0))
	# Archiv: von jedem Jahr seit 1974 ein Glas, an Nord- und Westwand
	var holz := Look.holz(Look.NUSSBAUM, 6.0, 0.2)
	var glas := Look.glas()
	var sorten := ["hasel", "wal", "mandel", "pekan"]
	var jahr := 1974
	for wand_nr in 2:
		for reihe in 4:
			var y := 0.45 + reihe * 0.48
			if wand_nr == 0:
				Bau.teil(r, Bau.box_mesh(Vector3(4.6, 0.03, 0.26)), holz, Vector3(0, y, -1.86))
			else:
				Bau.teil(r, Bau.box_mesh(Vector3(0.26, 0.03, 2.4)), holz, Vector3(-2.36, y, 0.4))
			var anzahl := 9 if wand_nr == 0 else 4
			for i in anzahl:
				if jahr > 2025:
					break
				var p: Vector3 = Vector3(-2.05 + i * 0.51, y + 0.015, -1.86) if wand_nr == 0 else Vector3(-2.36, y + 0.015, -0.5 + i * 0.6)
				Bau.teil(r, Bau.zylinder_mesh(0.085, 0.085, 0.22, 10), glas, p + Vector3(0, 0.11, 0))
				var fuell := 0.03 + 0.15 * float(jahr - 1974) / 51.0
				Bau.teil(r, Bau.zylinder_mesh(0.078, 0.078, fuell, 10), Look.nusshaufen(0.03) if jahr % 4 != 0 else Look.kern(sorten[jahr % 4]), p + Vector3(0, fuell * 0.5 + 0.004, 0))
				Bau.teil(r, Bau.zylinder_mesh(0.088, 0.088, 0.015, 10), Look.metall(Color(0.6, 0.5, 0.3), 0.5), p + Vector3(0, 0.226, 0))
				var schild_pos: Vector3 = p + (Vector3(0, 0.1, 0.088) if wand_nr == 0 else Vector3(0.088, 0.1, 0))
				Bau.teil(r, Bau.box_mesh(Vector3(0.1, 0.05, 0.002) if wand_nr == 0 else Vector3(0.002, 0.05, 0.1)), Bau.mat(Color(0.93, 0.9, 0.8)), schild_pos)
				Bau.schrift(r, str(jahr), schild_pos + (Vector3(0, 0, 0.002) if wand_nr == 0 else Vector3(0.002, 0, 0)), 30, Color(0.2, 0.12, 0.06), Vector3(0, 0 if wand_nr == 0 else 90, 0))
				jahr += 1
	Bau.holzschild(r, "ARCHIV · ein Glas pro Jahr", Vector3(0, 2.25, -1.97), Vector2(1.6, 0.2), Vector3.ZERO, 54)
	# Kisten, Fass, Spinnweben ohne Spinnen
	Modelle.setze(r, "kueche/barrel.glb", Vector3(1.9, 0, 1.4), 0.0, 1.2)
	Bau.block(r, Vector3(0.7, 0.5, 0.6), Vector3(1.85, 0.25, 0.5), Look.holz(Look.KIEFER, 8.0, 0.0), true, Vector3(0, 12, 0))
	# Das alte Foto an der Ostwand
	var foto := Node3D.new()
	foto.position = Vector3(2.39, 1.5, -0.6)
	foto.rotation_degrees.y = -90
	r.add_child(foto)
	_altes_foto(foto)
	ia["keller_foto"] = Interaktiv.erzeuge(r, Vector3(0.2, 0.6, 0.7), Vector3(2.3, 1.5, -0.6), "Altes Foto ansehen", func(_s):
		Game.fund("keller")
		_zettel("Haselgrund, Herbst 1974", TEXT_FOTO))
	# Leiter nach oben
	for s in [-1.0, 1.0]:
		Bau.teil(r, Bau.box_mesh(Vector3(0.06, 2.5, 0.06)), holz, Vector3(1.2 + s * 0.24, 1.25, 1.88), Vector3(6, 0, 0))
	for i in 8:
		Bau.teil(r, Bau.box_mesh(Vector3(0.48, 0.04, 0.04)), holz, Vector3(1.2, 0.3 + i * 0.3, 1.9 - i * 0.03))
	Bau.teil(r, Bau.box_mesh(Vector3(0.9, 0.02, 0.9)), Bau.mat(Color(0.95, 0.85, 0.6)), Vector3(1.2, 2.49, 1.5))
	ia["keller_leiter"] = Interaktiv.erzeuge(r, Vector3(0.7, 2.2, 0.4), Vector3(1.2, 1.2, 1.8), "Leiter: zurück in die Werkstatt", func(s2): _raum_verlassen(s2))
	# Figur im Regal
	_figur_aufstellen("keller", r, Vector3(-2.3, 0.465, 1.75), 100.0)
	_rueckweg = Vector3(5.85, 0.05, 1.25)
	Sfx.spiele("knarzen", -6.0, 0.7)
	_versetzen(sp, KELLER_POS + Vector3(1.2, 0.1, 1.1))
	(sp as Node3D).rotation.y = 0.0


## Das alte Foto: winzige Hütte, ein Korb, zwei Leute, leere Wiese.
func _altes_foto(k: Node3D) -> void:
	var braun := Bau.mat(Color(0.36, 0.24, 0.14), 0.9)
	Bau.teil(k, Bau.box_mesh(Vector3(0.62, 0.48, 0.025)), Look.holz(Look.NUSSBAUM, 8.0, 0.3))
	Bau.teil(k, Bau.box_mesh(Vector3(0.54, 0.4, 0.006)), Look.putz(Color(0.86, 0.78, 0.6), Color(0.78, 0.69, 0.5), 90.0, 0.0, 0.9), Vector3(0, 0, 0.013))
	Bau.teil(k, Bau.box_mesh(Vector3(0.5, 0.004, 0.002)), braun, Vector3(0, -0.09, 0.017))
	Bau.teil(k, Bau.box_mesh(Vector3(0.11, 0.08, 0.002)), braun, Vector3(-0.15, -0.05, 0.017))
	Bau.teil(k, Bau.box_mesh(Vector3(0.1, 0.1, 0.002)), braun, Vector3(-0.15, 0.0, 0.0172), Vector3(0, 0, 45), Vector3(1, 0.6, 1))
	for s in [0.0, 1.0]:
		Bau.teil(k, Bau.box_mesh(Vector3(0.018, 0.07 - s * 0.008, 0.002)), braun, Vector3(-0.02 + s * 0.045, -0.055, 0.017))
		Bau.teil(k, Bau.kugel_mesh(0.012, false, 8), braun, Vector3(-0.02 + s * 0.045, -0.008 - s * 0.006, 0.017), Vector3.ZERO, Vector3(1, 1, 0.15))
	Bau.teil(k, Bau.kugel_mesh(0.016, true, 8), braun, Vector3(0.06, -0.09, 0.017), Vector3.ZERO, Vector3(1, 1, 0.15))
	Bau.schrift(k, "Haselgrund, Herbst 1974", Vector3(0, -0.16, 0.0175), 22, Color(0.3, 0.2, 0.12))


func _raum_verlassen(sp: Node) -> void:
	Sfx.variante("footstep_wood", -8.0, 0.9)
	_versetzen(sp, _rueckweg)
	_raum_weg()


# =============================================================================
# 11. Das Studio hinter dem Wasserfall
# =============================================================================
func _studio_zugang() -> void:
	var kante: Vector3 = WeltPlan.BACH[WeltPlan.BACH_KANTE]
	var becken: Vector3 = WeltPlan.BACH[WeltPlan.BACH_KANTE + 1]
	var richtung := Vector3(becken.x - kante.x, 0, becken.z - kante.z).normalized()
	var k := Node3D.new()
	k.name = "Wasserfallzugang"
	add_child(k)
	k.global_position = Vector3(kante.x, becken.y, kante.z) + richtung * 1.6
	k.rotation.y = atan2(richtung.x, richtung.z)
	ia["wasserfall"] = Interaktiv.erzeuge(k, Vector3(2.2, 2.4, 0.9), Vector3(0, 1.3, 0), "Hinter den Wasserfall treten", func(sp): _ins_studio(sp))
	var ufer := becken + richtung * 5.5
	k.set_meta("ufer", _g.position(ufer.x, ufer.z) + Vector3(0, 0.25, 0))


func _ins_studio(sp: Node) -> void:
	var r := _raum_huelle(4.2, 2.5, 3.6, Look.holz([Color(0.7, 0.5, 0.32), Color(0.44, 0.28, 0.16)], 6.0, 0.25, 0.16, true),
		Look.putz(Color(0.36, 0.34, 0.32), Color(0.26, 0.25, 0.24), 20.0, 0.0, 0.95), Look.putz(Color(0.3, 0.28, 0.27), Color(0.22, 0.21, 0.2), 20.0, 0.0, 0.95))
	r.name = "Studio"
	r.position = STUDIO_POS
	var lampe := Einrichtung.haengelampe(r, Vector3(0, 2.0, -0.4), 1.8)
	lampe.omni_range = 6.0
	# Schreibtisch mit Bildschirm, Zetteln, Tasse und Gummiente
	Einrichtung.tisch(r, Vector3(0, 0, -1.3), Vector3(2.0, 0.78, 0.8))
	Einrichtung.hocker(r, Vector3(0.1, 0, -0.55))
	Bau.teil(r, Bau.box_mesh(Vector3(0.7, 0.42, 0.04)), Look.plastik(Color(0.08, 0.08, 0.09), 0.5), Vector3(0, 1.15, -1.5), Vector3(-6, 0, 0))
	Bau.teil(r, Bau.box_mesh(Vector3(0.64, 0.36, 0.005)), Look.leuchten(Color(0.55, 0.42, 0.25), 1.2), Vector3(0, 1.15, -1.478), Vector3(-6, 0, 0))
	Bau.schrift(r, "func _ready() -> void:\n    nuesse = 1_000_000\n    # TODO: nachzählen", Vector3(0, 1.16, -1.474), 20, Color(1.0, 0.9, 0.6), Vector3(-6, 0, 0), 500)
	Bau.teil(r, Bau.box_mesh(Vector3(0.1, 0.22, 0.1)), Look.plastik(Color(0.08, 0.08, 0.09), 0.5), Vector3(0, 0.89, -1.5))
	Bau.teil(r, Bau.box_mesh(Vector3(0.5, 0.02, 0.17)), Look.plastik(Color(0.15, 0.15, 0.16), 0.6), Vector3(0, 0.79, -1.15))
	Modelle.setze(r, "kueche/mug.glb", Vector3(0.62, 0.78, -1.2), 30.0, 0.34)
	for i in 4:
		Bau.teil(r, Bau.box_mesh(Vector3(0.2, 0.003, 0.28)), Bau.mat(Color(0.94, 0.92, 0.85)), Vector3(-0.7 + i * 0.05, 0.782 + i * 0.003, -1.25 + i * 0.02), Vector3(0, i * 14.0 - 20.0, 0))
	var gelb := Look.plastik(Color(0.98, 0.82, 0.12), 0.35)
	var ente := Node3D.new()
	ente.name = "Gummiente"
	ente.position = Vector3(-0.38, 0.78, -1.45)
	ente.rotation_degrees.y = 25
	r.add_child(ente)
	Bau.teil(ente, Bau.kugel_mesh(0.06, false, 12), gelb, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 0.8, 1.25))
	Bau.teil(ente, Bau.kugel_mesh(0.04, false, 12), gelb, Vector3(0, 0.12, 0.045))
	Bau.teil(ente, Bau.box_mesh(Vector3(0.03, 0.012, 0.03)), Look.plastik(Color(0.95, 0.45, 0.1), 0.4), Vector3(0, 0.115, 0.09))
	for s in [-1.0, 1.0]:
		Bau.teil(ente, Bau.kugel_mesh(0.006, false, 6), Bau.mat(Color(0.05, 0.05, 0.05)), Vector3(s * 0.018, 0.133, 0.078))
	# Klebezettel an der Westwand
	var zettel := ["Eichhörnchen\nzu frech?", "Berg: 1.000.000\n– nachzählen!", "Nadel nicht\nvergessen", "Mehr\nKNACK", "Opa\nhat recht"]
	var farben := [Color(1.0, 0.9, 0.4), Color(0.6, 0.9, 0.6), Color(1.0, 0.7, 0.75), Color(0.6, 0.8, 1.0), Color(1.0, 0.9, 0.4)]
	for i in zettel.size():
		var zp := Vector3(-2.09, 1.75 - (i / 3) * 0.4, -0.9 + (i % 3) * 0.42)
		Bau.teil(r, Bau.box_mesh(Vector3(0.004, 0.26, 0.26)), Bau.mat(farben[i], 0.9), zp, Vector3((i % 2) * 6.0 - 3.0, 0, 0))
		Bau.schrift(r, zettel[i], zp + Vector3(0.004, 0, 0), 22, Color(0.15, 0.12, 0.1), Vector3(0, 90, 0))
	# Tafel mit den Namen des Teams an der Ostwand
	var tafel := Node3D.new()
	tafel.position = Vector3(2.08, 1.5, -0.3)
	tafel.rotation_degrees.y = -90
	r.add_child(tafel)
	Bau.teil(tafel, Bau.box_mesh(Vector3(1.5, 1.0, 0.03)), Look.holz(Look.NUSSBAUM, 4.0, 0.3))
	Bau.teil(tafel, Bau.box_mesh(Vector3(1.4, 0.9, 0.01)), Look.putz(Color(0.16, 0.2, 0.17), Color(0.13, 0.16, 0.14), 120.0, 0.0, 0.9), Vector3(0, 0, 0.012))
	Bau.schrift(tafel, "DEEZ NUTS!\ngebaut von\n%s" % "\n".join(PackedStringArray(Data.TEAM)), Vector3(0, 0, 0.02), 110, Color(0.95, 0.95, 0.9), Vector3.ZERO, 600)
	ia["studio_tafel"] = Interaktiv.erzeuge(r, Vector3(0.2, 1.0, 1.5), Vector3(1.98, 1.5, -0.3), "Tafel lesen", func(_s):
		Game.fund("studio")
		_zettel("Hinter dem Wasserfall", "Hier wurde Deez Nuts! gebaut.\n\nVon: %s\n\nDanke fürs Spielen. Und fürs Suchen: Wer bis hierher kommt, schaut wirklich hinter alles.\n\nDie Gummiente heißt übrigens Walter junior." % ", ".join(PackedStringArray(Data.TEAM))))
	# Ausgang: der Wasservorhang an der Südwand
	Bau.teil(r, Bau.box_mesh(Vector3(1.6, 2.2, 0.03)), Look.glas(Color(0.6, 0.8, 0.9)), Vector3(0, 1.1, 1.78))
	Bau.teil(r, Bau.box_mesh(Vector3(1.7, 2.3, 0.02)), Look.leuchten(Color(0.5, 0.65, 0.75), 0.5), Vector3(0, 1.15, 1.795))
	ia["studio_ausgang"] = Interaktiv.erzeuge(r, Vector3(1.6, 2.2, 0.3), Vector3(0, 1.1, 1.65), "Zurück durch den Wasserfall", func(s2): _raum_verlassen(s2))
	var zugang := get_node("Wasserfallzugang")
	_rueckweg = zugang.get_meta("ufer")
	Sfx.spiele("rutsch", -6.0, 0.8)
	_versetzen(sp, STUDIO_POS + Vector3(0, 0.1, 0.9))
	(sp as Node3D).rotation.y = 0.0


# =============================================================================
# 9. Sir Nussbert
# =============================================================================
## Lässt Sir Nussbert sofort erscheinen (sonst kommt er von selbst alle paar Minuten für eine Minute).
func nussbert_jetzt() -> SammelHelfer:
	if welt._helfer_knoten.is_empty():
		return null
	if _nb_helfer and is_instance_valid(_nb_helfer):
		_nb_helfer.setze_nussbert(false)
	_nb_helfer = welt._helfer_knoten[_rng.randi() % welt._helfer_knoten.size()]
	_nb_helfer.setze_nussbert(true)
	_nb_aktiv = 60.0
	_nb_blick = 0.0
	return _nb_helfer


func _nussbert(delta: float) -> void:
	if _nb_aktiv <= 0.0:
		if Game.hat_fund("nussbert") or welt._helfer_knoten.is_empty():
			return
		_nb_timer -= delta
		if _nb_timer <= 0.0:
			_nb_timer = _rng.randf_range(240.0, 600.0)
			nussbert_jetzt()
		return
	_nb_aktiv -= delta
	if _nb_helfer == null or not is_instance_valid(_nb_helfer):
		_nb_aktiv = 0.0
		return
	if _nb_aktiv <= 0.0:
		_nb_helfer.setze_nussbert(false)
		return
	if Game.hat_fund("nussbert"):
		return
	# Schaut der Spieler ihn drei Sekunden lang an?
	var kam: Camera3D = welt.spieler.kamera
	var zu := _nb_helfer.global_position + Vector3(0, 0.3, 0) - kam.global_position
	nussbert_winkel = rad_to_deg((-kam.global_transform.basis.z).angle_to(zu))
	var sieht := zu.length() < 22.0 and nussbert_winkel < 9.0
	_nb_blick = _nb_blick + delta if sieht else maxf(0.0, _nb_blick - delta * 2.0)
	if _nb_blick >= 3.0:
		_nb_helfer.hutgruss()
		Game.fund("nussbert")
		Game.toast.emit("Sir Nussbert lüftet den Zylinder.", Game.FARBE_GOLD)
		_nb_aktiv = minf(_nb_aktiv, 6.0)


# =============================================================================
# 10. Der Hexenring
# =============================================================================
func _hexenring() -> void:
	var o: Vector3 = WeltPlan.ORTE.hexenring
	_ring = Node3D.new()
	_ring.name = "Hexenring"
	add_child(_ring)
	_ring.global_position = _g.position(o.x, o.z)
	var stiel := Bau.mat(Color(0.9, 0.88, 0.8), 0.8)
	var hut := Look.leuchten(Color(0.45, 1.0, 0.8), 2.4)
	var r := RandomNumberGenerator.new()
	r.seed = 13
	for i in 11:
		var w := TAU * i / 11.0 + r.randf_range(-0.08, 0.08)
		var p := Vector3(cos(w) * 1.5, 0, sin(w) * 1.5)
		var h := r.randf_range(0.12, 0.26)
		Bau.teil(_ring, Bau.zylinder_mesh(0.018, 0.026, h, 6), stiel, p + Vector3(0, h * 0.5, 0), Vector3(r.randf_range(-8, 8), 0, r.randf_range(-8, 8)))
		Bau.teil(_ring, Bau.kugel_mesh(0.075, true, 10), hut, p + Vector3(0, h - 0.01, 0), Vector3.ZERO, Vector3(1, 0.7, 1) * r.randf_range(0.8, 1.3))
	var licht := OmniLight3D.new()
	licht.position = Vector3(0, 0.5, 0)
	licht.light_color = Color(0.45, 1.0, 0.8)
	licht.light_energy = 0.8
	licht.omni_range = 4.5
	_ring.add_child(licht)
	_ring.visible = false


func hexenring_aktiv() -> bool:
	return Game.ist_nacht() and Game.spielzeit - Game.letzter_regen < 1800.0


func _hexenring_pruefen(delta: float) -> void:
	if _ring == null:
		return
	var an := hexenring_aktiv()
	if an != _ring.visible:
		_ring.visible = an
		_figur_sichtbar("hexenring", an)
	if _sternbild and is_instance_valid(_sternbild):
		_stern_zeit -= delta
		if _stern_zeit <= 0.0:
			_sternbild.queue_free()
			_sternbild = null
	if not an or welt.spieler == null:
		return
	var sp: Vector3 = welt.spieler.global_position
	if Vector2(sp.x - _ring.global_position.x, sp.z - _ring.global_position.z).length() < 1.25 and absf(sp.y - _ring.global_position.y) < 2.0:
		if Game.spielzeit >= float(Game.extra.get("hexen_bis", 0.0)):
			Game.extra["hexen_bis"] = Game.spielzeit + 600.0
			Sfx.spiele("glocke", -6.0, 1.4)
			Game.fund("hexenring")
			Game.toast.emit("Über dir leuchtet ein Sternbild in Nussform. 10 Minuten lang doppelt so viele Goldene Nüsse!", Game.FARBE_GOLD)
			_sternbild_zeigen()


## Ein Sternbild in Nussform über dem Ring, für eine Viertelminute.
func _sternbild_zeigen() -> void:
	if _sternbild and is_instance_valid(_sternbild):
		_sternbild.queue_free()
	_sternbild = Node3D.new()
	_sternbild.position = Vector3(0, 14.0, -6.0)
	_sternbild.rotation_degrees.x = 55
	_ring.add_child(_sternbild)
	var stern := Look.leuchten(Color(1.0, 0.95, 0.75), 8.0)
	for i in 12:
		var w := TAU * i / 12.0
		var p := Vector3(cos(w) * 2.2, sin(w) * 2.9 + (0.5 if i == 3 else 0.0), 0)
		Bau.teil(_sternbild, Bau.kugel_mesh(0.09 + 0.04 * (i % 3), false, 6), stern, p)
	Bau.teil(_sternbild, Bau.kugel_mesh(0.1, false, 6), stern, Vector3(0, 3.9, 0))
	_stern_zeit = 15.0


# =============================================================================
# Küche: Vitrine für die Nadel, Kellerfoto, goldener Nussknacker
# =============================================================================
func _kueche() -> void:
	# Vitrine an der Südwand
	_vitrine = Node3D.new()
	_vitrine.name = "Nadelvitrine"
	_vitrine.position = Vector3(1.35, 1.45, 2.8)
	add_child(_vitrine)
	Bau.teil(_vitrine, Bau.box_mesh(Vector3(0.3, 0.03, 0.16)), Look.holz(Look.NUSSBAUM, 6.0, 0.3))
	Bau.teil(_vitrine, Bau.box_mesh(Vector3(0.22, 0.012, 0.1)), Look.stoff(Color(0.5, 0.1, 0.12)), Vector3(0, 0.02, 0))
	Bau.teil(_vitrine, Bau.box_mesh(Vector3(0.26, 0.16, 0.13)), Look.glas(), Vector3(0, 0.095, 0))
	Bau.teil(_vitrine, Bau.zylinder_mesh(0.0015, 0.0003, 0.03, 5), Look.metall(Color(1.0, 0.8, 0.25), 0.15), Vector3(0, 0.03, 0), Vector3(0, 0, 90), Vector3(2.2, 2.2, 2.2))
	Bau.schrift(_vitrine, "Die Nadel", Vector3(0, -0.045, -0.081), 22, Color(0.9, 0.85, 0.7), Vector3(0, 180, 0))
	Bau.teil(_vitrine, Bau.box_mesh(Vector3(0.2, 0.05, 0.004)), Look.metall(Color(0.6, 0.5, 0.3), 0.5), Vector3(0, -0.045, -0.079))
	# Foto aus dem Keller, neben der Tafel
	_foto_kueche = Node3D.new()
	_foto_kueche.name = "Kellerfoto"
	_foto_kueche.position = Vector3(-1.45, 1.75, 2.885)
	_foto_kueche.rotation_degrees = Vector3(0, 180, 2)
	add_child(_foto_kueche)
	_altes_foto(_foto_kueche)
	# Goldener Nussknacker auf einer kleinen Konsole
	_trophaee = Node3D.new()
	_trophaee.name = "GoldenerNussknacker"
	_trophaee.position = Vector3(2.2, 1.25, 2.78)
	_trophaee.rotation_degrees.y = 180
	add_child(_trophaee)
	Bau.teil(_trophaee, Bau.box_mesh(Vector3(0.3, 0.03, 0.2)), Look.holz(Look.NUSSBAUM, 6.0, 0.3))
	var figur := Node3D.new()
	figur.position = Vector3(0, 0.015, 0)
	figur.scale = Vector3.ONE * 1.3
	_trophaee.add_child(figur)
	Ersatz.nussknacker_figur(figur)
	var gold := Look.metall(Color(1.0, 0.8, 0.25), 0.2)
	for mi in figur.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = gold


func _trophaeen_zeigen() -> void:
	if _vitrine:
		_vitrine.visible = Game.hat_fund("nadel")
	if _foto_kueche:
		_foto_kueche.visible = Game.hat_fund("keller")
	if _trophaee:
		_trophaee.visible = Game.hat_fund("figuren")


# =============================================================================
# 12. Opas Nussknacker-Figuren
# =============================================================================
func figuren_gefunden() -> Array:
	var f = Game.extra.get("figuren", [])
	return f if typeof(f) == TYPE_ARRAY else []


func _figuren_bauen() -> void:
	_figur_aufstellen("kueche", self, Vector3(2.78, 1.865, 2.62), -90.0)
	_figur_aufstellen("werkstatt", self, Vector3(7.35, 0.905, 2.55), 170.0)
	_figur_an("veranda", "veranda", Vector3(4.0, 0.67, -0.95), 0.0)
	_figur_an("brunnen", "brunnen", Vector3(0.0, 0.8, 0.68), 0.0)
	_figur_an("hochsitz", "hochsitz", Vector3(0.82, 3.66, -0.3), -60.0)
	_figur_an("picknick", "picknick", Vector3(0.75, 0.8, -0.15), 200.0)
	_figur_an("koehler", "koehlerhuette_ruine", Vector3(-1.1, 0.7, -1.2), 20.0)
	_figur_an("lagerhaus", "lagerhaus_alt", Vector3(2.16, 0.02, -0.4), 90.0)
	_figur_an("angelplatz", "angelplatz", Vector3(-0.45, 0.25, 0.5), 150.0)
	_figur_an("koenigseiche", "koenigseiche", Vector3(1.75, 0.05, 2.75), 30.0)
	if _ring:
		_figur_aufstellen("hexenring", _ring, Vector3(0, 0, 0), 0.0)
		_figur_sichtbar("hexenring", false)
	_figur_sichtbar("lagerhaus", false)


func _figur_an(id: String, ort: String, lokal: Vector3, drehung: float) -> void:
	var k := _ort(ort)
	if k:
		_figur_aufstellen(id, k, lokal, drehung)


func _figur_aufstellen(id: String, eltern: Node3D, pos: Vector3, drehung: float) -> void:
	if id in figuren_gefunden():
		return
	var f := Node3D.new()
	f.name = "Figur_" + id
	f.position = pos
	f.rotation_degrees.y = drehung
	eltern.add_child(f)
	Ersatz.nussknacker_figur(f)
	var i := Interaktiv.erzeuge(f, Vector3(0.2, 0.36, 0.2), Vector3(0, 0.17, 0), "Opas Nussknacker-Figur mitnehmen", func(_s): figur_nehmen(id))
	i.info = func(): return "%d von %d gefunden" % [figuren_gefunden().size(), FIGUREN.size()]
	f.set_meta("ia", i)
	_figuren[id] = f


func _figur_sichtbar(id: String, an: bool) -> void:
	if not _figuren.has(id) or not is_instance_valid(_figuren[id]):
		return
	var f: Node3D = _figuren[id]
	if f.visible == an:
		return
	f.visible = an
	_interaktiv_an(f.get_meta("ia"), an)


func figur_nehmen(id: String) -> void:
	var liste := figuren_gefunden().duplicate()
	if id in liste or not id in FIGUREN:
		return
	liste.append(id)
	Game.extra["figuren"] = liste
	if _figuren.has(id):
		_spaeter_weg(_figuren[id])
	_figuren.erase(id)
	Sfx.spiele("greifen")
	Sfx.spiele("ziel", -6.0)
	if liste.size() >= FIGUREN.size():
		Game.fund("figuren")
		Game.toast.emit("Alle zwölf Figuren! Trefferzone dauerhaft +3 %. Der Goldene Nussknacker steht jetzt in der Küche.", Game.FARBE_GOLD)
		_parade_starten()
	else:
		Game.toast.emit("Nussknacker-Figur %d von %d" % [liste.size(), FIGUREN.size()], Game.FARBE_GUT)


## Die zwölf Figuren marschieren eine halbe Minute lang im Gänsemarsch um die Hütte.
func _parade_starten() -> void:
	for e in _parade:
		if is_instance_valid(e):
			e.queue_free()
	_parade.clear()
	for i in 12:
		var f := Node3D.new()
		f.scale = Vector3.ONE * 2.6
		add_child(f)
		Ersatz.nussknacker_figur(f)
		_parade.append(f)
	_parade_zeit = 30.0
	Sfx.spiele("meilenstein")
	Sfx.spiele("freischalten", -3.0)


func parade_laeuft() -> bool:
	return _parade_zeit > 0.0 and not _parade.is_empty()


func _parade_bewegen(delta: float) -> void:
	if _parade.is_empty():
		return
	_parade_zeit -= delta
	var mitte := Vector2(3.5, 1.0)
	for i in _parade.size():
		var f: Node3D = _parade[i]
		var w := _zeit * 0.22 - i * 0.14
		var p := mitte + Vector2(cos(w) * 12.5, sin(w) * 9.0)
		f.global_position = Vector3(p.x, _g.hoehe_bei(p.x, p.y) + absf(sin(_zeit * 7.0 + i * 0.9)) * 0.1, p.y)
		f.rotation.y = atan2(-sin(w) * 12.5, cos(w) * 9.0)
	if _parade_zeit <= 0.0:
		for f in _parade:
			Effekte.funken(welt, (f as Node3D).global_position + Vector3(0, 0.4, 0), Color(1.0, 0.85, 0.4), 8, 0.5)
			f.queue_free()
		_parade.clear()
