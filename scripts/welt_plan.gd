class_name WeltPlan
extends RefCounted
## Der Aufbau des Haselgrunds: Talform, Bachlauf, Wege und die festen Orte.
## Koordinaten in Metern wie im Spiel: x nach Osten, z nach Süden (Norden = Berg).
## Die Karte dazu steht im Weltplan (Link in der README).

# --- Talform -------------------------------------------------------------------
## Mittelpunkt und Halbachsen der flachen Talsohle. Außerhalb (r > 1) steigen die Hügel an.
const TAL_MITTE := Vector2(0.0, -15.0)
const TAL_RADIEN := Vector2(65.0, 72.0)
const HUEGEL_HOEHE := 14.0
## Bis hierhin darf man laufen (in Talradien), dahinter steht eine unsichtbare Grenze.
const GRENZE := 1.5
## Talsohle liegt knapp unter null, damit Fußböden und Berg sauber darauf sitzen.
const SOHLE := -0.02

## Bereiche, die topfeben bleiben müssen (Berg, Hütte, Posten, Bänder). [Mitte, Radius]
const EBEN := [
	[Vector2(1.0, -32.0), 27.0],     # Nussberg samt Rand
	[Vector2(4.0, 4.0), 20.0],       # Anwesen
	[Vector2(-23.0, -22.0), 6.0],    # Außenposten West
	[Vector2(24.5, -24.0), 6.0],     # Außenposten Ost
	[Vector2(1.0, -57.0), 6.0],      # Außenposten Hinten
	[Vector2(28.0, -32.0), 16.0],    # Bandstrecke Ost
]

## Einzelne Erhebungen in der Talsohle. [Mitte, Radius, Höhe]
const BUCKEL := [
	[Vector2(44.0, -63.0), 15.0, 7.5],    # Hügel mit Opas Hochsitz
	[Vector2(-40.0, 22.0), 12.0, 1.6],    # sanfte Kuppe bei der Siedlung
	[Vector2(30.0, 22.0), 10.0, 1.2],
	[Vector2(-16.0, -62.0), 9.0, 1.4],
]

## Felsstufe, über die der Bach als Wasserfall fällt. [Mitte, flacher Radius, Kantenbreite, Höhe]
const FELSSTUFE := [Vector2(-61.0, -83.0), 15.2, 1.6, 5.2]

# --- Bach ----------------------------------------------------------------------
## Mittellinie des Bachs von der Quelle bis zum Ausgang. Der dritte Wert ist die Wasserhöhe.
## Zwischen Punkt 2 (Kante) und 3 (Becken) fällt der Wasserfall.
const BACH := [
	Vector3(-70.0, 4.0, -96.0),
	Vector3(-60.0, 4.0, -80.0),
	Vector3(-52.5, 4.0, -70.0),     # Kante des Wasserfalls
	Vector3(-49.5, -0.55, -65.5),   # Becken unter dem Wasserfall
	Vector3(-45.0, -0.55, -50.0),
	Vector3(-37.0, -0.55, -24.0),
	Vector3(-31.0, -0.55, -2.0),
	Vector3(-28.5, -0.55, 12.0),
	Vector3(-19.0, -0.55, 28.0),
	Vector3(-6.0, -0.55, 34.0),
	Vector3(8.0, -0.55, 35.5),
	Vector3(32.0, -0.55, 41.0),
	Vector3(58.0, -0.55, 46.0),
	Vector3(90.0, -0.55, 52.0),
]
const BACH_KANTE := 2
const BACH_BREITE := 2.8     # Wasserfläche
const BACH_TIEFE := 0.45     # Wasser über dem tiefsten Punkt
const BACH_UFER := 4.5       # Breite der Uferböschung

# --- Wege ----------------------------------------------------------------------
## [Punkte, Breite]. Breite 0 = nur leicht ausgetretener Pfad.
const WEGE := [
	# Zufahrt vom Südausgang über die Hofbrücke und am Anwesen vorbei bis zum Berg
	[[Vector2(4.0, 80.0), Vector2(3.0, 52.0), Vector2(2.5, 36.0), Vector2(2.0, 22.0), Vector2(-3.0, 13.0),
		Vector2(-5.2, 5.0), Vector2(-6.2, -3.5), Vector2(-5.2, -8.0), Vector2(-2.0, -10.0), Vector2(1.0, -11.0)], 2.6],
	# Vom Hof zur Feuerstelle und weiter zum Angelplatz
	[[Vector2(-6.2, -3.5), Vector2(-9.5, -8.5), Vector2(-12.5, -10.2), Vector2(-20.0, -12.5), Vector2(-31.0, -14.0)], 1.2],
	# Vom Hof über Omas Brücke nach Alt-Haselgrund
	[[Vector2(-5.2, 5.0), Vector2(-15.0, 7.5), Vector2(-28.5, 11.5), Vector2(-40.0, 16.0), Vector2(-50.0, 20.0)], 1.5],
	# Siedlung zum Heuschober und zum Picknickplatz
	[[Vector2(-50.0, 20.0), Vector2(-54.0, 10.0), Vector2(-56.0, 4.0)], 1.0],
	[[Vector2(-40.0, 16.0), Vector2(-40.5, 28.0), Vector2(-40.0, 36.0)], 0.9],
	# Vom Hof am Berg vorbei hinauf zum Hochsitz
	[[Vector2(15.0, -9.0), Vector2(27.0, -14.0), Vector2(36.0, -30.0), Vector2(40.0, -48.0), Vector2(43.0, -61.0)], 1.0],
	# Wildpfad hinter dem Berg zur Königseiche
	[[Vector2(16.0, -52.0), Vector2(24.0, -64.0), Vector2(30.0, -76.0)], 0.0],
	# Hof zum Hühnerstall
	[[Vector2(2.0, 22.0), Vector2(9.0, 14.0), Vector2(14.0, 9.0)], 0.0],
]

