# Blender-Werkstatt

Hier liegen die Skripte, mit denen die Modellplätze von Deez Nuts! in Blender entstehen und als
`.glb` ins Spiel kommen. Die Arbeitsdatei selbst liegt außerhalb des Repos:
`D:\Games\Deez Nuts\Blender\deez_nuts_modelle.blend` (Blender 5.3, EEVEE, Meter).

## Ablauf

1. **Maße aus dem Spiel holen** (nur nötig, wenn sich ein Ersatzmodell in `scripts/ersatz.gd` ändert):
   `godot --headless --path . -- --selbsttest --bilder=/tmp/x --modell-export=tools/blender/ersatz.json`
   Dabei baut das Spiel die Ersatzmodelle aus Code (auch wenn schon `.glb` da sind) und schreibt
   jedes Teil mit Maß, Lage und Material in `ersatz.json`.
2. **In Blender bauen**: `blockout.py` baut daraus je Modellplatz eine Collection `MP_<name>` –
   maßgenau, mit gefasten Kanten, echten Brettern statt Flächen, einzelnen Dachschindeln mit
   Firstziegeln, unregelmäßigen Feldsteinen und benannten Materialien.
3. **Ansehen**: `vorschau.py` rendert jeden Modellplatz einzeln (EEVEE, 640 px) nach
   `D:\Games\Deez Nuts\Blender\vorschau\` und setzt Übersichtsbögen zusammen.
4. **Exportieren**: `export.py` schreibt `assets/blender/<name>.glb` und `materialien.json`.
5. Im Repo: `godot --headless --path . --import`, dann Selbsttest.

Alles in einem Schritt: `alles.py` laden und `durchlauf()` aufrufen (steht im Kopf der Datei).

**Achtung beim Weiterbauen von Hand:** `durchlauf()` und `baue_alles()` bauen die Collections neu
auf. Wer einen Modellplatz in Blender von Hand umgestaltet, ruft danach nur noch
`exportiere_alles([...])` aus `export.py` auf oder nimmt den Platz mit `durchlauf(ohne=["brunnen"])` aus.

## Regeln für die Modelle

- Wurzel ist ein Leerobjekt mit dem Namen des Modellplatzes, Ursprung am Boden, Front nach −Y.
- Bewegliche Teile heißen wie im Spiel (`Kurbel`, `Eimer`, `Klappe`, `Torfluegel`, `Schild`,
  `Loses_Brett`, `Leiter`, `Thron` …). Der Name steht in der Eigenschaft `dn_godot` des Objekts,
  weil Blender gleiche Namen sonst durchnummeriert. Der Export setzt ihn wieder ein.
- Kollision: Objekte mit der Endung `-colonly` (als Drahtgitter sichtbar, nicht im Bild).
- Der Export verbindet alle festen Teile eines Modellplatzes zu einem Netz und lässt bewegliche
  Teile als eigene Knoten. Die .blend bleibt dabei unverändert.

## Materialien

Blender-Materialien heißen nach Art und Farbe: `holz_altholz`, `holz_eiche`, `holz_kiefer`,
`holz_nussbaum`, `stein_feldstein`, `schindel_dachziegel`, `putz_<farbe>`, `metall_<farbe>` …
Gleiche Namen mit `_b`, `_c` unterscheiden sich nur in Shader-Werten (Ringdichte, Lack).

Im Spiel zählt für Holz, Putz, Stein, Laub und Nuss nicht das Blender-Material, sondern der
Godot-Shader: `assets/blender/materialien.json` ordnet jedem Materialnamen Shader und Werte zu,
`Modelle.platz()` tauscht beim Laden. Alle übrigen Materialien (Metall, Glas, Farbe, Schrift)
kommen mit ihrer Grundfarbe über glTF ins Spiel – deshalb haben sie in Blender keine Knoten vor
der Grundfarbe.

Holz bekommt seine Maserung über zwei UV-Ebenen: `UVMap` = (längs der Faser, quer),
`UVMap2` = (quer, Zufallswert je Brett). So läuft die Maserung immer längs des Bretts und jedes
Brett sieht etwas anders aus (`shaders/holz.gdshader`, Schalter `uv_koordinaten`).

## Fremde Inhalte in den Modellen

Für die Blender-Arbeit wurde nichts Neues heruntergeladen und kein Add-on installiert; der
glTF-Export gehört zu Blender. In einigen Modellen stecken Teile, die schon im Spiel waren:

| Inhalt | Quelle | Lizenz | Verwendet in |
|---|---|---|---|
| Töpfe, Pflanzen, Gemüse, Pilze (`assets/natur/`) | Kenney Nature Kit, kenney.nl | CC0 | Gewächshaus, Köhlerhütte, Angelplatz |
| Becher, Teller, Fass (`assets/kueche/`) | Kenney Food Kit, kenney.nl | CC0 | Picknick, Veranda, Schuppen |
| Gras, Busch (`assets/wald/`), Holzstapel (`assets/rohstoffe/`) | KayKit Forest Nature Pack und Resource Bits, Kay Lousberg | CC0 | Angelplatz, Köhlerhütte, Holzlager |
| Schrift Fredoka (`fonts/`) | Google Fonts | SIL Open Font License | Schilder (als Netz) |

## Stand und Grenzen

- Alle 27 Modellplätze sind gebaut, gerendert, exportiert und im Spiel geprüft (Selbsttest 0 Fehler,
  Bildschirmfotos). Übersicht: `docs/blender/modellplaetze_blender.jpg`, im Spiel: `docs/blender/im_spiel.jpg`.
- Es sind veredelte Nachbauten der Ersatzmodelle, keine neu entworfenen Einzelstücke. Nur der Brunnen
  hat bisher eigene Zutaten (Seil auf der Welle, Moos, lose Feldsteine).
- Die Hütte (Küche, Werkstatt, Silo, Knackbank) ist noch kein Modellplatz und kommt weiter aus Code.
- Schilder sind jetzt Netze statt Label3D: fester Text, etwas dünnere Schrift.
- Zusammen rund 114.000 Dreiecke für alle 27 Modelle.
