extends Node
## Alle festen Spielwerte an einer Stelle: Nüsse, Sammel- und Knackwerkzeuge, Beutel,
## Maschinen, Helfer, Bergschichten und der Skillbaum. Balancing passiert hier.

const BERG_GROESSE := 1_000_000

# Physik-Ebenen (Bitmasken)
const L_WELT := 1
const L_ITEM := 2
const L_BEHAELTER := 4
const L_SPIELER := 8
const L_INTERAKT := 16
const L_TIER := 32

# --- Nüsse -----------------------------------------------------------------
# haerte = Mindestkraft, sweet = Breite der Trefferzone (Anteil an einer Zeigerrunde von 1,3),
# wert = Münzen je ganzer Kernhälfte, groesse = Radius in Metern (spielfreundlich vergrößert)
const NUESSE := {
	"hasel": {"name": "Haselnuss", "haerte": 1.0, "sweet": 0.30, "wert": 1.0, "groesse": 0.034, "muster": 0, "falten": 0.0,
		"form": Vector3(1.0, 1.0, 1.0), "farbe": Color(0.74, 0.47, 0.22), "farbe2": Color(0.48, 0.28, 0.12),
		"kern": Color(0.9, 0.78, 0.58), "kern2": Color(0.6, 0.4, 0.22)},
	"wal": {"name": "Walnuss", "haerte": 3.0, "sweet": 0.22, "wert": 4.0, "groesse": 0.046, "muster": 1, "falten": 1.0,
		"form": Vector3(1.0, 1.08, 1.0), "farbe": Color(0.72, 0.55, 0.35), "farbe2": Color(0.36, 0.24, 0.13),
		"kern": Color(0.82, 0.64, 0.4), "kern2": Color(0.48, 0.3, 0.14)},
	"mandel": {"name": "Mandel", "haerte": 2.0, "sweet": 0.18, "wert": 6.0, "groesse": 0.042, "muster": 2, "falten": 0.0,
		"form": Vector3(0.72, 0.55, 1.35), "farbe": Color(0.82, 0.63, 0.41), "farbe2": Color(0.56, 0.38, 0.22),
		"kern": Color(0.97, 0.91, 0.8), "kern2": Color(0.62, 0.4, 0.22)},
	"pekan": {"name": "Pekannuss", "haerte": 4.0, "sweet": 0.12, "wert": 10.0, "groesse": 0.042, "muster": 3, "falten": 1.0,
		"form": Vector3(0.78, 0.78, 1.5), "farbe": Color(0.58, 0.32, 0.16), "farbe2": Color(0.24, 0.12, 0.06),
		"kern": Color(0.74, 0.48, 0.26), "kern2": Color(0.4, 0.22, 0.1)},
	"para": {"name": "Paranuss", "haerte": 7.0, "sweet": 0.15, "wert": 18.0, "groesse": 0.048, "muster": 4, "falten": 0.0,
		"form": Vector3(0.75, 0.9, 1.4), "farbe": Color(0.42, 0.29, 0.18), "farbe2": Color(0.2, 0.13, 0.08),
		"kern": Color(0.96, 0.93, 0.86), "kern2": Color(0.55, 0.4, 0.28), "springt": true},
	"macadamia": {"name": "Macadamia", "haerte": 12.0, "sweet": 0.14, "wert": 35.0, "groesse": 0.04, "muster": 5, "falten": 0.0,
		"form": Vector3(1.0, 1.0, 1.0), "farbe": Color(0.64, 0.47, 0.3), "farbe2": Color(0.42, 0.3, 0.18),
		"kern": Color(0.98, 0.95, 0.86), "kern2": Color(0.84, 0.75, 0.58)},
}

# Sonderfälle (Wahrscheinlichkeit je Nuss vom Berg)
const CHANCE_GOLD := 0.005
const CHANCE_DOPPEL := 0.01
const CHANCE_FAUL := 0.05
const CHANCE_WURM := 0.03

