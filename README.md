# Deez Nuts!

Ein physisches Ego-Incremental über Nüsse, eine Mischung aus Potato Please, Moon Sweepers, How They Built the Pyramids und „1.000.000 Coins“. Hinter Opas Hütte liegt ein Berg aus einer Million Nüssen, auf dem man herumlaufen kann. Du schaufelst ihn Stück für Stück ab: sammeln, im Beutel zur Hütte tragen, in den Trichter kippen, an der Knackbank knacken, aufrüsten. Später sammeln Eichhörnchen für dich, Außenposten mit Förderbändern sparen Wege, und der Berg wird sichtbar kleiner, bis er weg ist.

Gebaut mit [Godot 4.7.2](https://godotengine.org) (GDScript, Forward+, Jolt-Physik). Sprache im Projekt: Deutsch.

## Spielen

```
Deez Nuts\
  Godot\Godot_v4.7.2-stable_win64.exe
  deez-nuts\            ← dieses Repo
    Spiel_starten.bat   ← Doppelklick
```

- **Spiel_starten.bat** startet das Spiel ohne Editor.
- **Godot_Editor_oeffnen.bat** öffnet das Projekt im Godot-Editor (F5 startet).
- **Selbsttest.bat** lässt einen automatischen Testlauf durch alle Abläufe laufen.

Wer das Repo neu klont: Godot 4.7.2 (Standard-Version, nicht .NET) von https://godotengine.org/download in einen Ordner `Godot` neben das Repo legen.

## Steuerung

**Draußen und in der Hütte**

| Taste | Aktion |
| --- | --- |
| WASD, Maus | laufen, schauen |
| Shift / Leertaste | rennen / springen |
| Linksklick halten (Blick auf den Berg) | Nüsse sammeln |
| X | Sammelwerkzeug wechseln |
| E | benutzen, nehmen, ablegen; an der Knackbank: hinsetzen |
| Rechtsklick (mit etwas in der Hand) | werfen |
| Q | fallen lassen |
| B | Bestellbrett (Laden) |
| Tab | Opas Notizbuch (Skillbaum, darin der Knopf zum Fundbuch) |
| Esc | Menü, Einstellungen, Speichern |
| F9 / F10 / F11 | Testhilfen: +5.000 Münzen / +1.000 Nüsse ins Lager / +50.000 Münzen |

Abliefern geht von selbst: in den gelben Kreis am Trichter (oder an einem Außenposten) laufen. Ist der Beutel voll, zeigt ein Pfeil den Weg.

**An der Knackbank (Nahansicht)**

| Taste | Aktion |
| --- | --- |
| Linksklick halten | zudrücken – loslassen, wenn die Nuss zittert und knistert |
| Rechtsklick | Schalen in den Eimer wischen (oder Eichhörnchen verjagen) |
| R | Nüsse aus dem Lager holen |
| Maus | etwas umschauen (z. B. zum Fenster) |
| E / Esc / S | aufstehen |
| H | Hilfsring um die Nuss an/aus |

## Was drin ist

- **Der Nussberg:** eine Million Nüsse als begehbares Höhenfeld mit Kollision. Was man wegsammelt, fehlt sichtbar; Hänge rutschen nach. Fünf Schichten (Kuppe, Hang, Kern, Fuß, Grund). Der Zähler hängt fest am Volumen.
- **Sammeln mit wachsenden Werkzeugen:** bloße Hände, Holzlöffel, Laubharke, Schaufel, Laubsauger, Saugturbine, XXL-Sauger. Jedes hat eigenes Modell, Rate, Radius und Reichweite. Nüsse fliegen sichtbar in den Beutel.
- **Tragen:** Hosentaschen, Stoffbeutel, Rucksack, Kiepe, Schubkarre, Bollerwagen, Riesensack. Größere Beutel machen etwas langsamer.
- **Abliefern:** Trichter und Silo an der Hütte, sofort Münzen pro Nuss, die Nüsse landen im Lager. Volles Lager verkauft den Rest roh.
- **Knacken wie in Potato Please:** Man setzt sich an den Tisch, die Kamera fährt nah heran, die eigenen Hände greifen den Nussknacker. Risse wachsen, die Nuss zittert im richtigen Moment, im Sweet Spot knistert es. Beim Knack: Einfrier-Moment, Kamerastoß, Splitter, „PERFEKT!“. Kerne bringen deutlich mehr als rohe Nüsse.
- **Sechs Nusssorten:** Haselnuss, Walnuss, Mandel, Pekannuss, Paranuss, Macadamia, dazu goldene, faule, doppelte und Wurmnüsse.
- **Automatisieren:** Sammel-Eichhörnchen (beliebig viele, mit Halstuch), vier Außenposten mit Förderbändern zum Silo, Nussrutsche, Walzenknacker, Lagerhalle, Katze Mimi, Sieb, Glasdeckel, Rohrpost.
- **Opas Notizbuch:** Skillbaum mit über 200 Knoten in sieben Pfaden (Sammeln, Tragen, Handel, Knacken, Maschinen, Helfer, Glück) und 21 Schlüssel-Talenten. Verschieben, zoomen, anklicken.
- **Bestellungen** von Eisdiele, Bäckerei und Co., Meilensteine mit Münzen, geführter Einstieg mit 7 Zielen.
- **Das Tal Haselgrund:** Gelände mit Hügeln, Bach und Wasserfall, Wald, Wege, zwei Brücken. Opas Anwesen mit Veranda, Garten, Gewächshaus, Brunnen, Hühnerstall, Holzlager, Feuerstelle, Hoftor und Briefkasten. Im Westen die verlassene Siedlung Alt-Haselgrund, Heuschober, Picknickplatz und Angelplatz, im Nordosten Opas Hochsitz mit Blick über Berg und Tal.
- **Zwölf Geheimnisse im Fundbuch:** die Mondlichtung (Mondstaub wegfegen, Mondsiebmaschine, Goldene Zahnbürste), die goldene Nadel im Heuhaufen, der Eichhörnchen-König in der hohlen Eiche, dazu Opas Keller, ein Raum hinter dem Wasserfall, Flaschenpost, Hexenring, Sir Nussbert, zwölf Nussknacker-Figuren und mehr. Keine Leuchtmarker, Hinweise stehen in der Welt.
- **Tag und Nacht, Wetter, Tiere:** ein Spieltag dauert 24 Minuten (in den Einstellungen anhaltbar), dazu Bewölkung und kurzer Regen, Vögel, Hühner, Enten, Schmetterlinge, Glühwürmchen, Rauch aus dem Schornstein und Klänge je nach Ort und Tageszeit.
- **Ären zum Anfassen:** Im Berg liegen Funde, die beim Abtragen von selbst auftauchen (Opas erste Hütte, eine Dampfmaschine, sein Fahrrad). Rund um den Berg wächst der Betrieb mit jeder Ära: Arbeitslampen, Gerüst, Lagerzelte, Lichterketten, Hochsilo. Ganz unten wartet eine Luke mit Opas Brief.
- **Optik:** prozedurale Shader für Holz, Putz, Nussschalen, Kerne und Gras, dazu Bäume, Büsche, Steine und Pilze aus freien Modell-Paketen (siehe unten). Warmes Herbstlicht.
- **Ton:** knapp 40 erzeugte Geräusche plus aufgenommene Schritte und Aufpralle (Kenney), Musikschleife, Vogelgezwitscher.
- **Speichern** automatisch alle 30 Sekunden und beim Beenden, der Berg samt Löchern wird mitgespeichert.

## Was noch fehlt (bewusst)

- Freies Aufstellen und Verbinden von Maschinen (jetzt feste Plätze)
- Kokosnuss, Pressen und Dampfhammer als späte Inhalte
- Der blasse Boden unter dem Berg erholt sich noch nicht mit der Zeit
- Eigene Blender-Modelle (Hütte, Maschinen und Nüsse sind noch aus Code gebaut)
- Koop (der Code ist so angelegt, dass er später dazukommen kann)

Wie die Welt aussehen soll (Karte, Orte, Geheimnisse, Etappen, Blender-Modellliste), steht im [Weltplan](https://claude.ai/artifact/7LfpnmDcRzZ3xFstdxxkPi).

Das ganze Konzept steht im [Game-Design-Dokument](https://claude.ai/artifact/9C4dkKBXe7qzwhuc2TQ86Z) und kurz in [`docs/konzept.md`](docs/konzept.md).

## Aufbau

| Ordner / Datei | Inhalt |
| --- | --- |
| `scripts/autoload/data.gd` | Alle Spielwerte: Nüsse, Werkzeuge, Maschinen, Schichten, Talente. **Balancing passiert hier.** |
| `scripts/autoload/game.gd` | Spielstand, Wirtschaft, Talente, Bestellungen, Speichern |
| `scripts/autoload/sfx.gd` | Soundeffekte, Musik und Atmo |
| `scripts/world.gd` | Baut Küche, Werkstatt und Hof, Silo, Außenposten und Bänder, steuert Maschinen, Abliefern und Eichhörnchen |
| `scripts/welt_plan.gd` | Aufbau des Tals: Talform, Bachlauf, Wege, Orte, Baumgruppen (Karte im Weltplan) |
| `scripts/gelaende.gd` | Das Tal als Höhenfeld mit Hügeln, Bachbett, Felsstufe, Wegen und Kollision |
| `scripts/bach.gd` | Wasser des Bachs, Wasserfall, Gischt und Wasserrauschen |
| `scripts/wald.gd` | Waldgürtel, Baumgruppen, Unterholz, Uferbewuchs, Blumen |
| `scripts/streuer.gd` | Stellt Modelle massenhaft als MultiMesh auf |
| `scripts/ersatz.gd` | Ersatzmodelle aus Code für die Blender-Modellplätze |
| `scripts/himmel.gd` | Tag-Nacht-Lauf, Wetter, Licht |
| `scripts/tierwelt.gd` | Vögel, Hühner, Enten, Schmetterlinge, Glühwürmchen, Rauch |
| `scripts/geheimnisse.gd` | Alle zwölf Geheimnisse samt Keller und Studio |
| `scripts/aeren.gd` | Funde im Berg, Bauten je Ära, das letzte Geheimnis |
| `scripts/nussberg.gd` | Der begehbare Nussberg: Höhenfeld, Abbauen, Nachrutschen, Speichern |
| `scripts/sammelgeraet.gd` | Sammelwerkzeuge und Beutel in der Ego-Ansicht |
| `scripts/helfer.gd` | Sammel-Eichhörnchen |
| `scripts/nussflug.gd` | Fliegende Nüsse (Sammeln, Abliefern) |
| `scripts/modelle.gd` | Lädt die fertigen Modelle aus `assets/` |
| `scripts/ui/skillbaum.gd` | Opas Notizbuch (Skillbaum-Ansicht) |
| `scripts/knackstation.gd` | Die Knack-Mechanik und die Werkzeug-Modelle |
| `scripts/spieler.gd` | Ego-Steuerung, Knackbank-Ansicht, Greifen, Tragen, Werfen, Kamerawackeln |
| `scripts/hand.gd` | Die Hände mit beweglichen Fingern |
| `scripts/look.gd` | Alle Materialien und die Schrift |
| `scripts/nussmodelle.gd` | Erzeugt Nüsse, Kerne, Schalen und Bruch aus Code |
| `scripts/einrichtung.gd` | Möbel und Deko |
| `scripts/effekte.gd` | Partikel: Splitter, Staub, Funken, Münzen |
| `shaders/` | Prozedurale Materialien (Holz, Putz, Nuss mit Rissen, Kern, Gras, Laub, Leuchtrand) |
| `fonts/` | Schrift Fredoka (SIL Open Font License) |
| `assets/blender/` | Hier kommen die Blender-Modelle hin (`<modellplatz>.glb`), siehe `LIESMICH.md` dort |
| `assets/` | Fertige 3D-Modelle (CC0): `wald/` KayKit Forest Nature, `natur/` Kenney Nature Kit, `kueche/` Kenney Food Kit, `rohstoffe/` KayKit Resource Bits |
| `scripts/items/` | Nüsse und Teile (`item.gd`), Gefäße (`behaelter.gd`) |
| `scripts/ui/` | HUD, Menüs, Stil |
| `sounds/` | Soundeffekte, Musik und Atmo, erzeugt mit `tools/generate_sfx.py`; `sounds/kenney/` aufgenommene Geräusche (Kenney Impact/Interface Sounds, CC0) |
| `tests/` | Selbsttest und automatische Bildschirmfotos |

Selbsttest ohne Fenster: `godot --headless --path . -- --selbsttest`

Bildschirmfotos aller Situationen: `godot --path . -- --selbsttest --bilder=C:/irgendwo`

Einzelne Blicke: zusätzlich `--blicke=name:x,z,zielx,ziely,zielz[,höhe];…`, davor wahlweise `--aera=4` (Bauten bis Ära 4) und `--graben=x,z,radius,anzahl;…` (Nüsse wegräumen). Jedes Bild meldet Draw Calls und Dreiecke.

## Fremde Inhalte

Alle fremden Modelle und Geräusche stehen unter CC0 (gemeinfrei), eine Nennung ist freiwillig, wir machen sie trotzdem gern:

- [Kenney](https://kenney.nl): Nature Kit, Food Kit, Impact Sounds, Interface Sounds
- [KayKit](https://kaylousberg.itch.io) von Kay Lousberg: Forest Nature Pack, Resource Bits
- Schrift [Fredoka](https://fonts.google.com/specimen/Fredoka) (SIL Open Font License)

Die Herbstfarben der KayKit-Bäume (`assets/wald/forest_texture_herbst.png`) sind aus der Originaltextur umgefärbt.
