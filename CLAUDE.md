# Hinweise für Claude

- Projekt: **Deez Nuts!**, physisches Ego-Incremental in **Godot 4.7.2** (GDScript, Forward+, Jolt-Physik).
- Sprache: **Deutsch** – UI-Texte, Bezeichner, Kommentare, Commit-Nachrichten.
- Spielgefühl wie Potato Please / How They Built the Pyramids, **nicht** wie CRACK: kein Horror, kein Riesenobjekt, alles anfassbar, kein Prestige-Reset.
- Alle Spielwerte stehen in `scripts/autoload/data.gd`. Neue Inhalte zuerst dort anlegen.
- Geometrie ist Platzhalter aus Grundformen (`scripts/bau.gd`), bis Blender-Modelle kommen.
- Vor jedem Commit den Selbsttest laufen lassen: `godot --headless --path . -- --selbsttest` (muss mit 0 Fehlern enden).
- Bildschirmfotos zum Prüfen: `xvfb-run godot --path . --rendering-driver opengl3 -- --selbsttest --bilder=/tmp/bilder`
- Sounds neu erzeugen: `python tools/generate_sfx.py`
- Konzept: `docs/konzept.md` und das Game-Design-Dokument (Link in der README).
