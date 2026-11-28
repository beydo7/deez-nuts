extends Node
## Spielstand, Wirtschaft, Skillbaum, Bestellungen und Speichern.
## Alles, was über einen Neustart des Spiels hinaus erhalten bleibt, lebt hier.

signal geld_geaendert
signal stand_geaendert
signal toast(text: String, farbe: Color)
signal aera_erreicht(aera: int, schicht: String)
signal werkzeug_geaendert
signal maschine_gekauft(id: String)
signal talent_gelernt(id: String)
signal beutel_geaendert
signal lager_geaendert
signal abgeliefert(anzahl: int, betrag: float, pos: Vector3)
signal helfer_gekauft
signal posten_gekauft(id: String)
signal bestellungen_geaendert
signal knack_ergebnis(ergebnis: String, text: String)
signal berg_leer
signal ziel_geaendert
signal verkauft(betrag: float, pos: Vector3)

var SPEICHER_PFAD := "user://spielstand.json"
var selbsttest := false
const SPEICHER_VERSION := 2
var BERG_PFAD := "user://berg.dat"

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
var talente := {}               # alt, wird nicht mehr benutzt
var skills := {}                # id -> true (Skillbaum)
var sammler := {"haende": 0}    # Sammelwerkzeuge id -> 0
var sammler_aktiv := "haende"
var beutel_id := "taschen"
var beutel := {}                # Nusssorte -> Anzahl im Beutel
var lager := {}                 # Nusssorte -> Anzahl im Lager der Hütte
var helfer: int = 0
var posten := {}                # id -> true
var bestellungen: Array = []
var tageszeit: float = 10.5     # Stunden 0..24; der Himmel zählt weiter
var wetter := "klar"            # klar | bewoelkt | regen
var letzter_regen := -99999.0   # Spielzeit (Sekunden), zu der es zuletzt geregnet hat
var extra := {}                 # freie Ablage für Welt-Zustände (Funde, Opfergaben, Bauten ...), wird mitgespeichert
var behaelter := {}             # vom World-Skript befüllt / gelesen
var statistik := {"perfekt": 0, "bruch": 0, "matsch": 0, "verkauft": 0.0, "gestohlen": 0, "verscheucht": 0}
var erster_start := true
var berg_fertig := false
var spielzeit: float = 0.0
var ziel_index: int = 0
var ziel_zaehler: int = 0

