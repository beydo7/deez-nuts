extends Node
## Spielstand, Wirtschaft, Talente, Bestellungen und Speichern.
## Alles, was über einen Neustart des Spiels hinaus erhalten bleibt, lebt hier.

signal geld_geaendert
signal stand_geaendert
signal toast(text: String, farbe: Color)
signal aera_erreicht(aera: int, schicht: String)
signal werkzeug_geaendert
signal maschine_gekauft(id: String)
signal talent_gelernt(id: String)
signal bestellungen_geaendert
signal knack_ergebnis(ergebnis: String, text: String)
signal berg_leer
signal ziel_geaendert
signal verkauft(betrag: float, pos: Vector3)

var SPEICHER_PFAD := "user://spielstand.json"
var selbsttest := false
const SPEICHER_VERSION := 1

const FARBE_GUT := Color(0.55, 0.95, 0.45)
const FARBE_INFO := Color(1.0, 0.9, 0.6)
const FARBE_WARN := Color(1.0, 0.55, 0.35)
const FARBE_GOLD := Color(1.0, 0.82, 0.25)

var rng := RandomNumberGenerator.new()

# --- Stand -------------------------------------------------------------------
var muenzen: float = 0.0
var gold: int = 0
var mp: int = 0
var mp_gesamt: int = 0
var geknackt: int = 0          # alle geknackten Nüsse (Hand + Maschine)
var genommen: int = 0          # Nüsse, die den Berg verlassen haben
var combo: int = 0
var energie: float = 0.0
var aera: int = 1
var naechster_meilenstein: int = 1
var werkzeuge := {"haende": 0}  # id -> Upgrade-Stufe
var werkzeug_aktiv := "haende"
var maschinen := {}             # id -> Stufe (vorhanden = gekauft)
var talente := {}               # id -> Stufe
var bestellungen: Array = []
var behaelter := {}             # vom World-Skript befüllt / gelesen
var statistik := {"perfekt": 0, "bruch": 0, "matsch": 0, "verkauft": 0.0, "gestohlen": 0, "verscheucht": 0}
var erster_start := true
var berg_fertig := false
var spielzeit: float = 0.0
var ziel_index: int = 0
var ziel_zaehler: int = 0

var einstellungen := {
	"empfindlichkeit": 0.25,
	"hilfsring": true,
	"tippen": false,
	"lautstaerke": 0.8,
	"musik": 0.6,
}

var _speicher_timer := 0.0
var _hitstop_ende := 0
var _zins_timer := 0.0
var _laden_erfolgt := false


func _ready() -> void:
	rng.randomize()
	_eingaben_anlegen()
	if "--selbsttest" in OS.get_cmdline_user_args():
		selbsttest = true
		SPEICHER_PFAD = "user://selbsttest.json"
		if FileAccess.file_exists(SPEICHER_PFAD):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SPEICHER_PFAD))
	laden()
	_pruefe_aera(false)
	if bestellungen.is_empty():
		_bestellungen_auffuellen()
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001, float(einstellungen.lautstaerke))))


func _process(delta: float) -> void:
	if _hitstop_ende > 0 and Time.get_ticks_msec() >= _hitstop_ende:
		_hitstop_ende = 0
		Engine.time_scale = 1.0
	spielzeit += delta
	_bestellungen_ticken(delta)
	_speicher_timer += delta
	if _speicher_timer > 30.0:
		_speicher_timer = 0.0
		speichern()
	if hat_talent("nussbaron"):
		_zins_timer += delta
		if _zins_timer >= 60.0:
			_zins_timer = 0.0
			var zins: float = min(muenzen * 0.01, 500.0)
			if zins >= 1.0:
				verdiene(zins, false)
				toast.emit("Zinsen: +%s Münzen" % Data.zahl(zins), FARBE_GOLD)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		speichern()


# --- Eingaben (werden zur Laufzeit angelegt, damit project.godot schlank bleibt) ---
func _eingaben_anlegen() -> void:
	var tasten := {
		"vor": [KEY_W, KEY_UP], "zurueck": [KEY_S, KEY_DOWN], "links": [KEY_A, KEY_LEFT], "rechts": [KEY_D, KEY_RIGHT],
		"springen": [KEY_SPACE], "rennen": [KEY_SHIFT], "benutzen": [KEY_E], "fallenlassen": [KEY_Q],
		"wischen": [KEY_F], "hebel": [KEY_R], "talente": [KEY_TAB], "hilfsring": [KEY_H], "pause": [KEY_ESCAPE],
		"cheat_geld": [KEY_F9], "cheat_nuesse": [KEY_F10], "cheat_mp": [KEY_F11],
	}
	for aktion in tasten:
		if not InputMap.has_action(aktion):
			InputMap.add_action(aktion)
		for k in tasten[aktion]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(aktion, ev)
	var maus := {"druecken": MOUSE_BUTTON_LEFT, "rechts_klick": MOUSE_BUTTON_RIGHT}
	for aktion in maus:
		if not InputMap.has_action(aktion):
			InputMap.add_action(aktion)
		var mev := InputEventMouseButton.new()
		mev.button_index = maus[aktion]
		InputMap.action_add_event(aktion, mev)


