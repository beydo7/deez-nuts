extends Node
## Alle festen Spielwerte an einer Stelle: Nüsse, Werkzeuge, Maschinen,
## Bergschichten und Talente. Balancing passiert hier.

const BERG_GROESSE := 1_000_000

# Physik-Ebenen (Bitmasken)
const L_WELT := 1
const L_ITEM := 2
const L_BEHAELTER := 4
const L_SPIELER := 8
const L_INTERAKT := 16
const L_TIER := 32

# --- Nüsse -----------------------------------------------------------------
# haerte = Mindestkraft, sweet = Breite des Sweet Spots (Anteil der Druckskala),
# wert = Münzen je ganzer Kernhälfte, groesse = Radius in Metern (spielfreundlich vergrößert)
const NUESSE := {
	"hasel": {"name": "Haselnuss", "haerte": 1.0, "sweet": 0.30, "wert": 1.0, "groesse": 0.034,
		"form": Vector3(1.0, 1.0, 1.0), "farbe": Color(0.66, 0.42, 0.2), "kern": Color(0.93, 0.82, 0.62)},
	"wal": {"name": "Walnuss", "haerte": 3.0, "sweet": 0.22, "wert": 4.0, "groesse": 0.046,
		"form": Vector3(1.0, 1.08, 1.0), "farbe": Color(0.6, 0.43, 0.25), "kern": Color(0.82, 0.66, 0.42)},
	"mandel": {"name": "Mandel", "haerte": 2.0, "sweet": 0.18, "wert": 6.0, "groesse": 0.04,
		"form": Vector3(0.72, 0.55, 1.35), "farbe": Color(0.78, 0.58, 0.36), "kern": Color(0.95, 0.88, 0.75)},
	"pekan": {"name": "Pekannuss", "haerte": 4.0, "sweet": 0.12, "wert": 10.0, "groesse": 0.04,
		"form": Vector3(0.78, 0.78, 1.5), "farbe": Color(0.5, 0.27, 0.13), "kern": Color(0.7, 0.45, 0.25)},
	"para": {"name": "Paranuss", "haerte": 7.0, "sweet": 0.15, "wert": 18.0, "groesse": 0.046,
		"form": Vector3(0.75, 0.9, 1.4), "farbe": Color(0.36, 0.25, 0.17), "kern": Color(0.96, 0.92, 0.84), "springt": true},
	"macadamia": {"name": "Macadamia", "haerte": 12.0, "sweet": 0.14, "wert": 35.0, "groesse": 0.04,
		"form": Vector3(1.0, 1.0, 1.0), "farbe": Color(0.55, 0.4, 0.27), "kern": Color(0.97, 0.94, 0.85)},
}

# Sonderfälle (Wahrscheinlichkeit je Nuss vom Berg)
const CHANCE_GOLD := 0.005
const CHANCE_DOPPEL := 0.01
const CHANCE_FAUL := 0.05
const CHANCE_WURM := 0.03

# --- Bergschichten -----------------------------------------------------------
const SCHICHTEN := [
	{"ab": 0, "name": "Kuppe", "aera": 1, "mix": {"hasel": 0.45, "wal": 0.55}},
	{"ab": 1000, "name": "Hang", "aera": 2, "mix": {"hasel": 0.15, "wal": 0.4, "mandel": 0.27, "pekan": 0.18}},
	{"ab": 25000, "name": "Kern des Bergs", "aera": 3, "mix": {"wal": 0.3, "mandel": 0.2, "pekan": 0.2, "para": 0.18, "macadamia": 0.12}},
	{"ab": 150000, "name": "Fuß des Bergs", "aera": 4, "mix": {"wal": 0.25, "mandel": 0.15, "pekan": 0.2, "para": 0.2, "macadamia": 0.2}},
	{"ab": 500000, "name": "Grund", "aera": 5, "mix": {"hasel": 0.1, "wal": 0.2, "mandel": 0.15, "pekan": 0.15, "para": 0.2, "macadamia": 0.2}},
]

