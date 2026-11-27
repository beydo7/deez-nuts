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
