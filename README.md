# Deez Nuts!

Ein physisches Ego-Incremental über das Knacken von Nüssen, in der Art von Potato Please und How They Built the Pyramids. Vor dir liegt ein Berg aus einer Million Nüssen. Du knackst die ersten mit bloßen Händen und baust dir Schritt für Schritt deine eigene Knackstraße. Die Eichhörnchen aus dem Wald wollen auch etwas abhaben.

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

**Im Raum**

| Taste | Aktion |
| --- | --- |
| WASD, Maus | laufen, schauen |
| Shift / Leertaste | rennen / springen |
| E | benutzen, nehmen, ablegen, hineinlegen; am Nussknacker: hinsetzen |
| Rechtsklick (mit etwas in der Hand) | werfen |
| Q | fallen lassen |
| R | Hebel ziehen (Nüsse vom Berg) |
| Tab | Talentbaum |
| Esc | Menü, Einstellungen, Speichern |
| F9 / F10 / F11 | Testhilfen: +5.000 Münzen / +1.000 Nüsse / +5 Meisterpunkte |

**An der Knackbank (Nahansicht)**

| Taste | Aktion |
| --- | --- |
| Linksklick halten | zudrücken – loslassen, wenn die Nuss zittert und knistert |
| Rechtsklick | Schalen in den Eimer wischen (oder Eichhörnchen verjagen) |
| R | Hebel ziehen |
| Maus | etwas umschauen (z. B. zum Fenster) |
| E / Esc / S | aufstehen |
| H | Hilfsring um die Nuss an/aus |

## Was drin ist

- **Knackbank-Ansicht wie in Potato Please:** Man setzt sich an den Tisch, die Kamera fährt nah heran, die eigenen Hände greifen den Nussknacker. Die nächste Nuss wird automatisch aus der Schale nachgelegt.
- **Knacken mit Wumms:** Risse wachsen sichtbar über die Schale, die Nuss wird gequetscht und zittert im richtigen Moment, Knarzen wird höher, im Sweet Spot knistert es. Beim Knack: kurzer Einfrier-Moment, Kamerastoß, Splitter, Staub und Funken, ein Stempel „PERFEKT!“. Combo bis +100 % (mit Talent mehr).
- **Kerne fliegen ins Glas** und liegen dort sichtbar, Stück für Stück. Bruch fliegt in die Bruchschale. Schalen bleiben liegen, bis man sie wegwischt.
- **Sechs Nusssorten** mit eigener Form und Schale (alles aus Code erzeugt): Haselnuss, Walnuss, Mandel, Pekannuss, Paranuss (Sweet Spot springt), Macadamia (braucht den Schraubstock). Dazu goldene, faule, doppelte und Wurmnüsse.
- **Fünf Werkzeuge** mit eigenem Modell und eigener Bewegung: Hände, Holz-Hebelpresse, Metall-Hebelpresse, Hammer (halten = ausholen), Schraubstock (Kurbel). Je 10 Upgrade-Stufen.
- **Verkaufen:** Glas nehmen, zur Verkaufsklappe tragen, dort [E]. Münzen spritzen, der Betrag fliegt in die Kasse.
- **Maschinen:** Nussrutsche, Großes Glas, Glasdeckel, Katze Mimi, Rohrpost (volles Glas verkauft sich selbst), Tisch-Sieb, Schalenofen, Walzenknacker, Förderband, Eichhörnchen-Laufrad.
- **Geführter Einstieg:** 7 Ziele bringen einen durch die ersten Minuten, danach zeigt das Spiel immer das nächste lohnende Ziel mit Fortschrittsbalken.
- **Werkstatt** öffnet sich nach 600 Nüssen (Schicht „Hang“).
- **Eichhörnchen** mit Gier (je voller das Glas, desto öfter) und Raubzügen ab Ära 2. Verscheuchen mit E, Rechtsklick an der Bank, Würfen oder durch die Katze.
- **Talentbaum** mit 19 Talenten, im Wald die Wahl zwischen Abwehr und Zähmen.
- **Meisterpunkte** aus Meilensteinen und Bestellungen. Bestellungen hängen auch an der Pinnwand.
- **Optik:** prozedurale Shader für Holz, Putz, Nussschalen, Kerne, Gras und Laub, warmes Licht mit Lichtstrahlen durchs Fenster, wiegende Grashalme, ein Berg aus Tausenden Nüssen.
- **Ton:** über 35 erzeugte Geräusche, gemütliche Musikschleife und Vogelgezwitscher.
- **Speichern** automatisch alle 30 Sekunden und beim Beenden. **Abspann**, wenn der Berg leer ist.

## Was noch fehlt (bewusst)

- Freies Aufstellen und Verbinden von Maschinen (jetzt feste Plätze)
- Ära 4 und 5 mit eigenen Räumen, Kokosnuss, Pressen, Dampfhammer, Eichhörnchen-König
- Blender-Modelle (alles ist noch aus Code gebaut)
- Koop

Das ganze Konzept steht im [Game-Design-Dokument](https://claude.ai/artifact/9C4dkKBXe7qzwhuc2TQ86Z) und kurz in [`docs/konzept.md`](docs/konzept.md).

## Aufbau

| Ordner / Datei | Inhalt |
| --- | --- |
| `scripts/autoload/data.gd` | Alle Spielwerte: Nüsse, Werkzeuge, Maschinen, Schichten, Talente. **Balancing passiert hier.** |
| `scripts/autoload/game.gd` | Spielstand, Wirtschaft, Talente, Bestellungen, Speichern |
| `scripts/autoload/sfx.gd` | Soundeffekte, Musik und Atmo |
| `scripts/world.gd` | Baut Küche, Werkstatt und Hof, steuert Maschinen, Verkauf und Eichhörnchen |
| `scripts/knackstation.gd` | Die Knack-Mechanik und die Werkzeug-Modelle |
| `scripts/spieler.gd` | Ego-Steuerung, Knackbank-Ansicht, Greifen, Tragen, Werfen, Kamerawackeln |
| `scripts/hand.gd` | Die Hände mit beweglichen Fingern |
| `scripts/look.gd` | Alle Materialien und die Schrift |
| `scripts/nussmodelle.gd` | Erzeugt Nüsse, Kerne, Schalen und Bruch aus Code |
| `scripts/einrichtung.gd` | Möbel und Deko |
| `scripts/effekte.gd` | Partikel: Splitter, Staub, Funken, Münzen |
| `shaders/` | Prozedurale Materialien (Holz, Putz, Nuss mit Rissen, Kern, Gras, Laub, Leuchtrand) |
| `fonts/` | Schrift Fredoka (SIL Open Font License) |
| `scripts/items/` | Nüsse und Teile (`item.gd`), Gefäße (`behaelter.gd`) |
| `scripts/ui/` | HUD, Menüs, Stil |
| `sounds/` | Soundeffekte, Musik und Atmo, erzeugt mit `tools/generate_sfx.py` |
| `tests/` | Selbsttest und automatische Bildschirmfotos |

Selbsttest ohne Fenster: `godot --headless --path . -- --selbsttest`

Bildschirmfotos aller Situationen: `godot --path . -- --selbsttest --bilder=C:/irgendwo`
