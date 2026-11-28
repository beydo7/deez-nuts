"""Rendert Vorschaubilder der Modellplätze (EEVEE) und setzt sie zu Übersichtsbögen zusammen.

Je Modellplatz wird nur dessen Collection gezeigt, die Kamera rahmt das Objekt von schräg vorn.
Ausgabe: D:\\Games\\Deez Nuts\\Blender\\vorschau\\<name>.png und bogen_<n>.png

Aufruf in Blender:
    exec(open(r"D:\\Games\\Deez Nuts\\deez-nuts\\tools\\blender\\vorschau.py", encoding="utf-8").read())
    rendere(["brunnen", "hoftor"])      # ohne Liste: alle
"""
import bpy
import math
import os
import numpy as np
from mathutils import Vector

AUSGABE = r"D:\Games\Deez Nuts\Blender\vorschau"
KANTE = 640


def _grenzen(col):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in col.all_objects:
        if o.type not in ("MESH", "FONT") or o.hide_render:
            continue
        for e in o.bound_box:
            p = o.matrix_world @ Vector(e)
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    return lo, hi


def _szene():
    sz = bpy.context.scene
    kam = bpy.data.objects.get("Vorschaukamera")
    if kam is None:
        kam = bpy.data.objects.new("Vorschaukamera", bpy.data.cameras.new("Vorschaukamera"))
        sz.collection.objects.link(kam)
    kam.data.lens = 50
    sz.camera = kam
    boden = bpy.data.objects.get("Vorschauboden")
    if boden is None:
        me = bpy.data.meshes.new("Vorschauboden")
        s = 60.0
        me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
        boden = bpy.data.objects.new("Vorschauboden", me)
        sz.collection.objects.link(boden)
        mat = bpy.data.materials.new("vorschau_boden")
        mat.use_nodes = True
        b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = (0.2, 0.26, 0.1, 1.0)
        b.inputs["Roughness"].default_value = 1.0
        me.materials.append(mat)
    sz.render.engine = "BLENDER_EEVEE"
    sz.render.resolution_x = KANTE
    sz.render.resolution_y = KANTE
    sz.render.resolution_percentage = 100
    sz.render.image_settings.file_format = "PNG"
    sz.render.film_transparent = False
    try:
        sz.eevee.taa_render_samples = 32
        sz.eevee.use_shadows = True
        sz.eevee.use_raytracing = True
    except Exception:
        pass
    try:
        sz.view_settings.view_transform = "AgX"
        sz.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    return kam, boden


def rendere(nur=None, richtung=(0.62, -1.0, 0.5), bogen=True):
    os.makedirs(AUSGABE, exist_ok=True)
    sz = bpy.context.scene
    kam, boden = _szene()
    plaetze = [c for c in sorted(bpy.data.collections, key=lambda c: c.name) if c.name.startswith("MP_")]
    vorher = {c.name: c.hide_render for c in plaetze}
    fertig = []
    for col in plaetze:
        n = col.name[3:]
        if nur and n not in nur:
            continue
        for c in plaetze:
            c.hide_render = c != col
        lo, hi = _grenzen(col)
        mitte = (lo + hi) * 0.5
        radius = (hi - lo).length * 0.5
        r = Vector(richtung).normalized()
        abstand = radius / math.tan(kam.data.angle * 0.5) * 1.08
        kam.location = mitte + r * abstand
        kam.rotation_euler = (mitte - kam.location).to_track_quat("-Z", "Y").to_euler()
        boden.location = (mitte.x, mitte.y, lo.z - 0.002)
        sz.render.filepath = os.path.join(AUSGABE, n + ".png")
        bpy.ops.render.render(write_still=True)
        fertig.append(n)
    for c in plaetze:
        c.hide_render = vorher[c.name]
    boegen = []
    if bogen and fertig:
        boegen = setze_zusammen(fertig)
    print("Gerendert:", ", ".join(fertig))
    print("Bögen:", ", ".join(boegen))
    return boegen


def setze_zusammen(namen, spalten=3, zeilen=2, kachel=480, praefix="bogen"):
    """Fügt Einzelbilder zu Übersichtsbögen zusammen (verkleinert durch Auslassen von Pixeln)."""
    pfade = []
    je = spalten * zeilen
    for b in range(0, len(namen), je):
        teil = namen[b:b + je]
        feld = np.zeros((zeilen * kachel, spalten * kachel, 4), dtype=np.float32)
        feld[..., 3] = 1.0
        for i, n in enumerate(teil):
            bild = bpy.data.images.load(os.path.join(AUSGABE, n + ".png"), check_existing=False)
            w, h = bild.size
            px = np.empty(w * h * 4, dtype=np.float32)
            bild.pixels.foreach_get(px)
            px = px.reshape(h, w, 4)
            ys = (np.arange(kachel) * h / kachel).astype(int)
            xs = (np.arange(kachel) * w / kachel).astype(int)
            klein = px[ys][:, xs]
            z = zeilen - 1 - i // spalten
            s = i % spalten
            feld[z * kachel:(z + 1) * kachel, s * kachel:(s + 1) * kachel] = klein
            bpy.data.images.remove(bild)
        aus = bpy.data.images.new("bogen_tmp", spalten * kachel, zeilen * kachel, alpha=False)
        aus.pixels.foreach_set(feld.ravel())
        pfad = os.path.join(AUSGABE, "%s_%d.png" % (praefix, b // je + 1))
        aus.filepath_raw = pfad
        aus.file_format = "PNG"
        aus.save()
        bpy.data.images.remove(aus)
        pfade.append(pfad)
    return pfade
