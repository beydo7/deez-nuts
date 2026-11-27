class_name NussFlug
extends Node3D
## Nüsse, die vom Berg zum Spieler (oder zu einem Trichter) fliegen. Rein optisch, ohne Physik.
## Ein Pool aus MultiMeshes pro Sorte hält das auch bei hunderten Nüssen pro Sekunde flüssig.

const MAX := 160

var _fluege: Array = []      # {von, ziel(Callable), t, dauer, nuss, dreh, hoch}
var _multis := {}            # nuss -> MultiMeshInstance3D
var _tick_timer := 0.0


func _ready() -> void:
	for id in Data.NUESSE:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Nussmodelle.ganz(id, 2, 0)
		mmi.multimesh = mm
		mmi.material_override = Look.nuss(id)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_multis[id] = mmi


## Startet eine fliegende Nuss. ziel liefert die aktuelle Zielposition (das Ziel darf sich bewegen).
func starte(von: Vector3, nuss: String, ziel: Callable, dauer := 0.35, hoch := 0.5) -> void:
	if _fluege.size() >= MAX:
		return
	_fluege.append({"von": von, "ziel": ziel, "t": 0.0, "dauer": dauer * randf_range(0.85, 1.2), "nuss": nuss,
		"dreh": Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12)), "hoch": hoch * randf_range(0.6, 1.3),
		"seite": Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))})


func anzahl() -> int:
	return _fluege.size()


func _process(delta: float) -> void:
	var listen := {}
	for id in _multis:
		listen[id] = []
	var fertig := 0
	for i in range(_fluege.size() - 1, -1, -1):
		var f: Dictionary = _fluege[i]
		f.t += delta / f.dauer
		if f.t >= 1.0 or not f.ziel.is_valid():
			_fluege.remove_at(i)
			fertig += 1
			continue
		var ende: Vector3 = f.ziel.call()
		var t: float = f.t
		var e := t * t * (3.0 - 2.0 * t)
		var p: Vector3 = f.von.lerp(ende, e) + Vector3.UP * sin(t * PI) * f.hoch + f.seite * sin(t * PI)
		var s := 1.4 * (1.0 - t * 0.6)
		var b := Basis.from_euler(f.dreh * t).scaled(Vector3.ONE * s)
		listen[f.nuss].append(Transform3D(b, p))
	for id in _multis:
		var mm: MultiMesh = _multis[id].multimesh
		var l: Array = listen[id]
		mm.instance_count = l.size()
		for j in l.size():
			mm.set_instance_transform(j, l[j])
	_tick_timer -= delta
	if fertig > 0 and _tick_timer <= 0.0:
		_tick_timer = 0.045
		Sfx.spiele("rollen", -16.0, randf_range(1.1, 1.5), 0.1)
