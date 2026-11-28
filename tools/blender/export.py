"""Exportiert die Modellplätze aus deez_nuts_modelle.blend als spielfertige .glb.

Je Modellplatz (Collection "MP_<name>") entsteht assets/blender/<name>.glb:
  - alle festen Teile zu einem Netz verbunden (wenige Zeichenaufrufe),
  - bewegliche Teile (Objekte mit eigenem Namen wie Kurbel, Klappe, Torfluegel) bleiben eigene
    Knoten mit Ursprung am Drehpunkt,
  - Kollisionen als "<name>_koll-colonly".
Die .blend bleibt unberührt: gearbeitet wird auf Kopien mit angewandten Modifikatoren.
Zusätzlich wird assets/blender/materialien.json geschrieben (Materialname -> Godot-Shader).

Aufruf in Blender:
    exec(open(r"D:\\Games\\Deez Nuts\\deez-nuts\\tools\\blender\\export.py", encoding="utf-8").read())
    exportiere_alles()            # oder exportiere_alles(["brunnen", "hoftor"])
"""
import bpy
import json
import os
from mathutils import Matrix

REPO = r"D:\Games\Deez Nuts\deez-nuts"
ZIEL = os.path.join(REPO, "assets", "blender")
STANDARD = ("MeshInstance3D", "Node3D", "StaticBody3D", "CollisionShape3D", "Label3D", "@")


def _eigenname(o):
    n = o.get("dn_godot", "")
    if not n or n.startswith("_") or any(n.startswith(s) for s in STANDARD):
        return ""
    return n


def _gruppe_von(o, wurzel):
    """Nächster Vorfahr (oder das Objekt selbst), der im Spiel einen eigenen Namen trägt."""
    k = o
    while k is not None and k != wurzel:
        if _eigenname(k):
            return k
        k = k.parent
    return wurzel


def _verbinde(objekte, name, col):
    if not objekte:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objekte:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objekte[0]
    if len(objekte) > 1:
        bpy.ops.object.join()
    erg = bpy.context.view_layer.objects.active
    erg.name = name
    erg.data.name = name
    return erg


def exportiere(name):
    col = bpy.data.collections.get("MP_" + name)
    wurzel = bpy.data.objects.get(name)
    if col is None or wurzel is None:
        return "%s: fehlt" % name
    sz = bpy.context.scene
    tmp = bpy.data.collections.new("Export_tmp")
    sz.collection.children.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    inv = wurzel.matrix_world.inverted()
    umbenannt = []

    def nimm_namen(n):
        alt = bpy.data.objects.get(n)
        if alt is not None:
            alt.name = n + "~quelle"
            umbenannt.append((alt, n))

    # Gruppen: Wurzel und alle Objekte mit eigenem Namen
    gruppen = {wurzel: []}
    for o in col.objects:
        if o != wurzel and _eigenname(o):
            gruppen[o] = []
    for o in col.objects:
        if o.type in ("MESH", "FONT", "CURVE"):
            gruppen[_gruppe_von(o, wurzel)].append(o)

    kopf = {}
    reihenfolge = sorted(gruppen, key=lambda g: len(_kette(g, wurzel)))
    for g in reihenfolge:
        n = "Modell" if g == wurzel else _eigenname(g)
        nimm_namen(n)
        e = bpy.data.objects.new(n, None)
        tmp.objects.link(e)
        eltern = _gruppe_von(g.parent, wurzel) if (g != wurzel and g.parent is not None) else None
        if g != wurzel and eltern is None:
            eltern = wurzel
        if eltern is not None:
            e.parent = kopf[eltern]
        e.matrix_world = inv @ g.matrix_world
        kopf[g] = e
    bpy.context.view_layer.update()

    dreiecke = 0
    for g in reihenfolge:
        sicht, koll = [], []
        for o in gruppen[g]:
            ev = o.evaluated_get(dg)
            try:
                me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
            except Exception:
                continue
            if len(me.polygons) == 0:
                bpy.data.meshes.remove(me)
                continue
            k = bpy.data.objects.new("tmp", me)
            tmp.objects.link(k)
            k.matrix_world = inv @ o.matrix_world
            (koll if o.name.endswith("-colonly") else sicht).append(k)
        bpy.context.view_layer.update()
        basis = name if g == wurzel else _eigenname(g)
        for liste, endung in ((sicht, "_netz"), (koll, "_koll-colonly")):
            nimm_namen(basis + endung)
            erg = _verbinde(liste, basis + endung, tmp)
            if erg is None:
                continue
            welt = erg.matrix_world.copy()
            erg.parent = kopf[g]
            erg.matrix_parent_inverse = Matrix.Identity(4)
            bpy.context.view_layer.update()
            # Netz in den Raum der Gruppe rechnen, Objekt selbst bleibt ohne Versatz
            lokal = kopf[g].matrix_world.inverted() @ welt
            erg.data.transform(lokal)
            erg.matrix_basis = Matrix.Identity(4)
            if endung == "_netz":
                erg.data.calc_loop_triangles()
                dreiecke += len(erg.data.loop_triangles)
    bpy.context.view_layer.update()

    bpy.ops.object.select_all(action="DESELECT")
    for o in tmp.objects:
        o.select_set(True)
    pfad = os.path.join(ZIEL, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=pfad, export_format="GLB", use_selection=True, export_apply=False,
                              export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False,
                              export_animations=False, export_extras=False)
    for o in list(tmp.objects):
        daten = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if daten is not None and daten.users == 0 and isinstance(daten, bpy.types.Mesh):
            bpy.data.meshes.remove(daten)
    bpy.data.collections.remove(tmp)
    for o, n in umbenannt:
        o.name = n
    return "%s: %d Dreiecke, %d kB" % (name, dreiecke, os.path.getsize(pfad) // 1024)


def _kette(g, wurzel):
    k, liste = g, []
    while k is not None and k != wurzel:
        liste.append(k)
        k = k.parent
    return liste


def schreibe_materialien():
    tabelle = {}
    for m in bpy.data.materials:
        if m.users > 0 and m.get("dn_json"):
            tabelle[m.name] = json.loads(m["dn_json"])
    with open(os.path.join(ZIEL, "materialien.json"), "w", encoding="utf-8") as f:
        json.dump(tabelle, f, indent=1, sort_keys=True)
    return len(tabelle)


def exportiere_alles(nur=None):
    os.makedirs(ZIEL, exist_ok=True)
    try:
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception:
        pass
    bericht = []
    for col in sorted(bpy.data.collections, key=lambda c: c.name):
        if not col.name.startswith("MP_"):
            continue
        n = col.name[3:]
        if nur and n not in nur:
            continue
        try:
            bericht.append(exportiere(n))
        except Exception as e:
            import traceback
            bericht.append("%s: FEHLER %s" % (n, traceback.format_exc()[-400:]))
    anzahl = schreibe_materialien()
    print("\n".join(bericht))
    print("materialien.json: %d Materialien" % anzahl)