# --- Bergschichten -----------------------------------------------------------
const SCHICHTEN := [
	{"ab": 0, "name": "Kuppe", "aera": 1, "mix": {"hasel": 0.45, "wal": 0.55}},
	{"ab": 25000, "name": "Hang", "aera": 2, "mix": {"hasel": 0.2, "wal": 0.4, "mandel": 0.25, "pekan": 0.15}},
	{"ab": 150000, "name": "Kern des Bergs", "aera": 3, "mix": {"wal": 0.3, "mandel": 0.2, "pekan": 0.2, "para": 0.18, "macadamia": 0.12}},
	{"ab": 450000, "name": "Fuß des Bergs", "aera": 4, "mix": {"wal": 0.25, "mandel": 0.15, "pekan": 0.2, "para": 0.2, "macadamia": 0.2}},
	{"ab": 800000, "name": "Grund", "aera": 5, "mix": {"hasel": 0.1, "wal": 0.2, "mandel": 0.15, "pekan": 0.15, "para": 0.2, "macadamia": 0.2}},
]

# --- Sammeln am Berg ---------------------------------------------------------
# rate = Nüsse pro Sekunde bei gedrückter Taste, radius = Fläche, aus der gesammelt wird,
# reichweite = wie weit man vom Berg entfernt sein darf
const SAMMLER := [
	{"id": "haende", "name": "Bloße Hände", "rate": 1.3, "radius": 0.45, "reichweite": 2.6, "preis": 0, "aera": 1,
		"text": "Eine Nuss nach der anderen. Opa hat auch so angefangen."},
	{"id": "loeffel", "name": "Holzlöffel", "rate": 3.0, "radius": 0.55, "reichweite": 2.8, "preis": 40, "aera": 1,
		"text": "Ein großer Suppenlöffel. Lächerlich, aber dreimal so schnell."},
	{"id": "harke", "name": "Laubharke", "rate": 6.5, "radius": 0.9, "reichweite": 3.2, "preis": 300, "aera": 1,
		"text": "Zieht die Nüsse in breiten Bahnen zu dir."},
	{"id": "schaufel", "name": "Schaufel", "rate": 14.0, "radius": 1.1, "reichweite": 3.2, "preis": 2200, "aera": 1,
		"text": "Ehrliche Arbeit: ganze Ladungen auf einmal."},
	{"id": "laubsauger", "name": "Laubsauger", "rate": 32.0, "radius": 1.6, "reichweite": 5.0, "preis": 15000, "aera": 2,
		"text": "Saugt Nüsse aus fünf Metern Entfernung an."},
	{"id": "turbine", "name": "Saugturbine", "rate": 80.0, "radius": 2.4, "reichweite": 7.0, "preis": 110000, "aera": 3,
		"text": "Ein dröhnender Rüssel. Die Nüsse kommen in Wellen."},
	{"id": "xxl", "name": "Nuss-Sauger XXL", "rate": 220.0, "radius": 3.4, "reichweite": 9.0, "preis": 400000, "aera": 4,
		"text": "Der Berg zittert, wenn du ihn einschaltest."},
	# Geheimes Werkzeug: gibt es nicht zu kaufen, nur an der Mondlichtung zu finden
	{"id": "zahnbuerste", "name": "Goldene Zahnbürste", "rate": 1.0, "radius": 0.3, "reichweite": 2.6, "preis": 0, "aera": 1, "geheim": true,
		"text": "Lächerlich langsam. Aber jede 50. Nuss ist eine Mondnuss (50 Münzen)."},
]
const MONDNUSS_JEDE := 50
const MONDNUSS_WERT := 50.0