# --- Werkzeuge ---------------------------------------------------------------
# kraft, zeit = Sekunden bis Druck 1.0, sweet = Bonus auf Sweet-Spot-Breite
const WERKZEUGE := [
	{"id": "haende", "name": "Bloße Hände", "kraft": 2.0, "zeit": 1.2, "sweet": 0.0, "preis": 0, "aera": 1,
		"text": "Zwei Nüsse gegeneinander drücken. Walnüsse nur über einen Riss."},
	{"id": "holz", "name": "Holz-Nussknacker", "kraft": 4.0, "zeit": 1.0, "sweet": 0.0, "preis": 50, "aera": 1,
		"text": "Der Klassiker. Schafft Walnüsse in einem Zug."},
	{"id": "metall", "name": "Metall-Hebelknacker", "kraft": 6.0, "zeit": 0.8, "sweet": 0.03, "preis": 400, "aera": 1,
		"text": "Schneller und etwas gnädiger."},
	{"id": "hammer", "name": "Hammer", "kraft": 10.0, "zeit": 0.45, "sweet": -0.05, "preis": 2500, "aera": 2,
		"text": "Sehr schnell, aber ungenau."},
	{"id": "schraubstock", "name": "Schraubstock", "kraft": 14.0, "zeit": 1.6, "sweet": 0.08, "preis": 12000, "aera": 2,
		"text": "Langsam, sehr präzise. Schafft Macadamia."},
]
const WERKZEUG_MAX_STUFE := 10

# --- Maschinen und Extras ------------------------------------------------------
const MASCHINEN := {
	"rutsche": {"name": "Nussrutsche", "preis": 150, "aera": 1, "stufen": 10, "stufenpreis": 120,
		"text": "Holt Nüsse vom Berg und legt sie in den Knacker."},
	"deckel": {"name": "Glasdeckel", "preis": 300, "aera": 1, "stufen": 0,
		"text": "Eichhörnchen brauchen dreimal so lange am Glas."},
	"mimi": {"name": "Katze Mimi", "preis": 800, "aera": 1, "stufen": 0,
		"text": "Verscheucht Eichhörnchen. Fängt nie eins."},
	"sieb": {"name": "Tisch-Sieb", "preis": 1500, "aera": 2, "stufen": 0,
		"text": "Sortiert Kerne, Bruch und Schalen am Tisch von selbst."},
	"ofen": {"name": "Schalenofen", "preis": 1200, "aera": 2, "stufen": 0,
		"text": "Verbrennt Schalen zu Energie für Maschinen."},
	"walze": {"name": "Walzenknacker", "preis": 3000, "aera": 2, "stufen": 10, "stufenpreis": 900,
		"text": "Knackt allein. Braucht Energie. Präzision steigt mit jeder Stufe."},
	"band": {"name": "Förderband", "preis": 6000, "aera": 2, "stufen": 0,
		"text": "Bringt die Maschinenkiste automatisch zur Klappe."},
	"laufrad": {"name": "Eichhörnchen-Laufrad", "preis": 4000, "aera": 2, "stufen": 0, "talent": "laufrad",
		"text": "Gezähmte Eichhörnchen erzeugen Energie."},
}

const WALZE_KRAFT := 8.0

