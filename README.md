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

| Taste | Aktion |
| --- | --- |
| WASD, Maus | laufen, schauen |
| Shift / Leertaste | rennen / springen |
| E | greifen, ablegen, in den Knacker legen, ins Glas legen, benutzen |
| Linksklick halten | Nussknacker zudrücken, loslassen zum Knacken |
| Linksklick mit etwas in der Hand | werfen |
| Q | fallen lassen |
| F | Schalen vom Tisch in den Eimer wischen |
| Tab | Talentbaum |
| H | Hilfsring am Fadenkreuz an/aus |
| Esc | Menü, Einstellungen, Speichern |
| F9 / F10 / F11 | Testhilfen: +5.000 Münzen / +1.000 Nüsse / +5 Meisterpunkte |

## Was im Prototyp drin ist

- **Knacken mit Gefühl:** Fünf Phasen beim Zudrücken (zu früh, Riss, Sweet Spot, Bruch, Matsch). Knarzen, Risse und Zittern zeigen den Druck; der Hilfsring ist abschaltbar. Combo bis +100 % (mit Talent mehr).
- **Sechs Nusssorten** in drei Bergschichten: Haselnuss, Walnuss, Mandel, Pekannuss, Paranuss (Sweet Spot springt), Macadamia (braucht den Schraubstock). Dazu goldene, faule, doppelte und Wurmnüsse.
- **Fünf Werkzeuge** mit je 10 Upgrade-Stufen: Hände, Holz-Nussknacker, Metall-Hebelknacker, Hammer, Schraubstock.
- **Alles anfassbar:** Nüsse, Kernhälften, Bruch, Schalen, Würmer, Glas, Eimer, Bruchschale und Maschinenkiste sind Physik-Objekte. Gefäße trägt man zur Verkaufsklappe, den Eimer zum Ofen.
- **Maschinen:** Nussrutsche, Glasdeckel, Katze Mimi, Tisch-Sieb, Schalenofen, Walzenknacker, Förderband, Eichhörnchen-Laufrad.
- **Werkstatt** öffnet sich nach 1.000 Nüssen.
- **Eichhörnchen** mit Gier (je voller das Glas, desto öfter) und Raubzügen ab Ära 2. Verscheuchen mit E, mit Würfen oder durch die Katze.
- **Talentbaum** mit 19 Talenten in vier Zweigen, im Wald die Wahl zwischen Abwehr und Zähmen.
- **Meisterpunkte** aus Meilensteinen (100 × k^1,75 Nüsse) und Bestellungen.
- **Bestellungen** von Kunden mit Frist, Lohn und Meisterpunkt.
- **Speichern** automatisch alle 30 Sekunden und beim Beenden.
- **Abspann**, wenn der Berg leer ist.

## Was noch fehlt (bewusst)

- Freies Aufstellen und Verbinden von Maschinen (jetzt feste Plätze)
- Ära 4 und 5 mit eigenen Räumen, Kokosnuss, Pressen, Dampfhammer, Eichhörnchen-König
- Blender-Modelle (alles ist noch aus Grundformen gebaut), echte Hände, Musik
- Koop

Das ganze Konzept steht im [Game-Design-Dokument](https://claude.ai/artifact/9C4dkKBXe7qzwhuc2TQ86Z) und kurz in [`docs/konzept.md`](docs/konzept.md).

## Aufbau

| Ordner / Datei | Inhalt |
| --- | --- |
| `scripts/autoload/data.gd` | Alle Spielwerte: Nüsse, Werkzeuge, Maschinen, Schichten, Talente. **Balancing passiert hier.** |
| `scripts/autoload/game.gd` | Spielstand, Wirtschaft, Talente, Bestellungen, Speichern |
| `scripts/autoload/sfx.gd` | Soundeffekte |
| `scripts/world.gd` | Baut Küche, Werkstatt und Hof, steuert Maschinen und Eichhörnchen |
| `scripts/knackstation.gd` | Die Knack-Mechanik |
| `scripts/spieler.gd` | Ego-Steuerung, Greifen, Tragen, Werfen |
| `scripts/items/` | Nüsse und Teile (`item.gd`), Gefäße (`behaelter.gd`) |
| `scripts/ui/` | HUD, Menüs, Stil |
| `sounds/` | Soundeffekte, erzeugt mit `tools/generate_sfx.py` |
| `tests/` | Selbsttest und automatische Bildschirmfotos |

Selbsttest ohne Fenster: `godot --headless --path . -- --selbsttest`