# kap = wie viele Nüsse man tragen kann, tempo = Laufgeschwindigkeit (Faktor)
const BEUTEL := [
	{"id": "taschen", "name": "Hosentaschen", "kap": 12, "tempo": 1.0, "preis": 0, "aera": 1, "text": "Mehr passt nicht rein."},
	{"id": "stoffbeutel", "name": "Stoffbeutel", "kap": 30, "tempo": 1.0, "preis": 120, "aera": 1, "text": "Opas alter Einkaufsbeutel."},
	{"id": "rucksack", "name": "Rucksack", "kap": 80, "tempo": 1.0, "preis": 900, "aera": 1, "text": "Zwei Riemen, viel Platz."},
	{"id": "kiepe", "name": "Kiepe", "kap": 220, "tempo": 0.97, "preis": 6500, "aera": 1, "text": "Ein Weidenkorb für den Rücken."},
	{"id": "schubkarre", "name": "Schubkarre", "kap": 650, "tempo": 0.95, "preis": 45000, "aera": 2, "text": "Quietscht, aber schafft was weg."},
	{"id": "bollerwagen", "name": "Bollerwagen", "kap": 1800, "tempo": 0.93, "preis": 180000, "aera": 3, "text": "Vier Räder, keine Ausreden."},
	{"id": "riesensack", "name": "Riesensack", "kap": 5000, "tempo": 0.9, "preis": 900000, "aera": 4, "text": "Größer als du. Viel größer."},
]

# Abliefern: jede abgelieferte Nuss bringt sofort etwas, Knacken bringt viel mehr
const ABLIEFER_PRAEMIE := 1.0
const LAGER_GROESSE := 300

# Sammel-Eichhörnchen (zahme Helfer): kosten steigen mit jedem weiteren
const HELFER_PREIS := 500.0
const HELFER_FAKTOR := 1.35
const HELFER_LAST := 8
const HELFER_RATE := 1.0
const HELFER_TEMPO := 2.4
const HELFER_MAX_SICHTBAR := 40

# Außenposten am Bergfuß: Abgabestellen mit Förderband zur Hütte
# "weg" = Knickpunkte des Hochförderbands vom Posten zur Hütte
const POSTEN := [
	{"id": "posten_vorn", "name": "Außenposten Vorn", "preis": 3500, "aera": 1, "pos": Vector3(6.5, 0, -9.0),
		"weg": [Vector3(3.0, 0, -5.4)],
		"text": "Eine Abgabestelle direkt am Fuß des Bergs. Ein Förderband bringt alles ins Silo."},
	{"id": "posten_west", "name": "Außenposten West", "preis": 30000, "aera": 2, "pos": Vector3(-23.0, 0, -22.0),
		"weg": [Vector3(-9.0, 0, -6.0)],
		"text": "Für die Westflanke. Spart lange Wege."},
	{"id": "posten_ost", "name": "Außenposten Ost", "preis": 180000, "aera": 3, "pos": Vector3(24.5, 0, -24.0),
		"weg": [Vector3(13.0, 0, -6.0), Vector3(3.0, 0, -5.4)],
		"text": "Für die Ostflanke."},
	{"id": "posten_hinten", "name": "Außenposten Hinten", "preis": 900000, "aera": 4, "pos": Vector3(1.0, 0, -57.0),
		"weg": [Vector3(28.0, 0, -46.0), Vector3(28.0, 0, -18.0), Vector3(13.0, 0, -6.0), Vector3(3.0, 0, -5.4)],
		"text": "Ganz hinten am Berg, wo bisher keiner hinkam."},
]