# --- Abgeleitete Werte -------------------------------------------------------
func talent(id: String) -> int:
	return int(talente.get(id, 0))


func hat_talent(id: String) -> bool:
	return talent(id) > 0


func hat_maschine(id: String) -> bool:
	return maschinen.has(id)


func maschinen_stufe(id: String) -> int:
	return int(maschinen.get(id, -1))


func preis_faktor() -> float:
	return 1.0 + 0.05 * talent("feilschen")


func combo_max() -> int:
	return 20 + 10 * talent("rhythmus")


func combo_bonus() -> float:
	return min(combo, combo_max()) * 0.05


func gold_chance() -> float:
	return Data.CHANCE_GOLD * (2.0 if hat_talent("goldhand") else 1.0)


func werkzeug_werte(id: String = "") -> Dictionary:
	if id == "":
		id = werkzeug_aktiv
	var w: Dictionary = Data.werkzeug(id)
	var stufe := int(werkzeuge.get(id, 0))
	return {
		"id": id,
		"name": w.name,
		"kraft": w.kraft * (1.0 + 0.05 * stufe),
		"zeit": w.zeit * pow(0.95, stufe),
		"sweet": w.sweet + 0.005 * stufe + 0.02 * talent("ruhige_hand"),
		"stufe": stufe,
	}


func maschinen_tempo() -> float:
	return 1.0 + 0.1 * talent("gut_geoelt")


func walzen_praezision() -> float:
	var stufe: int = max(0, maschinen_stufe("walze"))
	var p := 0.4 + 0.05 * stufe
	if hat_talent("selbstlaeufer"):
		p += 0.2
	return min(p, 0.98)


func energie_pro_schale() -> float:
	return 3.0 * (1.5 if hat_talent("schalenglut") else 1.0)


func berg_rest() -> int:
	return max(0, Data.BERG_GROESSE - genommen)


func schicht() -> Dictionary:
	return Data.schicht_fuer(genommen)


# --- Geld --------------------------------------------------------------------
func verdiene(betrag: float, mit_steuer := true) -> float:
	if mit_steuer and hat_talent("koenigsbund"):
		betrag *= 0.9
	muenzen += betrag
	statistik.verkauft += betrag
	geld_geaendert.emit()
	return betrag


func ausgeben(betrag: float) -> bool:
	if muenzen + 0.001 < betrag:
		Sfx.spiele("fehler")
		toast.emit("Nicht genug Münzen", FARBE_WARN)
		return false
	muenzen -= betrag
	geld_geaendert.emit()
	return true


# --- Werkzeuge ---------------------------------------------------------------
func werkzeug_upgrade_preis(id: String) -> float:
	var w: Dictionary = Data.werkzeug(id)
	var basis: float = max(40.0, w.preis * 0.4)
	return round(basis * pow(1.15, int(werkzeuge.get(id, 0))))


func kaufe_werkzeug(id: String) -> bool:
	var w: Dictionary = Data.werkzeug(id)
	if werkzeuge.has(id) or w.aera > aera:
		return false
	if not ausgeben(w.preis):
		return false
	werkzeuge[id] = 0
	werkzeug_aktiv = id
	ziel_melden("kaufen")
	Sfx.spiele("kasse")
	toast.emit("%s gekauft" % w.name, FARBE_GUT)
	werkzeug_geaendert.emit()
	stand_geaendert.emit()
	return true


func werte_werkzeug_auf(id: String) -> bool:
	if not werkzeuge.has(id) or int(werkzeuge[id]) >= Data.WERKZEUG_MAX_STUFE:
		return false
	if not ausgeben(werkzeug_upgrade_preis(id)):
		return false
	werkzeuge[id] = int(werkzeuge[id]) + 1
	Sfx.spiele("kasse")
	werkzeug_geaendert.emit()
	stand_geaendert.emit()
	return true


