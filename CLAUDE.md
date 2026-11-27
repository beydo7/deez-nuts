# Hinweise für Claude

- Projekt: **Deez Nuts!**, physisches Ego-Incremental in **Godot 4.7.2** (GDScript, Forward+, Jolt-Physik).
- Sprache: **Deutsch** – UI-Texte, Bezeichner, Kommentare, Commit-Nachrichten.
- Spielgefühl wie Potato Please / How They Built the Pyramids, **nicht** wie CRACK: kein Horror, kein Riesenobjekt, alles anfassbar, kein Prestige-Reset.
- Alle Spielwerte stehen in `scripts/autoload/data.gd`. Neue Inhalte zuerst dort anlegen.
- Geometrie für Hütte, Maschinen und Nüsse kommt aus Code (`scripts/bau.gd`, `scripts/einrichtung.gd`, `scripts/nussmodelle.gd`), Materialien aus `scripts/look.gd` + `shaders/`, bis Blender-Modelle kommen.
- Natur-Deko und Kleinkram kommen als fertige CC0-Modelle aus `assets/` (Kenney, KayKit; Lizenzen liegen dort), geladen über `scripts/modelle.gd`. Nur CC0-Pakete aufnehmen und im README unter „Fremde Inhalte“ nennen. Eigene Texturdateien nur, wenn es nicht anders geht.
- Die Welt folgt dem Weltplan (Link in der README). Orte, Bach, Wege stehen in `scripts/welt_plan.gd`; nichts wird zufällig über die Karte gestreut.
- Große Objekte bekommen einen Modellplatz: `Modelle.platz(eltern, "name", pos, drehung, ersatz)`. Blender-Modelle (`assets/blender/<name>.glb`) ersetzen den Ersatz aus `scripts/ersatz.gd` automatisch.
- Aufgenommene Geräusche (Kenney, CC0) liegen in `sounds/kenney/` und laufen über `Sfx.variante()`.
- Vor jedem Commit den Selbsttest laufen lassen: `godot --headless --path . -- --selbsttest` (muss mit 0 Fehlern enden).
- Bildschirmfotos zum Prüfen (echter Forward+-Renderer über lavapipe): `. /opt/lavapipe/use-lavapipe.sh; xvfb-run godot --path . --rendering-driver vulkan -- --selbsttest --bilder=/tmp/bilder`
- Sounds neu erzeugen: `python tools/generate_sfx.py`
- Konzept: `docs/konzept.md` und das Game-Design-Dokument (Link in der README).
