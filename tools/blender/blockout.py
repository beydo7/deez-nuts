"""Baut alle Modellplätze von Deez Nuts! maßgenau in Blender nach (Blockout).

Quelle ist tools/blender/ersatz.json, geschrieben von tools/blender/ersatz_export.gd aus den
Ersatzmodellen des Spiels. Jeder Modellplatz bekommt eine eigene Collection "MP_<name>" mit einem
Leerobjekt <name> als Wurzel (Ursprung am Boden, Front nach -Y, wie in assets/blender/LIESMICH.md).

Schon beim Blockout wird veredelt: gefaste Kanten, leicht unregelmäßige Bretter und Steine,
Ziegeldächer aus einzelnen Schindeln, benannte Materialien.

Aufruf in Blender (Python-Konsole oder MCP):
    exec(open(r"D:\\Games\\Deez Nuts\\deez-nuts\\tools\\blender\\blockout.py", encoding="utf-8").read())
    baue_alles()
"""
import bpy
import bmesh
import json
import math
import os
import random
from mathutils import Matrix, Vector, noise

BASIS = r"D:\Games\Deez Nuts"
REPO = os.path.join(BASIS, "deez-nuts")
JSON_PFAD = os.path.join(REPO, "tools", "blender", "ersatz.json")
BLEND_PFAD = os.path.join(BASIS, "Blender", "deez_nuts_modelle.blend")
RASTER = 14.0
SPALTEN = 6

# Godot (x rechts, y oben, z nach vorn) -> Blender (x rechts, y nach hinten, z oben)
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()
STANDARDNAMEN = ("MeshInstance3D", "Node3D", "StaticBody3D", "CollisionShape3D", "Label3D", "@")

_extern_cache = {}
_zaehler = {}
_daecher = []       # (Platz, Weltmatrix, Breite, Tiefe, Dicke, Richtung, Material) je Schindeldach


def xform(x):
    m = Matrix(((x[0], x[3], x[6], x[9]), (x[1], x[4], x[7], x[10]), (x[2], x[5], x[8], x[11]), (0, 0, 0, 1)))
    return C @ m @ CI


def hexfarbe(c):
    return "%02x%02x%02x" % tuple(max(0, min(255, int(round(v * 255)))) for v in c[:3])


def lin(c):
    """sRGB (wie in Godot angegeben) -> linear für Blender."""
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c[:3]) + (1.0,)


# --- Materialien -----------------------------------------------------------------
def _mat_name(basis, schluessel):
    """Gleicher Name nur bei gleichen Shader-Werten, sonst _b, _c ..."""
    for zusatz in [""] + ["_" + c for c in "bcdefghijklmnopqrstuvwxyz"]:
        mat = bpy.data.materials.get(basis + zusatz)
        if mat is None or mat.get("dn_schluessel", "") == schluessel:
            return basis + zusatz, mat
    return basis + "_zz", None


# Sprechende Namen für die Holzarten und Grundfarben des Spiels (scripts/look.gd, scripts/ersatz.gd)
FARBNAMEN = {"bd8c59": "eiche", "805433": "nussbaum", "dbb27a": "kiefer", "8c7359": "altholz",
             "999185": "feldstein", "9e3d29": "dachziegel", "471c12": "dachlatte"}