func waehle_werkzeug(id: String) -> void:
	if werkzeuge.has(id):
		werkzeug_aktiv = id
		werkzeug_geaendert.emit()
		stand_geaendert.emit()


# --- Maschinen ---------------------------------------------------------------
func maschinen_preis(id: String) -> float:
	var m: Dictionary = Data.MASCHINEN[id]
	var p: float = m.preis
	if id == "deckel" and hat_talent("festung"):
		return 0.0
	if hat_talent("baumeister"):
		p *= 0.5
	return round(p)


func maschinen_upgrade_preis(id: String) -> float:
	var m: Dictionary = Data.MASCHINEN[id]
	var p: float = m.get("stufenpreis", 0) * pow(1.15, maschinen_stufe(id))
	if hat_talent("baumeister"):
		p *= 0.5
	return round(p)


func maschine_verfuegbar(id: String) -> bool:
	var m: Dictionary = Data.MASCHINEN[id]
	if m.aera > aera:
		return false
	if m.has("talent") and not hat_talent(m.talent):
		return false
	return true


func kaufe_maschine(id: String) -> bool:
	if hat_maschine(id) or not maschine_verfuegbar(id):
		return false
	if not ausgeben(maschinen_preis(id)):
		return false
	maschinen[id] = 0
	Sfx.spiele("kasse")
	toast.emit("%s geliefert" % Data.MASCHINEN[id].name, FARBE_GUT)
	maschine_gekauft.emit(id)
	stand_geaendert.emit()
	return true


func werte_maschine_auf(id: String) -> bool:
	var m: Dictionary = Data.MASCHINEN[id]
	if not hat_maschine(id) or maschinen_stufe(id) >= int(m.stufen):
		return false
	if not ausgeben(maschinen_upgrade_preis(id)):
		return false
	maschinen[id] = maschinen_stufe(id) + 1
	Sfx.spiele("kasse")
	stand_geaendert.emit()
	return true


# --- Talente -----------------------------------------------------------------
## Rückgabe: "max", "gesperrt", "ausgeschlossen", "zu_teuer" oder "frei"
func talent_status(id: String) -> String:
	var t: Dictionary = Data.TALENTE[id]
	if talent(id) >= int(t.max):
		return "max"
	if t.braucht != "" and not hat_talent(t.braucht):
		return "gesperrt"
	if t.zweig == "abwehr" and _zweig_begonnen("zaehmen"):
		return "ausgeschlossen"
	if t.zweig == "zaehmen" and _zweig_begonnen("abwehr"):
		return "ausgeschlossen"
	if mp < int(t.kosten):
		return "zu_teuer"
	return "frei"


func _zweig_begonnen(zweig: String) -> bool:
	for id in talente:
		if Data.TALENTE[id].zweig == zweig and int(talente[id]) > 0:
			return true
	return false


func lerne_talent(id: String) -> bool:
	if talent_status(id) != "frei":
		return false
	mp -= int(Data.TALENTE[id].kosten)
	talente[id] = talent(id) + 1
	Sfx.spiele("freischalten")
	toast.emit("Talent gelernt: %s" % Data.TALENTE[id].name, FARBE_GOLD)
	talent_gelernt.emit(id)
	stand_geaendert.emit()
	return true


# --- Knacken und Berg --------------------------------------------------------
func nuesse_vom_berg(anzahl: int) -> int:
	var n: int = min(anzahl, berg_rest())
	genommen += n
	_pruefe_aera(true)
	stand_geaendert.emit()
	return n


## Meldet einen abgeschlossenen Knack. ergebnis: perfekt | bruch | matsch | faul
func melde_knack(nuss: String, ergebnis: String, hand: bool, haelften := 0) -> void:
	geknackt += 1
	match ergebnis:
		"perfekt":
			statistik.perfekt += 1
			if hand:
				combo = min(combo + 1, combo_max())
				ziel_melden("knacken")
			_bestellung_fortschritt(nuss, haelften * (3 if hand and hat_talent("meisterknack") else 1))
		"bruch":
			statistik.bruch += 1
			if hand:
				combo = 0
		"matsch":
			statistik.matsch += 1
			if hand:
				combo = 0
	_pruefe_meilensteine()
	stand_geaendert.emit()
	if genommen >= Data.BERG_GROESSE and not berg_fertig and berg_rest() == 0:
		berg_fertig = true
		berg_leer.emit()


func _pruefe_meilensteine() -> void:
	while geknackt >= Data.meilenstein_bei(naechster_meilenstein):
		naechster_meilenstein += 1
		mp += 1
		mp_gesamt += 1
		Sfx.spiele("meilenstein")
		toast.emit("Meilenstein %d: +1 Meisterpunkt  [Tab]" % (naechster_meilenstein - 1), FARBE_GOLD)


