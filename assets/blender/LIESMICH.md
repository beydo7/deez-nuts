# Blender-Modelle

Hier landen die fertigen Blender-Modelle als `.glb`. Der Dateiname muss genau dem Namen
des Modellplatzes entsprechen (z. B. `bruecke_oma.glb`). Liegt eine Datei hier, lädt das
Spiel sie beim nächsten Start statt des Ersatzmodells aus Code.

Regeln (Kurzfassung, ausführlich im Weltplan, Abschnitt 8):

- Meter, Maßstab 1:1, Export als glTF Binary mit „+Y Up“.
- Ursprung am Boden in der Mitte der Grundfläche, Front in Blender nach −Y.
- Kollision als eigene einfache Objekte mit dem Namenszusatz `-colonly`.
- Bewegliche Teile als eigene Objekte mit festem Namen, Ursprung im Drehpunkt.

Welche Modellplätze es gibt und ob schon ein Modell da ist, zeigt der Selbsttest
(Abschnitt „Modellplätze“).

## Woher die Dateien kommen

Die `.glb` hier werden aus `D:\Games\Deez Nuts\Blender\deez_nuts_modelle.blend` exportiert, die
Skripte dazu liegen in `tools/blender/` (siehe `LIESMICH.md` dort). `materialien.json` gehört dazu:
Sie ordnet den Materialnamen aus Blender die Shader des Spiels zu. Wer ein Modell von Hand
austauscht, benennt seine Materialien wie dort (`holz_eiche`, `stein_feldstein` …) oder lässt sie
weg – dann gilt das Material aus der `.glb`.
