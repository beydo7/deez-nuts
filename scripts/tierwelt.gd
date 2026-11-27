class_name Tierwelt
extends Node3D
## Vögel, Hühner, Schmetterlinge, Glühwürmchen, Rauch (Etappe 5).

var welt: Node


func _init(w: Node) -> void:
	welt = w
	name = "Tierwelt"