const WERKZEUGE := [
	{"id": "haende", "name": "Bloße Hände", "kraft": 2.0, "zeit": 1.2, "sweet": 0.0, "preis": 0, "aera": 1,
		"text": "Mit beiden Händen zusammenpressen. Walnüsse brauchen erst einen Riss."},
	{"id": "holz", "name": "Holz-Nussknacker", "kraft": 4.0, "zeit": 1.0, "sweet": 0.0, "preis": 150, "aera": 1,
		"text": "Opas alte Hebelpresse aus Eiche. Schafft Walnüsse in einem Zug."},
	{"id": "metall", "name": "Metall-Hebelknacker", "kraft": 6.0, "zeit": 0.8, "sweet": 0.03, "preis": 1200, "aera": 1,
		"text": "Verchromter Hebel: schneller und etwas gnädiger."},
	{"id": "hammer", "name": "Hammer", "kraft": 10.0, "zeit": 0.45, "sweet": -0.05, "preis": 9000, "aera": 2,
		"text": "Holt blitzschnell aus: Der Zeiger rast, die Trefferzone ist kleiner."},
	{"id": "schraubstock", "name": "Schraubstock", "kraft": 14.0, "zeit": 1.6, "sweet": 0.08, "preis": 40000, "aera": 3,
		"text": "Kurbel drehen: langsam, sehr präzise. Schafft Macadamia."},
]
const WERKZEUG_MAX_STUFE := 10

# --- Maschinen und Extras ------------------------------------------------------
const MASCHINEN := {
	"rutsche": {"name": "Nussrutsche", "preis": 150, "aera": 1, "stufen": 10, "stufenpreis": 150,
		"text": "Holt Nüsse aus dem Lager in die Schale und legt nach, auch wenn du draußen bist."},
	"sieb": {"name": "Tisch-Sieb", "preis": 500, "aera": 1, "stufen": 0,
		"text": "Schalen und Bruch rutschen von selbst weg. Kein Wischen mehr."},
	"deckel": {"name": "Glasdeckel", "preis": 400, "aera": 1, "stufen": 0,
		"text": "Eichhörnchen brauchen dreimal so lange am Glas."},
	"mimi": {"name": "Katze Mimi", "preis": 1200, "aera": 1, "stufen": 0,
		"text": "Verscheucht diebische Eichhörnchen. Fängt nie eins."},
	"walze": {"name": "Walzenknacker", "preis": 6000, "aera": 2, "stufen": 15, "stufenpreis": 2500,
		"text": "Knackt Nüsse aus dem Lager von allein. Jede Stufe schneller und genauer."},
	"lagerhalle": {"name": "Lagerhalle", "preis": 20000, "aera": 2, "stufen": 10, "stufenpreis": 15000,
		"text": "Zehnmal so viel Platz im Lager. Jede Stufe +50 %."},
}