def material(m):
    art = m.get("art", "std")
    u = dict(m.get("u", {}))
    if art == "holz":
        c1, c2 = m.get("farbe_hell", [0.7, 0.5, 0.3]), m.get("farbe_dunkel", [0.4, 0.3, 0.2])
        basis = "holz_%s" % FARBNAMEN.get(hexfarbe(c1), hexfarbe(c1))
        if m.get("lack", 0.0) > 0.3:
            basis = "lack_%s" % hexfarbe(c1)
        rau, metall, alpha = 0.75 - 0.4 * m.get("lack", 0.0), 0.0, 1.0
        u["dielen_breite"] = 0.0        # Bretter sind in Blender echte Bretter
        u["welt_koordinaten"] = False
        u["uv_koordinaten"] = True
    elif art in ("putz", "nuss", "kern", "laub", "halm", "gras"):
        c1 = m.get("farbe", m.get("oben", [0.6, 0.6, 0.6]))
        c2 = m.get("farbe2", m.get("unten", c1))
        vor = "ziegel" if (art == "putz" and ist_ziegel(m)) else ("stein" if (art == "putz" and ist_stein(m)) else art)
        if m.get("_schindel"):
            vor = "schindel"
            u["kacheln"] = 0.0          # Schindeln sind echte Schindeln, das Fliesenmuster entfällt
        basis = "%s_%s" % (vor, FARBNAMEN.get(hexfarbe(c1), hexfarbe(c1)))
        rau, metall, alpha = m.get("rauheit", 0.9), 0.0, 1.0
    else:
        c1 = c2 = m.get("farbe", [0.6, 0.6, 0.6])
        alpha = m.get("alpha", 1.0)
        metall = m.get("metall", 0.0)
        rau = m.get("rauheit", 0.8)
        vor = "glas" if alpha < 0.9 else ("metall" if metall > 0.5 else ("licht" if m.get("leuchtet") else "farbe"))
        basis = "%s_%s" % (vor, hexfarbe(c1))
    daten = {"art": art, "shader": m.get("shader", ""), "u": u} if m.get("shader") else {}
    schluessel = json.dumps([basis, daten, round(rau, 3), round(metall, 3), round(alpha, 3)], sort_keys=True)
    name, mat = _mat_name(basis, schluessel)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat["dn_schluessel"] = schluessel
    mat["dn_art"] = art
    if daten:
        mat["dn_json"] = json.dumps(daten, sort_keys=True)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return mat
    bsdf.inputs["Base Color"].default_value = lin(c1)
    bsdf.inputs["Roughness"].default_value = rau
    bsdf.inputs["Metallic"].default_value = metall
    mat.diffuse_color = lin(c1)
    if alpha < 0.9:
        bsdf.inputs["Alpha"].default_value = max(0.15, alpha)
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            pass
        return mat
    if m.get("leuchtet"):
        try:
            bsdf.inputs["Emission Color"].default_value = lin(c1)
            bsdf.inputs["Emission Strength"].default_value = 3.0
        except Exception:
            pass
        return mat
    if metall > 0.5 or not daten:
        # Ohne Godot-Shader zählt die reine Grundfarbe: nur sie kommt über glTF im Spiel an.
        return mat
    # Nur für Blender-Bilder: Farbstreuung und Relief. Im Spiel übernehmen die Godot-Shader
    # (Zuordnung über den Materialnamen, siehe assets/blender/materialien.json).
    try:
        rausch = nt.nodes.new("ShaderNodeTexNoise")
        rampe = nt.nodes.new("ShaderNodeValToRGB")
        bump = nt.nodes.new("ShaderNodeBump")
        rausch.inputs["Detail"].default_value = 5.0
        if art == "holz":
            # Maserkoordinaten liegen in den UV-Ebenen: UVMap = (längs, quer1), UVMap2 = (quer2, Zufall)
            uv1 = nt.nodes.new("ShaderNodeUVMap")
            uv1.uv_map = "UVMap"
            uv2 = nt.nodes.new("ShaderNodeUVMap")
            uv2.uv_map = "UVMap2"
            t1 = nt.nodes.new("ShaderNodeSeparateXYZ")
            t2 = nt.nodes.new("ShaderNodeSeparateXYZ")
            zus = nt.nodes.new("ShaderNodeCombineXYZ")
            karte = nt.nodes.new("ShaderNodeMapping")
            karte.inputs["Scale"].default_value = (0.9, 16.0, 16.0)
            nt.links.new(uv1.outputs["UV"], t1.inputs[0])
            nt.links.new(uv2.outputs["UV"], t2.inputs[0])
            nt.links.new(t1.outputs["X"], zus.inputs["X"])
            nt.links.new(t1.outputs["Y"], zus.inputs["Y"])
            nt.links.new(t2.outputs["X"], zus.inputs["Z"])
            nt.links.new(zus.outputs[0], karte.inputs["Vector"])
            nt.links.new(karte.outputs["Vector"], rausch.inputs["Vector"])
            rausch.inputs["Scale"].default_value = 1.0
            # Zufallswert je Brett hellt auf oder dunkelt ab
            mal = nt.nodes.new("ShaderNodeMixRGB")
            mal.blend_type = "MULTIPLY"
            mal.inputs["Fac"].default_value = 1.0
            hell = nt.nodes.new("ShaderNodeMapRange")
            hell.inputs["To Min"].default_value = 0.78
            hell.inputs["To Max"].default_value = 1.12
            nt.links.new(t2.outputs["Y"], hell.inputs["Value"])
            nt.links.new(rampe.outputs["Color"], mal.inputs["Color1"])
            nt.links.new(hell.outputs[0], mal.inputs["Color2"])
            nt.links.new(mal.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            koord = nt.nodes.new("ShaderNodeTexCoord")
            rausch.inputs["Scale"].default_value = 14.0 if art == "putz" else 20.0
            nt.links.new(koord.outputs["Object"], rausch.inputs["Vector"])
            nt.links.new(rampe.outputs["Color"], bsdf.inputs["Base Color"])
        rampe.color_ramp.elements[0].position = 0.35
        rampe.color_ramp.elements[0].color = lin(c2)
        rampe.color_ramp.elements[1].position = 0.68
        rampe.color_ramp.elements[1].color = lin(c1)
        bump.inputs["Strength"].default_value = 0.25
        bump.inputs["Distance"].default_value = 0.02
        nt.links.new(rausch.outputs[0], rampe.inputs["Fac"])
        nt.links.new(rausch.outputs[0], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    except Exception as e:
        print("Material-Knoten:", name, e)
    return mat


def ist_ziegel(m):
    c = m.get("farbe", [0, 0, 0])
    return m.get("art") == "putz" and c[0] > 0.3 and c[0] > c[1] * 1.9 and c[0] > c[2] * 2.2 and m.get("kacheln", 0.0) > 0.2


def ist_stein(m):
    c = m.get("farbe", [0, 0, 0])
    return m.get("art") == "putz" and abs(c[0] - c[2]) < 0.12 and 0.3 < c[0] < 0.7 and m.get("kacheln", 0.0) == 0.0 and m.get("rauheit", 0.9) >= 0.93


def ist_weich(m):
    """Heu, Moos, Stoffballen: runde, unregelmäßige Formen."""
    c = m.get("farbe", [0, 0, 0])
    return m.get("art") == "putz" and m.get("rauheit", 0.9) >= 0.99 and not ist_stein(m)


# --- Geometrie -------------------------------------------------------------------
def name_fuer(platz, art):
    k = (platz, art)
    _zaehler[k] = _zaehler.get(k, 0) + 1
    return "%s_%s_%03d" % (platz, art, _zaehler[k])


def objekt(name, bm, col, mat, W, fase=0.0, glatt=True, segmente=1):
    """Erzeugt ein Mesh-Objekt. Die Skalierung aus W wird ins Mesh gerechnet."""
    loc, rot, scl = W.decompose()
    for v in bm.verts:
        v.co = Vector((v.co.x * scl.x, v.co.y * scl.y, v.co.z * scl.z))
    if scl.x * scl.y * scl.z < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = glatt
    if mat:
        me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    ob.matrix_basis = Matrix.LocRotScale(loc, rot, Vector((1, 1, 1)))
    if fase > 0.0005:
        b = ob.modifiers.new("Fase", "BEVEL")
        b.width = fase
        b.segments = segmente
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(40)
        try:
            b.harden_normals = False
        except Exception:
            pass
    if glatt:
        e = ob.modifiers.new("Kanten", "EDGE_SPLIT")
        e.split_angle = math.radians(38)
    return ob


def bm_box(g, zittern=0.0, saat=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    rng = random.Random(saat)
    for v in bm.verts:
        v.co = Vector((v.co.x * g[0], v.co.y * g[1], v.co.z * g[2]))
        if zittern > 0:
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * zittern
    return bm


def holz_uv(bm, flaechen, achse, rng):
    """Schreibt Maserkoordinaten in zwei UV-Ebenen: längs der Faser (achse) und quer dazu."""
    uv1 = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.get("UVMap2") or bm.loops.layers.uv.new("UVMap2")
    a, b = [i for i in range(3) if i != achse]
    o = (rng.uniform(0, 30), rng.uniform(0, 8), rng.uniform(0, 8))
    z = rng.random()
    for f in flaechen:
        for l in f.loops:
            c = l.vert.co
            l[uv1].uv = (c[achse] + o[0], c[a] + o[1])
            l[uv2].uv = (c[b] + o[2], z)


def laengste_achse(g):
    return max(range(3), key=lambda i: g[i])


def bm_holz(gb, saat):
    """Holzteil. Große flache Flächen werden zu einzelnen Brettern mit Fugen."""
    rng = random.Random(saat)
    bm = bmesh.new()
    achsen = sorted(range(3), key=lambda i: gb[i])
    dick, quer, lang = achsen
    teile = []
    if gb[dick] <= 0.12 and gb[quer] > 0.45:
        n = max(2, int(round(gb[quer] / rng.uniform(0.15, 0.2))))
        breiten = [rng.uniform(0.8, 1.2) for _ in range(n)]
        summe = sum(breiten)
        pos = -gb[quer] * 0.5
        for br in breiten:
            w = gb[quer] * br / summe
            g = [0.0, 0.0, 0.0]
            g[dick] = gb[dick] * rng.uniform(0.92, 1.0)
            g[quer] = w - 0.006
            g[lang] = gb[lang] + rng.uniform(-0.012, 0.012)
            m = [0.0, 0.0, 0.0]
            m[quer] = pos + w * 0.5
            m[dick] = rng.uniform(-0.003, 0.003)
            m[lang] = rng.uniform(-0.006, 0.006)
            teile.append((g, m))
            pos += w
    else:
        teile.append((list(gb), [0.0, 0.0, 0.0]))
    for g, m in teile:
        vs = bmesh.ops.create_cube(bm, size=1.0)["verts"]
        zit = min(0.004, min(g) * 0.08)
        for v in vs:
            v.co = Vector((v.co.x * g[0] + m[0], v.co.y * g[1] + m[1], v.co.z * g[2] + m[2]))
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * zit
        fl = set()
        for v in vs:
            fl.update(v.link_faces)
        holz_uv(bm, fl, lang, rng)
    return bm


def bm_zylinder(r_oben, r_unten, h, seg):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=max(int(seg), 6), radius1=max(r_unten, 0.0001), radius2=max(r_oben, 0.0001), depth=h)
    return bm


def bm_kugel(r, hoehe, halb, rauh=0.0, saat=0):
    bm = bmesh.new()
    if rauh > 0:
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    else:
        bmesh.ops.create_uvsphere(bm, u_segments=18, v_segments=10, radius=r)
    voll = hoehe / (r if halb else 2.0 * r) if r > 0 else 1.0
    if halb:
        unten = [v for v in bm.verts if v.co.z < -1e-5]
        bmesh.ops.delete(bm, geom=unten, context="VERTS")
        rand = [e for e in bm.edges if e.is_boundary]
        if rand:
            try:
                bmesh.ops.holes_fill(bm, edges=rand)
            except Exception:
                pass
    v_off = Vector((saat * 0.37, saat * 0.11, saat * 0.23))
    for v in bm.verts:
        if rauh > 0 and (not halb or v.co.z > 1e-4):
            n = noise.noise(v.co * (1.6 / max(r, 0.01)) + v_off)
            v.co *= 1.0 + n * rauh
        v.co.z *= voll
    return bm


def torus_in(bm, r_innen, r_aussen, seg=28, rohr=10):
    """Fügt einen Ring (Achse Z) in ein bestehendes Netz ein und gibt seine Punkte zurück."""
    gross = (r_innen + r_aussen) * 0.5
    klein = (r_aussen - r_innen) * 0.5
    ringe = []
    for i in range(seg):
        a = math.tau * i / seg
        ring = []
        for j in range(rohr):
            b = math.tau * j / rohr
            rr = gross + math.cos(b) * klein
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, math.sin(b) * klein)))
        ringe.append(ring)
    for i in range(seg):
        for j in range(rohr):
            bm.faces.new((ringe[i][j], ringe[(i + 1) % seg][j], ringe[(i + 1) % seg][(j + 1) % rohr], ringe[i][(j + 1) % rohr]))
    return [v for ring in ringe for v in ring]


