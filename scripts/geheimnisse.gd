class_name Geheimnisse
extends Node3D
## Alle Geheimnisse des Haselgrunds und das Fundbuch (Etappe 4).

var welt: Node


func _init(w: Node) -> void:
	welt = w
	name = "Geheimnisse"