# --- Fundbuch: die Geheimnisse des Haselgrunds ---------------------------------------
# hinweis = Andeutung, solange noch nicht gefunden; text = Opas Kommentar danach
const FUNDE := [
	{"id": "mondlichtung", "name": "Die Mondlichtung", "hinweis": "Hinter dem Berg liegt grauer Staub, den keiner bestellt hat.",
		"text": "Ich hab's immer gesagt: Manche Nüsse kommen vom Mond. Jetzt hast du den Beweis und eine Zahnbürste."},
	{"id": "nadel", "name": "Die Nadel im Heuhaufen", "hinweis": "Nadel verloren. Irgendwo zwischen Heu und Abendrot.",
		"text": "Elf Jahre hab ich die gesucht. Elf! Und du läufst einfach hin. Die Eichhörnchen haben zu Recht geklatscht."},
	{"id": "koenig", "name": "Der Eichhörnchen-König", "hinweis": "Kleine Füße, immer paarweise, und Bäume mit Krone.",
		"text": "Seine Majestät nimmt Gold, aber keine Befehle. Unser Pakt gilt jetzt auch für dich."},
	{"id": "miniberg", "name": "Der Mini-Nussberg", "hinweis": "Die Post bringt nicht nur Briefe.",
		"text": "Maßstab 1 zu 150. Der Briefträger fand das nicht lustig. Ich schon."},
	{"id": "flaschenpost", "name": "Opas Flaschenpost", "hinweis": "Im Schilf treibt etwas, das kein Fisch ist.",
		"text": "Die sollte eigentlich bis zum Meer. Sie ist zwölf Meter weit gekommen."},
	{"id": "herz", "name": "O + F", "hinweis": "Manches sieht man nur, wenn man nasse Füße riskiert.",
		"text": "Frieda wollte die Brücke, ich wollte den Berg. Wir haben beides bekommen."},
	{"id": "goldwalnuss", "name": "Die Goldene Walnuss", "hinweis": "Ein Vogel sammelt auch. Nur weiter oben.",
		"text": "Die Elster hat sie mir 1989 geklaut. Ich hab den Hochsitz nur gebaut, um sie zu beobachten."},
	{"id": "keller", "name": "Opas Keller", "hinweis": "Unter manchem Teppich liegt mehr als Staub.",
		"text": "Von jedem Jahr ein Glas. 1974 schmeckt übrigens furchtbar."},
	{"id": "nussbert", "name": "Sir Nussbert", "hinweis": "Einer von dreihundert trägt Hut.",
		"text": "Er kam eines Tages mit Zylinder und Monokel. Ich habe nie gefragt, woher."},
	{"id": "hexenring", "name": "Der Hexenring", "hinweis": "Nach dem Regen, wenn es dunkel ist, leuchtet der Wald an einer Stelle.",
		"text": "Nicht reintreten, hat Frieda gesagt. Ich bin jedes Mal reingetreten."},
	{"id": "studio", "name": "Hinter dem Wasserfall", "hinweis": "Wasser fällt nicht immer vor einer Wand.",
		"text": "Hier sitzen die, die sich das alles ausgedacht haben. Sei nett zu ihnen."},
	{"id": "figuren", "name": "Opas Nussknacker-Figuren", "hinweis": "Zwölf kleine Kerle aus Holz stehen im Tal herum.",
		"text": "Jeden Winter eine geschnitzt. Der Goldene gehört dir, du hast ihn dir verdient."},
]

# Wer Deez Nuts! gebaut hat. Das Team trägt hier seine Namen ein; sie erscheinen im Raum hinter dem Wasserfall.
const TEAM := ["beydo7"]

# --- Geführte Ziele am Anfang ----------------------------------------------------
# Danach zeigt das Spiel immer das nächste bezahlbare Ziel aus dem Katalog.
const ZIELE := [
	{"id": "berg", "text": "Geh raus zum Nussberg", "hilfe": "Die Tür ist rechts vom Fenster", "lohn": 0},
	{"id": "voll", "text": "Füll deine Taschen", "hilfe": "[Linksklick] halten, während du auf den Berg schaust", "lohn": 5},
	{"id": "abliefern", "text": "Bring die Nüsse zum Trichter", "hilfe": "Lauf in den gelben Kreis an der Hütte", "lohn": 5},
	{"id": "knacken", "text": "Knack 3 Nüsse perfekt", "hilfe": "Drinnen an die Knackbank [E], [R] holt Nüsse. [Leertaste], wenn der Zeiger im hellen Bereich ist", "lohn": 10, "anzahl": 3},
	{"id": "loeffel", "text": "Kauf den Holzlöffel", "hilfe": "Am Bestellbrett neben dem Trichter [E] oder am Telefon", "lohn": 0},
	{"id": "beutel", "text": "Kauf den Stoffbeutel", "hilfe": "Mehr tragen = weniger laufen", "lohn": 0},
	{"id": "skill", "text": "Lern deinen ersten Skill", "hilfe": "[Tab] öffnet Opas Notizbuch", "lohn": 0},
]

const WALZE_KRAFT := 8.0