def bm_torus(r_innen, r_aussen, seg=28, rohr=10):
    bm = bmesh.new()
    torus_in(bm, r_innen, r_aussen, seg, rohr)
    return bm


def schindeln(platz, col, mat_info, g, W):
    """Ersetzt eine Dachplatte (Godot: x Breite, y Dicke, z Tiefe) durch Reihen einzelner Schindeln."""
    breite, dicke, tiefe = g[0], g[1], g[2]
    # Blender lokal: X Breite, Y Tiefe, Z Dicke. Traufe = das Ende, das in der Welt tiefer liegt.
    y_welt = (W.to_3x3() @ Vector((0, 1, 0))).z
    richtung = -1.0 if y_welt > 0 else 1.0     # zeigt von der Traufe zum First
    rng = random.Random(int(breite * 100) + int(tiefe * 1000))
    mat_info = dict(mat_info)
    mat_info["_schindel"] = True
    _daecher.append((platz, W.copy(), breite, tiefe, dicke, richtung, mat_info))
    bm = bmesh.new()
    lang, frei, stark = 0.36, 0.25, 0.03
    reihen = max(1, int(math.ceil(tiefe / frei)))
    neigung = math.atan2(stark * 1.1, frei)
    for r in range(reihen):
        s = -tiefe * 0.5 + r * frei + lang * 0.5 - 0.06
        x = -breite * 0.5 - (0.16 if r % 2 else 0.0)
        while x < breite * 0.5:
            b = rng.uniform(0.26, 0.36)
            x0, x1 = max(x, -breite * 0.5 - 0.03), min(x + b - 0.012, breite * 0.5 + 0.03)
            x += b
            if x1 - x0 < 0.06:
                continue
            teil = bmesh.ops.create_cube(bm, size=1.0)["verts"]
            lg = lang * rng.uniform(0.94, 1.06)
            m = (Matrix.Translation(((x0 + x1) * 0.5, richtung * (s + rng.uniform(-0.012, 0.012)), dicke * 0.5 + stark * 0.9))
                 @ Matrix.Rotation(richtung * -neigung + rng.uniform(-0.02, 0.02), 4, "X")
                 @ Matrix.Rotation(rng.uniform(-0.03, 0.03), 4, "Z")
                 @ Matrix.Diagonal((x1 - x0, lg, stark, 1.0)))
            bmesh.ops.transform(bm, matrix=m, verts=teil)
    ob = objekt(name_fuer(platz, "schindeln"), bm, col, material(mat_info), W, fase=0.0, glatt=False)
    # Unterlage, damit zwischen den Schindeln nichts durchscheint
    dunkel = dict(mat_info)
    dunkel["farbe"] = [v * 0.45 for v in mat_info.get("farbe", [0.4, 0.2, 0.1])]
    dunkel["kacheln"] = 0.0
    dunkel["rauheit"] = 0.9
    dunkel["u"] = dict(mat_info.get("u", {}))
    dunkel["u"]["farbe"] = ["c"] + dunkel["farbe"] + [1.0]
    dunkel["u"]["farbe2"] = ["c"] + [v * 0.8 for v in dunkel["farbe"]] + [1.0]
    dunkel["u"]["kacheln"] = 0.0
    objekt(name_fuer(platz, "dachlatte"), bm_box((breite, tiefe, dicke)), col, material(dunkel), W, fase=0.0, glatt=False)
    return ob


