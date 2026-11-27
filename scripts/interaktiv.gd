class_name Interaktiv
extends StaticBody3D
## Etwas, das man mit [E] benutzt: Hebel, Telefon, Talentbaum, Eichhörnchen-Glocke ...

var text := "Benutzen"
var aktion: Callable


static func erzeuge(eltern: Node3D, groesse: Vector3, pos: Vector3, hinweis: String, rueckruf: Callable, sichtbar := false, farbe := Color.WHITE) -> Interaktiv:
	var i := Interaktiv.new()
	i.text = hinweis
	i.aktion = rueckruf
	i.collision_layer = Data.L_INTERAKT
	i.collision_mask = 0
	i.position = pos
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = groesse
	cs.shape = b
	i.add_child(cs)
	if sichtbar:
		i.add_child(Bau.mesh_instanz(Bau.box_mesh(groesse), Bau.mat(farbe)))
	eltern.add_child(i)
	return i


func benutzen(spieler: Node) -> void:
	if aktion.is_valid():
		aktion.call(spieler)