var einstellungen := {
	"empfindlichkeit": 0.25,
	"lautstaerke": 0.8,
	"musik": 0.6,
	"zeit_fest": false,
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
		BERG_PFAD = "user://selbsttest_berg.dat"
		for pfad in [SPEICHER_PFAD, BERG_PFAD]:
			if FileAccess.file_exists(pfad):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
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
			var zins: float = min(muenzen * 0.01, 5000.0)
			if zins >= 1.0:
				verdiene(zins, false)
				toast.emit("Zinsen: +%s Münzen" % Data.zahl(zins), FARBE_GOLD)


func ist_nacht() -> bool:
	return tageszeit >= 20.0 or tageszeit < 6.0


## Abendsonne (17 bis 19 Uhr)
func ist_abend() -> bool:
	return tageszeit >= 17.0 and tageszeit < 19.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		speichern()


# --- Eingaben (werden zur Laufzeit angelegt, damit project.godot schlank bleibt) ---
func _eingaben_anlegen() -> void:
	var tasten := {
		"vor": [KEY_W, KEY_UP], "zurueck": [KEY_S, KEY_DOWN], "links": [KEY_A, KEY_LEFT], "rechts": [KEY_D, KEY_RIGHT],
		"springen": [KEY_SPACE], "rennen": [KEY_SHIFT], "benutzen": [KEY_E], "fallenlassen": [KEY_Q],
		"wischen": [KEY_F], "hebel": [KEY_R], "talente": [KEY_TAB], "treffen": [KEY_SPACE], "pause": [KEY_ESCAPE],
		"laden": [KEY_B], "werkzeug_wechseln": [KEY_X],
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
## Summe aller gekauften Skill-Boni für einen Wert (z. B. "sammel_tempo").
func bonus(stat: String) -> float:
	var summe := 0.0
	var alle := Data.skills()
	for id in skills:
		var k: Dictionary = alle.get(id, {})
		if k.has("wert") and k.wert[0] == stat:
			summe += float(k.wert[1])
	return summe


func talent(id: String) -> int:
	return 1 if skills.has(id) else 0


func hat_talent(id: String) -> bool:
	return skills.has(id)


func hat_maschine(id: String) -> bool:
	return maschinen.has(id)


func maschinen_stufe(id: String) -> int:
	return int(maschinen.get(id, -1))


func preis_faktor() -> float:
	return 1.0 + bonus("preise") + (0.15 if hat_talent("feilschen") else 0.0)


func praemie() -> float:
	return Data.ABLIEFER_PRAEMIE * (1.0 + bonus("praemie")) * (1.15 if hat_talent("feilschen") else 1.0)


func combo_max() -> int:
	return 20 + int(bonus("combo")) + (10 if hat_talent("rhythmus") else 0)


func combo_bonus() -> float:
	return min(combo, combo_max()) * 0.05


func gold_chance() -> float:
	var hexenring := 2.0 if spielzeit < float(extra.get("hexen_bis", 0.0)) else 1.0
	return Data.CHANCE_GOLD * (1.0 + bonus("gold")) * (2.0 if hat_talent("goldhand") else 1.0) * hexenring


func faul_chance() -> float:
	return Data.CHANCE_FAUL * (0.5 if hat_talent("festung") else 1.0)


func doppel_chance() -> float:
	return Data.CHANCE_DOPPEL * (1.0 + bonus("doppel"))


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
		"sweet": w.sweet + 0.005 * stufe + bonus("sweet") + (0.06 if hat_talent("ruhige_hand") else 0.0) + (0.03 if hat_fund("figuren") else 0.0),
		"stufe": stufe,
	}


## Werte des aktiven Sammelwerkzeugs inklusive Skill-Boni.
func sammel_werte() -> Dictionary:
	var w: Dictionary = Data.sammler(sammler_aktiv)
	var tempo := 1.0 + bonus("sammel_tempo") + (0.3 if hat_talent("wuehlmaus") else 0.0)
	var radius := 1.0 + bonus("sammel_radius") + (0.4 if hat_talent("grabkoenig") else 0.0)
	return {"id": w.id, "name": w.name, "rate": float(w.rate) * tempo, "radius": float(w.radius) * radius,
		"reichweite": float(w.reichweite), "doppel": bonus("doppelgriff")}


func kapazitaet() -> int:
	var k := float(Data.beutel(beutel_id).kap) * (1.0 + bonus("kapazitaet") + (0.5 if hat_talent("packesel") else 0.0))
	if hat_talent("bodenlos"):
		k *= 2.0
	return int(k)


func lauf_faktor() -> float:
	return float(Data.beutel(beutel_id).tempo) * (1.0 + bonus("lauftempo") + (0.2 if hat_talent("siebenmeilen") else 0.0))


func lager_kapazitaet() -> int:
	var k := float(Data.LAGER_GROESSE) * (1.0 + bonus("lager"))
	if hat_maschine("lagerhalle"):
		k *= 10.0 * (1.0 + 0.5 * maschinen_stufe("lagerhalle"))
	return int(k)


func maschinen_tempo() -> float:
	return 1.0 + bonus("walze_tempo") + (0.25 if hat_talent("gut_geoelt") else 0.0)


func rutschen_tempo() -> float:
	return 1.0 + bonus("rutsche") + (0.25 if hat_talent("gut_geoelt") else 0.0)


func walzen_praezision() -> float:
	var stufe: int = max(0, maschinen_stufe("walze"))
	var p := 0.45 + 0.03 * stufe + bonus("walze_praezision")
	if hat_talent("selbstlaeufer"):
		p += 0.15
	return min(p, 0.98)


func walzen_tempo() -> float:
	var stufe: int = max(0, maschinen_stufe("walze"))
	return 1.5 * (1.0 + 0.2 * stufe) * maschinen_tempo()


func helfer_werte() -> Dictionary:
	var k := 1.5 if hat_talent("koenigsbund") else 1.0
	return {"rate": Data.HELFER_RATE * k * (1.0 + bonus("helfer_tempo")), "tempo": Data.HELFER_TEMPO * (1.0 + bonus("helfer_tempo") * 0.5),
		"last": int(Data.HELFER_LAST * k * (1.0 + bonus("helfer_last")))}


func energie_pro_schale() -> float:
	return 3.0


# --- Beutel und Lager ----------------------------------------------------------
func beutel_menge() -> int:
	var n := 0
	for k in beutel:
		n += int(beutel[k])
	return n


func beutel_frei() -> int:
	return max(0, kapazitaet() - beutel_menge())


func beutel_hinzu(nuss: String, anzahl: int) -> int:
	var n: int = min(anzahl, beutel_frei())
	if n <= 0:
		return 0
	beutel[nuss] = int(beutel.get(nuss, 0)) + n
	beutel_geaendert.emit()
	if beutel_frei() == 0:
		ziel_melden("voll")
	return n


func lager_menge() -> int:
	var n := 0
	for k in lager:
		n += int(lager[k])
	return n


## Leert den Beutel ins Lager. Jede Nuss bringt sofort die Ablieferprämie.
func abliefern(pos := Vector3.ZERO) -> int:
	var anzahl := beutel_menge()
	if anzahl <= 0:
		return 0
	var betrag := einlagern(beutel, pos)
	beutel.clear()
	beutel_geaendert.emit()
	ziel_melden("abliefern")
	return anzahl if betrag >= 0.0 else 0


## Legt Nüsse (Sorte -> Anzahl) ins Lager und zahlt die Prämie. Was nicht mehr ins Lager passt,
## wird roh verkauft (doppelte Prämie). Gibt den Betrag zurück.
func einlagern(sorten: Dictionary, pos := Vector3.ZERO) -> float:
	var anzahl := 0
	var platz: int = max(0, lager_kapazitaet() - lager_menge())
	var ueber := 0
	for nuss in sorten:
		var n := int(sorten[nuss])
		anzahl += n
		var rein: int = min(n, platz)
		platz -= rein
		ueber += n - rein
		if rein > 0:
			lager[nuss] = int(lager.get(nuss, 0)) + rein
	if anzahl <= 0:
		return 0.0
	var betrag := anzahl * praemie() + ueber * praemie()
	verdiene(betrag, false)
	statistik["abgeliefert"] = int(statistik.get("abgeliefert", 0)) + anzahl
	lager_geaendert.emit()
	abgeliefert.emit(anzahl, betrag, pos)
	return betrag


## Nimmt bis zu n Nüsse aus dem Lager (gemischt nach Bestand). Gibt die Sorten zurück.
func lager_nehmen(n: int) -> Array:
	var aus: Array = []
	for i in n:
		var gesamt := lager_menge()
		if gesamt <= 0:
			break
		var r := rng.randi() % gesamt
		for nuss in lager:
			r -= int(lager[nuss])
			if r < 0:
				lager[nuss] = int(lager[nuss]) - 1
				if int(lager[nuss]) <= 0:
					lager.erase(nuss)
				aus.append(nuss)
				break
	if not aus.is_empty():
		lager_geaendert.emit()
	return aus


func berg_rest() -> int:
	return max(0, Data.BERG_GROESSE - genommen)


func schicht() -> Dictionary:
	return Data.schicht_fuer(genommen)


# --- Geld --------------------------------------------------------------------
func verdiene(betrag: float, mit_steuer := true) -> float:
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
	if hat_talent("baumeister"):
		p *= 0.7
	return round(p)


func maschinen_upgrade_preis(id: String) -> float:
	var m: Dictionary = Data.MASCHINEN[id]
	var p: float = m.get("stufenpreis", 0) * pow(1.25, maschinen_stufe(id))
	if hat_talent("baumeister"):
		p *= 0.7
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


# --- Sammeln, Beutel, Helfer, Posten kaufen ------------------------------------
func kaufe_sammler(id: String) -> bool:
	var w: Dictionary = Data.sammler(id)
	if sammler.has(id) or int(w.aera) > aera:
		return false
	if not ausgeben(w.preis):
		return false
	sammler[id] = 0
	sammler_aktiv = id
	if id == "loeffel":
		ziel_melden("loeffel")
	Sfx.spiele("kasse")
	toast.emit("%s gekauft" % w.name, FARBE_GUT)
	werkzeug_geaendert.emit()
	stand_geaendert.emit()
	return true


func waehle_sammler(id: String) -> void:
	if sammler.has(id):
		sammler_aktiv = id
		werkzeug_geaendert.emit()


func kaufe_beutel(id: String) -> bool:
	var b: Dictionary = Data.beutel(id)
	var alt := Data.BEUTEL.find(Data.beutel(beutel_id))
	var neu := Data.BEUTEL.find(b)
	if neu <= alt or int(b.get("aera", 1)) > aera:
		return false
	if not ausgeben(b.preis):
		return false
	beutel_id = id
	ziel_melden("beutel")
	Sfx.spiele("kasse")
	toast.emit("%s: du trägst jetzt %d Nüsse" % [b.name, kapazitaet()], FARBE_GUT)
	beutel_geaendert.emit()
	stand_geaendert.emit()
	return true


func helfer_preis() -> float:
	return round(Data.HELFER_PREIS * pow(Data.HELFER_FAKTOR, helfer) * max(0.4, 1.0 - bonus("helfer_preis")))


func kaufe_helfer() -> bool:
	if not ausgeben(helfer_preis()):
		return false
	helfer += 1
	Sfx.spiele("kasse")
	toast.emit("Ein Sammel-Eichhörnchen hilft jetzt mit (%d)" % helfer, FARBE_GUT)
	helfer_gekauft.emit()
	stand_geaendert.emit()
	return true


func posten_preis(id: String) -> float:
	var p: float = Data.posten(id).preis
	return round(p * (0.7 if hat_talent("baumeister") else 1.0))


func kaufe_posten(id: String) -> bool:
	var p: Dictionary = Data.posten(id)
	if p.is_empty() or posten.has(id) or int(p.aera) > aera:
		return false
	if not ausgeben(posten_preis(id)):
		return false
	posten[id] = true
	Sfx.spiele("kasse")
	toast.emit("%s gebaut" % p.name, FARBE_GUT)
	posten_gekauft.emit(id)
	stand_geaendert.emit()
	return true


# --- Skillbaum -------------------------------------------------------------------
## Rückgabe: "besessen", "gesperrt", "zu_teuer" oder "frei"
func skill_status(id: String) -> String:
	if id == "wurzel" or skills.has(id):
		return "besessen"
	var k: Dictionary = Data.skills().get(id, {})
	if k.is_empty():
		return "gesperrt"
	if k.braucht != "wurzel" and not skills.has(k.braucht):
		return "gesperrt"
	if muenzen + 0.001 < float(k.preis):
		return "zu_teuer"
	return "frei"


func kaufe_skill(id: String) -> bool:
	if skill_status(id) != "frei":
		return false
	var k: Dictionary = Data.skills()[id]
	muenzen -= float(k.preis)
	skills[id] = true
	Sfx.spiele("freischalten")
	toast.emit("%s: %s" % ["Gelernt" if k.get("schluessel", false) else "Skill", k.name], FARBE_GOLD if k.get("schluessel", false) else FARBE_GUT)
	ziel_melden("skill")
	geld_geaendert.emit()
	talent_gelernt.emit(id)
	beutel_geaendert.emit()
	stand_geaendert.emit()
	return true


## Kompatibel zu alten Aufrufen: Talente sind jetzt Schlüsselknoten im Skillbaum.
func lerne_talent(id: String) -> bool:
	return kaufe_skill(id)


# --- Fundbuch und Geheimnisse ------------------------------------------------------
signal fund_gemacht(id: String)


func hat_fund(id: String) -> bool:
	var f = extra.get("funde", {})
	return typeof(f) == TYPE_DICTIONARY and bool(f.get(id, false))


func funde_anzahl() -> int:
	var n := 0
	for f in Data.FUNDE:
		if hat_fund(f.id):
			n += 1
	return n


## Trägt eine Entdeckung ins Fundbuch ein. false, wenn sie schon drinsteht.
func fund(id: String) -> bool:
	if hat_fund(id) or Data.fund_daten(id).is_empty():
		return false
	var f = extra.get("funde", {})
	if typeof(f) != TYPE_DICTIONARY:
		f = {}
	f[id] = true
	extra["funde"] = f
	Sfx.spiele("gold")
	toast.emit("Fundbuch: %s  (%d von %d)" % [Data.fund_daten(id).name, funde_anzahl(), Data.FUNDE.size()], FARBE_GOLD)
	fund_gemacht.emit(id)
	stand_geaendert.emit()
	return true


## Mit der Goldenen Zahnbürste ist jede 50. gesammelte Nuss eine Mondnuss.
func zahnbuerste_gesammelt(anzahl: int) -> void:
	if sammler_aktiv != "zahnbuerste" or anzahl <= 0:
		return
	var z := int(extra.get("zahnbuerste", 0)) + anzahl
	while z >= Data.MONDNUSS_JEDE:
		z -= Data.MONDNUSS_JEDE
		verdiene(Data.MONDNUSS_WERT, false)
		Sfx.spiele("gold", -4.0, 1.3)
		toast.emit("Eine Mondnuss! +%s Münzen" % Data.zahl(Data.MONDNUSS_WERT), FARBE_GOLD)
	extra["zahnbuerste"] = z


## Wie viele Kernhälften ein wildes Eichhörnchen klaut. Freunde der Krone verlieren ein Viertel weniger.
func klau_menge(basis: int) -> int:
	if hat_fund("koenig") and rng.randf() < 0.25 * basis:
		return max(0, basis - 1)
	return basis


# --- Knacken und Berg --------------------------------------------------------
func nuesse_vom_berg(anzahl: int) -> int:
	var n: int = min(anzahl, berg_rest())
	genommen += n
	_pruefe_aera(true)
	stand_geaendert.emit()
	if berg_rest() == 0 and not berg_fertig:
		berg_fertig = true
		berg_leer.emit()
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
		var lohn: float = round(20.0 * pow(float(naechster_meilenstein), 1.6))
		naechster_meilenstein += 1
		verdiene(lohn, false)
		Sfx.spiele("meilenstein")
		toast.emit("%s Nüsse geknackt: +%s Münzen Bonus" % [Data.zahl(Data.meilenstein_bei(naechster_meilenstein - 1)), Data.zahl(lohn)], FARBE_GOLD)


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
	var wert: float = Data.NUESSE[nuss].wert * menge * 3.0 * (1.0 + 0.25 * talent("stammkunden"))
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
			gold += int(b.gold)
			Sfx.spiele("meilenstein")
			var extra := " + 1 Goldene Nuss" if b.gold > 0 else ""
			toast.emit("Bestellung %s erfüllt: +%s Münzen%s" % [b.kunde, Data.zahl(b.lohn), extra], FARBE_GOLD)
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
		"skills": skills, "sammler": sammler, "sammler_aktiv": sammler_aktiv, "beutel_id": beutel_id,
		"beutel": beutel, "lager": lager, "helfer": helfer, "posten": posten,
		"tageszeit": tageszeit, "wetter": wetter, "letzter_regen": letzter_regen, "extra": extra,
	}
	if welt and welt.has_method("berg_speichern"):
		welt.berg_speichern(BERG_PFAD)
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
	if int(d.get("version", 1)) < 2:
		# Alter Spielstand vor dem Sammel-Umbau: Fortschritt behalten, neue Systeme frisch
		ziel_index = 0
		maschinen = {}
	skills = {}
	for k in d.get("skills", {}):
		skills[str(k)] = true
	sammler = _int_werte(d.get("sammler", {"haende": 0}))
	if sammler.is_empty():
		sammler = {"haende": 0}
	sammler_aktiv = str(d.get("sammler_aktiv", "haende"))
	beutel_id = str(d.get("beutel_id", "taschen"))
	beutel = _int_werte(d.get("beutel", {}))
	lager = _int_werte(d.get("lager", {}))
	helfer = int(d.get("helfer", 0))
	posten = {}
	for k in d.get("posten", {}):
		posten[str(k)] = true
	tageszeit = float(d.get("tageszeit", 10.5))
	wetter = str(d.get("wetter", "klar"))
	letzter_regen = float(d.get("letzter_regen", -99999.0))
	extra = d.get("extra", {})
	if typeof(extra) != TYPE_DICTIONARY:
		extra = {}
	_laden_erfolgt = true