# --- Fremde Modelle (Kenney, KayKit) ------------------------------------------------
def extern(pfad, col, W, platz):
    datei = os.path.join(REPO, pfad.replace("res://", "").replace("/", os.sep))
    if not os.path.isfile(datei):
        print("  fehlt:", datei)
        return None
    if pfad not in _extern_cache:
        vorher = set(bpy.data.objects)
        try:
            bpy.ops.import_scene.gltf(filepath=datei)
        except Exception as e:
            print("  Import fehlgeschlagen:", datei, e)
            return None
        neu = [o for o in bpy.data.objects if o not in vorher]
        lager = bpy.data.collections.get("Fremdmodelle") or bpy.data.collections.new("Fremdmodelle")
        if lager.name not in [c.name for c in bpy.context.scene.collection.children]:
            bpy.context.scene.collection.children.link(lager)
        for o in neu:
            for c in list(o.users_collection):
                c.objects.unlink(o)
            lager.objects.link(o)
        _extern_cache[pfad] = [o for o in neu if o.parent is None]
        lager.hide_viewport = True
        lager.hide_render = True
    wurzel = bpy.data.objects.new(name_fuer(platz, os.path.basename(pfad).split(".")[0]), None)
    wurzel.empty_display_size = 0.15
    col.objects.link(wurzel)
    wurzel.matrix_basis = W

    def kopiere(o, eltern):
        k = o.copy()
        col.objects.link(k)
        k.parent = eltern
        for kind in o.children:
            kopiere(kind, k)
    for o in _extern_cache[pfad]:
        kopiere(o, wurzel)
    return wurzel


