class_name Look
extends RefCounted
## Alle Materialien und die Schrift an einer Stelle. Materialien sind prozedurale Shader
## (keine Texturdateien) und werden zwischengespeichert, damit gleiche Teile sich eins teilen.

const SH_HOLZ := preload("res://shaders/holz.gdshader")
const SH_PUTZ := preload("res://shaders/putz.gdshader")
const SH_NUSS := preload("res://shaders/nuss.gdshader")
const SH_KERN := preload("res://shaders/kern.gdshader")
const SH_GRAS := preload("res://shaders/gras.gdshader")
const SH_HALM := preload("res://shaders/halm.gdshader")
const SH_LAUB := preload("res://shaders/laub.gdshader")
const SH_HERVOR := preload("res://shaders/hervorheben.gdshader")
const SCHRIFT_DATEI := preload("res://fonts/Fredoka.ttf")

# Holzfarben (hell, dunkel)
const EICHE := [Color(0.74, 0.55, 0.35), Color(0.5, 0.33, 0.19)]
const NUSSBAUM := [Color(0.5, 0.33, 0.2), Color(0.28, 0.17, 0.09)]
const KIEFER := [Color(0.86, 0.7, 0.48), Color(0.66, 0.48, 0.3)]
const ALTHOLZ := [Color(0.55, 0.45, 0.35), Color(0.35, 0.27, 0.2)]

static var _cache := {}
static var _schriften := {}


static func _hole(schluessel: String, bauen: Callable) -> Material:
	if not _cache.has(schluessel):
		_cache[schluessel] = bauen.call()
	return _cache[schluessel]


static func holz(farben: Array = EICHE, ringdichte := 7.0, lack := 0.0, dielen := 0.0, welt := false) -> ShaderMaterial:
	var k := "holz|%s|%s|%.1f|%.2f|%.2f|%s" % [farben[0].to_html(), farben[1].to_html(), ringdichte, lack, dielen, welt]
	return _hole(k, func():
		var m := ShaderMaterial.new()
		m.shader = SH_HOLZ
		m.set_shader_parameter("farbe_hell", farben[0])
		m.set_shader_parameter("farbe_dunkel", farben[1])
		m.set_shader_parameter("ringdichte", ringdichte)
		m.set_shader_parameter("lack", lack)
		m.set_shader_parameter("dielen_breite", dielen)
		m.set_shader_parameter("welt_koordinaten", welt)
		m.set_shader_parameter("abnutzung", 0.6 if dielen > 0.0 else 0.2)
		return m)


static func lackiert(farbe: Color, glanz := 0.6) -> ShaderMaterial:
	return holz([farbe.lightened(0.08), farbe.darkened(0.25)], 3.0, glanz)


static func putz(farbe: Color, farbe2 := Color(-1, 0, 0), koernung := 60.0, kacheln := 0.0, rauheit := 0.92) -> ShaderMaterial:
	if farbe2.r < 0.0:
		farbe2 = farbe.darkened(0.1)
	var k := "putz|%s|%s|%.0f|%.2f|%.2f" % [farbe.to_html(), farbe2.to_html(), koernung, kacheln, rauheit]
	return _hole(k, func():
		var m := ShaderMaterial.new()
		m.shader = SH_PUTZ
		m.set_shader_parameter("farbe", farbe)
		m.set_shader_parameter("farbe2", farbe2)
		m.set_shader_parameter("koernung", koernung)
		m.set_shader_parameter("kacheln", kacheln)
		m.set_shader_parameter("rauheit", rauheit)
		return m)


## Nusshaufen aus der Ferne: lauter runde Knubbel.
static func nusshaufen(groesse := 0.16) -> ShaderMaterial:
	return _hole("haufen|%.2f" % groesse, func():
		var m := ShaderMaterial.new()
		m.shader = SH_PUTZ
		m.set_shader_parameter("kiesel", groesse)
		m.set_shader_parameter("fugenfarbe", Color(0.22, 0.14, 0.08))
		m.set_shader_parameter("beule_staerke", 12.0)
		m.set_shader_parameter("rauheit", 0.8)
		return m)


static func metall(farbe: Color, rauheit := 0.35) -> StandardMaterial3D:
	var k := "metall|%s|%.2f" % [farbe.to_html(), rauheit]
	return _hole(k, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = farbe
		m.metallic = 0.9
		m.roughness = rauheit
		return m)


static func plastik(farbe: Color, rauheit := 0.45) -> StandardMaterial3D:
	var k := "plastik|%s|%.2f" % [farbe.to_html(), rauheit]
	return _hole(k, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = farbe
		m.roughness = rauheit
		return m)


static func stoff(farbe: Color) -> ShaderMaterial:
	return putz(farbe, farbe.darkened(0.15), 220.0, 0.0, 1.0)