func _int_werte(quelle) -> Dictionary:
	var aus := {}
	if typeof(quelle) == TYPE_DICTIONARY:
		for k in quelle:
			aus[str(k)] = int(quelle[k])
	return aus


func zuruecksetzen() -> void:
	for pfad in [SPEICHER_PFAD, BERG_PFAD]:
		if FileAccess.file_exists(pfad):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(pfad))
	skills = {}
	sammler = {"haende": 0}
	sammler_aktiv = "haende"
	beutel_id = "taschen"
	beutel = {}
	lager = {}
	helfer = 0
	posten = {}
	tageszeit = 10.5
	wetter = "klar"
	letzter_regen = -99999.0
	extra = {}
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
	var kandidaten: Array = []
	for w in Data.SAMMLER:
		if w.get("geheim", false):
			continue
		if not sammler.has(w.id) and int(w.aera) <= aera:
			kandidaten.append({"name": w.name, "preis": float(w.preis), "art": "Sammeln"})
			break
	var bi := Data.BEUTEL.find(Data.beutel(beutel_id))
	if bi + 1 < Data.BEUTEL.size() and int(Data.BEUTEL[bi + 1].get("aera", 1)) <= aera:
		kandidaten.append({"name": Data.BEUTEL[bi + 1].name, "preis": float(Data.BEUTEL[bi + 1].preis), "art": "Tragen"})
	for w in Data.WERKZEUGE:
		if not werkzeuge.has(w.id) and int(w.aera) <= aera:
			kandidaten.append({"name": w.name, "preis": float(w.preis), "art": "Knacken"})
			break
	for id in Data.MASCHINEN:
		if not hat_maschine(id) and maschine_verfuegbar(id):
			kandidaten.append({"name": Data.MASCHINEN[id].name, "preis": maschinen_preis(id), "art": "Maschine"})
	for p in Data.POSTEN:
		if not posten.has(p.id) and int(p.aera) <= aera:
			kandidaten.append({"name": p.name, "preis": posten_preis(p.id), "art": "Posten"})
			break
	var best := {}
	for k in kandidaten:
		if best.is_empty() or float(k.preis) < float(best.preis):
			best = k
	return best


# --- Spielgefühl --------------------------------------------------------------
## Friert das Spiel kurz fast ein (Treffer-Gefühl beim Knacken).
func hitstop(dauer: float, skala := 0.05) -> void:
	Engine.time_scale = skala
	_hitstop_ende = Time.get_ticks_msec() + int(dauer * 1000.0)