# --- Aufbau -------------------------------------------------------------------------
def hat_namen(n):
    return not any(n.startswith(s) for s in STANDARDNAMEN) and not n.startswith("_")


def baue_knoten(platz, d, col, W_eltern, eltern_ob, eltern_W):
    if d["n"].startswith("Figur_"):
        return      # Sammelfiguren setzt das Spiel selbst, sie gehören nicht zum Modell
    W = W_eltern @ xform(d["x"])
    t = d["t"]
    ob = None
    saat = len(bpy.data.objects)
    if t == "box":
        g = d["g"]
        m = d.get("mat", {})
        gb = (g[0], g[2], g[1])
        klein = min(g)
        if ist_ziegel(m) and klein <= 0.13 and sorted(g)[1] > 0.5:
            ob = schindeln(platz, col, m, g, W)
        else:
            holz = m.get("art") == "holz"
            stein = ist_stein(m)
            fase = min(0.035 if stein else 0.014, klein * 0.22)
            zittern = min(0.012 if stein else (0.004 if holz else 0.0), klein * 0.08)
            netz = bm_holz(gb, saat) if holz else bm_box(gb, zittern, saat)
            ob = objekt(name_fuer(platz, "stein" if stein else ("holz" if holz else "teil")), netz, col, material(m), W, fase, segmente=2 if stein else 1)
    elif t == "zyl":
        m = d.get("mat", {})
        seg = max(int(d.get("seg", 12)), 14) if max(d["r1"], d["r2"]) > 0.03 else max(int(d.get("seg", 8)), 6)
        netz = bm_zylinder(d["r1"], d["r2"], d["h"], seg)
        if m.get("art") == "holz":
            holz_uv(netz, netz.faces, 2, random.Random(saat))
        ob = objekt(name_fuer(platz, "rund"), netz, col, material(m), W,
                    fase=min(0.012, min(d["h"], max(d["r1"], d["r2"])) * 0.18))
    elif t == "kugel":
        m = d.get("mat", {})
        rauh = 0.16 if ist_stein(m) else (0.12 if (ist_weich(m) or m.get("art") == "laub") else 0.0)
        netz = bm_kugel(d["r"], d["hh"], d["halb"], rauh, saat)
        if m.get("art") == "holz":
            holz_uv(netz, netz.faces, 2, random.Random(saat))
        ob = objekt(name_fuer(platz, "form"), netz, col, material(m), W)
    elif t == "torus":
        netz = bm_torus(d["r1"], d["r2"])
        if d.get("mat", {}).get("art") == "holz":
            holz_uv(netz, netz.faces, 0, random.Random(saat))
        ob = objekt(name_fuer(platz, "ring"), netz, col, material(d.get("mat", {})), W)
    elif t == "text":
        kurve = bpy.data.curves.new(name_fuer(platz, "schrift"), "FONT")
        kurve.body = d["text"]
        kurve.size = d["hoehe"] * 0.72
        kurve.align_x = "CENTER"
        kurve.align_y = "CENTER"
        kurve.extrude = 0.0
        kurve.resolution_u = 2
        if _schrift():
            kurve.font = _schrift()
        ob = bpy.data.objects.new(kurve.name, kurve)
        col.objects.link(ob)
        kurve.offset = d["hoehe"] * 0.018       # etwas fetter, wie die Schrift im Spiel
        # 4 mm vor die Fläche: echte Bretter sind nicht ganz eben, die Schrift soll nicht versinken
        ob.matrix_basis = W @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Translation((0, 0, 0.004))
        farbe = d.get("farbe", [0.1, 0.1, 0.1])
        if 0.3 * farbe[0] + 0.6 * farbe[1] + 0.1 * farbe[2] > 0.45:
            # Im Spiel war die helle Schrift schwarz umrandet. Als Netz wirkt eingebrannte,
            # dunkle Schrift auf Holz ehrlicher und bleibt lesbar.
            farbe = [0.13, 0.08, 0.05]
        kurve.materials.append(material({"art": "std", "farbe": farbe, "rauheit": 0.95}))
    elif t == "extern":
        ob = extern(d["pfad"], col, W, platz)
    elif t in ("koll_box", "koll_zyl"):
        if t == "koll_box":
            g = d["g"]
            bm = bm_box((g[0], g[2], g[1]))
        else:
            bm = bm_zylinder(d["r"], d["r"], d["h"], 10)
        ob = objekt(name_fuer(platz, "koll") + "-colonly", bm, col, None, W, glatt=False)
        ob.display_type = "WIRE"
        ob.hide_render = True
    elif t == "node" and hat_namen(d["n"]):
        ob = bpy.data.objects.new(d["n"], None)
        ob.empty_display_size = 0.2
        col.objects.link(ob)
        ob.matrix_basis = W
    if ob is not None:
        if hat_namen(d["n"]) and t != "node":
            ob.name = d["n"]
        ob["dn_godot"] = d["n"]
        if eltern_ob is not None:
            welt = ob.matrix_basis.copy()
            ob.parent = eltern_ob
            ob.matrix_parent_inverse = eltern_W.inverted()
            ob.matrix_basis = welt
    # Kinder: benannte Leerobjekte werden Eltern, alles andere reicht nur die Lage weiter
    if t == "node" and ob is not None:
        for k in d.get("k", []):
            baue_knoten(platz, k, col, W, ob, W)
    else:
        for k in d.get("k", []):
            baue_knoten(platz, k, col, W, eltern_ob, eltern_W)