func _pruefe_aera(melden: bool) -> void:
	var s: Dictionary = schicht()
	if int(s.aera) > aera:
		aera = int(s.aera)
		if melden:
			Sfx.spiele("freischalten")
			aera_erreicht.emit(aera, s.name)
	elif not melden:
		aera = max(aera, int(s.aera))


# --- Bestellungen ------------------------------------------------------------
const KUNDEN := ["Bäckerei Krümel", "Weihnachtsmarkt", "Konditorei Zuckerguss", "Eisdiele Venezia", "Lebkuchenfabrik", "Café Nussecke"]


func max_bestellungen() -> int:
	return 4 if hat_talent("stammkunden") else 3


func _neue_bestellung() -> Dictionary:
	var mix: Dictionary = schicht().mix
	var nuss: String = mix.keys()[rng.randi() % mix.size()]
	var menge := rng.randi_range(4, 12) * 2
	var wert: float = Data.NUESSE[nuss].wert * menge * 2.5 * (1.0 + 0.25 * talent("stammkunden"))
	var frei: Array = KUNDEN.duplicate()
	for b in bestellungen:
		frei.erase(b.kunde)
	if frei.is_empty():
		frei = KUNDEN.duplicate()
	return {
		"kunde": frei[rng.randi() % frei.size()],
		"nuss": nuss,
		"menge": menge,
		"stand": 0,
		"zeit": float(rng.randi_range(4, 8) * 60),
		"lohn": round(max(wert, 20.0)),
		"gold": 1 if rng.randf() < 0.2 else 0,
	}


func _bestellungen_auffuellen() -> void:
	while bestellungen.size() < max_bestellungen():
		bestellungen.append(_neue_bestellung())
	bestellungen_geaendert.emit()


func _bestellungen_ticken(delta: float) -> void:
	var geaendert := false
	for i in range(bestellungen.size() - 1, -1, -1):
		var b: Dictionary = bestellungen[i]
		b.zeit -= delta
		if b.zeit <= 0.0:
			bestellungen.remove_at(i)
			geaendert = true
	if geaendert or bestellungen.size() < max_bestellungen():
		_bestellungen_auffuellen()


func _bestellung_fortschritt(nuss: String, haelften: int) -> void:
	if haelften <= 0:
		return
	for i in range(bestellungen.size()):
		var b: Dictionary = bestellungen[i]
		if b.nuss != nuss:
			continue
		b.stand = min(int(b.menge), int(b.stand) + haelften)
		if b.stand >= b.menge:
			verdiene(b.lohn)
			mp += 1
			mp_gesamt += 1
			gold += int(b.gold)
			Sfx.spiele("meilenstein")
			var extra := " + 1 Goldene Nuss" if b.gold > 0 else ""
			toast.emit("Bestellung %s erfüllt: +%s Münzen, +1 Meisterpunkt%s" % [b.kunde, Data.zahl(b.lohn), extra], FARBE_GOLD)
			bestellungen.remove_at(i)
		break
	bestellungen_geaendert.emit()