static func glas(tint := Color(0.85, 0.95, 1.0)) -> StandardMaterial3D:
	var k := "glas|%s" % tint.to_html()
	return _hole(k, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(tint.r, tint.g, tint.b, 0.16)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.04
		m.metallic_specular = 0.9
		m.rim_enabled = true
		m.rim = 0.4
		m.rim_tint = 0.2
		m.cull_mode = BaseMaterial3D.CULL_BACK
		return m)


static func leuchten(farbe: Color, staerke := 2.0) -> StandardMaterial3D:
	var k := "leuchten|%s|%.1f" % [farbe.to_html(), staerke]
	return _hole(k, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = farbe
		m.emission_enabled = true
		m.emission = farbe
		m.emission_energy_multiplier = staerke
		return m)


## Nussschale. "eigen" = eigenes Material (für Risse/Druck an genau dieser Nuss).
static func nuss(id: String, gold := false, faul := false, eigen := false, instanzfarbe := false) -> ShaderMaterial:
	var k := "nuss|%s|%s|%s|%s" % [id, gold, faul, instanzfarbe]
	if eigen:
		return _nuss_bauen(id, gold, faul, instanzfarbe)
	return _hole(k, func(): return _nuss_bauen(id, gold, faul, instanzfarbe))


static func _nuss_bauen(id: String, gold: bool, faul: bool, instanzfarbe: bool) -> ShaderMaterial:
	var info: Dictionary = Data.NUESSE[id]
	var m := ShaderMaterial.new()
	m.shader = SH_NUSS
	m.set_shader_parameter("farbe", info.farbe)
	m.set_shader_parameter("farbe2", info.farbe2)
	m.set_shader_parameter("art", int(info.muster))
	m.set_shader_parameter("radius", float(info.groesse))
	m.set_shader_parameter("gold", 1.0 if gold else 0.0)
	m.set_shader_parameter("faul", 1.0 if faul else 0.0)
	m.set_shader_parameter("saat", randf() * 10.0 if instanzfarbe == false else 0.0)
	m.set_shader_parameter("instanzfarbe", instanzfarbe)
	return m


static func schale_innen(id: String) -> ShaderMaterial:
	return _hole("innen|" + id, func():
		var info: Dictionary = Data.NUESSE[id]
		var m := ShaderMaterial.new()
		m.shader = SH_NUSS
		m.set_shader_parameter("farbe", info.farbe.lightened(0.35))
		m.set_shader_parameter("farbe2", info.farbe.lightened(0.1))
		m.set_shader_parameter("art", 9)
		m.set_shader_parameter("radius", float(info.groesse))
		return m)


static func kern(id: String, gold := false, instanzfarbe := false) -> ShaderMaterial:
	return _hole("kern|%s|%s|%s" % [id, gold, instanzfarbe], func():
		var info: Dictionary = Data.NUESSE[id]
		var m := ShaderMaterial.new()
		m.shader = SH_KERN
		m.set_shader_parameter("farbe", info.kern)
		m.set_shader_parameter("farbe2", info.kern2)
		m.set_shader_parameter("radius", float(info.groesse))
		m.set_shader_parameter("falten", float(info.falten))
		m.set_shader_parameter("gold", 1.0 if gold else 0.0)
		m.set_shader_parameter("instanzfarbe", instanzfarbe)
		return m)


static func gras() -> ShaderMaterial:
	return _hole("gras", func():
		var m := ShaderMaterial.new()
		m.shader = SH_GRAS
		return m)


static func halm() -> ShaderMaterial:
	return _hole("halm", func():
		var m := ShaderMaterial.new()
		m.shader = SH_HALM
		return m)


static func laub(farbe: Color, farbe2: Color) -> ShaderMaterial:
	return _hole("laub|%s|%s" % [farbe.to_html(), farbe2.to_html()], func():
		var m := ShaderMaterial.new()
		m.shader = SH_LAUB
		m.set_shader_parameter("farbe", farbe)
		m.set_shader_parameter("farbe2", farbe2)
		return m)


static func hervorheben() -> ShaderMaterial:
	return _hole("hervor", func():
		var m := ShaderMaterial.new()
		m.shader = SH_HERVOR
		return m)


## Fredoka in einer bestimmten Stärke (400 normal, 500 mittel, 600 halbfett).
static func schrift(staerke := 500) -> Font:
	if not _schriften.has(staerke):
		var f := FontVariation.new()
		f.base_font = SCHRIFT_DATEI
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): staerke}
		_schriften[staerke] = f
	return _schriften[staerke]


## Setzt (oder entfernt) den Leuchtrand an allen Meshes unter einem Knoten.
static func markiere(knoten: Node, an: bool) -> void:
	if knoten == null or not is_instance_valid(knoten):
		return
	var m: Material = hervorheben() if an else null
	_markiere_rekursiv(knoten, m)


static func _markiere_rekursiv(n: Node, m: Material) -> void:
	if n is GeometryInstance3D and not (n is Label3D) and not n.has_meta("ohne_rand"):
		n.material_overlay = m
	for c in n.get_children():
		_markiere_rekursiv(c, m)