_font = [None, False]


def _schrift():
    if not _font[1]:
        _font[1] = True
        p = os.path.join(REPO, "fonts", "Fredoka.ttf")
        if os.path.isfile(p):
            try:
                _font[0] = bpy.data.fonts.load(p)
            except Exception:
                _font[0] = None
    return _font[0]


def leere_collection(name, eltern):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        eltern.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return col


def baue_platz(daten, index, haupt):
    name = daten["name"]
    for k in [k for k in _zaehler if k[0] == name]:
        del _zaehler[k]
    col = leere_collection("MP_" + name, haupt)
    wurzel = bpy.data.objects.new(name, None)
    wurzel.empty_display_type = "ARROWS"
    wurzel.empty_display_size = 0.5
    col.objects.link(wurzel)
    W = Matrix.Translation(((index % SPALTEN) * RASTER, -(index // SPALTEN) * RASTER, 0.0))
    wurzel.matrix_basis = W
    del _daecher[:]
    for d in daten["k"]:
        baue_knoten(name, d, col, W, wurzel, W)
    firste(name, col, wurzel, W)
    if name in VEREDELN:
        VEREDELN[name](name, col, wurzel, W)
    return len(col.objects)


# --- Veredelung -------------------------------------------------------------------
def haenge_an(ob, eltern, eltern_W=None):
    welt = ob.matrix_basis.copy()
    if eltern_W is None:
        bpy.context.view_layer.update()
    ob.parent = eltern
    ob.matrix_parent_inverse = (eltern_W if eltern_W is not None else eltern.matrix_world).inverted()
    ob.matrix_basis = welt


def firste(platz, col, wurzel, W_wurzel):
    """Wo zwei Schindeldächer am First zusammenstoßen, kommt eine Reihe Firstziegel darauf."""
    linien = []
    for (p, W, breite, tiefe, dicke, richtung, mat_info) in _daecher:
        a = W @ Vector((-breite * 0.5, richtung * tiefe * 0.5, dicke * 0.5))
        b = W @ Vector((breite * 0.5, richtung * tiefe * 0.5, dicke * 0.5))
        linien.append((a, b, mat_info))
    benutzt = set()
    rng = random.Random(len(linien) * 31 + len(platz))
    for i in range(len(linien)):
        for j in range(i + 1, len(linien)):
            if i in benutzt or j in benutzt:
                continue
            a1, b1, m1 = linien[i]
            a2, b2, _m2 = linien[j]
            if (a1 - a2).length > (a1 - b2).length:
                a2, b2 = b2, a2
            if (a1 - a2).length > 0.4 or (b1 - b2).length > 0.4:
                continue
            benutzt.update((i, j))
            a, b = (a1 + a2) * 0.5, (b1 + b2) * 0.5
            d = (b - a)
            laenge = d.length
            if laenge < 0.3:
                continue
            x = d.normalized()
            z = Vector((0, 0, 1))
            y = z.cross(x).normalized()
            z = x.cross(y)
            R = Matrix((x, y, z)).transposed().to_4x4()
            bm = bmesh.new()
            n = max(1, int(round(laenge / 0.3)))
            for k in range(n):
                t = (k + 0.5) / n
                teil = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.085, radius2=0.075, depth=laenge / n + 0.07)["verts"]
                m = (Matrix.Translation(a.lerp(b, t) + Vector((0, 0, 0.02 + rng.uniform(-0.006, 0.006)))) @ R
                     @ Matrix.Rotation(rng.uniform(-0.04, 0.04), 4, "Z") @ Matrix.Rotation(rng.uniform(-0.03, 0.03) + 0.05, 4, "Y")
                     @ Matrix.Diagonal((1.0, 1.0, 0.62, 1.0)) @ Matrix.Rotation(math.radians(90), 4, "Y"))
                bmesh.ops.transform(bm, matrix=m, verts=teil)
            ob = objekt(name_fuer(platz, "first"), bm, col, material(m1), Matrix.Identity(4), glatt=True)
            haenge_an(ob, wurzel, W_wurzel)


def _finde(col, godot_name):
    for o in col.objects:
        if o.get("dn_godot", "") == godot_name:
            return o
    return None


def _g(W, x, y, z):
    """Punkt in Godot-Koordinaten des Modells (y nach oben, z nach vorn) -> Blender-Welt."""
    return W @ Vector((x, -z, y))


MOOS = {"art": "putz", "shader": "res://shaders/putz.gdshader", "farbe": [0.3, 0.42, 0.18], "farbe2": [0.22, 0.33, 0.13], "rauheit": 1.0, "kacheln": 0.0,
        "u": {"farbe": ["c", 0.3, 0.42, 0.18, 1.0], "farbe2": ["c", 0.22, 0.33, 0.13, 1.0], "koernung": 90.0, "rauheit": 1.0, "kacheln": 0.0}}
FELDSTEIN = {"art": "putz", "shader": "res://shaders/putz.gdshader", "farbe": [0.6, 0.57, 0.52], "farbe2": [0.46, 0.44, 0.4], "rauheit": 0.95, "kacheln": 0.0,
             "u": {"farbe": ["c", 0.6, 0.57, 0.52, 1.0], "farbe2": ["c", 0.46, 0.44, 0.4, 1.0], "koernung": 26.0, "rauheit": 0.95, "kacheln": 0.0}}
SEIL = {"art": "std", "farbe": [0.75, 0.68, 0.5], "rauheit": 0.95}


def polster(platz, col, wurzel, W, punkte, mat_info, art="moos", flach=0.35, saat=1):
    """Kleine unregelmäßige Hügel (Moos, Feldsteine). punkte: (x, y, z, radius) in Godot-Koordinaten."""
    rng = random.Random(saat)
    bm = bmesh.new()
    for (x, y, z, r) in punkte:
        teil = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)["verts"]
        v_off = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
        for v in teil:
            v.co *= 1.0 + noise.noise(v.co * (1.7 / r) + v_off) * 0.22
            v.co.z *= flach
        m = Matrix.Translation(_g(Matrix.Identity(4), x, y, z)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z") @ Matrix.Diagonal((1.0, rng.uniform(0.7, 1.0), 1.0, 1.0))
        bmesh.ops.transform(bm, matrix=m, verts=teil)
    ob = objekt(name_fuer(platz, art), bm, col, material(mat_info), W, glatt=True)
    haenge_an(ob, wurzel, W)
    return ob


def veredle_brunnen(platz, col, wurzel, W):
    rng = random.Random(7)
    # Seil auf der Welle: ein paar unordentliche Windungen, dreht sich mit der Kurbel
    kurbel = _finde(col, "Kurbel")
    bm = bmesh.new()
    for i in range(7):
        vs = torus_in(bm, 0.062, 0.092, 14, 6)
        m = (Matrix.Translation(_g(Matrix.Identity(4), -0.1 + i * 0.033 + rng.uniform(-0.004, 0.004), 1.75, 0))
             @ Matrix.Rotation(math.radians(90) + rng.uniform(-0.09, 0.09), 4, "Y") @ Matrix.Rotation(rng.uniform(-0.08, 0.08), 4, "X"))
        bmesh.ops.transform(bm, matrix=m, verts=vs)
    seil = objekt(name_fuer(platz, "seilwickel"), bm, col, material(SEIL), W, glatt=True)
    haenge_an(seil, kurbel if kurbel else wurzel, None if kurbel else W)
    # Moos am Fuß und auf dem Rand, lose Feldsteine im Gras
    moos = []
    for i in range(9):
        w = rng.uniform(0, math.tau)
        r = rng.uniform(0.86, 0.98)
        moos.append((math.cos(w) * r, rng.uniform(0.0, 0.1), math.sin(w) * r, rng.uniform(0.09, 0.17)))
    for i in range(4):
        w = rng.uniform(2.2, 4.4)
        moos.append((math.cos(w) * 0.72, 0.82, math.sin(w) * 0.72, rng.uniform(0.07, 0.11)))
    polster(platz, col, wurzel, W, moos, MOOS, "moos", 0.45, 3)
    steine = []
    for i in range(6):
        w = rng.uniform(0, math.tau)
        r = rng.uniform(1.1, 1.5)
        steine.append((math.cos(w) * r, 0.02, math.sin(w) * r, rng.uniform(0.07, 0.15)))
    polster(platz, col, wurzel, W, steine, FELDSTEIN, "feldstein", 0.7, 5)


VEREDELN = {"brunnen": veredle_brunnen}


def szene_einrichten():
    sz = bpy.context.scene
    sz.unit_settings.system = "METRIC"
    sz.unit_settings.scale_length = 1.0
    for n in ("Cube",):
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
    sonne = bpy.data.objects.get("Sonne")
    if sonne is None:
        licht = bpy.data.lights.new("Sonne", "SUN")
        sonne = bpy.data.objects.new("Sonne", licht)
        sz.collection.objects.link(sonne)
    sonne.data.energy = 3.2
    sonne.data.color = (1.0, 0.9, 0.76)
    sonne.data.angle = math.radians(3.0)
    sonne.rotation_euler = (math.radians(52), 0.0, math.radians(35))
    alt = bpy.data.objects.get("Light")
    if alt:
        bpy.data.objects.remove(alt, do_unlink=True)
    welt = sz.world or bpy.data.worlds.new("Welt")
    sz.world = welt
    welt.use_nodes = True
    hg = next((n for n in welt.node_tree.nodes if n.type == "BACKGROUND"), None)
    if hg:
        hg.inputs[0].default_value = (0.62, 0.74, 0.9, 1.0)
        hg.inputs[1].default_value = 0.9


def baue_alles(nur=None):
    """Baut alle Modellplätze neu (oder nur die genannten) und speichert die .blend."""
    with open(JSON_PFAD, encoding="utf-8") as f:
        alle = json.load(f)
    szene_einrichten()
    haupt = bpy.data.collections.get("Modellplaetze")
    if haupt is None:
        haupt = bpy.data.collections.new("Modellplaetze")
        bpy.context.scene.collection.children.link(haupt)
    bericht = []
    for i, daten in enumerate(alle):
        if nur and daten["name"] not in nur:
            continue
        try:
            n = baue_platz(daten, i, haupt)
            bericht.append("%s:%d" % (daten["name"], n))
        except Exception as e:
            import traceback
            bericht.append("%s:FEHLER %s" % (daten["name"], e))
            traceback.print_exc()
    os.makedirs(os.path.dirname(BLEND_PFAD), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PFAD)
    print("Gebaut:", ", ".join(bericht))
    print("Gespeichert:", BLEND_PFAD)