# --- Speichern ---------------------------------------------------------------
func speichern() -> void:
	var welt := get_tree().current_scene if is_inside_tree() else null
	if welt and welt.has_method("behaelter_speichern"):
		behaelter = welt.behaelter_speichern()
	var d := {
		"version": SPEICHER_VERSION,
		"muenzen": muenzen, "gold": gold, "mp": mp, "mp_gesamt": mp_gesamt,
		"geknackt": geknackt, "genommen": genommen, "energie": energie, "aera": aera,
		"naechster_meilenstein": naechster_meilenstein,
		"werkzeuge": werkzeuge, "werkzeug_aktiv": werkzeug_aktiv,
		"maschinen": maschinen, "talente": talente, "bestellungen": bestellungen,
		"behaelter": behaelter, "statistik": statistik, "einstellungen": einstellungen,
		"erster_start": erster_start, "berg_fertig": berg_fertig, "spielzeit": spielzeit,
		"ziel_index": ziel_index, "ziel_zaehler": ziel_zaehler,
	}
	var f := FileAccess.open(SPEICHER_PFAD, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


func laden() -> void:
	if not FileAccess.file_exists(SPEICHER_PFAD):
		return
	var text := FileAccess.get_file_as_string(SPEICHER_PFAD)
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		return
	muenzen = float(d.get("muenzen", 0))
	gold = int(d.get("gold", 0))
	mp = int(d.get("mp", 0))
	mp_gesamt = int(d.get("mp_gesamt", 0))
	geknackt = int(d.get("geknackt", 0))
	genommen = int(d.get("genommen", 0))
	energie = float(d.get("energie", 0))
	aera = int(d.get("aera", 1))
	naechster_meilenstein = int(d.get("naechster_meilenstein", 1))
	werkzeuge = _int_werte(d.get("werkzeuge", {"haende": 0}))
	werkzeug_aktiv = str(d.get("werkzeug_aktiv", "haende"))
	maschinen = _int_werte(d.get("maschinen", {}))
	talente = _int_werte(d.get("talente", {}))
	bestellungen = d.get("bestellungen", [])
	behaelter = d.get("behaelter", {})
	for k in statistik:
		statistik[k] = d.get("statistik", {}).get(k, statistik[k])
	for k in einstellungen:
		einstellungen[k] = d.get("einstellungen", {}).get(k, einstellungen[k])
	erster_start = bool(d.get("erster_start", false))
	berg_fertig = bool(d.get("berg_fertig", false))
	spielzeit = float(d.get("spielzeit", 0))
	ziel_index = int(d.get("ziel_index", Data.ZIELE.size() if geknackt > 50 else 0))
	ziel_zaehler = int(d.get("ziel_zaehler", 0))
	_laden_erfolgt = true


func _int_werte(quelle) -> Dictionary:
	var aus := {}
	if typeof(quelle) == TYPE_DICTIONARY:
		for k in quelle:
			aus[str(k)] = int(quelle[k])
	return aus


func zuruecksetzen() -> void:
	if FileAccess.file_exists(SPEICHER_PFAD):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SPEICHER_PFAD))
	muenzen = 0.0
	gold = 0
	mp = 0
	mp_gesamt = 0
	geknackt = 0
	genommen = 0
	combo = 0
	energie = 0.0
	aera = 1
	naechster_meilenstein = 1
	werkzeuge = {"haende": 0}
	werkzeug_aktiv = "haende"
	maschinen = {}
	talente = {}
	bestellungen = []
	behaelter = {}
	statistik = {"perfekt": 0, "bruch": 0, "matsch": 0, "verkauft": 0.0, "gestohlen": 0, "verscheucht": 0}
	erster_start = true
	berg_fertig = false
	spielzeit = 0.0
	ziel_index = 0
	ziel_zaehler = 0
	_bestellungen_auffuellen()
	get_tree().reload_current_scene()


# --- Ziele -------------------------------------------------------------------
## Das aktuelle geführte Ziel oder {} wenn alle geschafft sind.
func ziel_aktuell() -> Dictionary:
	if ziel_index < Data.ZIELE.size():
		return Data.ZIELE[ziel_index]
	return {}


func ziel_melden(id: String, menge := 1) -> void:
	var z := ziel_aktuell()
	if z.is_empty() or z.id != id:
		return
	ziel_zaehler += menge
	if ziel_zaehler < int(z.get("anzahl", 1)):
		ziel_geaendert.emit()
		return
	ziel_zaehler = 0
	ziel_index += 1
	if int(z.lohn) > 0:
		verdiene(float(z.lohn), false)
	Sfx.spiele("ziel")
	toast.emit("Geschafft: %s%s" % [z.text, ("  +%d Münzen" % int(z.lohn)) if int(z.lohn) > 0 else ""], FARBE_GUT)
	ziel_geaendert.emit()


## Das günstigste Werkzeug oder die günstigste Maschine, die man noch nicht hat.
func naechstes_kaufziel() -> Dictionary:
	var best := {}
	for w in Data.WERKZEUGE:
		if werkzeuge.has(w.id) or int(w.aera) > aera:
			continue
		if best.is_empty() or float(w.preis) < float(best.preis):
			best = {"name": w.name, "preis": float(w.preis), "art": "Werkzeug"}
	for id in Data.MASCHINEN:
		if hat_maschine(id) or not maschine_verfuegbar(id):
			continue
		var p := maschinen_preis(id)
		if best.is_empty() or p < float(best.preis):
			best = {"name": Data.MASCHINEN[id].name, "preis": p, "art": "Maschine"}
	return best


# --- Spielgefühl --------------------------------------------------------------
## Friert das Spiel kurz fast ein (Treffer-Gefühl beim Knacken).
func hitstop(dauer: float, skala := 0.05) -> void:
	Engine.time_scale = skala
	_hitstop_ende = Time.get_ticks_msec() + int(dauer * 1000.0)
