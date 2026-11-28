"""Ein Durchlauf für alles: aufräumen, Modellplätze bauen, Vorschau rendern, .glb exportieren, speichern.

Aufruf in Blender (Skript-Editor oder Python-Konsole):
    exec(open(r"D:\\Games\\Deez Nuts\\deez-nuts\\tools\\blender\\alles.py", encoding="utf-8").read())
    durchlauf()                     # alles
    durchlauf(vorschau=False)       # ohne Bilder, schneller

Achtung: Der Durchlauf baut die Collections "MP_<name>" aus tools/blender/ersatz.json neu auf.
Handarbeit an einem Modellplatz geht dabei verloren. Wer von Hand weiterbaut, exportiert nur noch
(export.py, exportiere_alles) und lässt den Neuaufbau weg oder nimmt den Platz mit `ohne=[...]` aus.
"""
import bpy
import os
import zipfile

ORDNER = r"D:\Games\Deez Nuts\deez-nuts\tools\blender"
BLENDER_ORDNER = r"D:\Games\Deez Nuts\Blender"


def _lade(datei):
    ns = {"__name__": datei}
    p = os.path.join(ORDNER, datei)
    exec(compile(open(p, encoding="utf-8").read(), p, "exec"), ns)
    return ns


def durchlauf(vorschau=True, ohne=None, paket=""):
    ohne = set(ohne or [])
    blockout, export, bilder = _lade("blockout.py"), _lade("export.py"), _lade("vorschau.py")
    alle = [c.name[3:] for c in bpy.data.collections if c.name.startswith("MP_")]
    for c in [c for c in bpy.data.collections if c.name.startswith("MP_") and c.name[3:] not in ohne]:
        for o in list(c.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    if not ohne:
        lager = bpy.data.collections.get("Fremdmodelle")
        if lager:
            for o in list(lager.objects):
                bpy.data.objects.remove(o, do_unlink=True)
        for m in [m for m in bpy.data.materials if m.get("dn_art") is not None]:
            bpy.data.materials.remove(m)
        bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    import json
    with open(blockout["JSON_PFAD"], encoding="utf-8") as f:
        namen = [d["name"] for d in json.load(f)]
    blockout["baue_alles"]([n for n in namen if n not in ohne])
    # Ordnung in der Datei: Helfer für die Vorschau in eine eigene Collection
    sz = bpy.context.scene
    bilder["_szene"]()
    vor = bpy.data.collections.get("Vorschau") or bpy.data.collections.new("Vorschau")
    if vor.name not in [c.name for c in sz.collection.children]:
        sz.collection.children.link(vor)
    for n in ("Vorschaukamera", "Vorschauboden", "Sonne"):
        o = bpy.data.objects.get(n)
        if o and vor not in o.users_collection:
            for c in list(o.users_collection):
                c.objects.unlink(o)
            vor.objects.link(o)
    # Der glTF-Import hinterlässt leere Collections "Orphan Nodes"
    for c in [c for c in bpy.data.collections if c.name.startswith("Orphan Nodes") and len(c.all_objects) == 0]:
        bpy.data.collections.remove(c)
    if vorschau:
        bilder["rendere"]()
    export["exportiere_alles"]()
    bpy.ops.wm.save_mainfile()
    if paket:
        ziel = export["ZIEL"]
        with zipfile.ZipFile(os.path.join(BLENDER_ORDNER, paket), "w", zipfile.ZIP_DEFLATED) as zf:
            for f in sorted(os.listdir(ziel)):
                if f.endswith(".glb") or f == "materialien.json":
                    zf.write(os.path.join(ziel, f), f)
            vo = bilder["AUSGABE"]
            for f in sorted(os.listdir(vo)):
                if f.startswith("bogen_"):
                    zf.write(os.path.join(vo, f), "vorschau/" + f)
    print("Fertig. Gespeichert:", bpy.data.filepath)