# --- Orte ----------------------------------------------------------------------
const ORTE := {
	"hoftor": Vector3(2.0, 0, 22.0),
	"feuerstelle": Vector3(-12.0, 0, -12.5),
	"angelplatz": Vector3(-33.0, 0, -13.0),
	"bruecke_oma": Vector3(-28.8, 0, 11.6),
	"bruecke_hof": Vector3(2.5, 0, 35.2),
	"wasserfall": Vector3(-52.5, 0, -70.0),
	"siedlung": Vector3(-50.0, 0, 20.0),
	"picknick": Vector3(-40.0, 0, 36.0),
	"heuschober": Vector3(-56.0, 0, 4.0),
	"hochsitz": Vector3(44.0, 0, -63.0),
	"koenigseiche": Vector3(30.0, 0, -78.0),
	"mondlichtung": Vector3(-8.0, 0, -92.0),
	"traktor": Vector3(19.5, 0, -39.5),
	"brunnen": Vector3(-10.0, 0, 2.0),
	"garten": Vector3(-11.1, 0, 12.25),
	"huehnerstall": Vector3(15.8, 0, 8.2),
	"holzlager": Vector3(13.0, 0, 1.8),
	"apfelbaum": Vector3(-6.0, 0, 18.5),
}

## Baumgruppen in der Talsohle, von Hand gesetzt. [Mitte, Anzahl, Streuung, Art]
## Art: "gruen", "herbst", "kahl", "gemischt"
const BAUMGRUPPEN := [
	[Vector2(-15.0, -16.0), 3, 4.0, "herbst"],     # hinter der Feuerstelle, rahmt den Blick auf den Berg
	[Vector2(-36.5, -8.0), 2, 3.0, "gruen"],       # Schatten über dem Angelplatz
	[Vector2(-33.0, 16.0), 3, 4.5, "gemischt"],    # an Omas Brücke
	[Vector2(-22.0, 30.0), 4, 6.0, "herbst"],      # Bachbogen im Süden
	[Vector2(16.0, 26.0), 3, 5.0, "gemischt"],     # beim Hoftor
	[Vector2(-4.0, 26.0), 2, 3.0, "herbst"],
	[Vector2(30.0, 6.0), 4, 6.0, "gruen"],         # östliche Wiese
	[Vector2(38.0, -40.0), 3, 5.0, "herbst"],      # am Weg zum Hochsitz
	[Vector2(-30.0, -48.0), 4, 6.0, "gemischt"],   # Westseite des Bergs
	[Vector2(-12.0, -70.0), 3, 5.0, "herbst"],
	[Vector2(18.0, -66.0), 3, 4.0, "kahl"],
	[Vector2(-46.0, 32.0), 3, 5.0, "gruen"],       # Picknickplatz
	[Vector2(-58.0, 14.0), 3, 5.0, "herbst"],      # Siedlungsrand
	[Vector2(48.0, 18.0), 3, 6.0, "herbst"],
	[Vector2(-44.0, -32.0), 2, 3.0, "kahl"],
]


## Bebaute Flächen des Anwesens (x, z, Breite, Tiefe): hier wächst nichts Wildes.
const BEBAUT := [
	Rect2(-3.3, 2.9, 10.6, 3.2),      # Veranda
	Rect2(-14.9, 8.2, 7.6, 8.1),      # Garten
	Rect2(-11.2, 0.8, 2.4, 2.4),      # Brunnen
	Rect2(14.0, 6.9, 3.8, 2.8),       # Hühnerstall
	Rect2(11.2, 0.9, 4.8, 2.8),       # Holzlager
	Rect2(-14.6, -14.6, 4.6, 5.2),    # Feuerstelle
	Rect2(-14.6, 20.8, 33.0, 2.2),    # Hofzaun, Tor, Briefkasten
]


static func bebaut(x: float, z: float, rand := 0.0) -> bool:
	for r in BEBAUT:
		if (r as Rect2).grow(rand).has_point(Vector2(x, z)):
			return true
	return false


static func tal_r(x: float, z: float) -> float:
	return Vector2((x - TAL_MITTE.x) / TAL_RADIEN.x, (z - TAL_MITTE.y) / TAL_RADIEN.y).length()