# --- Skillbaum (Opas Notizbuch) -------------------------------------------------
# Sieben Pfade vom Mittelpunkt aus. Jeder Knoten kostet Münzen und gibt einen kleinen Bonus,
# Schlüsselknoten (gross) geben besondere Fähigkeiten. Der Baum wird aus diesen Daten erzeugt.
const SKILL_PFADE := [
	{"id": "sammeln", "name": "Sammeln", "farbe": Color(0.95, 0.7, 0.3), "basis": 25.0,
		"werte": [["sammel_tempo", 0.08, "Sammeln +8 %"], ["sammel_radius", 0.06, "Sammelradius +6 %"], ["doppelgriff", 0.015, "+1,5 % doppelte Ausbeute"]],
		"schluessel": [["wuehlmaus", "Wühlmaus", "Sammeln +30 %"], ["grabkoenig", "Grabkönig", "Sammelradius +40 %"], ["nusswelle", "Nusswelle", "Jede 10. Sekunde Sammeln fünffach"]]},
	{"id": "tragen", "name": "Tragen", "farbe": Color(0.55, 0.8, 0.45), "basis": 30.0,
		"werte": [["kapazitaet", 0.1, "Tragen +10 %"], ["lauftempo", 0.03, "Laufen +3 %"], ["kapazitaet", 0.1, "Tragen +10 %"]],
		"schluessel": [["packesel", "Packesel", "Tragen +50 %"], ["siebenmeilen", "Siebenmeilenstiefel", "Laufen +20 %"], ["bodenlos", "Bodenloser Beutel", "Tragen verdoppelt"]]},
	{"id": "abliefern", "name": "Handel", "farbe": Color(1.0, 0.85, 0.35), "basis": 35.0,
		"werte": [["praemie", 0.1, "Ablieferprämie +10 %"], ["preise", 0.05, "Kernpreise +5 %"], ["lager", 0.15, "Lager +15 %"]],
		"schluessel": [["feilschen", "Feilschen", "Alle Preise +15 %"], ["stammkunden", "Stammkunden", "4. Bestellung, +25 % Belohnung"], ["nussbaron", "Nussbaron", "1 % Zinsen pro Minute (max. 5.000)"]]},
	{"id": "knacken", "name": "Knacken", "farbe": Color(0.95, 0.45, 0.35), "basis": 30.0,
		"werte": [["sweet", 0.01, "Trefferzone +1 %"], ["kernwert", 0.08, "Handknack +8 % Wert"], ["combo", 2.0, "Combo-Limit +2"]],
		"schluessel": [["ruhige_hand", "Ruhige Hand", "Trefferzone +6 %"], ["rhythmus", "Rhythmusgefühl", "Combo-Limit +10"], ["meisterknack", "Meisterknack", "Handknack zählt für Bestellungen dreifach"]]},
	{"id": "maschinen", "name": "Maschinen", "farbe": Color(0.5, 0.7, 0.95), "basis": 60.0,
		"werte": [["walze_tempo", 0.1, "Walze +10 %"], ["walze_praezision", 0.02, "Walze +2 % Präzision"], ["rutsche", 0.1, "Rutsche +10 %"]],
		"schluessel": [["gut_geoelt", "Gut geölt", "Alle Maschinen +25 %"], ["baumeister", "Baumeister", "Maschinen und Posten 30 % günstiger"], ["selbstlaeufer", "Selbstläufer", "Walze +15 % Präzision"]]},
	{"id": "helfer", "name": "Helfer", "farbe": Color(0.85, 0.55, 0.3), "basis": 80.0,
		"werte": [["helfer_tempo", 0.08, "Helfer +8 % schneller"], ["helfer_last", 0.15, "Helfer tragen +15 %"], ["helfer_preis", 0.03, "Helfer 3 % günstiger"]],
		"schluessel": [["nussfluesterer", "Nussflüsterer", "Wilde Eichhörnchen klauen nur halb so viel"], ["katzenfreund", "Katzenfreund", "Mimi doppelt so schnell"], ["koenigsbund", "Königsbund", "Keine Diebe mehr, Helfer +50 %"]]},
	{"id": "glueck", "name": "Glück", "farbe": Color(0.75, 0.55, 0.95), "basis": 50.0,
		"werte": [["gold", 0.12, "Goldene Nüsse +12 %"], ["doppel", 0.15, "Doppelnüsse +15 %"], ["goldwert", 0.1, "Goldnüsse +10 % Wert"]],
		"schluessel": [["goldhand", "Goldhändchen", "Goldene Nüsse doppelt so oft"], ["festung", "Glückspilz", "Faule Nüsse halb so oft"], ["waechter", "Wächter", "Verscheuchte Diebe lassen Beute fallen (+5 Münzen)"]]},
]
const SKILL_KETTE := 18          # Knoten auf dem Hauptast jedes Pfads
const SKILL_SEITEN := [3, 7, 11, 15]   # an diesen Knoten zweigt ein Seitenast ab
const SKILL_SEITE_LAENGE := 3
const SKILL_WACHSTUM := 1.7