# --- Talente -------------------------------------------------------------------
# zweig: handwerk | maschinen | handel | wald | abwehr | zaehmen
const TALENTE := {
	"ruhige_hand": {"name": "Ruhige Hand", "zweig": "handwerk", "reihe": 1, "kosten": 1, "max": 5, "braucht": "",
		"text": "Sweet Spot +2 % pro Stufe"},
	"rhythmus": {"name": "Rhythmusgefühl", "zweig": "handwerk", "reihe": 2, "kosten": 5, "max": 3, "braucht": "ruhige_hand",
		"text": "Combo-Limit +10 pro Stufe"},
	"goldhand": {"name": "Goldhändchen", "zweig": "handwerk", "reihe": 3, "kosten": 15, "max": 1, "braucht": "rhythmus",
		"text": "Goldene Nüsse doppelt so oft"},
	"meisterknack": {"name": "Meisterknack", "zweig": "handwerk", "reihe": 4, "kosten": 50, "max": 1, "braucht": "goldhand",
		"text": "Handknack zählt für Bestellungen dreifach"},
	"gut_geoelt": {"name": "Gut geölt", "zweig": "maschinen", "reihe": 1, "kosten": 1, "max": 5, "braucht": "",
		"text": "Maschinen +10 % pro Stufe"},
	"baumeister": {"name": "Baumeister", "zweig": "maschinen", "reihe": 2, "kosten": 5, "max": 1, "braucht": "gut_geoelt",
		"text": "Maschinen zum halben Preis"},
	"schalenglut": {"name": "Schalenglut", "zweig": "maschinen", "reihe": 3, "kosten": 15, "max": 1, "braucht": "baumeister",
		"text": "+50 % Energie pro Schale"},
	"selbstlaeufer": {"name": "Selbstläufer", "zweig": "maschinen", "reihe": 4, "kosten": 50, "max": 1, "braucht": "schalenglut",
		"text": "Maschinen +20 % Präzision"},
	"feilschen": {"name": "Feilschen", "zweig": "handel", "reihe": 1, "kosten": 1, "max": 5, "braucht": "",
		"text": "Preise +5 % pro Stufe"},
	"stammkunden": {"name": "Stammkunden", "zweig": "handel", "reihe": 2, "kosten": 5, "max": 1, "braucht": "feilschen",
		"text": "4. Bestellung, +25 % Belohnung"},
	"grosshandel": {"name": "Großhandel", "zweig": "handel", "reihe": 3, "kosten": 15, "max": 1, "braucht": "stammkunden",
		"text": "Großhandelsbonus schon ab halbem Glas"},
	"nussbaron": {"name": "Nussbaron", "zweig": "handel", "reihe": 4, "kosten": 50, "max": 1, "braucht": "grosshandel",
		"text": "1 % Zinsen pro Minute (max. 500)"},
	"waldkenner": {"name": "Waldkenner", "zweig": "wald", "reihe": 1, "kosten": 1, "max": 1, "braucht": "",
		"text": "Raubzüge kündigen sich 10 s vorher an"},
	"katzenfreund": {"name": "Katzenfreund", "zweig": "abwehr", "reihe": 2, "kosten": 5, "max": 1, "braucht": "waldkenner",
		"text": "Mimi doppelt so schnell"},
	"festung": {"name": "Festung", "zweig": "abwehr", "reihe": 3, "kosten": 15, "max": 1, "braucht": "katzenfreund",
		"text": "Glasdeckel gratis, Diebe doppelt so langsam"},
	"waechter": {"name": "Wächter", "zweig": "abwehr", "reihe": 4, "kosten": 50, "max": 1, "braucht": "festung",
		"text": "Verscheuchte werfen Beute ab (+5 Münzen)"},
	"nussfluesterer": {"name": "Nussflüsterer", "zweig": "zaehmen", "reihe": 2, "kosten": 5, "max": 1, "braucht": "waldkenner",
		"text": "Eichhörnchen klauen nur noch halb so viel"},
	"laufrad": {"name": "Laufrad", "zweig": "zaehmen", "reihe": 3, "kosten": 15, "max": 1, "braucht": "nussfluesterer",
		"text": "Schaltet das Eichhörnchen-Laufrad frei"},
	"koenigsbund": {"name": "Königsbund", "zweig": "zaehmen", "reihe": 4, "kosten": 50, "max": 1, "braucht": "laufrad",
		"text": "Keine Raubzüge mehr, dafür 10 % Steuer"},
}

const ZWEIGE := ["handwerk", "maschinen", "handel", "abwehr", "zaehmen"]
const ZWEIG_NAMEN := {"handwerk": "Handwerk", "maschinen": "Maschinen", "handel": "Handel",
	"abwehr": "Wald: Abwehr", "zaehmen": "Wald: Zähmen", "wald": "Wald"}


func werkzeug(id: String) -> Dictionary:
	for w in WERKZEUGE:
		if w.id == id:
			return w
	return WERKZEUGE[0]


func schicht_fuer(genommen: int) -> Dictionary:
	var s: Dictionary = SCHICHTEN[0]
	for x in SCHICHTEN:
		if genommen >= x.ab:
			s = x
	return s


func naechste_schicht(genommen: int) -> Dictionary:
	for x in SCHICHTEN:
		if genommen < x.ab:
			return x
	return {}


## Meilenstein k liegt bei 100 * k^1.75 geknackten Nüssen.
func meilenstein_bei(k: int) -> int:
	return int(round(100.0 * pow(float(k), 1.75)))


func zufalls_nuss(genommen: int, rng: RandomNumberGenerator) -> String:
	var mix: Dictionary = schicht_fuer(genommen).mix
	var r := rng.randf()
	var summe := 0.0
	for id in mix:
		summe += mix[id]
		if r <= summe:
			return id
	return mix.keys()[mix.size() - 1]


## Formatiert Zahlen mit deutschem Tausenderpunkt.
func zahl(n: float) -> String:
	var ganz := int(floor(abs(n)))
	var s := str(ganz)
	var aus := ""
	var zaehler := 0
	for i in range(s.length() - 1, -1, -1):
		aus = s[i] + aus
		zaehler += 1
		if zaehler % 3 == 0 and i > 0:
			aus = "." + aus
	return ("-" if n < 0 else "") + aus