var _skills_cache := {}


## Alle Knoten des Skillbaums: id -> {name, text, pfad, wert:[stat, betrag] oder schluessel, preis, braucht, pos}
func skills() -> Dictionary:
	if not _skills_cache.is_empty():
		return _skills_cache
	var alle := {}
	alle["wurzel"] = {"name": "Opas Notizbuch", "text": "Hier fängt alles an.", "pfad": "", "preis": 0.0, "braucht": "", "pos": Vector2.ZERO, "gross": true}
	for pi in SKILL_PFADE.size():
		var p: Dictionary = SKILL_PFADE[pi]
		var winkel := TAU * float(pi) / SKILL_PFADE.size() - PI * 0.5
		var richtung := Vector2(cos(winkel), sin(winkel))
		var quer := Vector2(-richtung.y, richtung.x)
		var vorher := "wurzel"
		var schluessel_nr := 0
		for i in SKILL_KETTE:
			var id := "%s_%d" % [p.id, i]
			var tiefe := i + 1
			var knoten := {"pfad": p.id, "braucht": vorher, "preis": round(float(p.basis) * pow(SKILL_WACHSTUM, tiefe)),
				"pos": richtung * (125.0 + i * 52.0) + quer * sin(i * 0.7) * 10.0, "gross": false}
			if (i + 1) % 6 == 0 and schluessel_nr < p.schluessel.size():
				var s: Array = p.schluessel[schluessel_nr]
				id = s[0]
				knoten.name = s[1]
				knoten.text = s[2]
				knoten.schluessel = true
				knoten.gross = true
				knoten.preis = round(knoten.preis * 2.0)
				schluessel_nr += 1
			else:
				var w: Array = p.werte[i % p.werte.size()]
				knoten.name = w[2]
				knoten.text = w[2]
				knoten.wert = [w[0], w[1]]
			alle[id] = knoten
			if i in SKILL_SEITEN:
				var vor_seite := id
				var seite := 1.0 if (i / 4) % 2 == 0 else -1.0
				for j in SKILL_SEITE_LAENGE:
					var sid := "%s_%d_s%d" % [p.id, i, j]
					var w2: Array = p.werte[(i + j + 1) % p.werte.size()]
					alle[sid] = {"pfad": p.id, "braucht": vor_seite, "preis": round(float(p.basis) * pow(SKILL_WACHSTUM, tiefe + j + 1) * 1.2),
						"pos": richtung * (125.0 + i * 52.0 + (j + 1) * 20.0) + quer * seite * (48.0 + j * 40.0),
						"name": w2[2], "text": w2[2], "wert": [w2[0], w2[1] * 1.5], "gross": false}
					vor_seite = sid
			vorher = id
	_skills_cache = alle
	return alle


func fund_daten(id: String) -> Dictionary:
	for f in FUNDE:
		if f.id == id:
			return f
	return {}


func sammler(id: String) -> Dictionary:
	for w in SAMMLER:
		if w.id == id:
			return w
	return SAMMLER[0]


func beutel(id: String) -> Dictionary:
	for b in BEUTEL:
		if b.id == id:
			return b
	return BEUTEL[0]


func posten(id: String) -> Dictionary:
	for p in POSTEN:
		if p.id == id:
			return p
	return {}


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
